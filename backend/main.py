"""
Recognition Based Automated Attendance System - Main FastAPI Application
"""
import os
import io
import csv
import json
import uuid
import secrets
import asyncio
from datetime import datetime, date, timedelta
from typing import List, Optional
from math import ceil

from dotenv import load_dotenv
from fastapi import FastAPI, Depends, HTTPException, status, UploadFile, File, Query, Form, Request
from fastapi.responses import JSONResponse, StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from sqlalchemy import func

from database import (
    get_db, SessionLocal, User, Attendance, Class, Student, init_db,
    PasswordResetToken, LeaveRequest, Setting, AuditLog, QRSession, Notification
)
from models import (
    Token, UserCreate, UserLogin, UserUpdate, UserResponse, UserWithToken,
    AttendanceCreate, AttendanceResponse, AttendanceStats, AttendanceReport, AttendanceUpdate,
    AttendanceManualCreate, PaginatedAttendance,
    FaceRegistrationResponse, FaceRecognitionResult, DashboardStats, RoomScanResponse,
    ClassCreate, ClassUpdate, ClassResponse, StudentResponse, StudentRegistrationResponse,
    DetectedObject, ExamProctorResponse,
    ForgotPasswordRequest, ResetPasswordRequest, ChangePasswordRequest, PasswordResetTokenResponse,
    LeaveRequestCreate, LeaveRequestReview, LeaveRequestResponse,
    SettingUpdate, SettingResponse, SettingsBulkUpdate, AppSettings,
    AuditLogResponse, PaginatedAuditLog,
    QRSessionCreate, QRSessionResponse, QRAttendanceRequest,
    NotificationResponse, NotificationMarkRead, UnreadCountResponse,
    RollCallSubmit, RollCallResponse,
    BulkImportResponse,
)
from auth import (
    get_password_hash, verify_password, create_access_token, authenticate_user,
    get_current_user, get_current_active_user, get_current_admin_user
)
from face_service import face_service, exam_proctor_service
import face_recognition

load_dotenv()

# Initialize FastAPI app
app = FastAPI(
    title="Recognition Based Automated Attendance System",
    description="Backend API for facial recognition attendance tracking",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS middleware — read from env in production
_allowed_origins = os.getenv("ALLOWED_ORIGINS", "*").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ========================
# GLOBAL EXCEPTION HANDLER
# ========================

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    import traceback
    tb = traceback.format_exc()
    print(f"Unhandled error on {request.method} {request.url}: {exc}\n{tb}")
    # Never expose traceback to clients
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal Server Error. Please contact the administrator."}
    )


# ========================
# HELPERS
# ========================

def _get_settings(db: Session) -> AppSettings:
    """Load all settings from DB into an AppSettings object."""
    rows = db.query(Setting).all()
    raw = {r.key: r.value for r in rows}
    return AppSettings(
        late_threshold_hour=int(raw.get("late_threshold_hour", 9)),
        late_threshold_minute=int(raw.get("late_threshold_minute", 0)),
        min_face_images=int(raw.get("min_face_images", 3)),
        max_face_images=int(raw.get("max_face_images", 10)),
        attendance_alert_pct=float(raw.get("attendance_alert_pct", 75)),
        qr_session_minutes=int(raw.get("qr_session_minutes", 15)),
        allow_manual_entry=raw.get("allow_manual_entry", "true").lower() == "true",
        allow_qr_attendance=raw.get("allow_qr_attendance", "true").lower() == "true",
        allow_face_attendance=raw.get("allow_face_attendance", "true").lower() == "true",
        app_name=raw.get("app_name", "Face Attendance System"),
    )


def _write_audit(
    db: Session,
    actor_id: Optional[int],
    action: str,
    target_type: Optional[str] = None,
    target_id: Optional[int] = None,
    detail: Optional[str] = None,
    ip_address: Optional[str] = None,
):
    """Helper to write an audit log entry."""
    try:
        log = AuditLog(
            actor_id=actor_id,
            action=action,
            target_type=target_type,
            target_id=target_id,
            detail=detail,
            ip_address=ip_address,
        )
        db.add(log)
        db.flush()
    except Exception as e:
        print(f"Warning: audit log write failed: {e}")


def _push_notification(
    db: Session,
    user_id: int,
    title: str,
    message: str,
    notif_type: str = "system",
    related_type: Optional[str] = None,
    related_id: Optional[int] = None,
):
    """Create an in-app notification for a user."""
    try:
        notif = Notification(
            user_id=user_id,
            title=title,
            message=message,
            type=notif_type,
            related_type=related_type,
            related_id=related_id,
        )
        db.add(notif)
        db.flush()
    except Exception as e:
        print(f"Warning: notification push failed: {e}")


def _parse_face_encoding(raw_encoding: Optional[str]) -> Optional[List[float]]:
    """Parse JSON face encoding safely."""
    if not raw_encoding:
        return None
    try:
        return json.loads(raw_encoding)
    except Exception:
        return None


def _student_to_user_response(student: Student, class_name: Optional[str]) -> UserResponse:
    """Map Student model to UserResponse-compatible payload."""
    return UserResponse(
        id=student.id,
        email=f"student{student.id}@student.example.com",
        full_name=student.name,
        phone=None,
        department=class_name,
        role="student",
        has_registered_face=student.has_registered_face,
        is_active=True,
        is_verified=True,
        created_at=student.created_at or datetime.utcnow()
    )


def _split_meeting_days(raw_days: Optional[str]) -> List[str]:
    if not raw_days:
        return []
    return [day for day in raw_days.split(",") if day]


def _normalize_meeting_days(days: Optional[List[str]]) -> Optional[str]:
    if not days:
        return None
    normalized = []
    seen = set()
    for day in days:
        value = (day or "").strip().title()
        if not value or value in seen:
            continue
        seen.add(value)
        normalized.append(value)
    return ",".join(normalized) if normalized else None


def _class_to_response(class_obj: Class, db: Session) -> ClassResponse:
    return ClassResponse(
        id=class_obj.id,
        name=class_obj.name,
        teacher_id=class_obj.teacher_id,
        subject=class_obj.subject,
        room=class_obj.room,
        start_time=class_obj.start_time,
        end_time=class_obj.end_time,
        meeting_days=_split_meeting_days(class_obj.meeting_days),
        created_at=class_obj.created_at,
        student_count=db.query(Student).filter(Student.class_id == class_obj.id).count(),
    )


def _user_to_response(user: User) -> UserResponse:
    """Safely map User model to UserResponse."""
    return UserResponse(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        phone=user.phone,
        department=user.department,
        role=user.role,
        has_registered_face=user.has_registered_face,
        is_active=user.is_active,
        is_verified=user.is_verified,
        created_at=user.created_at or datetime.utcnow()
    )


def _managed_student_email(student_id: int) -> str:
    return f"managed_student_{student_id}@local.attendance"


def _ensure_student_linked_user(db: Session, student: Student, class_obj: Optional[Class] = None) -> User:
    """Ensure each managed class-student has a stable backing user id."""
    managed_user = None
    if student.linked_user_id:
        managed_user = db.query(User).filter(User.id == student.linked_user_id).first()

    if managed_user is None:
        managed_user = db.query(User).filter(User.email == _managed_student_email(student.id)).first()

    if class_obj is None:
        class_obj = db.query(Class).filter(Class.id == student.class_id).first()

    if managed_user is None:
        managed_user = User(
            email=_managed_student_email(student.id),
            full_name=student.name,
            hashed_password=get_password_hash(secrets.token_urlsafe(24)),
            phone=None,
            department=class_obj.name if class_obj else None,
            role="managed_student",
            has_registered_face=False,
            is_active=True,
            is_verified=True,
            verification_token=None,
        )
        db.add(managed_user)
        db.flush()

    managed_user.full_name = student.name
    managed_user.department = class_obj.name if class_obj else managed_user.department
    managed_user.role = "managed_student"
    managed_user.is_active = True
    managed_user.is_verified = True
    student.linked_user_id = managed_user.id
    db.flush()
    return managed_user


def _attendance_to_response(db: Session, attendance: Attendance) -> AttendanceResponse:
    student = None
    class_obj = None
    if attendance.student_id is not None:
        student = db.query(Student).filter(Student.id == attendance.student_id).first()
    if attendance.class_id is not None:
        class_obj = db.query(Class).filter(Class.id == attendance.class_id).first()
    elif student is not None:
        class_obj = db.query(Class).filter(Class.id == student.class_id).first()

    response = AttendanceResponse.model_validate(attendance)
    response.user = None
    if attendance.user and attendance.user.role != "managed_student":
        response.user = UserResponse.model_validate(attendance.user)
    response.student_name = student.name if student else (
        attendance.user.full_name if attendance.user and attendance.user.role == "managed_student" else None
    )
    response.class_name = class_obj.name if class_obj else (
        attendance.user.department if attendance.user and attendance.user.role == "managed_student" else None
    )
    return response


