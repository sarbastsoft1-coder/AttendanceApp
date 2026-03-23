"""
Recognition Based Automated Attendance System - Main FastAPI Application
"""
import os
import json
import asyncio
from datetime import datetime, date, timedelta
from typing import List, Optional

from dotenv import load_dotenv
from fastapi import FastAPI, Depends, HTTPException, status, UploadFile, File, Query, Form, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from sqlalchemy import func

from database import get_db, User, Attendance, Class, Student, init_db
from models import (
    Token, UserCreate, UserLogin, UserUpdate, UserResponse, UserWithToken,
    AttendanceCreate, AttendanceResponse, AttendanceStats, AttendanceReport, AttendanceUpdate,
    FaceRegistrationResponse, FaceRecognitionResult, DashboardStats, RoomScanResponse,
    ClassCreate, ClassResponse, StudentResponse, StudentRegistrationResponse,
    DetectedObject, ExamProctorResponse
)
from auth import (
    get_password_hash, create_access_token, authenticate_user,
    get_current_user, get_current_active_user, get_current_admin_user
)
from face_service import face_service, exam_proctor_service
import face_recognition

load_dotenv()

# Initialize FastAPI app
app = FastAPI(
    title="Recognition Based Automated Attendance System",
    description="Backend API for facial recognition attendance tracking",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Update with specific origins in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    import traceback
    error_msg = f"Internal Server Error: {str(exc)}\n{traceback.format_exc()}"
    print(error_msg)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal Server Error", "error": str(exc), "traceback": traceback.format_exc()}
    )


# ========================
# STARTUP EVENT
# ========================

@app.on_event("startup")
async def startup():
    """Initialize database and models on startup"""
    # Initialize database
    init_db()
    
    # Wait for startup tasks
    pass


# ========================
# ROOT ENDPOINTS
# ========================

@app.get("/", tags=["Root"])
async def root():
    """API health check"""
    return {
        "message": "Recognition Based Automated Attendance System API",
        "status": "running",
        "version": "1.0.0",
        "docs": "/docs"
    }


@app.get("/health", tags=["Health"])
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}


# ========================
# AUTHENTICATION ENDPOINTS
# ========================

@app.post("/api/auth/register", response_model=UserWithToken, tags=["Authentication"])
async def register(user_data: UserCreate, db: Session = Depends(get_db)):
    """Register a new user"""
    # Check if email exists
    existing_user = db.query(User).filter(User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Create user
    new_user = User(
        email=user_data.email,
        full_name=user_data.full_name,
        hashed_password=get_password_hash(user_data.password),
        phone=user_data.phone,
        department=user_data.department,
        role=user_data.role or "student"
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    # Generate token
    access_token = create_access_token(data={"sub": new_user.email, "user_id": new_user.id})
    
    return UserWithToken(
        user=UserResponse.model_validate(new_user),
        token=Token(access_token=access_token)
    )


@app.post("/api/auth/login", response_model=Token, tags=["Authentication"])
async def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """Login and get access token"""
    user = authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is disabled"
        )
    
    access_token = create_access_token(data={"sub": user.email, "user_id": user.id})
    return Token(access_token=access_token)


@app.post("/api/auth/login-json", response_model=UserWithToken, tags=["Authentication"])
async def login_json(user_data: UserLogin, db: Session = Depends(get_db)):
    """Login with JSON body (for Flutter app)"""
    user = authenticate_user(db, user_data.email, user_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is disabled"
        )
    
    access_token = create_access_token(data={"sub": user.email, "user_id": user.id})
    
    return UserWithToken(
        user=UserResponse.model_validate(user),
        token=Token(access_token=access_token)
    )


@app.get("/api/auth/verify", response_model=UserResponse, tags=["Authentication"])
async def verify_token(current_user: User = Depends(get_current_active_user)):
    """Verify token and get current user"""
    return UserResponse.model_validate(current_user)


@app.get("/api/auth/me", response_model=UserResponse, tags=["Authentication"])
async def get_me(current_user: User = Depends(get_current_active_user)):
    """Get current user profile"""
    return UserResponse.model_validate(current_user)


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
    """Get all users (admin only)"""
    query = db.query(User)
    
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
    """Get user by ID"""
    # Users can only view their own profile unless admin
    if current_user.role != "admin" and current_user.id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to view this user"
        )
    
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    return UserResponse.model_validate(user)