def _leave_to_response(leave: LeaveRequest) -> LeaveRequestResponse:
    return LeaveRequestResponse(
        id=leave.id,
        user_id=leave.user_id,
        student_id=leave.student_id,
        submitted_by_id=leave.submitted_by_id,
        leave_date=leave.leave_date,
        reason=leave.reason,
        status=leave.status,
        reviewed_by_id=leave.reviewed_by_id,
        reviewed_at=leave.reviewed_at,
        review_note=leave.review_note,
        created_at=leave.created_at,
        updated_at=leave.updated_at,
        user_name=leave.user.full_name if leave.user else None,
        student_name=leave.student.name if leave.student else None,
        submitted_by_name=leave.submitted_by.full_name if leave.submitted_by else None,
        reviewed_by_name=leave.reviewed_by.full_name if leave.reviewed_by else None,
    )


# ========================
# STARTUP EVENT
# ========================

@app.on_event("startup")
async def startup():
    """Initialize database and models on startup"""
    init_db()
    db = SessionLocal()
    try:
        students = db.query(Student).all()
        for student in students:
            _ensure_student_linked_user(db, student)
        db.commit()
    except Exception as e:
        db.rollback()
        print(f"Warning: student link backfill failed: {e}")
    finally:
        db.close()


# ========================
# ROOT ENDPOINTS
# ========================

@app.get("/", tags=["Root"])
async def root():
    return {
        "message": "Recognition Based Automated Attendance System API",
        "status": "running",
        "version": "2.0.0",
        "docs": "/docs"
    }


@app.get("/health", tags=["Health"])
async def health_check():
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}


# ========================
# AUTHENTICATION ENDPOINTS
# ========================