@app.put("/api/users/{user_id}", response_model=UserResponse, tags=["Users"])
async def update_user(
    user_id: int,
    user_data: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Update user information"""
    # Users can only update their own profile unless admin
    if current_user.role != "admin" and current_user.id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to update this user"
        )
    
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    update_data = user_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(user, field, value)
    
    user.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(user)
    
    return UserResponse.model_validate(user)


@app.delete("/api/users/{user_id}", tags=["Users"])
async def delete_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user)
):
    """Delete user (admin only)"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Delete face images
    face_service.delete_face_images(user_id)
    
    db.delete(user)
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
    if len(images) < 3:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please upload at least 3 face images"
        )
    
    if len(images) > 10:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Maximum 10 images allowed"
        )
    
    # Read all images
    image_bytes_list = []
    for img in images:
        content = await img.read()
        image_bytes_list.append(content)
    
    # Process and encode faces
    success, encoding, message = await asyncio.to_thread(face_service.encode_multiple_faces, image_bytes_list)
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message
        )
    
    # Save face encoding to database
    current_user.face_encoding = json.dumps(encoding)
    current_user.has_registered_face = True
    current_user.updated_at = datetime.utcnow()
    
    # Save first image as profile reference
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
    """Remove registered face"""
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
    db: Session = Depends(get_db)
):
    """Mark attendance using face recognition"""
    # Read image
    image_bytes = await image.read()
    
    # Detect and encode face
    success, rgb_img, message = await asyncio.to_thread(face_service.detect_face, image_bytes)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message
        )
    
    unknown_encoding = await asyncio.to_thread(face_service.encode_face, rgb_img)
    if unknown_encoding is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Could not encode face"
        )
    
    # Get all users with registered faces
    users_with_faces = db.query(User).filter(User.has_registered_face == True).all()
    
    if not users_with_faces:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No registered faces in the system"
        )
    
    # Prepare encodings for comparison
    known_encodings = []
    for user in users_with_faces:
        if user.face_encoding:
            encoding = json.loads(user.face_encoding)
            known_encodings.append((user.id, user.full_name, encoding))
    
    # Find best match
    user_id, user_name, confidence = await asyncio.to_thread(face_service.find_best_match, known_encodings, unknown_encoding)
    
    if user_id is None or confidence < 0.4:  # Minimum threshold
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Face not recognized. Please try again or register your face."
        )
    
    # Check if already marked today
    today = date.today()
    existing_attendance = db.query(Attendance).filter(
        Attendance.user_id == user_id,
        func.date(Attendance.date) == today
    ).first()
    
    if existing_attendance:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Attendance already marked for {user_name} today"
        )
    
    # Determine status based on time
    current_time = datetime.now()
    late_threshold = current_time.replace(hour=9, minute=0, second=0, microsecond=0)
    status_value = "late" if current_time > late_threshold else "present"
    
    # Create attendance record
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
    
    # Add user info to response
    user = db.query(User).filter(User.id == user_id).first()
    response = AttendanceResponse.model_validate(attendance)
    response.user = UserResponse.model_validate(user)
    
    return response


@app.post("/api/attendance/check-out", tags=["Attendance"])
async def check_out(
    image: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """Mark check-out using face recognition"""
    # Similar face recognition process
    image_bytes = await image.read()
    
    success, rgb_img, message = await asyncio.to_thread(face_service.detect_face, image_bytes)
    if not success:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=message)
    
    unknown_encoding = await asyncio.to_thread(face_service.encode_face, rgb_img)
    if unknown_encoding is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Could not encode face")
    
    # Find user
    users_with_faces = db.query(User).filter(User.has_registered_face == True).all()
    known_encodings = [(u.id, u.full_name, json.loads(u.face_encoding)) for u in users_with_faces if u.face_encoding]
    
    user_id, user_name, confidence = await asyncio.to_thread(face_service.find_best_match, known_encodings, unknown_encoding)
    
    if user_id is None or confidence < 0.4:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Face not recognized")
    
    # Find today's attendance
    today = date.today()
    attendance = db.query(Attendance).filter(
        Attendance.user_id == user_id,
        func.date(Attendance.date) == today
    ).first()
    
    if not attendance:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No check-in found for today. Please check in first."
        )
    
    if attendance.check_out_time:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Already checked out for today"
        )
    
    attendance.check_out_time = datetime.now()
    db.commit()
    
    return {"message": f"Check-out successful for {user_name}", "check_out_time": attendance.check_out_time}