@app.post("/api/auth/register", response_model=UserWithToken, tags=["Authentication"])
async def register(user_data: UserCreate, request: Request, db: Session = Depends(get_db)):
    """Register a new user"""
    existing_user = db.query(User).filter(User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered")

    verification_token = secrets.token_hex(32)
    new_user = User(
        email=user_data.email,
        full_name=user_data.full_name,
        hashed_password=get_password_hash(user_data.password),
        phone=user_data.phone,
        department=user_data.department,
        role=user_data.role or "student",
        verification_token=verification_token,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    _write_audit(db, new_user.id, "register", "User", new_user.id,
                 f"New user registered: {new_user.email}",
                 request.client.host if request.client else None)
    db.commit()

    access_token = create_access_token(data={"sub": new_user.email, "user_id": new_user.id})
    return UserWithToken(
        user=UserResponse.model_validate(new_user),
        token=Token(access_token=access_token)
    )


@app.post("/api/auth/login", response_model=Token, tags=["Authentication"])
async def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """Login and get access token (form-encoded, used by Swagger)"""
    user = authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                            detail="Incorrect email or password",
                            headers={"WWW-Authenticate": "Bearer"})
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User account is disabled")

    access_token = create_access_token(data={"sub": user.email, "user_id": user.id})
    return Token(access_token=access_token)


@app.post("/api/auth/login-json", response_model=UserWithToken, tags=["Authentication"])
async def login_json(user_data: UserLogin, db: Session = Depends(get_db)):
    """Login with JSON body (for Flutter app)"""
    user = authenticate_user(db, user_data.email, user_data.password)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect email or password")
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User account is disabled")

    access_token = create_access_token(data={"sub": user.email, "user_id": user.id})
    return UserWithToken(
        user=UserResponse.model_validate(user),
        token=Token(access_token=access_token)
    )


@app.get("/api/auth/verify", response_model=UserResponse, tags=["Authentication"])
async def verify_token(current_user: User = Depends(get_current_active_user)):
    return UserResponse.model_validate(current_user)


@app.get("/api/auth/me", response_model=UserResponse, tags=["Authentication"])
async def get_me(current_user: User = Depends(get_current_active_user)):
    return UserResponse.model_validate(current_user)


@app.post("/api/auth/verify-email/{token}", tags=["Authentication"])
async def verify_email(token: str, db: Session = Depends(get_db)):
    """Verify user email with token"""
    user = db.query(User).filter(User.verification_token == token).first()
    if not user:
        raise HTTPException(status_code=404, detail="Invalid verification token")
    if user.is_verified:
        return {"message": "Email already verified"}

    user.is_verified = True
    user.verification_token = None
    user.updated_at = datetime.utcnow()
    db.commit()
    return {"message": "Email verified successfully"}


@app.post("/api/auth/forgot-password", response_model=PasswordResetTokenResponse, tags=["Authentication"])
async def forgot_password(data: ForgotPasswordRequest, db: Session = Depends(get_db)):
    """Request a password reset token"""
    user = db.query(User).filter(User.email == data.email).first()
    # Always return 200 to prevent email enumeration
    if not user:
        return PasswordResetTokenResponse(message="If that email exists, a reset token has been generated.")

    # Invalidate previous tokens
    db.query(PasswordResetToken).filter(
        PasswordResetToken.user_id == user.id,
        PasswordResetToken.used == False
    ).update({"used": True})

    token = secrets.token_hex(32)
    reset_token = PasswordResetToken(
        user_id=user.id,
        token=token,
        expires_at=datetime.utcnow() + timedelta(hours=1),
    )
    db.add(reset_token)
    db.commit()

    # In production: send email. Here we return token in response for local/desktop use.
    return PasswordResetTokenResponse(
        message="Password reset token generated. Share this token with the user.",
        reset_token=token
    )


@app.post("/api/auth/reset-password", tags=["Authentication"])
async def reset_password(data: ResetPasswordRequest, db: Session = Depends(get_db)):
    """Reset password using a token"""
    reset_token = db.query(PasswordResetToken).filter(
        PasswordResetToken.token == data.token,
        PasswordResetToken.used == False,
        PasswordResetToken.expires_at > datetime.utcnow()
    ).first()

    if not reset_token:
        raise HTTPException(status_code=400, detail="Invalid or expired reset token")

    user = db.query(User).filter(User.id == reset_token.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.hashed_password = get_password_hash(data.new_password)
    user.updated_at = datetime.utcnow()
    reset_token.used = True
    db.commit()

    return {"message": "Password reset successfully"}


@app.post("/api/auth/change-password", tags=["Authentication"])
async def change_password(
    data: ChangePasswordRequest,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Change password for the current authenticated user"""
    if not verify_password(data.current_password, current_user.hashed_password):
        raise HTTPException(status_code=400, detail="Current password is incorrect")

    current_user.hashed_password = get_password_hash(data.new_password)
    current_user.updated_at = datetime.utcnow()
    db.commit()
    return {"message": "Password changed successfully"}


# ========================
# USER ENDPOINTS
# ========================

@app.get("/api/users", response_model=List[UserResponse], tags=["Users"])
async def get_users(
    skip: int = 0,
    limit: int = 100,
    role: Optional[str] = None,
    department: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user)
):
    query = db.query(User).filter(User.role != "managed_student")
    if role:
        query = query.filter(User.role == role)
    if department:
        query = query.filter(User.department == department)
    users = query.offset(skip).limit(limit).all()
    return [UserResponse.model_validate(u) for u in users]


@app.get("/api/users/{user_id}", response_model=UserResponse, tags=["Users"])
async def get_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    if current_user.role != "admin" and current_user.id != user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return UserResponse.model_validate(user)


@app.put("/api/users/{user_id}", response_model=UserResponse, tags=["Users"])
async def update_user(
    user_id: int,
    user_data: UserUpdate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    if current_user.role != "admin" and current_user.id != user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")

    # Non-admins cannot change role or is_active
    if current_user.role != "admin":
        user_data.role = None
        user_data.is_active = None

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    update_data = user_data.model_dump(exclude_unset=True, exclude_none=True)
    for field, value in update_data.items():
        setattr(user, field, value)

    user.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(user)

    _write_audit(db, current_user.id, "update_user", "User", user_id,
                 f"Updated fields: {list(update_data.keys())}",
                 request.client.host if request.client else None)
    db.commit()

    return UserResponse.model_validate(user)


@app.delete("/api/users/{user_id}", tags=["Users"])
async def delete_user(
    user_id: int,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user)
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot delete your own account")

    face_service.delete_face_images(user_id)
    name = user.full_name
    db.delete(user)
    _write_audit(db, current_user.id, "delete_user", "User", user_id,
                 f"Deleted user: {name}",
                 request.client.host if request.client else None)
    db.commit()
    return {"message": "User deleted successfully"}


# ========================
# FACE REGISTRATION ENDPOINTS
# ========================

@app.post("/api/users/register-face", response_model=FaceRegistrationResponse, tags=["Face Recognition"])
async def register_face(
    images: List[UploadFile] = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Register face with multiple images (3-5 recommended)"""
    settings = _get_settings(db)

    if len(images) < settings.min_face_images:
        raise HTTPException(status_code=400,
                            detail=f"Please upload at least {settings.min_face_images} face images")
    if len(images) > settings.max_face_images:
        raise HTTPException(status_code=400,
                            detail=f"Maximum {settings.max_face_images} images allowed")

    image_bytes_list = [await img.read() for img in images]

    success, encoding, message = await asyncio.to_thread(
        face_service.encode_multiple_faces, image_bytes_list
    )
    if not success:
        raise HTTPException(status_code=400, detail=message)

    current_user.face_encoding = json.dumps(encoding)
    current_user.has_registered_face = True
    current_user.updated_at = datetime.utcnow()

    face_path = face_service.save_face_image(image_bytes_list[0], current_user.id)
    current_user.face_image_path = face_path
    db.commit()

    return FaceRegistrationResponse(
        success=True,
        message="Face registered successfully",
        user_id=current_user.id,
        images_processed=len(images)
    )


@app.delete("/api/users/remove-face", tags=["Face Recognition"])
async def remove_face(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    current_user.face_encoding = None
    current_user.has_registered_face = False
    current_user.face_image_path = None
    current_user.updated_at = datetime.utcnow()
    face_service.delete_face_images(current_user.id)
    db.commit()
    return {"message": "Face registration removed"}


# ========================
# ATTENDANCE ENDPOINTS
# ========================

@app.post("/api/attendance/mark", response_model=AttendanceResponse, tags=["Attendance"])
async def mark_attendance(
    image: UploadFile = File(...),
    location: Optional[str] = Form(None),
    latitude: Optional[float] = Form(None),
    longitude: Optional[float] = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Mark attendance using face recognition (requires authentication)"""
    settings = _get_settings(db)
    if not settings.allow_face_attendance:
        raise HTTPException(status_code=400, detail="Face attendance is currently disabled")

    image_bytes = await image.read()

    success, rgb_img, message = await asyncio.to_thread(face_service.detect_face, image_bytes)
    if not success:
        raise HTTPException(status_code=400, detail=message)

    unknown_encoding = await asyncio.to_thread(face_service.encode_face, rgb_img)
    if unknown_encoding is None:
        raise HTTPException(status_code=400, detail="Could not encode face")

    users_with_faces = db.query(User).filter(
        User.has_registered_face == True,
        User.role != "managed_student"
    ).all()
    if not users_with_faces:
        raise HTTPException(status_code=400, detail="No registered faces in the system")

    known_encodings = []
    for user in users_with_faces:
        if user.face_encoding:
            encoding = json.loads(user.face_encoding)
            known_encodings.append((user.id, user.full_name, encoding))

    user_id, user_name, confidence = await asyncio.to_thread(
        face_service.find_best_match, known_encodings, unknown_encoding
    )

    if user_id is None or confidence < 0.4:
        raise HTTPException(status_code=400,
                            detail="Face not recognized. Please try again or register your face.")

    today = date.today()
    existing_attendance = db.query(Attendance).filter(
        Attendance.user_id == user_id,
        func.date(Attendance.date) == today
    ).first()

    if existing_attendance:
        raise HTTPException(status_code=400,
                            detail=f"Attendance already marked for {user_name} today")

    current_time = datetime.now()
    late_threshold = current_time.replace(
        hour=settings.late_threshold_hour,
        minute=settings.late_threshold_minute,
        second=0, microsecond=0
    )
    status_value = "late" if current_time > late_threshold else "present"

    attendance = Attendance(
        user_id=user_id,
        date=datetime.now(),
        check_in_time=datetime.now(),
        confidence=confidence,
        method="face",
        status=status_value,
        location=location,
        latitude=latitude,
        longitude=longitude
    )
    db.add(attendance)
    db.commit()
    db.refresh(attendance)

    # Check attendance percentage and notify if below threshold
    _check_attendance_alert(db, user_id, settings)

    # Notify user
    if status_value == "late":
        _push_notification(db, user_id, "Late Check-In",
                           f"You have been marked late today at {current_time.strftime('%H:%M')}.",
                           "attendance")
    db.commit()

    return _attendance_to_response(db, attendance)


def _check_attendance_alert(db: Session, user_id: int, settings: AppSettings):
    """Push a notification if attendance falls below threshold."""
    records = db.query(Attendance).filter(Attendance.user_id == user_id).all()
    if len(records) < 5:
        return
    present = len([r for r in records if r.status in ("present", "late")])
    pct = present / len(records) * 100
    if pct < settings.attendance_alert_pct:
        _push_notification(
            db, user_id,
            "Low Attendance Warning",
            f"Your attendance is {pct:.1f}%, which is below the {settings.attendance_alert_pct:.0f}% threshold.",
            "alert"
        )


@app.post("/api/attendance/check-out", tags=["Attendance"])
async def check_out(
    image: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Mark check-out using face recognition"""
    image_bytes = await image.read()

    success, rgb_img, message = await asyncio.to_thread(face_service.detect_face, image_bytes)
    if not success:
        raise HTTPException(status_code=400, detail=message)

    unknown_encoding = await asyncio.to_thread(face_service.encode_face, rgb_img)
    if unknown_encoding is None:
        raise HTTPException(status_code=400, detail="Could not encode face")

    users_with_faces = db.query(User).filter(
        User.has_registered_face == True,
        User.role != "managed_student"
    ).all()
    known_encodings = [(u.id, u.full_name, json.loads(u.face_encoding))
                       for u in users_with_faces if u.face_encoding]

    user_id, user_name, confidence = await asyncio.to_thread(
        face_service.find_best_match, known_encodings, unknown_encoding
    )

    if user_id is None or confidence < 0.4:
        raise HTTPException(status_code=400, detail="Face not recognized")

    today = date.today()
    attendance = db.query(Attendance).filter(
        Attendance.user_id == user_id,
        func.date(Attendance.date) == today
    ).first()

    if not attendance:
        raise HTTPException(status_code=400, detail="No check-in found for today.")
    if attendance.check_out_time:
        raise HTTPException(status_code=400, detail="Already checked out for today")

    attendance.check_out_time = datetime.now()
    db.commit()
    return {"message": f"Check-out successful for {user_name}", "check_out_time": attendance.check_out_time}


@app.post("/api/attendance/manual", response_model=AttendanceResponse, tags=["Attendance"])
async def manual_attendance(
    data: AttendanceManualCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Manually create an attendance record (teacher/admin only)"""
    if current_user.role not in ("admin", "teacher"):
        raise HTTPException(status_code=403, detail="Only teachers and admins can add manual attendance")

    settings = _get_settings(db)
    if not settings.allow_manual_entry:
        raise HTTPException(status_code=400, detail="Manual attendance entry is currently disabled")

    if data.user_id is None and data.student_id is None:
        raise HTTPException(status_code=400, detail="user_id or student_id is required for manual attendance")

    user = None
    student = None
    class_obj = None
    resolved_user_id = data.user_id
    resolved_student_id = None
    resolved_class_id = data.class_id

    if data.student_id is not None:
        student = db.query(Student).filter(Student.id == data.student_id).first()
        if not student:
            raise HTTPException(status_code=404, detail="Student not found")
        class_obj = db.query(Class).filter(Class.id == student.class_id).first()
        if not class_obj:
            raise HTTPException(status_code=404, detail="Class not found")
        if current_user.role != "admin" and class_obj.teacher_id != current_user.id:
            raise HTTPException(status_code=403, detail="Not authorized for this class")
        managed_user = _ensure_student_linked_user(db, student, class_obj)
        resolved_user_id = managed_user.id
        resolved_student_id = student.id
        resolved_class_id = student.class_id
    else:
        user = db.query(User).filter(User.id == data.user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

    attendance_date = data.attendance_date or datetime.now()
    target_date = attendance_date.date()

    existing = db.query(Attendance).filter(
        Attendance.user_id == resolved_user_id,
        func.date(Attendance.date) == target_date
    ).first()

    if existing:
        # Update status instead of creating duplicate
        existing.status = data.status
        if data.notes:
            existing.notes = data.notes
        if data.check_in_time:
            existing.check_in_time = data.check_in_time
        if data.check_out_time:
            existing.check_out_time = data.check_out_time
        existing.student_id = resolved_student_id
        existing.class_id = resolved_class_id
        db.commit()
        db.refresh(existing)
        return _attendance_to_response(db, existing)

    attendance = Attendance(
        user_id=resolved_user_id,
        student_id=resolved_student_id,
        class_id=resolved_class_id,
        date=attendance_date,
        check_in_time=(data.check_in_time or attendance_date) if data.status != "absent" else None,
        check_out_time=data.check_out_time,
        method="manual",
        status=data.status,
        notes=data.notes,
    )
    db.add(attendance)
    db.commit()
    db.refresh(attendance)

    _write_audit(db, current_user.id, "manual_attendance", "Attendance", attendance.id,
                 f"Manual entry on {target_date}: {data.status}",
                 request.client.host if request.client else None)
    db.commit()

    return _attendance_to_response(db, attendance)


@app.post("/api/attendance/roll-call", response_model=RollCallResponse, tags=["Attendance"])
async def submit_roll_call(
    data: RollCallSubmit,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Submit a manual roll call for an entire class (teacher/admin)"""
    if current_user.role not in ("admin", "teacher"):
        raise HTTPException(status_code=403, detail="Only teachers and admins can submit roll calls")

    class_obj = db.query(Class).filter(Class.id == data.class_id).first()
    if not class_obj:
        raise HTTPException(status_code=404, detail="Class not found")
    if current_user.role != "admin" and class_obj.teacher_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized for this class")

    attendance_date = data.attendance_date or datetime.now()
    target_date = attendance_date.date()

    marked = 0
    skipped = 0

    for entry in data.entries:
        if entry.student_id is None and entry.user_id is None:
            skipped += 1
            continue

        resolved_user_id = None
        resolved_student_id = None
        resolved_class_id = data.class_id

        if entry.student_id is not None:
            student = db.query(Student).filter(
                Student.id == entry.student_id,
                Student.class_id == data.class_id
            ).first()
            if not student:
                skipped += 1
                continue
            managed_user = _ensure_student_linked_user(db, student, class_obj)
            resolved_user_id = managed_user.id
            resolved_student_id = student.id
            resolved_class_id = student.class_id
        elif entry.user_id is not None:
            user = db.query(User).filter(User.id == entry.user_id).first()
            if not user:
                skipped += 1
                continue
            resolved_user_id = entry.user_id

        if resolved_user_id is None:
            skipped += 1
            continue

        existing = db.query(Attendance).filter(
            Attendance.user_id == resolved_user_id,
            func.date(Attendance.date) == target_date
        ).first()

        if existing:
            existing.status = entry.status
            existing.notes = entry.notes
            existing.student_id = resolved_student_id
            existing.class_id = resolved_class_id
            existing.check_in_time = attendance_date if entry.status != "absent" else None
        else:
            att = Attendance(
                user_id=resolved_user_id,
                student_id=resolved_student_id,
                class_id=resolved_class_id,
                date=attendance_date,
                check_in_time=attendance_date if entry.status != "absent" else None,
                method="manual",
                status=entry.status,
                notes=entry.notes,
            )
            db.add(att)
        marked += 1

    db.commit()

    _write_audit(db, current_user.id, "roll_call", "Class", data.class_id,
                 f"Roll call for class {class_obj.name} on {target_date}: {marked} marked",
                 request.client.host if request.client else None)
    db.commit()

    return RollCallResponse(
        marked_count=marked,
        skipped_count=skipped,
        message=f"Roll call complete. {marked} students marked, {skipped} skipped."
    )


@app.get("/api/attendance/today", response_model=List[AttendanceResponse], tags=["Attendance"])
async def get_today_attendance(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    today = date.today()
    query = db.query(Attendance).filter(func.date(Attendance.date) == today)
    if current_user.role != "admin":
        query = query.filter(Attendance.user_id == current_user.id)

    records = query.order_by(Attendance.check_in_time.desc()).all()
    return [_attendance_to_response(db, record) for record in records]


@app.get("/api/attendance/history", response_model=PaginatedAttendance, tags=["Attendance"])
async def get_attendance_history(
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    user_id: Optional[int] = Query(None),
    status_filter: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get paginated attendance history with optional filters"""
    query = db.query(Attendance)

    if current_user.role != "admin":
        query = query.filter(Attendance.user_id == current_user.id)
    elif user_id:
        query = query.filter(Attendance.user_id == user_id)

    if start_date:
        query = query.filter(func.date(Attendance.date) >= start_date)
    if end_date:
        query = query.filter(func.date(Attendance.date) <= end_date)
    if status_filter and status_filter != "all":
        query = query.filter(Attendance.status == status_filter)

    total = query.count()
    total_pages = ceil(total / page_size) if total > 0 else 1
    offset = (page - 1) * page_size

    records = query.order_by(Attendance.date.desc()).offset(offset).limit(page_size).all()

    responses = [_attendance_to_response(db, record) for record in records]

    return PaginatedAttendance(
        items=responses,
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages,
    )


@app.get("/api/attendance/stats/{user_id}", response_model=AttendanceStats, tags=["Attendance"])
async def get_attendance_stats(
    user_id: int,
    month: Optional[int] = Query(None),
    year: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    if current_user.role != "admin" and current_user.id != user_id:
        raise HTTPException(status_code=403, detail="Not authorized")

    settings = _get_settings(db)
    query = db.query(Attendance).filter(Attendance.user_id == user_id)

    if month and year:
        start_dt = datetime(year, month, 1)
        end_dt = datetime(year + 1, 1, 1) if month == 12 else datetime(year, month + 1, 1)
        query = query.filter(Attendance.date >= start_dt, Attendance.date < end_dt)

    records = query.all()
    present_days = len([r for r in records if r.status == "present"])
    late_days = len([r for r in records if r.status == "late"])
    absent_days = len([r for r in records if r.status == "absent"])
    total_days = len(records)
    attendance_percentage = (present_days + late_days) / total_days * 100 if total_days > 0 else 0

    return AttendanceStats(
        user_id=user_id,
        total_days=total_days,
        present_days=present_days,
        late_days=late_days,
        absent_days=absent_days,
        attendance_percentage=round(attendance_percentage, 2),
        below_threshold=attendance_percentage < settings.attendance_alert_pct,
        threshold=settings.attendance_alert_pct,
    )


@app.patch("/api/attendance/{attendance_id}", response_model=AttendanceResponse, tags=["Attendance"])
async def update_attendance_status(
    attendance_id: int,
    data: AttendanceUpdate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Update attendance status (teacher/admin only)"""
    if current_user.role not in ("admin", "teacher"):
        raise HTTPException(status_code=403, detail="Only teachers and admins can update attendance")

    attendance = db.query(Attendance).filter(Attendance.id == attendance_id).first()
    if not attendance:
        raise HTTPException(status_code=404, detail="Attendance record not found")

    old_status = attendance.status
    attendance.status = data.status
    if data.notes:
        attendance.notes = data.notes

    db.commit()
    db.refresh(attendance)

    _write_audit(db, current_user.id, "update_attendance", "Attendance", attendance_id,
                 f"Status changed from {old_status} to {data.status}",
                 request.client.host if request.client else None)
    db.commit()

    return _attendance_to_response(db, attendance)


@app.get("/api/attendance/export", tags=["Attendance"])
async def export_attendance_csv(
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    class_id: Optional[int] = Query(None),
    user_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user)
):
    """Export attendance history as CSV (Admin only)"""
    query = db.query(Attendance)

    if start_date:
        query = query.filter(func.date(Attendance.date) >= start_date)
    if end_date:
        query = query.filter(func.date(Attendance.date) <= end_date)
    if user_id:
        query = query.filter(Attendance.user_id == user_id)
    if class_id:
        query = query.filter(Attendance.class_id == class_id)

    records = query.order_by(Attendance.date.desc()).all()

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["ID", "Student Name", "Class", "Email", "Date", "Check-In Time",
                     "Check-Out Time", "Status", "Method", "Confidence", "Notes"])

    for r in records:
        response = _attendance_to_response(db, r)
        display_name = response.student_name or (response.user.full_name if response.user else "Unknown")
        display_email = response.user.email if response.user else ""
        writer.writerow([
            r.id,
            display_name,
            response.class_name or "",
            display_email,
            r.date.strftime("%Y-%m-%d"),
            r.check_in_time.strftime("%H:%M:%S") if r.check_in_time else "N/A",
            r.check_out_time.strftime("%H:%M:%S") if r.check_out_time else "N/A",
            r.status,
            r.method,
            f"{r.confidence:.2f}" if r.confidence else "N/A",
            r.notes or ""
        ])

    output.seek(0)
    filename = f"attendance_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )


# ========================
# ROOM SCAN ENDPOINT
# ========================

@app.post("/api/attendance/room-scan", response_model=RoomScanResponse, tags=["Attendance"])
async def room_scan(
    image: UploadFile = File(...),
    department: Optional[str] = Form(None),
    class_id: Optional[int] = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Scan a whole room/hall to identify present and missing students."""
    image_bytes = await image.read()
    print(f"DEBUG: Starting Room Scan for {len(image_bytes)} bytes...")

    try:
        success, rgb_img, face_locations, message = await asyncio.to_thread(
            face_service.detect_all_faces, image_bytes
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Face detection error: {str(e)}")

    if not success:
        raise HTTPException(status_code=400, detail=message)

    print(f"DEBUG: Detected {len(face_locations)} faces.")

    # ── Class-based scan ──────────────────────────────────────────────────────
    if class_id is not None:
        class_query = db.query(Class).filter(Class.id == class_id)
        if current_user.role != "admin":
            class_query = class_query.filter(Class.teacher_id == current_user.id)

        class_obj = class_query.first()
        if not class_obj:
            raise HTTPException(status_code=404, detail="Class not found")

        expected_students = db.query(Student).filter(
            Student.class_id == class_id,
            Student.has_registered_face == True
        ).all()

        if not face_locations:
            return RoomScanResponse(
                present_count=0,
                absent_count=len(expected_students),
                total_students=len(expected_students),
                present_users=[],
                absent_users=[_student_to_user_response(s, class_obj.name) for s in expected_students],
                message="No faces were detected in the image. Make sure faces are clearly visible and well-lit, then retry."
            )

        unknown_encodings = await asyncio.to_thread(
            face_recognition.face_encodings, rgb_img, face_locations
        )

        known_encodings = []
        for student in expected_students:
            enc = _parse_face_encoding(student.face_encoding)
            if enc:
                known_encodings.append((student.id, student.name, enc))

        matches = await asyncio.to_thread(
            face_service.find_all_matches, known_encodings, unknown_encodings
        )
        present_ids = {m[0] for m in matches}

        present_students = [s for s in expected_students if s.id in present_ids]
        absent_students = [s for s in expected_students if s.id not in present_ids]

        today = date.today()
        for student in present_students:
            managed_user = _ensure_student_linked_user(db, student, class_obj)
            existing = db.query(Attendance).filter(
                Attendance.user_id == managed_user.id,
                func.date(Attendance.date) == today
            ).first()
            if not existing:
                db.add(Attendance(
                    user_id=managed_user.id,
                    student_id=student.id,
                    class_id=class_obj.id,
                    date=datetime.now(),
                    check_in_time=datetime.now(),
                    method="room_scan",
                    status="present"
                ))
        db.commit()

        faces_detected = len(face_locations)
        if len(present_students) == 0 and faces_detected > 0:
            msg = (
                f"{faces_detected} face(s) were detected in the image but none matched any "
                f"registered student in '{class_obj.name}'. "
                "Make sure students have registered their faces first."
            )
        elif faces_detected == 0:
            msg = "No faces were detected in the image. Make sure faces are clearly visible and well-lit."
        else:
            msg = f"Found {len(present_students)} of {len(expected_students)} students in {class_obj.name}."
        return RoomScanResponse(
            present_count=len(present_students),
            absent_count=len(absent_students),
            total_students=len(expected_students),
            present_users=[_student_to_user_response(s, class_obj.name) for s in present_students],
            absent_users=[_student_to_user_response(s, class_obj.name) for s in absent_students],
            message=msg
        )

    # ── Legacy user/department scan ───────────────────────────────────────────
    if not face_locations:
        query = db.query(User).filter(User.role == "student", User.is_active == True)
        if department:
            query = query.filter(User.department == department)
        all_students = query.all()
        return RoomScanResponse(
            present_count=0,
            absent_count=len(all_students),
            total_students=len(all_students),
            present_users=[],
            absent_users=[_user_to_response(u) for u in all_students],
            message="No faces were detected in the image. Make sure faces are clearly visible and well-lit, then retry."
        )

    unknown_encodings = await asyncio.to_thread(
        face_recognition.face_encodings, rgb_img, face_locations
    )

    query = db.query(User).filter(
        User.has_registered_face == True,
        User.is_active == True,
        User.role != "managed_student"
    )
    if department:
        query = query.filter(User.department == department)
    expected_students = query.all()

    known_encodings = []
    for u in expected_students:
        enc = _parse_face_encoding(u.face_encoding)
        if enc:
            known_encodings.append((u.id, u.full_name, enc))

    matches = await asyncio.to_thread(
        face_service.find_all_matches, known_encodings, unknown_encodings
    )
    present_ids = {m[0] for m in matches}

    present_users = [u for u in expected_students if u.id in present_ids]
    absent_users = [u for u in expected_students if u.id not in present_ids]

    today = date.today()
    for user in present_users:
        existing = db.query(Attendance).filter(
            Attendance.user_id == user.id,
            func.date(Attendance.date) == today
        ).first()
        if not existing:
            db.add(Attendance(
                user_id=user.id,
                date=datetime.now(),
                check_in_time=datetime.now(),
                method="room_scan",
                status="present"
            ))
    db.commit()

    return RoomScanResponse(
        present_count=len(present_users),
        absent_count=len(absent_users),
        total_students=len(expected_students),
        present_users=[_user_to_response(u) for u in present_users],
        absent_users=[_user_to_response(u) for u in absent_users],
        message=f"Found {len(present_users)} students in the room."
    )


# ========================
# QR CODE ATTENDANCE
# ========================

@app.post("/api/qr/create-session", response_model=QRSessionResponse, tags=["QR Attendance"])
async def create_qr_session(
    data: QRSessionCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Create a QR attendance session for a class (teacher/admin)"""
    if current_user.role not in ("admin", "teacher"):
        raise HTTPException(status_code=403, detail="Only teachers and admins can create QR sessions")

    settings = _get_settings(db)
    if not settings.allow_qr_attendance:
        raise HTTPException(status_code=400, detail="QR attendance is currently disabled")

    class_obj = db.query(Class).filter(Class.id == data.class_id).first()
    if not class_obj:
        raise HTTPException(status_code=404, detail="Class not found")
    if current_user.role != "admin" and class_obj.teacher_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized for this class")

    # Deactivate any existing active sessions for this class
    db.query(QRSession).filter(
        QRSession.class_id == data.class_id,
        QRSession.is_active == True
    ).update({"is_active": False})

    duration = data.duration_minutes or settings.qr_session_minutes
    token = secrets.token_hex(32)
    session = QRSession(
        class_id=data.class_id,
        teacher_id=current_user.id,
        token=token,
        expires_at=datetime.utcnow() + timedelta(minutes=duration),
        is_active=True,
        session_date=datetime.now(),
    )
    db.add(session)
    db.commit()
    db.refresh(session)

    _write_audit(db, current_user.id, "create_qr_session", "QRSession", session.id,
                 f"QR session for class {class_obj.name}, valid {duration} min",
                 request.client.host if request.client else None)
    db.commit()

    base_url = os.getenv("APP_BASE_URL", "http://localhost:8000")
    return QRSessionResponse(
        id=session.id,
        class_id=session.class_id,
        class_name=class_obj.name,
        token=session.token,
        expires_at=session.expires_at,
        is_active=session.is_active,
        session_date=session.session_date,
        created_at=session.created_at,
        qr_url=f"{base_url}/api/qr/scan/{session.token}",
    )


@app.get("/api/qr/session/{class_id}", response_model=Optional[QRSessionResponse], tags=["QR Attendance"])
async def get_active_qr_session(
    class_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get the currently active QR session for a class"""
    session = db.query(QRSession).filter(
        QRSession.class_id == class_id,
        QRSession.is_active == True,
        QRSession.expires_at > datetime.utcnow()
    ).first()

    if not session:
        return None

    class_obj = db.query(Class).filter(Class.id == class_id).first()
    base_url = os.getenv("APP_BASE_URL", "http://localhost:8000")
    return QRSessionResponse(
        id=session.id,
        class_id=session.class_id,
        class_name=class_obj.name if class_obj else None,
        token=session.token,
        expires_at=session.expires_at,
        is_active=session.is_active,
        session_date=session.session_date,
        created_at=session.created_at,
        qr_url=f"{base_url}/api/qr/scan/{session.token}",
    )


@app.post("/api/qr/scan/{token}", response_model=AttendanceResponse, tags=["QR Attendance"])
async def scan_qr_attendance(
    token: str,
    data: QRAttendanceRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Mark attendance by scanning a QR code (student endpoint)"""
    session = db.query(QRSession).filter(
        QRSession.token == token,
        QRSession.is_active == True,
        QRSession.expires_at > datetime.utcnow()
    ).first()

    if not session:
        raise HTTPException(status_code=400, detail="Invalid or expired QR code")

    settings = _get_settings(db)
    user_id = current_user.id

    today = date.today()
    existing = db.query(Attendance).filter(
        Attendance.user_id == user_id,
        func.date(Attendance.date) == today
    ).first()

    if existing:
        raise HTTPException(status_code=400, detail="Attendance already marked today")

    current_time = datetime.now()
    late_threshold = current_time.replace(
        hour=settings.late_threshold_hour,
        minute=settings.late_threshold_minute,
        second=0, microsecond=0
    )
    status_value = "late" if current_time > late_threshold else "present"

    attendance = Attendance(
        user_id=user_id,
        date=current_time,
        check_in_time=current_time,
        method="qr_code",
        status=status_value,
    )
    db.add(attendance)
    db.commit()
    db.refresh(attendance)

    return _attendance_to_response(db, attendance)


@app.delete("/api/qr/session/{session_id}", tags=["QR Attendance"])
async def deactivate_qr_session(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Deactivate a QR session"""
    if current_user.role not in ("admin", "teacher"):
        raise HTTPException(status_code=403, detail="Not authorized")

    session = db.query(QRSession).filter(QRSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    session.is_active = False
    db.commit()
    return {"message": "QR session deactivated"}


# ========================
# ADMIN ENDPOINTS
# ========================

@app.get("/api/admin/dashboard", response_model=DashboardStats, tags=["Admin"])
async def get_dashboard_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user)
):
    today = date.today()
    regular_users = db.query(User).filter(User.role != "managed_student")
    total_users = regular_users.count()
    active_users = regular_users.filter(User.is_active == True).count()
    registered_faces = regular_users.filter(User.has_registered_face == True).count()

    managed_user_ids = {
        user_id for (user_id,) in db.query(User.id).filter(User.role == "managed_student").all()
    }
    today_attendance = db.query(Attendance).filter(func.date(Attendance.date) == today).all()
    today_attendance = [a for a in today_attendance if a.user_id not in managed_user_ids]
    present_today = len([a for a in today_attendance if a.status == "present"])
    late_today = len([a for a in today_attendance if a.status == "late"])
    absent_today = max(0, active_users - (present_today + late_today))

    pending_leaves = db.query(LeaveRequest).filter(LeaveRequest.status == "pending").count()
    unread_notifications = db.query(Notification).filter(
        Notification.user_id == current_user.id,
        Notification.is_read == False
    ).count()

    return DashboardStats(
        total_users=total_users,
        active_users=active_users,
        present_today=present_today,
        late_today=late_today,
        absent_today=absent_today,
        registered_faces=registered_faces,
        pending_leaves=pending_leaves,
        unread_notifications=unread_notifications,
    )


@app.get("/api/admin/reports", response_model=AttendanceReport, tags=["Admin"])
async def generate_report(
    start_date: date = Query(...),
    end_date: date = Query(...),
    department: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user)
):
    query = db.query(Attendance).filter(
        func.date(Attendance.date) >= start_date,
        func.date(Attendance.date) <= end_date
    )
    if department:
        user_ids = [
            u.id for u in db.query(User).filter(
                User.department == department,
                User.role != "managed_student"
            ).all()
        ]
        query = query.filter(Attendance.user_id.in_(user_ids))

    records = query.order_by(Attendance.date.desc()).all()
    responses = [_attendance_to_response(db, record) for record in records]

    total_users = db.query(User).filter(
        User.is_active == True,
        User.role != "managed_student"
    ).count()
    return AttendanceReport(
        start_date=datetime.combine(start_date, datetime.min.time()),
        end_date=datetime.combine(end_date, datetime.max.time()),
        total_users=total_users,
        present_count=len([r for r in records if r.status == "present"]),
        late_count=len([r for r in records if r.status == "late"]),
        absent_count=len([r for r in records if r.status == "absent"]),
        attendance_list=responses
    )


@app.get("/api/admin/analytics", tags=["Admin"])
async def get_analytics(
    days: int = Query(30, ge=1, le=365),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user)
):
    """Get analytics data for charts (last N days)"""
    start_dt = datetime.now() - timedelta(days=days)
    managed_user_ids = {
        user_id for (user_id,) in db.query(User.id).filter(User.role == "managed_student").all()
    }

    # Daily trend
    daily_records = [
        r for r in db.query(Attendance).filter(Attendance.date >= start_dt).all()
        if r.user_id not in managed_user_ids
    ]
    daily_map: dict = {}
    for r in daily_records:
        d = r.date.strftime("%Y-%m-%d")
        if d not in daily_map:
            daily_map[d] = {"present": 0, "late": 0, "absent": 0}
        daily_map[d][r.status] = daily_map[d].get(r.status, 0) + 1

    sorted_days = sorted(daily_map.keys())
    daily_trend = [{"date": d, **daily_map[d]} for d in sorted_days]

    # Department breakdown
    departments = db.query(User.department).filter(
        User.department != None, User.is_active == True, User.role != "managed_student"
    ).distinct().all()
    dept_breakdown = []
    for (dept,) in departments:
        user_ids = [
            u.id for u in db.query(User).filter(
                User.department == dept,
                User.role != "managed_student"
            ).all()
        ]
        dept_records = db.query(Attendance).filter(
            Attendance.user_id.in_(user_ids),
            Attendance.date >= start_dt
        ).all()
        total = len(dept_records)
        present = len([r for r in dept_records if r.status in ("present", "late")])
        dept_breakdown.append({
            "department": dept,
            "total": total,
            "present": present,
            "percentage": round(present / total * 100, 1) if total > 0 else 0
        })

    # Method breakdown
    methods = db.query(Attendance.method, func.count(Attendance.id)).filter(
        Attendance.date >= start_dt
    ).group_by(Attendance.method).all()
    method_breakdown = [{"method": m, "count": c} for m, c in methods]

    # Overall summary for period
    all_records = db.query(Attendance).filter(Attendance.date >= start_dt).all()
    total = len(all_records)
    present_count = len([r for r in all_records if r.status == "present"])
    late_count = len([r for r in all_records if r.status == "late"])
    absent_count = len([r for r in all_records if r.status == "absent"])

    return {
        "period_days": days,
        "summary": {
            "total": total,
            "present": present_count,
            "late": late_count,
            "absent": absent_count,
            "attendance_rate": round((present_count + late_count) / total * 100, 1) if total > 0 else 0
        },
        "daily_trend": daily_trend,
        "department_breakdown": dept_breakdown,
        "method_breakdown": method_breakdown,
    }


# ========================
# SETTINGS ENDPOINTS
# ========================

@app.get("/api/settings", response_model=List[SettingResponse], tags=["Settings"])
async def get_all_settings(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user)
):
    """Get all system settings (admin only)"""
    return db.query(Setting).order_by(Setting.key).all()


@app.get("/api/settings/app", response_model=AppSettings, tags=["Settings"])
async def get_app_settings(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get parsed app settings (any authenticated user)"""
    return _get_settings(db)


@app.put("/api/settings/{key}", response_model=SettingResponse, tags=["Settings"])
async def update_setting(
    key: str,
    data: SettingUpdate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user)
):
    """Update a single setting (admin only)"""
    setting = db.query(Setting).filter(Setting.key == key).first()
    if not setting:
        raise HTTPException(status_code=404, detail=f"Setting '{key}' not found")

    old_value = setting.value
    setting.value = data.value
    setting.updated_by_id = current_user.id
    setting.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(setting)

    _write_audit(db, current_user.id, "update_setting", "Setting", setting.id,
                 f"Changed {key}: '{old_value}' -> '{data.value}'",
                 request.client.host if request.client else None)
    db.commit()
    return setting


@app.post("/api/settings/bulk", response_model=List[SettingResponse], tags=["Settings"])
async def bulk_update_settings(
    data: SettingsBulkUpdate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user)
):
    """Bulk update settings (admin only)"""
    updated = []
    for key, value in data.settings.items():
        setting = db.query(Setting).filter(Setting.key == key).first()
        if setting:
            setting.value = str(value)
            setting.updated_by_id = current_user.id
            setting.updated_at = datetime.utcnow()
            updated.append(setting)

    db.commit()
    _write_audit(db, current_user.id, "bulk_update_settings", None, None,
                 f"Bulk updated {len(updated)} settings",
                 request.client.host if request.client else None)
    db.commit()
    return updated


# ========================
# LEAVE REQUEST ENDPOINTS
# ========================

@app.post("/api/leave", response_model=LeaveRequestResponse, tags=["Leave Requests"])
async def create_leave_request(
    data: LeaveRequestCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Submit a leave request"""
    if data.user_id is None and data.student_id is None:
        # Default to current user
        data.user_id = current_user.id

    leave = LeaveRequest(
        user_id=data.user_id,
        student_id=data.student_id,
        submitted_by_id=current_user.id,
        leave_date=data.leave_date,
        reason=data.reason,
        status="pending",
    )
    db.add(leave)
    db.commit()
    db.refresh(leave)

    # Notify admins/teachers
    admins = db.query(User).filter(User.role.in_(["admin", "teacher"]), User.is_active == True).all()
    requester_name = current_user.full_name
    for admin in admins:
        _push_notification(
            db, admin.id,
            "New Leave Request",
            f"{requester_name} submitted a leave request for {data.leave_date.strftime('%Y-%m-%d')}.",
            "leave",
            "leave_request", leave.id
        )
    db.commit()

    return _leave_to_response(leave)


@app.get("/api/leave", response_model=List[LeaveRequestResponse], tags=["Leave Requests"])
async def get_leave_requests(
    status_filter: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get leave requests (own for students, all for admin/teacher)"""
    query = db.query(LeaveRequest)

    if current_user.role not in ("admin", "teacher"):
        query = query.filter(LeaveRequest.user_id == current_user.id)

    if status_filter:
        query = query.filter(LeaveRequest.status == status_filter)

    leaves = query.order_by(LeaveRequest.created_at.desc()).all()
    return [_leave_to_response(l) for l in leaves]


@app.patch("/api/leave/{leave_id}", response_model=LeaveRequestResponse, tags=["Leave Requests"])
async def review_leave_request(
    leave_id: int,
    data: LeaveRequestReview,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Approve or reject a leave request (teacher/admin)"""
    if current_user.role not in ("admin", "teacher"):
        raise HTTPException(status_code=403, detail="Not authorized to review leave requests")

    leave = db.query(LeaveRequest).filter(LeaveRequest.id == leave_id).first()
    if not leave:
        raise HTTPException(status_code=404, detail="Leave request not found")
    if leave.status != "pending":
        raise HTTPException(status_code=400, detail="Leave request already reviewed")

    leave.status = data.status
    leave.reviewed_by_id = current_user.id
    leave.reviewed_at = datetime.utcnow()
    leave.review_note = data.review_note
    leave.updated_at = datetime.utcnow()

    # If approved, create an attendance record
    if data.status == "approved" and leave.user_id:
        target_date = leave.leave_date.date()
        existing = db.query(Attendance).filter(
            Attendance.user_id == leave.user_id,
            func.date(Attendance.date) == target_date
        ).first()
        if not existing:
            db.add(Attendance(
                user_id=leave.user_id,
                date=leave.leave_date,
                method="manual",
                status="absent",
                notes=f"Approved leave: {leave.reason}",
            ))

    db.commit()
    db.refresh(leave)

    # Notify requester
    if leave.user_id:
        action_text = "approved" if data.status == "approved" else "rejected"
        _push_notification(
            db, leave.user_id,
            f"Leave Request {action_text.capitalize()}",
            f"Your leave request for {leave.leave_date.strftime('%Y-%m-%d')} was {action_text}."
            + (f" Note: {data.review_note}" if data.review_note else ""),
            "leave", "leave_request", leave.id
        )
    db.commit()

    _write_audit(db, current_user.id, f"{data.status}_leave", "LeaveRequest", leave_id,
                 f"Leave request {leave_id} {data.status}",
                 request.client.host if request.client else None)
    db.commit()

    return _leave_to_response(leave)


@app.delete("/api/leave/{leave_id}", tags=["Leave Requests"])
async def delete_leave_request(
    leave_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Delete a pending leave request"""
    leave = db.query(LeaveRequest).filter(LeaveRequest.id == leave_id).first()
    if not leave:
        raise HTTPException(status_code=404, detail="Leave request not found")
    if leave.submitted_by_id != current_user.id and current_user.role not in ("admin", "teacher"):
        raise HTTPException(status_code=403, detail="Not authorized")
    if leave.status != "pending":
        raise HTTPException(status_code=400, detail="Cannot delete a reviewed leave request")

    db.delete(leave)
    db.commit()
    return {"message": "Leave request deleted"}


# ========================
# AUDIT LOG ENDPOINTS
# ========================

@app.get("/api/admin/audit-log", response_model=PaginatedAuditLog, tags=["Admin"])
async def get_audit_log(
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    action: Optional[str] = Query(None),
    actor_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user)
):
    """Get audit log (admin only)"""
    query = db.query(AuditLog)
    if action:
        query = query.filter(AuditLog.action.ilike(f"%{action}%"))
    if actor_id:
        query = query.filter(AuditLog.actor_id == actor_id)

    total = query.count()
    total_pages = ceil(total / page_size) if total > 0 else 1
    offset = (page - 1) * page_size

    logs = query.order_by(AuditLog.created_at.desc()).offset(offset).limit(page_size).all()

    items = []
    for log in logs:
        actor_name = log.actor.full_name if log.actor else "System"
        items.append(AuditLogResponse(
            id=log.id,
            actor_id=log.actor_id,
            actor_name=actor_name,
            action=log.action,
            target_type=log.target_type,
            target_id=log.target_id,
            detail=log.detail,
            ip_address=log.ip_address,
            created_at=log.created_at,
        ))

    return PaginatedAuditLog(items=items, total=total, page=page,
                             page_size=page_size, total_pages=total_pages)


# ========================
# NOTIFICATION ENDPOINTS
# ========================

@app.get("/api/notifications", response_model=List[NotificationResponse], tags=["Notifications"])
async def get_notifications(
    unread_only: bool = Query(False),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    query = db.query(Notification).filter(Notification.user_id == current_user.id)
    if unread_only:
        query = query.filter(Notification.is_read == False)
    notifications = query.order_by(Notification.created_at.desc()).limit(limit).all()
    return [NotificationResponse.model_validate(n) for n in notifications]


@app.get("/api/notifications/unread-count", response_model=UnreadCountResponse, tags=["Notifications"])
async def get_unread_count(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    count = db.query(Notification).filter(
        Notification.user_id == current_user.id,
        Notification.is_read == False
    ).count()
    return UnreadCountResponse(count=count)


@app.post("/api/notifications/mark-read", tags=["Notifications"])
async def mark_notifications_read(
    data: NotificationMarkRead,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    query = db.query(Notification).filter(Notification.user_id == current_user.id)
    if data.notification_ids:
        query = query.filter(Notification.id.in_(data.notification_ids))
    query.update({"is_read": True}, synchronize_session=False)
    db.commit()
    return {"message": "Notifications marked as read"}


@app.delete("/api/notifications/{notification_id}", tags=["Notifications"])
async def delete_notification(
    notification_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    notif = db.query(Notification).filter(
        Notification.id == notification_id,
        Notification.user_id == current_user.id
    ).first()
    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found")
    db.delete(notif)
    db.commit()
    return {"message": "Notification deleted"}


# ========================
# CLASS AND STUDENT ENDPOINTS
# ========================

@app.post("/api/classes", response_model=ClassResponse, tags=["Classes"])
async def create_class(
    class_data: ClassCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Create a new class (teachers and admins only)"""
    if current_user.role not in ("admin", "teacher"):
        raise HTTPException(status_code=403, detail="Only teachers and admins can create classes")

    new_class = Class(
        name=class_data.name,
        teacher_id=current_user.id,
        subject=class_data.subject,
        room=class_data.room,
        start_time=class_data.start_time,
        end_time=class_data.end_time,
        meeting_days=_normalize_meeting_days(class_data.meeting_days),
    )
    db.add(new_class)
    db.commit()
    db.refresh(new_class)

    _write_audit(db, current_user.id, "create_class", "Class", new_class.id,
                 f"Class created: {class_data.name}",
                 request.client.host if request.client else None)
    db.commit()

    return _class_to_response(new_class, db)


@app.get("/api/classes", response_model=List[ClassResponse], tags=["Classes"])
async def get_classes(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    query = db.query(Class)
    if current_user.role != "admin":
        query = query.filter(Class.teacher_id == current_user.id)

    classes = query.order_by(Class.created_at.desc()).all()
    return [_class_to_response(c, db) for c in classes]


@app.get("/api/classes/{class_id}", response_model=ClassResponse, tags=["Classes"])
async def get_class(
    class_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    class_obj = db.query(Class).filter(Class.id == class_id).first()
    if not class_obj:
        raise HTTPException(status_code=404, detail="Class not found")
    if current_user.role != "admin" and class_obj.teacher_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")
    return _class_to_response(class_obj, db)


@app.put("/api/classes/{class_id}", response_model=ClassResponse, tags=["Classes"])
async def update_class(
    class_id: int,
    class_data: ClassUpdate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    class_obj = db.query(Class).filter(Class.id == class_id).first()
    if not class_obj:
        raise HTTPException(status_code=404, detail="Class not found")
    if current_user.role != "admin" and class_obj.teacher_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    update_data = class_data.model_dump(exclude_unset=True)
    if "meeting_days" in update_data:
        class_obj.meeting_days = _normalize_meeting_days(update_data["meeting_days"])
        update_data.pop("meeting_days")

    for field, value in update_data.items():
        setattr(class_obj, field, value)

    db.flush()
    for student in db.query(Student).filter(Student.class_id == class_id).all():
        _ensure_student_linked_user(db, student, class_obj)

    _write_audit(db, current_user.id, "update_class", "Class", class_id,
                 f"Updated class fields: {list(class_data.model_dump(exclude_unset=True).keys())}",
                 request.client.host if request.client else None)
    db.commit()
    db.refresh(class_obj)
    return _class_to_response(class_obj, db)


@app.get("/api/classes/{class_id}/students", response_model=List[StudentResponse], tags=["Classes"])
async def get_class_students(
    class_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    class_obj = db.query(Class).filter(Class.id == class_id).first()
    if not class_obj:
        raise HTTPException(status_code=404, detail="Class not found")
    if current_user.role != "admin" and class_obj.teacher_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    students = db.query(Student).filter(Student.class_id == class_id).all()
    return [StudentResponse.model_validate(s) for s in students]


@app.get("/api/classes/{class_id}/attendance", response_model=List[AttendanceResponse], tags=["Classes"])
async def get_class_attendance(
    class_id: int,
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get attendance records for a class using stable student/class linkage"""
    class_obj = db.query(Class).filter(Class.id == class_id).first()
    if not class_obj:
        raise HTTPException(status_code=404, detail="Class not found")
    if current_user.role != "admin" and class_obj.teacher_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    query = db.query(Attendance).filter(Attendance.class_id == class_id)
    if start_date:
        query = query.filter(func.date(Attendance.date) >= start_date)
    if end_date:
        query = query.filter(func.date(Attendance.date) <= end_date)

    records = query.order_by(Attendance.date.desc()).all()
    return [_attendance_to_response(db, record) for record in records]


@app.delete("/api/classes/{class_id}", tags=["Classes"])
async def delete_class(
    class_id: int,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    class_obj = db.query(Class).filter(Class.id == class_id).first()
    if not class_obj:
        raise HTTPException(status_code=404, detail="Class not found")
    if current_user.role != "admin" and class_obj.teacher_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    name = class_obj.name
    students = db.query(Student).filter(Student.class_id == class_id).all()
    for student in students:
        if student.linked_user_id:
            linked_user = db.query(User).filter(User.id == student.linked_user_id).first()
            if linked_user:
                linked_user.is_active = False
    db.query(Student).filter(Student.class_id == class_id).delete()
    db.query(QRSession).filter(QRSession.class_id == class_id).delete()
    db.delete(class_obj)
    _write_audit(db, current_user.id, "delete_class", "Class", class_id,
                 f"Deleted class: {name}",
                 request.client.host if request.client else None)
    db.commit()
    return {"message": "Class and all its students deleted successfully"}


@app.delete("/api/classes/{class_id}/students/{student_id}", tags=["Classes"])
async def delete_student(
    class_id: int,
    student_id: int,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    class_obj = db.query(Class).filter(Class.id == class_id).first()
    if not class_obj:
        raise HTTPException(status_code=404, detail="Class not found")
    if current_user.role != "admin" and class_obj.teacher_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    student = db.query(Student).filter(
        Student.id == student_id, Student.class_id == class_id
    ).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    name = student.name
    if student.linked_user_id:
        linked_user = db.query(User).filter(User.id == student.linked_user_id).first()
        if linked_user:
            linked_user.is_active = False
    db.delete(student)
    _write_audit(db, current_user.id, "delete_student", "Student", student_id,
                 f"Deleted student: {name} from class {class_obj.name}",
                 request.client.host if request.client else None)
    db.commit()
    return {"message": "Student deleted successfully"}


@app.put("/api/classes/{class_id}/students/{student_id}", response_model=StudentResponse, tags=["Classes"])
async def update_student(
    class_id: int,
    student_id: int,
    request: Request,
    name: str = Form(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    class_obj = db.query(Class).filter(Class.id == class_id).first()
    if not class_obj:
        raise HTTPException(status_code=404, detail="Class not found")
    if current_user.role != "admin" and class_obj.teacher_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    student = db.query(Student).filter(
        Student.id == student_id, Student.class_id == class_id
    ).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    student.name = name.strip()
    _ensure_student_linked_user(db, student, class_obj)
    _write_audit(db, current_user.id, "update_student", "Student", student_id,
                 f"Updated student name to {student.name}",
                 request.client.host if request.client else None)
    db.commit()
    db.refresh(student)
    return StudentResponse.model_validate(student)


@app.post("/api/students/register", response_model=StudentRegistrationResponse, tags=["Students"])
async def register_student(
    name: str = Form(...),
    class_id: int = Form(...),
    images: List[UploadFile] = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Register a new student with face images (teacher/admin)"""
    if current_user.role not in ("admin", "teacher"):
        raise HTTPException(status_code=403, detail="Only teachers and admins can register students")

    class_obj = db.query(Class).filter(Class.id == class_id).first()
    if not class_obj:
        raise HTTPException(status_code=404, detail="Class not found")
    if current_user.role != "admin" and class_obj.teacher_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized for this class")

    settings = _get_settings(db)
    if len(images) < settings.min_face_images:
        raise HTTPException(status_code=400,
                            detail=f"Please upload at least {settings.min_face_images} face images")
    if len(images) > settings.max_face_images:
        raise HTTPException(status_code=400,
                            detail=f"Maximum {settings.max_face_images} images allowed")

    image_bytes_list = [await img.read() for img in images]

    success, encoding, message = await asyncio.to_thread(
        face_service.encode_multiple_faces, image_bytes_list
    )
    if not success:
        raise HTTPException(status_code=400, detail=message)

    # Duplicate face check within class
    existing_students = db.query(Student).filter(
        Student.class_id == class_id, Student.has_registered_face == True
    ).all()
    for existing in existing_students:
        existing_enc = _parse_face_encoding(existing.face_encoding)
        if existing_enc:
            is_match, confidence = face_service.compare_faces(existing_enc, encoding)
            if is_match:
                raise HTTPException(
                    status_code=400,
                    detail=f'Face already registered under "{existing.name}" in this class.'
                )

    new_student = Student(
        name=name,
        class_id=class_id,
        face_encoding=json.dumps(encoding),
        has_registered_face=True
    )
    db.add(new_student)
    db.commit()
    db.refresh(new_student)

    face_path = face_service.save_face_image(image_bytes_list[0], f"student_{new_student.id}")
    new_student.face_image_path = face_path
    _ensure_student_linked_user(db, new_student, class_obj)
    db.commit()

    return StudentRegistrationResponse(
        success=True,
        message="Student registered successfully",
        student_id=new_student.id,
        images_processed=len(images)
    )


@app.post("/api/students/bulk-import", response_model=BulkImportResponse, tags=["Students"])
async def bulk_import_students(
    class_id: int = Form(...),
    csv_file: UploadFile = File(...),
    request: Request = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """
    Bulk import student names from a CSV file (teacher/admin).
    CSV format: name (one column, with header row 'name')
    Students are created without face data; faces registered separately.
    """
    if current_user.role not in ("admin", "teacher"):
        raise HTTPException(status_code=403, detail="Only teachers and admins can import students")

    class_obj = db.query(Class).filter(Class.id == class_id).first()
    if not class_obj:
        raise HTTPException(status_code=404, detail="Class not found")
    if current_user.role != "admin" and class_obj.teacher_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized for this class")

    content = await csv_file.read()
    try:
        text = content.decode("utf-8-sig")
    except Exception:
        text = content.decode("latin-1", errors="replace")

    reader = csv.DictReader(io.StringIO(text))
    success_count = 0
    error_count = 0
    errors = []

    for i, row in enumerate(reader, start=2):
        name = (row.get("name") or row.get("Name") or row.get("NAME") or "").strip()
        if not name:
            errors.append(f"Row {i}: empty name, skipped")
            error_count += 1
            continue

        # Check duplicate in class
        existing = db.query(Student).filter(
            Student.class_id == class_id, Student.name == name
        ).first()
        if existing:
            errors.append(f"Row {i}: '{name}' already exists in this class, skipped")
            error_count += 1
            continue

        new_student = Student(name=name, class_id=class_id, has_registered_face=False)
        db.add(new_student)
        db.flush()
        _ensure_student_linked_user(db, new_student, class_obj)
        success_count += 1

    db.commit()
    _write_audit(db, current_user.id, "bulk_import_students", "Class", class_id,
                 f"Imported {success_count} students into class {class_obj.name}",
                 request.client.host if request.client else None)
    db.commit()

    return BulkImportResponse(
        success_count=success_count,
        error_count=error_count,
        errors=errors,
        message=f"Imported {success_count} students. {error_count} errors."
    )


# ========================
# EXAM PROCTORING ENDPOINT
# ========================

@app.post("/api/exam-proctor", response_model=ExamProctorResponse, tags=["Exam Proctoring"])
async def exam_proctor_scan(
    image: UploadFile = File(...),
    student_id: Optional[int] = Form(None),
    class_id: Optional[int] = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Scan for cheating during exams."""
    image_bytes = await image.read()

    query = db.query(User).filter(User.has_registered_face == True, User.is_active == True)
    users_with_faces = query.all()

    known_encodings = []
    for u in users_with_faces:
        if u.face_encoding:
            known_encodings.append((u.id, u.full_name, json.loads(u.face_encoding)))

    result = exam_proctor_service.analyze_exam_frame(
        image_bytes=image_bytes,
        known_encodings=known_encodings,
        expected_student_id=student_id
    )

    detected_objects = [
        DetectedObject(
            type=obj['type'], label=obj['label'],
            confidence=obj['confidence'], bbox=obj['bbox'], color=obj['color']
        )
        for obj in result['detected_objects']
    ]

    return ExamProctorResponse(
        student_verified=result['student_verified'],
        student_id=result['student_id'],
        student_name=result['student_name'],
        face_count=result['face_count'],
        gaze_direction=result['gaze_direction'],
        detected_objects=detected_objects,
        suspicion_score=result['suspicion_score'],
        violations=result['violations'],
        is_cheating=result['is_cheating'],
        timestamp=result['timestamp'],
        message=result['message']
    )


# ========================
# RUN APPLICATION
# ========================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