def _parse_face_encoding(raw_encoding: Optional[str]) -> Optional[List[float]]:
    """Parse JSON face encoding safely."""
    if not raw_encoding:
        return None
    try:
        return json.loads(raw_encoding)
    except Exception:
        return None


def _student_to_user_response(student: Student, class_name: Optional[str]) -> UserResponse:
    """Map Student model to UserResponse-compatible payload for existing Flutter UI."""
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


def _user_to_response(user: User) -> UserResponse:
    """Safely map User model to UserResponse, handling mandatory fields."""
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


@app.post("/api/attendance/room-scan", response_model=RoomScanResponse, tags=["Attendance"])
async def room_scan(
    image: UploadFile = File(...),
    department: Optional[str] = Form(None),
    class_id: Optional[int] = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Scan a whole room/hall to identify present and missing students."""
    # Read image
    image_bytes = await image.read()

    print(f"DEBUG: Starting Room Scan processing for {len(image_bytes)} bytes...")
    
    try:
        # Detect all faces
        success, rgb_img, face_locations, message = await asyncio.to_thread(face_service.detect_all_faces, image_bytes)
    except Exception as e:
        print(f"DEBUG: Error in detect_all_faces: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Face detection error: {str(e)}")
    if not success:
        print(f"DEBUG: Face detection failure: {message}")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=message)

    print(f"DEBUG: Detected {len(face_locations)} faces.")

    # ------------------------
    # Class-based scan flow
    # ------------------------
    if class_id is not None:
        class_query = db.query(Class).filter(Class.id == class_id)
        if current_user.role != "admin":
            class_query = class_query.filter(Class.teacher_id == current_user.id)

        class_obj = class_query.first()
        if not class_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Class not found"
            )

        expected_students = db.query(Student).filter(
            Student.class_id == class_id,
            Student.has_registered_face == True
        ).all()

        if not face_locations:
            print(f"DEBUG: No faces detected in class scan. Returning {len(expected_students)} absent students.")
            return RoomScanResponse(
                present_count=0,
                absent_count=len(expected_students),
                total_students=len(expected_students),
                present_users=[],
                absent_users=[_student_to_user_response(s, class_obj.name) for s in expected_students],
                message="No faces detected in the image. All students marked as absent."
            )

        try:
            unknown_encodings = await asyncio.to_thread(face_recognition.face_encodings, rgb_img, face_locations)
        except ImportError:
            return RoomScanResponse(
                present_count=0,
                absent_count=len(expected_students),
                total_students=len(expected_students),
                present_users=[],
                absent_users=[_student_to_user_response(s, class_obj.name) for s in expected_students],
                message="Face recognition libraries not available for room scanning."
            )

        known_encodings = []
        for student in expected_students:
            encoding = _parse_face_encoding(student.face_encoding)
            if encoding:
                known_encodings.append((student.id, student.name, encoding))

        matches = await asyncio.to_thread(face_service.find_all_matches, known_encodings, unknown_encodings)
        present_ids = {m[0] for m in matches}

        present_students = [s for s in expected_students if s.id in present_ids]
        absent_students = [s for s in expected_students if s.id not in present_ids]

        return RoomScanResponse(
            present_count=len(present_students),
            absent_count=len(absent_students),
            total_students=len(expected_students),
            present_users=[_student_to_user_response(s, class_obj.name) for s in present_students],
            absent_users=[_student_to_user_response(s, class_obj.name) for s in absent_students],
            message=f"Found {len(present_students)} students in class {class_obj.name}."
        )

    # ------------------------
    # Legacy department/user scan flow
    # ------------------------
    if not face_locations:
        query = db.query(User).filter(User.role == "student", User.is_active == True)
        if department:
            query = query.filter(User.department == department)
        all_students = query.all()
        
        print(f"DEBUG: No faces detected in legacy scan. Returning {len(all_students)} absent students.")
        return RoomScanResponse(
            present_count=0,
            absent_count=len(all_students),
            total_students=len(all_students),
            present_users=[],
            absent_users=[_user_to_response(u) for u in all_students],
            message="No faces detected in the image. All students marked as absent."
        )

    try:
        unknown_encodings = await asyncio.to_thread(face_recognition.face_encodings, rgb_img, face_locations)
    except ImportError:
        return RoomScanResponse(
            present_count=0,
            absent_count=0,
            total_students=0,
            present_users=[],
            absent_users=[],
            message="Face recognition libraries not available for room scanning."
        )

    query = db.query(User).filter(User.has_registered_face == True, User.is_active == True)
    if department:
        query = query.filter(User.department == department)
    expected_students = query.all()

    known_encodings = []
    for u in expected_students:
        encoding = _parse_face_encoding(u.face_encoding)
        if encoding:
            known_encodings.append((u.id, u.full_name, encoding))

    matches = await asyncio.to_thread(face_service.find_all_matches, known_encodings, unknown_encodings)
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
            attendance = Attendance(
                user_id=user.id,
                date=datetime.now(),
                check_in_time=datetime.now(),
                method="room_scan",
                status="present"
            )
            db.add(attendance)

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
# EXAM PROCTORING ENDPOINTS
# ========================

@app.post("/api/exam-proctor", response_model=ExamProctorResponse, tags=["Exam Proctoring"])
async def exam_proctor_scan(
    image: UploadFile = File(...),
    student_id: Optional[int] = Form(None),
    class_id: Optional[int] = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """
    Scan for cheating during exams.
    
    Detects:
    - Suspicious objects (phones, books, etc.)
    - Multiple faces (potential helpers)
    - Student identity verification
    
    Returns an ESP-style response with bounding boxes for overlay rendering.
    """
    # Read image
    image_bytes = await image.read()
    
    # Get all users with registered faces for verification
    query = db.query(User).filter(User.has_registered_face == True, User.is_active == True)
    
    # If class_id provided, filter by students in that class
    if class_id:
        student_ids = [s.id for s in db.query(Student).filter(Student.class_id == class_id).all()]
        # For now, we'll use all registered faces since Student model may not have user_id
        pass
    
    users_with_faces = query.all()
    
    # Prepare known encodings
    known_encodings = []
    for u in users_with_faces:
        if u.face_encoding:
            known_encodings.append((u.id, u.full_name, json.loads(u.face_encoding)))
    
    # Analyze frame for cheating
    result = exam_proctor_service.analyze_exam_frame(
        image_bytes=image_bytes,
        known_encodings=known_encodings,
        expected_student_id=student_id
    )
    
    # Convert detected objects to Pydantic models
    detected_objects = [
        DetectedObject(
            type=obj['type'],
            label=obj['label'],
            confidence=obj['confidence'],
            bbox=obj['bbox'],
            color=obj['color']
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


@app.get("/api/attendance/today", response_model=List[AttendanceResponse], tags=["Attendance"])
async def get_today_attendance(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get today's attendance records"""
    today = date.today()
    
    query = db.query(Attendance).filter(func.date(Attendance.date) == today)
    
    # Non-admins can only see their own
    if current_user.role != "admin":
        query = query.filter(Attendance.user_id == current_user.id)
    
    records = query.order_by(Attendance.check_in_time.desc()).all()
    
    responses = []
    for record in records:
        response = AttendanceResponse.model_validate(record)
        response.user = UserResponse.model_validate(record.user)
        responses.append(response)
    
    return responses


@app.get("/api/attendance/history", response_model=List[AttendanceResponse], tags=["Attendance"])
async def get_attendance_history(
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    user_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get attendance history with optional filters"""
    query = db.query(Attendance)
    
    # Non-admins can only see their own
    if current_user.role != "admin":
        query = query.filter(Attendance.user_id == current_user.id)
    elif user_id:
        query = query.filter(Attendance.user_id == user_id)
    
    if start_date:
        query = query.filter(func.date(Attendance.date) >= start_date)
    if end_date:
        query = query.filter(func.date(Attendance.date) <= end_date)
    
    records = query.order_by(Attendance.date.desc()).limit(100).all()
    
    responses = []
    for record in records:
        response = AttendanceResponse.model_validate(record)
        response.user = UserResponse.model_validate(record.user)
        responses.append(response)
    
    return responses


@app.get("/api/attendance/stats/{user_id}", response_model=AttendanceStats, tags=["Attendance"])
async def get_attendance_stats(
    user_id: int,
    month: Optional[int] = Query(None),
    year: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get attendance statistics for a user"""
    # Non-admins can only see their own stats
    if current_user.role != "admin" and current_user.id != user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")
    
    query = db.query(Attendance).filter(Attendance.user_id == user_id)
    
    # Filter by month/year
    if month and year:
        start_date = datetime(year, month, 1)
        if month == 12:
            end_date = datetime(year + 1, 1, 1)
        else:
            end_date = datetime(year, month + 1, 1)
        query = query.filter(Attendance.date >= start_date, Attendance.date < end_date)
    
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
        attendance_percentage=round(attendance_percentage, 2)
    )


@app.patch("/api/attendance/{attendance_id}", response_model=AttendanceResponse, tags=["Attendance"])
async def update_attendance_status(
    attendance_id: int,
    data: AttendanceUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Update attendance status manually (Teacher/Admin)"""
    attendance = db.query(Attendance).filter(Attendance.id == attendance_id).first()
    if not attendance:
        raise HTTPException(status_code=404, detail="Attendance record not found")
    
    attendance.status = data.status
    if data.notes:
        attendance.notes = data.notes
    
    db.commit()
    db.refresh(attendance)
    
    # Include user info in response
    response = AttendanceResponse.model_validate(attendance)
    response.user = UserResponse.model_validate(attendance.user)
    return response


@app.get("/api/attendance/export", tags=["Attendance"])
async def export_attendance_csv(
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    class_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user)
):
    """Export attendance history as CSV (Admin only)"""
    import csv
    import io
    from fastapi.responses import StreamingResponse
    
    query = db.query(Attendance)
    
    if start_date:
        query = query.filter(func.date(Attendance.date) >= start_date)
    if end_date:
        query = query.filter(func.date(Attendance.date) <= end_date)
    if class_id:
        # Get students in that class
        student_ids = [s.id for s in db.query(Student).filter(Student.class_id == class_id).all()]
        # Note: In this system, Attendance usually links to User, not Student model.
        # This part might need adjustment depending on how teachers manage "Students" vs "Users".
        pass

    records = query.order_by(Attendance.date.desc()).all()
    
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["ID", "Student Name", "Email", "Date", "Time", "Status", "Method", "Confidence", "Notes"])
    
    for r in records:
        user = r.user
        writer.writerow([
            r.id,
            user.full_name,
            user.email,
            r.date.strftime("%Y-%m-%d"),
            r.check_in_time.strftime("%H:%M:%S") if r.check_in_time else "N/A",
            r.status,
            r.method,
            f"{r.confidence:.2f}" if r.confidence else "N/A",
            r.notes or ""
        ])
    
    output.seek(0)
    filename = f"attendance_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )


# ========================
# ADMIN ENDPOINTS
# ========================

@app.get("/api/admin/dashboard", response_model=DashboardStats, tags=["Admin"])
async def get_dashboard_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user)
):
    """Get admin dashboard statistics"""
    today = date.today()
    
    total_users = db.query(User).count()
    active_users = db.query(User).filter(User.is_active == True).count()
    registered_faces = db.query(User).filter(User.has_registered_face == True).count()
    
    today_attendance = db.query(Attendance).filter(func.date(Attendance.date) == today).all()
    present_today = len([a for a in today_attendance if a.status == "present"])
    late_today = len([a for a in today_attendance if a.status == "late"])
    absent_today = active_users - (present_today + late_today)
    
    return DashboardStats(
        total_users=total_users,
        active_users=active_users,
        present_today=present_today,
        late_today=late_today,
        absent_today=max(0, absent_today),
        registered_faces=registered_faces
    )


@app.get("/api/admin/reports", response_model=AttendanceReport, tags=["Admin"])
async def generate_report(
    start_date: date = Query(...),
    end_date: date = Query(...),
    department: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user)
):
    """Generate attendance report for date range"""
    query = db.query(Attendance).filter(
        func.date(Attendance.date) >= start_date,
        func.date(Attendance.date) <= end_date
    )
    
    if department:
        user_ids = [u.id for u in db.query(User).filter(User.department == department).all()]
        query = query.filter(Attendance.user_id.in_(user_ids))
    
    records = query.order_by(Attendance.date.desc()).all()
    
    responses = []
    for record in records:
        response = AttendanceResponse.model_validate(record)
        response.user = UserResponse.model_validate(record.user)
        responses.append(response)
    
    total_users = db.query(User).filter(User.is_active == True).count()
    present_count = len([r for r in records if r.status == "present"])
    late_count = len([r for r in records if r.status == "late"])
    absent_count = len([r for r in records if r.status == "absent"])
    
    return AttendanceReport(
        start_date=datetime.combine(start_date, datetime.min.time()),
        end_date=datetime.combine(end_date, datetime.max.time()),
        total_users=total_users,
        present_count=present_count,
        late_count=late_count,
        absent_count=absent_count,
        attendance_list=responses
    )


# ========================
# CLASS AND STUDENT ENDPOINTS
# ========================

@app.post("/api/classes", response_model=ClassResponse, tags=["Classes"])
async def create_class(
    class_data: ClassCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Create a new class (teachers only)"""
    new_class = Class(
        name=class_data.name,
        teacher_id=current_user.id
    )
    db.add(new_class)
    db.commit()
    db.refresh(new_class)
    
    return ClassResponse(
        id=new_class.id,
        name=new_class.name,
        teacher_id=new_class.teacher_id,
        created_at=new_class.created_at,
        student_count=0
    )


@app.get("/api/classes", response_model=List[ClassResponse], tags=["Classes"])
async def get_classes(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get all classes (for the current teacher or all for admin)"""
    query = db.query(Class)
    
    # Non-admins see only their own classes
    if current_user.role != "admin":
        query = query.filter(Class.teacher_id == current_user.id)
    
    classes = query.order_by(Class.created_at.desc()).all()
    
    responses = []
    for c in classes:
        student_count = db.query(Student).filter(Student.class_id == c.id).count()
        responses.append(ClassResponse(
            id=c.id,
            name=c.name,
            teacher_id=c.teacher_id,
            created_at=c.created_at,
            student_count=student_count
        ))
    
    return responses


@app.get("/api/classes/{class_id}/students", response_model=List[StudentResponse], tags=["Classes"])
async def get_class_students(
    class_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get all students in a class"""
    # Verify class exists
    class_obj = db.query(Class).filter(Class.id == class_id).first()
    if not class_obj:
        raise HTTPException(status_code=404, detail="Class not found")
    
    # Non-admins can only see their own classes
    if current_user.role != "admin" and class_obj.teacher_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to view this class")
    
    students = db.query(Student).filter(Student.class_id == class_id).all()
    return [StudentResponse.model_validate(s) for s in students]


@app.post("/api/students/register", response_model=StudentRegistrationResponse, tags=["Students"])
async def register_student(
    name: str = Form(...),
    class_id: int = Form(...),
    images: List[UploadFile] = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Register a new student with face images"""
    # Verify class belongs to teacher
    class_obj = db.query(Class).filter(Class.id == class_id, Class.teacher_id == current_user.id).first()
    if not class_obj:
        raise HTTPException(status_code=404, detail="Class not found")
    
    if len(images) < 3:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please upload at least 3 face images"
        )
    
    if len(images) > 10:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Maximum 10 images allowed"
        )
    
    # Read all images
    image_bytes_list = []
    for img in images:
        content = await img.read()
        image_bytes_list.append(content)
    
    # Process and encode faces
    success, encoding, message = await asyncio.to_thread(face_service.encode_multiple_faces, image_bytes_list)
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message
        )
    
    # Check for duplicate face among existing students in this class
    existing_students = db.query(Student).filter(
        Student.class_id == class_id,
        Student.has_registered_face == True
    ).all()
    
    for existing in existing_students:
        existing_enc = _parse_face_encoding(existing.face_encoding)
        if existing_enc:
            is_match, confidence = face_service.compare_faces(existing_enc, encoding)
            if is_match:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f'This face is already registered under "{existing.name}" in this class. Each student must have a unique face.'
                )
    
    # Create student record
    new_student = Student(
        name=name,
        class_id=class_id,
        face_encoding=json.dumps(encoding),
        has_registered_face=True
    )
    db.add(new_student)
    db.commit()
    db.refresh(new_student)
    
    # Save first image
    face_path = face_service.save_face_image(image_bytes_list[0], f"student_{new_student.id}")
    new_student.face_image_path = face_path
    db.commit()
    
    return StudentRegistrationResponse(
        success=True,
        message="Student registered successfully",
        student_id=new_student.id,
        images_processed=len(images)
    )


@app.get("/api/classes/{class_id}/attendance", response_model=List[AttendanceResponse], tags=["Classes"])
async def get_class_attendance(
    class_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get all attendance records for students in a specific class"""
    # Verify class belongs to teacher (or admin)
    class_obj = db.query(Class).filter(Class.id == class_id).first()
    if not class_obj:
        raise HTTPException(status_code=404, detail="Class not found")
        
    if current_user.role != "admin" and class_obj.teacher_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to view this class")
    
    # Attendance stores user_id. We need to match Students (in classes) to Users (in attendance)
    # In this system, Students are separate from Users? 
    # Let's check the database models again.
    # Student has name, class_id. User has email, full_name, role.
    # If a student is marked as present in room_scan, a record is created for a USER.
    # This might be tricky if Student names don't perfectly match User full_names.
    
    # For now, let's filter attendance by users who share names with students in this class
    # (A better way would be a direct link, but let's work with what we have)
    student_names = [s.name for s in class_obj.students]
    relevant_users = db.query(User).filter(User.full_name.in_(student_names)).all()
    user_ids = [u.id for u in relevant_users]
    
    records = db.query(Attendance).filter(Attendance.user_id.in_(user_ids)).order_by(Attendance.date.desc()).all()
    
    responses = []
    for record in records:
        response = AttendanceResponse.model_validate(record)
        response.user = UserResponse.model_validate(record.user)
        responses.append(response)
        
    return responses





# ========================
# DELETE CLASS AND STUDENT ENDPOINTS
# ========================

@app.delete("/api/classes/{class_id}", tags=["Classes"])
async def delete_class(
    class_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Delete a class and all its students"""
    class_obj = db.query(Class).filter(Class.id == class_id).first()
    if not class_obj:
        raise HTTPException(status_code=404, detail="Class not found")
    
    # Only the owning teacher or admin can delete
    if current_user.role != "admin" and class_obj.teacher_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to delete this class")
    
    # Delete all students in the class first
    db.query(Student).filter(Student.class_id == class_id).delete()
    db.delete(class_obj)
    db.commit()
    
    return {"message": "Class and all its students deleted successfully"}


@app.delete("/api/classes/{class_id}/students/{student_id}", tags=["Classes"])
async def delete_student(
    class_id: int,
    student_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Delete a student from a class"""
    class_obj = db.query(Class).filter(Class.id == class_id).first()
    if not class_obj:
        raise HTTPException(status_code=404, detail="Class not found")
    
    # Only the owning teacher or admin can delete students
    if current_user.role != "admin" and class_obj.teacher_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to modify this class")
    
    student = db.query(Student).filter(
        Student.id == student_id,
        Student.class_id == class_id
    ).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found in this class")
    
    db.delete(student)
    db.commit()
    
    return {"message": "Student deleted successfully"}


# ========================
# RUN APPLICATION
# ========================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

