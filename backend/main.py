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
from urllib.parse import quote, urlparse

from dotenv import load_dotenv
from fastapi import FastAPI, Depends, HTTPException, status, UploadFile, File, Query, Form, Request
from fastapi.responses import JSONResponse, StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from sqlalchemy import func, or_, text

from database import (
    get_db, SessionLocal, User, Attendance, Class, Student, init_db,
    PasswordResetToken, LeaveRequest, Setting, AuditLog, QRSession, Notification,
    TeacherGroup, TeacherGroupMember, TeacherGroupInvite, GroupSharedClass,
)
from models import (
    Token, UserCreate, ManagedUserCreate, UserLogin, UserUpdate, UserResponse, UserWithToken,
    AttendanceCreate, AttendanceResponse, AttendanceStats, AttendanceReport, AttendanceUpdate,
    AttendanceManualCreate, PaginatedAttendance,
    FaceRegistrationResponse, FaceRecognitionResult, DashboardStats, RoomScanResponse,
    ClassCreate, ClassUpdate, ClassResponse, StudentResponse, StudentRegistrationResponse,
    DetectedObject, ExamProctorResponse,
    ForgotPasswordRequest, ResetPasswordRequest, ChangePasswordRequest, PasswordResetTokenResponse,
    LeaveRequestCreate, LeaveRequestReview, LeaveRequestResponse, LeaveRequestUpdate,
    SettingUpdate, SettingResponse, SettingsBulkUpdate, AppSettings,
    AuditLogResponse, PaginatedAuditLog,
    QRSessionCreate, QRSessionResponse, QRAttendanceRequest,
    NotificationResponse, NotificationMarkRead, UnreadCountResponse,
    RollCallSubmit, RollCallResponse,
    BulkImportResponse,
    TeacherGroupCreate, TeacherGroupInviteCreate, TeacherGroupInviteRespond,
    TeacherGroupMemberUpdate, TeacherGroupMemberResponse, TeacherGroupInviteResponse,
    TeacherGroupResponse, GroupSharedClassCreate, GroupSharedClassResponse,
    SupervisionOverviewResponse,
)
from auth import (
    get_password_hash, verify_password, create_access_token, authenticate_user,
    get_current_user, get_current_active_user, get_current_admin_user
)
from face_service import FACE_IMAGES_DIR, face_service, exam_proctor_service

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
    allow_origin_regex=r"https?://.*",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.mount("/face-images", StaticFiles(directory=FACE_IMAGES_DIR), name="face-images")


def _get_face_recognition_module():
    """Load face_recognition through the shared face service lazy init path."""
    if face_service._lazy_init() and face_service._face_recognition is not None:
        return face_service._face_recognition
    raise HTTPException(
        status_code=503,
        detail="Face recognition service is not available on this server."
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
        min_face_images=int(raw.get("min_face_images", 2)),
        max_face_images=int(raw.get("max_face_images", 10)),
        attendance_alert_pct=float(raw.get("attendance_alert_pct", 75)),
        qr_session_minutes=int(raw.get("qr_session_minutes", 15)),
        allow_manual_entry=raw.get("allow_manual_entry", "true").lower() == "true",
        allow_qr_attendance=raw.get("allow_qr_attendance", "true").lower() == "true",
        allow_face_attendance=raw.get("allow_face_attendance", "true").lower() == "true",
        app_name=raw.get("app_name", "Face Attendance System"),
    )


ADMIN_ROLES = {"admin", "super_admin"}
TEACHER_ROLES = {"teacher", "super_teacher"}
GROUP_MANAGER_ROLES = {"admin", "super_admin", "super_teacher"}
SHARE_TARGET_ROLES = {"teacher", "super_teacher"}
MANAGEABLE_USER_ROLES = {"teacher", "super_teacher", "admin", "super_admin"}


def _display_role_name(role: str) -> str:
    return {
        "teacher": "user",
        "super_teacher": "super user",
    }.get(role, role.replace("_", " "))


def _is_admin_role(user: User) -> bool:
    return user.role in ADMIN_ROLES


def _is_teacher_role(user: User) -> bool:
    return user.role in TEACHER_ROLES


def _manageable_roles_for_user(user: User) -> set[str]:
    if user.role == "super_admin":
        return MANAGEABLE_USER_ROLES
    if user.role == "admin":
        return {"teacher", "super_teacher", "admin"}
    return set()


def _ensure_user_role_can_be_assigned(current_user: User, role: str) -> None:
    if role not in MANAGEABLE_USER_ROLES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid user role")
    if role not in _manageable_roles_for_user(current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to assign that role",
        )


def _ensure_user_account_can_be_managed(current_user: User, target_user: User) -> None:
    if target_user.role == "super_admin" and current_user.role != "super_admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only super admins can manage super admin accounts",
        )


def _require_admin_login_key(user: User, provided_key: Optional[str]) -> None:
    if user.role not in ADMIN_ROLES:
        return

    normalized_key = (provided_key or "").strip()
    if not normalized_key:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access key is required",
        )

    if user.admin_access_key_hash and verify_password(
        normalized_key,
        user.admin_access_key_hash,
    ):
        return

    configured_key = os.getenv("ADMIN_LOGIN_KEY", "").strip()
    if configured_key and secrets.compare_digest(normalized_key, configured_key):
        return

    if not configured_key and not user.admin_access_key_hash:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Admin login key is not configured",
        )

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Invalid admin access key",
    )


def _resolve_managed_admin_access_key(
    current_user: User,
    role: str,
    provided_key: Optional[str],
) -> Optional[str]:
    normalized_key = (provided_key or "").strip()
    if role not in ADMIN_ROLES:
        return None

    if len(normalized_key) < 4:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Admin accounts must include an admin access key",
        )

    if current_user.role == "admin" and role == "super_admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only super admins can create super admin accounts",
        )

    return get_password_hash(normalized_key)


def _can_manage_classes(user: User) -> bool:
    return _is_admin_role(user) or _is_teacher_role(user)


def _can_review_leave_requests(user: User) -> bool:
    return _can_manage_classes(user)


def _has_global_group_access(user: User) -> bool:
    return user.role in GROUP_MANAGER_ROLES


def _can_manage_groups(user: User) -> bool:
    return _has_global_group_access(user)


def _can_use_user_groups(user: User) -> bool:
    return user.role != "managed_student"


def _can_create_groups(user: User) -> bool:
    return _can_use_user_groups(user)


def _can_manage_group(user: User, group: TeacherGroup) -> bool:
    return _has_global_group_access(user) or group.created_by_id == user.id


def _is_group_member(db: Session, user_id: int, group_id: int) -> bool:
    return (
        db.query(TeacherGroupMember)
        .filter(
            TeacherGroupMember.group_id == group_id,
            TeacherGroupMember.teacher_id == user_id,
        )
        .first()
        is not None
    )


def _user_group_ids(db: Session, user_id: int) -> List[int]:
    return [
        row.group_id
        for row in db.query(TeacherGroupMember.group_id)
        .filter(TeacherGroupMember.teacher_id == user_id)
        .all()
    ]


def _shared_class_ids_for_user(db: Session, user_id: int) -> List[int]:
    group_ids = _user_group_ids(db, user_id)
    if not group_ids:
        return []
    return [
        row.class_id
        for row in db.query(GroupSharedClass.class_id)
        .filter(GroupSharedClass.group_id.in_(group_ids))
        .all()
    ]


def _accessible_class_ids_for_user(db: Session, user: User) -> List[int]:
    class_ids = set(_shared_class_ids_for_user(db, user.id))
    if _can_manage_classes(user):
        owned_ids = (
            db.query(Class.id)
            .filter(Class.teacher_id == user.id)
            .all()
        )
        class_ids.update(row.id for row in owned_ids)
    return sorted(class_ids)


def _can_access_class(db: Session, user: User, class_obj: Class) -> bool:
    if _is_admin_role(user) or class_obj.teacher_id == user.id:
        return True
    return class_obj.id in _shared_class_ids_for_user(db, user.id)


def _can_edit_class(db: Session, user: User, class_obj: Class) -> bool:
    return _is_admin_role(user) or class_obj.teacher_id == user.id


def _group_member_to_response(member: TeacherGroupMember) -> TeacherGroupMemberResponse:
    return TeacherGroupMemberResponse(
        id=member.id,
        teacher_id=member.teacher_id,
        teacher_name=member.teacher.full_name if member.teacher else "",
        teacher_email=member.teacher.email if member.teacher else "",
        teacher_role=member.teacher.role if member.teacher else "teacher",
        joined_at=member.joined_at,
    )


def _group_invite_to_response(invite: TeacherGroupInvite) -> TeacherGroupInviteResponse:
    return TeacherGroupInviteResponse(
        id=invite.id,
        group_id=invite.group_id,
        email=invite.email,
        invited_by_id=invite.invited_by_id,
        invited_by_name=invite.invited_by.full_name if invite.invited_by else None,
        teacher_id=invite.teacher_id,
        teacher_name=invite.teacher.full_name if invite.teacher else None,
        target_role=invite.target_role,
        status=invite.status,
        note=invite.note,
        created_at=invite.created_at,
        responded_at=invite.responded_at,
    )


def _group_shared_class_to_response(shared: GroupSharedClass) -> GroupSharedClassResponse:
    return GroupSharedClassResponse(
        id=shared.id,
        group_id=shared.group_id,
        class_id=shared.class_id,
        class_name=shared.class_ref.name if shared.class_ref else "",
        shared_by_id=shared.shared_by_id,
        shared_by_name=shared.shared_by.full_name if shared.shared_by else None,
        created_at=shared.created_at,
    )


def _ensure_group_member(db: Session, group_id: int, teacher_id: int) -> TeacherGroupMember:
    member = (
        db.query(TeacherGroupMember)
        .filter(
            TeacherGroupMember.group_id == group_id,
            TeacherGroupMember.teacher_id == teacher_id,
        )
        .first()
    )
    if member is not None:
        return member

    member = TeacherGroupMember(group_id=group_id, teacher_id=teacher_id)
    db.add(member)
    db.flush()
    return member


def _group_to_response(
    group: TeacherGroup,
    db: Session,
    current_user: Optional[User] = None,
) -> TeacherGroupResponse:
    members = (
        db.query(TeacherGroupMember)
        .filter(TeacherGroupMember.group_id == group.id)
        .order_by(TeacherGroupMember.joined_at.asc())
        .all()
    )
    invitations = (
        db.query(TeacherGroupInvite)
        .filter(TeacherGroupInvite.group_id == group.id)
        .order_by(TeacherGroupInvite.created_at.desc())
        .all()
    )
    shared_classes = (
        db.query(GroupSharedClass)
        .filter(GroupSharedClass.group_id == group.id)
        .order_by(GroupSharedClass.created_at.desc())
        .all()
    )

    return TeacherGroupResponse(
        id=group.id,
        name=group.name,
        description=group.description,
        created_by_id=group.created_by_id,
        created_by_name=group.created_by.full_name if group.created_by else None,
        can_manage=_can_manage_group(current_user, group) if current_user else False,
        created_at=group.created_at,
        updated_at=group.updated_at,
        members=[_group_member_to_response(member) for member in members],
        invitations=[_group_invite_to_response(invite) for invite in invitations],
        shared_classes=[_group_shared_class_to_response(shared) for shared in shared_classes],
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


def _origin_from_url(url: Optional[str]) -> Optional[str]:
    """Extract scheme + host from a full URL."""
    if not url:
        return None

    try:
        parsed = urlparse(url)
    except Exception:
        return None

    if not parsed.scheme or not parsed.netloc:
        return None

    return f"{parsed.scheme}://{parsed.netloc}"


def _build_face_image_url(request: Optional[Request], stored_path: Optional[str]) -> Optional[str]:
    """Build a public URL for a stored face image path."""
    if request is None or not stored_path:
        return None

    try:
        abs_root = os.path.abspath(FACE_IMAGES_DIR)
        abs_path = os.path.abspath(stored_path)
        if os.path.commonpath([abs_root, abs_path]) != abs_root:
            return None
        relative_path = os.path.relpath(abs_path, abs_root).replace(os.sep, "/")
    except Exception:
        return None

    return f"{str(request.base_url).rstrip('/')}/face-images/{quote(relative_path, safe='/')}"


def _latest_face_image_in_folder(folder_hint: Optional[str]) -> Optional[str]:
    if not folder_hint:
        return None

    folder_path = os.path.join(FACE_IMAGES_DIR, folder_hint)
    if not os.path.isdir(folder_path):
        return None

    files = [
        os.path.join(folder_path, name)
        for name in os.listdir(folder_path)
        if os.path.isfile(os.path.join(folder_path, name))
    ]
    if not files:
        return None

    return max(files, key=os.path.getmtime)


def _resolve_face_image_path(stored_path: Optional[str], folder_hint: Optional[str] = None) -> Optional[str]:
    """Resolve a usable local face image path, falling back to the latest file for the user/student folder."""
    if stored_path:
        abs_path = os.path.abspath(stored_path)
        if os.path.exists(abs_path):
            return abs_path

    fallback = _latest_face_image_in_folder(folder_hint)
    if fallback:
        return fallback

    return os.path.abspath(stored_path) if stored_path else None


def _build_qr_scan_url(request: Request, token: str) -> str:
    """Build a browser-friendly QR link that opens the frontend scan route."""
    frontend_base = os.getenv("FRONTEND_BASE_URL", "").strip()
    if not frontend_base:
        frontend_base = (
            request.headers.get("origin", "").strip()
            or _origin_from_url(request.headers.get("referer"))
            or ""
        )

    if frontend_base:
        return f"{frontend_base.rstrip('/')}/#/qr-scan?token={token}"

    base_url = os.getenv("APP_BASE_URL", "").strip() or str(request.base_url).rstrip("/")
    return f"{base_url}/api/qr/scan/{token}"


def _delete_class_with_dependencies(
    db: Session,
    class_obj: Class,
    actor_id: Optional[int] = None,
    ip_address: Optional[str] = None,
):
    """Delete a class and its managed records without leaving FK orphans."""
    students = db.query(Student).filter(Student.class_id == class_obj.id).all()
    student_ids = [student.id for student in students]
    linked_user_ids = [student.linked_user_id for student in students if student.linked_user_id]

    if linked_user_ids:
        db.query(User).filter(User.id.in_(linked_user_ids)).update(
            {User.is_active: False},
            synchronize_session=False,
        )

    if student_ids:
        db.query(LeaveRequest).filter(LeaveRequest.student_id.in_(student_ids)).delete(
            synchronize_session=False
        )
        db.query(Attendance).filter(Attendance.student_id.in_(student_ids)).delete(
            synchronize_session=False
        )

    db.query(Attendance).filter(Attendance.class_id == class_obj.id).delete(
        synchronize_session=False
    )
    db.query(QRSession).filter(QRSession.class_id == class_obj.id).delete(
        synchronize_session=False
    )
    db.query(Student).filter(Student.class_id == class_obj.id).delete(
        synchronize_session=False
    )

    class_name = class_obj.name
    class_id = class_obj.id
    db.delete(class_obj)

    if actor_id is not None:
        _write_audit(
            db,
            actor_id,
            "delete_class",
            "Class",
            class_id,
            f"Deleted class: {class_name}",
            ip_address,
        )


def _delete_user_with_dependencies(
    db: Session,
    user: User,
    actor_id: Optional[int] = None,
    ip_address: Optional[str] = None,
    action: str = "delete_user",
):
    """Delete a user and all dependent records that block removal."""
    owned_classes = db.query(Class).filter(Class.teacher_id == user.id).all()
    for class_obj in owned_classes:
        _delete_class_with_dependencies(db, class_obj)

    db.query(QRSession).filter(QRSession.teacher_id == user.id).delete(
        synchronize_session=False
    )
    db.query(Notification).filter(Notification.user_id == user.id).delete(
        synchronize_session=False
    )
    db.query(PasswordResetToken).filter(PasswordResetToken.user_id == user.id).delete(
        synchronize_session=False
    )
    db.query(Attendance).filter(Attendance.user_id == user.id).delete(
        synchronize_session=False
    )
    db.query(LeaveRequest).filter(
        or_(
            LeaveRequest.user_id == user.id,
            LeaveRequest.submitted_by_id == user.id,
            LeaveRequest.reviewed_by_id == user.id,
        )
    ).delete(synchronize_session=False)
    db.query(Setting).filter(Setting.updated_by_id == user.id).update(
        {Setting.updated_by_id: None},
        synchronize_session=False,
    )
    db.query(AuditLog).filter(AuditLog.actor_id == user.id).update(
        {AuditLog.actor_id: None},
        synchronize_session=False,
    )
    db.query(Student).filter(Student.linked_user_id == user.id).update(
        {Student.linked_user_id: None},
        synchronize_session=False,
    )

    user_id = user.id
    user_name = user.full_name
    user_email = user.email
    face_service.delete_face_images(user_id)
    db.delete(user)

    _write_audit(
        db,
        actor_id,
        action,
        "User",
        user_id,
        f"Deleted user: {user_name} <{user_email}>",
        ip_address,
    )


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
    resolved_face_image_path = _resolve_face_image_path(user.face_image_path, str(user.id))
    return UserResponse(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        phone=user.phone,
        department=user.department,
        role=user.role,
        face_image_path=resolved_face_image_path,
        has_registered_face=user.has_registered_face,
        is_active=user.is_active,
        is_verified=user.is_verified,
        created_at=user.created_at or datetime.utcnow()
    )


def _student_to_response(student: Student, request: Optional[Request] = None) -> StudentResponse:
    resolved_face_image_path = _resolve_face_image_path(
        student.face_image_path,
        f"student_{student.id}",
    )
    return StudentResponse(
        id=student.id,
        name=student.name,
        class_id=student.class_id,
        linked_user_id=student.linked_user_id,
        face_image_path=resolved_face_image_path,
        face_image_url=_build_face_image_url(request, resolved_face_image_path),
        has_registered_face=student.has_registered_face,
        created_at=student.created_at or datetime.utcnow(),
    )


def _attendance_face_image_path(db: Session, attendance: Attendance) -> Optional[str]:
    if attendance.student_id is not None:
        student = db.query(Student).filter(Student.id == attendance.student_id).first()
        if student:
            resolved_path = _resolve_face_image_path(
                student.face_image_path,
                f"student_{student.id}",
            )
            if resolved_path:
                return resolved_path

    if attendance.user:
        resolved_path = _resolve_face_image_path(
            attendance.user.face_image_path,
            str(attendance.user.id),
        )
        if resolved_path:
            return resolved_path

    if attendance.user_id is not None:
        user = attendance.user or db.query(User).filter(User.id == attendance.user_id).first()
        if user:
            resolved_path = _resolve_face_image_path(user.face_image_path, str(user.id))
            if resolved_path:
                return resolved_path

    return None


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
async def health_check(db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1"))
    except Exception as exc:
        return JSONResponse(
            status_code=503,
            content={
                "status": "unhealthy",
                "timestamp": datetime.utcnow().isoformat(),
                "database": "unavailable",
                "detail": str(exc),
            },
        )

    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "database": "healthy",
    }


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
        role="teacher",
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
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    admin_access_key: Optional[str] = Form(None),
    db: Session = Depends(get_db),
):
    """Login and get access token (form-encoded, used by Swagger)"""
    user = authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                            detail="Incorrect email or password",
                            headers={"WWW-Authenticate": "Bearer"})
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User account is disabled")
    _require_admin_login_key(user, admin_access_key)

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
    _require_admin_login_key(user, user_data.admin_access_key)

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


@app.delete("/api/auth/me", tags=["Authentication"])
async def delete_my_account(
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    if current_user.role == "admin":
        raise HTTPException(
            status_code=400,
            detail="Admin accounts cannot delete themselves",
        )

    _delete_user_with_dependencies(
        db,
        current_user,
        actor_id=None,
        ip_address=request.client.host if request.client else None,
        action="delete_own_account",
    )
    db.commit()
    return {"message": "Account deleted successfully"}


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

@app.post("/api/users", response_model=UserResponse, tags=["Users"])
async def create_user(
    user_data: ManagedUserCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user)
):
    existing_user = db.query(User).filter(User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered")

    _ensure_user_role_can_be_assigned(current_user, user_data.role)
    admin_access_key_hash = _resolve_managed_admin_access_key(
        current_user,
        user_data.role,
        user_data.admin_access_key,
    )

    verification_token = secrets.token_hex(32)
    new_user = User(
        email=user_data.email,
        full_name=user_data.full_name,
        hashed_password=get_password_hash(user_data.password),
        phone=user_data.phone,
        department=user_data.department,
        role=user_data.role,
        verification_token=verification_token,
        admin_access_key_hash=admin_access_key_hash,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    _write_audit(
        db,
        current_user.id,
        "create_user",
        "User",
        new_user.id,
        f"Created {new_user.role} account: {new_user.email}",
        request.client.host if request.client else None,
    )
    db.commit()

    return UserResponse.model_validate(new_user)

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
    if not _is_admin_role(current_user) and current_user.id != user_id:
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
    if not _is_admin_role(current_user) and current_user.id != user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")

    # Non-admins cannot change role or is_active
    if not _is_admin_role(current_user):
        user_data.role = None
        user_data.is_active = None

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if _is_admin_role(current_user):
        _ensure_user_account_can_be_managed(current_user, user)

    update_data = user_data.model_dump(exclude_unset=True, exclude_none=True)
    if "role" in update_data:
        _ensure_user_role_can_be_assigned(current_user, update_data["role"])
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
    _ensure_user_account_can_be_managed(current_user, user)
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot delete your own account")

    _delete_user_with_dependencies(
        db,
        user,
        actor_id=current_user.id,
        ip_address=request.client.host if request.client else None,
        action="delete_user",
    )
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
    if not _can_manage_classes(current_user):
        raise HTTPException(status_code=403, detail="Only users and admins can add manual attendance")

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
        if not _can_access_class(db, current_user, class_obj):
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
    if not _can_manage_classes(current_user):
        raise HTTPException(status_code=403, detail="Only users and admins can submit roll calls")

    class_obj = db.query(Class).filter(Class.id == data.class_id).first()
    if not class_obj:
        raise HTTPException(status_code=404, detail="Class not found")
    if not _can_access_class(db, current_user, class_obj):
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
    if _is_teacher_role(current_user):
        accessible_class_ids = _accessible_class_ids_for_user(db, current_user)
        if accessible_class_ids:
            query = query.filter(Attendance.class_id.in_(accessible_class_ids))
        else:
            query = query.filter(Attendance.user_id == current_user.id)
    elif not _is_admin_role(current_user):
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

    if _is_teacher_role(current_user):
        accessible_class_ids = _accessible_class_ids_for_user(db, current_user)
        if accessible_class_ids:
            query = query.filter(Attendance.class_id.in_(accessible_class_ids))
        else:
            query = query.filter(Attendance.user_id == current_user.id)
        if user_id:
            query = query.filter(Attendance.user_id == user_id)
    elif not _is_admin_role(current_user):
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
    if not _is_admin_role(current_user) and current_user.id != user_id:
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
    if not _can_manage_classes(current_user):
        raise HTTPException(status_code=403, detail="Only users and admins can update attendance")

    attendance = db.query(Attendance).filter(Attendance.id == attendance_id).first()
    if not attendance:
        raise HTTPException(status_code=404, detail="Attendance record not found")
    if attendance.class_id is not None:
        class_obj = db.query(Class).filter(Class.id == attendance.class_id).first()
        if class_obj and not _can_access_class(db, current_user, class_obj):
            raise HTTPException(status_code=403, detail="Not authorized for this class")

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
    request: Request,
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    class_id: Optional[int] = Query(None),
    user_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Export attendance history as CSV (teacher/admin)."""
    if not _can_manage_classes(current_user):
        raise HTTPException(status_code=403, detail="Only users and admins can export attendance")

    query = db.query(Attendance)

    if _is_teacher_role(current_user):
        accessible_class_ids = _accessible_class_ids_for_user(db, current_user)
        if accessible_class_ids:
            query = query.filter(Attendance.class_id.in_(accessible_class_ids))
        else:
            query = query.filter(Attendance.user_id == current_user.id)

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
    writer.writerow([
        "ID",
        "Student Name",
        "Class",
        "Email",
        "Date",
        "Check-In Time",
        "Check-Out Time",
        "Status",
        "Method",
        "Confidence",
        "Notes",
        "Face Image Path",
        "Face Image URL",
    ])

    for r in records:
        response = _attendance_to_response(db, r)
        display_name = response.student_name or (response.user.full_name if response.user else "Unknown")
        display_email = response.user.email if response.user else ""
        face_image_path = _attendance_face_image_path(db, r)
        face_image_url = _build_face_image_url(request, face_image_path)
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
            r.notes or "",
            face_image_path or "",
            face_image_url or "",
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
        class_obj = db.query(Class).filter(Class.id == class_id).first()
        if not class_obj:
            raise HTTPException(status_code=404, detail="Class not found")
        if not _can_access_class(db, current_user, class_obj):
            raise HTTPException(status_code=403, detail="Not authorized for this class")

        expected_students = db.query(Student).filter(
            Student.class_id == class_id,
            Student.has_registered_face == True
        ).all()

        scan_time = datetime.now()
        target_date = scan_time.date()
        managed_students = []
        for student in expected_students:
            managed_user = _ensure_student_linked_user(db, student, class_obj)
            managed_students.append((student, managed_user))

        existing_by_user_id = {}
        if managed_students:
            existing_records = db.query(Attendance).filter(
                Attendance.user_id.in_([managed_user.id for _, managed_user in managed_students]),
                func.date(Attendance.date) == target_date
            ).all()
            existing_by_user_id = {record.user_id: record for record in existing_records}

        present_ids = set()
        if face_locations:
            face_recognition = _get_face_recognition_module()
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

        for student, managed_user in managed_students:
            existing = existing_by_user_id.get(managed_user.id)
            is_present = student.id in present_ids

            if existing is None:
                attendance = Attendance(
                    user_id=managed_user.id,
                    student_id=student.id,
                    class_id=class_obj.id,
                    date=scan_time,
                    check_in_time=scan_time if is_present else None,
                    method="room_scan",
                    status="present" if is_present else "absent",
                )
                db.add(attendance)
                existing_by_user_id[managed_user.id] = attendance
                continue

            existing.student_id = student.id
            existing.class_id = class_obj.id

            if is_present and existing.status == "absent" and existing.method == "room_scan":
                existing.status = "present"
                existing.date = scan_time
                existing.check_in_time = scan_time
        db.commit()

        faces_detected = len(face_locations)
        if faces_detected == 0:
            msg = (
                f"No faces were detected in the image. Marked {len(absent_students)} "
                f"expected students absent for today in {class_obj.name}."
            )
        elif len(present_students) == 0:
            msg = (
                f"{faces_detected} face(s) were detected in the image but none matched any "
                f"registered student in '{class_obj.name}'. Expected students were marked absent for today."
            )
        else:
            msg = (
                f"Recorded attendance for {len(expected_students)} students in {class_obj.name}. "
                f"Found {len(present_students)} present and {len(absent_students)} absent."
            )
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

    face_recognition = _get_face_recognition_module()
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
    if not _can_manage_classes(current_user):
        raise HTTPException(status_code=403, detail="Only users and admins can create QR sessions")

    settings = _get_settings(db)
    if not settings.allow_qr_attendance:
        raise HTTPException(status_code=400, detail="QR attendance is currently disabled")

    class_obj = db.query(Class).filter(Class.id == data.class_id).first()
    if not class_obj:
        raise HTTPException(status_code=404, detail="Class not found")
    if not _can_access_class(db, current_user, class_obj):
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

    return QRSessionResponse(
        id=session.id,
        class_id=session.class_id,
        class_name=class_obj.name,
        token=session.token,
        expires_at=session.expires_at,
        is_active=session.is_active,
        session_date=session.session_date,
        created_at=session.created_at,
        qr_url=_build_qr_scan_url(request, session.token),
    )


@app.get("/api/qr/session/{class_id}", response_model=Optional[QRSessionResponse], tags=["QR Attendance"])
async def get_active_qr_session(
    class_id: int,
    request: Request,
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
    return QRSessionResponse(
        id=session.id,
        class_id=session.class_id,
        class_name=class_obj.name if class_obj else None,
        token=session.token,
        expires_at=session.expires_at,
        is_active=session.is_active,
        session_date=session.session_date,
        created_at=session.created_at,
        qr_url=_build_qr_scan_url(request, session.token),
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
    if not _can_manage_classes(current_user):
        raise HTTPException(status_code=403, detail="Not authorized")

    session = db.query(QRSession).filter(QRSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    class_obj = db.query(Class).filter(Class.id == session.class_id).first()
    if class_obj and not _can_access_class(db, current_user, class_obj):
        raise HTTPException(status_code=403, detail="Not authorized for this class")

    session.is_active = False
    db.commit()
    return {"message": "QR session deactivated"}


# ========================
# SUPERVISION ENDPOINTS
# ========================

@app.get("/api/supervision/overview", response_model=SupervisionOverviewResponse, tags=["Supervision"])
async def get_supervision_overview(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Supervisor hub data for teachers and admins."""
    if _has_global_group_access(current_user):
        groups = db.query(TeacherGroup).order_by(TeacherGroup.created_at.desc()).all()
        invitations = (
            db.query(TeacherGroupInvite)
            .order_by(TeacherGroupInvite.created_at.desc())
            .all()
        )
    else:
        group_ids = _user_group_ids(db, current_user.id)
        if group_ids:
            groups = (
                db.query(TeacherGroup)
                .filter(TeacherGroup.id.in_(group_ids))
                .order_by(TeacherGroup.created_at.desc())
                .all()
            )
        else:
            groups = []
        invitations = (
            db.query(TeacherGroupInvite)
            .filter(
                or_(
                    func.lower(TeacherGroupInvite.email) == current_user.email.lower(),
                    TeacherGroupInvite.teacher_id == current_user.id,
                )
            )
            .order_by(TeacherGroupInvite.created_at.desc())
            .all()
        )

    if _is_admin_role(current_user):
        shareable_classes = (
            db.query(Class)
            .order_by(Class.created_at.desc())
            .all()
        )
    elif _is_teacher_role(current_user):
        shareable_classes = (
            db.query(Class)
            .filter(Class.teacher_id == current_user.id)
            .order_by(Class.created_at.desc())
            .all()
        )
    else:
        shareable_classes = []

    pending_leave_count = (
        db.query(LeaveRequest)
        .filter(LeaveRequest.status == "pending")
        .count()
        if _can_review_leave_requests(current_user)
        else 0
    )

    return SupervisionOverviewResponse(
        can_create_groups=_can_create_groups(current_user),
        can_manage_groups=_has_global_group_access(current_user),
        can_share_classes=_can_manage_classes(current_user),
        pending_leave_count=pending_leave_count,
        groups=[_group_to_response(group, db, current_user) for group in groups],
        invitations=[_group_invite_to_response(invite) for invite in invitations],
        shareable_classes=[_class_to_response(class_obj, db) for class_obj in shareable_classes],
    )


@app.post("/api/supervision/groups", response_model=TeacherGroupResponse, tags=["Supervision"])
async def create_teacher_group(
    data: TeacherGroupCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Create a school teacher group."""
    if not _can_create_groups(current_user):
        raise HTTPException(
            status_code=403,
            detail="Managed student accounts cannot create user groups",
        )

    group = TeacherGroup(
        name=data.name.strip(),
        description=(data.description or "").strip() or None,
        created_by_id=current_user.id,
    )
    db.add(group)
    db.flush()

    _ensure_group_member(db, group.id, current_user.id)

    db.commit()
    db.refresh(group)

    _write_audit(
        db,
        current_user.id,
        "create_teacher_group",
        "TeacherGroup",
        group.id,
        f"Created user group {group.name}",
        request.client.host if request.client else None,
    )
    db.commit()
    return _group_to_response(group, db, current_user)


@app.post("/api/supervision/groups/{group_id}/invites", response_model=TeacherGroupResponse, tags=["Supervision"])
async def invite_teachers_to_group(
    group_id: int,
    data: TeacherGroupInviteCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Invite teachers to a group by email."""
    group = db.query(TeacherGroup).filter(TeacherGroup.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="User group not found")
    if not _can_manage_group(current_user, group):
        raise HTTPException(
            status_code=403,
            detail="Only group owners, super users, and admins can invite users",
        )
    if data.target_role not in SHARE_TARGET_ROLES:
        raise HTTPException(status_code=400, detail="Invalid user target role")
    if data.target_role == "super_teacher" and not _has_global_group_access(current_user):
        raise HTTPException(
            status_code=403,
            detail="Only admins and super users can invite super users",
        )

    normalized_emails = []
    seen_emails = set()
    for email in data.emails:
        value = email.strip().lower()
        if value in seen_emails:
            continue
        seen_emails.add(value)
        normalized_emails.append(value)

    for email in normalized_emails:
        existing_user = db.query(User).filter(func.lower(User.email) == email).first()
        if existing_user and not _can_use_user_groups(existing_user):
            raise HTTPException(
                status_code=400,
                detail=f"{email} is a managed student account and cannot be added to a user group",
            )

        if existing_user and _is_group_member(db, existing_user.id, group_id):
            if (
                data.target_role == "super_teacher"
                and _has_global_group_access(current_user)
                and existing_user.role == "teacher"
            ):
                existing_user.role = "super_teacher"
                _push_notification(
                    db,
                    existing_user.id,
                    "Supervisor Access Updated",
                    f"You were promoted to super user in {group.name}.",
                    "system",
                )
            continue

        existing_invite = (
            db.query(TeacherGroupInvite)
            .filter(
                TeacherGroupInvite.group_id == group_id,
                func.lower(TeacherGroupInvite.email) == email,
                TeacherGroupInvite.status == "pending",
            )
            .first()
        )
        if existing_invite:
            continue

        invite = TeacherGroupInvite(
            group_id=group_id,
            email=email,
            invited_by_id=current_user.id,
            teacher_id=existing_user.id if existing_user else None,
            target_role=data.target_role,
            note=(data.note or "").strip() or None,
        )
        db.add(invite)
        db.flush()

        if existing_user:
            _push_notification(
                db,
                existing_user.id,
                "User Group Invitation",
                f"You were invited to join {group.name} as {_display_role_name(data.target_role)}.",
                "system",
                "teacher_group_invite",
                invite.id,
            )

    _write_audit(
        db,
        current_user.id,
        "invite_teachers_to_group",
        "TeacherGroup",
        group.id,
        f"Invited {len(normalized_emails)} users to {group.name}",
        request.client.host if request.client else None,
    )
    db.commit()
    db.refresh(group)
    return _group_to_response(group, db, current_user)


@app.patch("/api/supervision/invitations/{invite_id}", response_model=TeacherGroupInviteResponse, tags=["Supervision"])
async def respond_to_teacher_group_invitation(
    invite_id: int,
    data: TeacherGroupInviteRespond,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Accept or reject a teacher group invitation."""
    invite = db.query(TeacherGroupInvite).filter(TeacherGroupInvite.id == invite_id).first()
    if not invite:
        raise HTTPException(status_code=404, detail="Invitation not found")
    if invite.status != "pending":
        raise HTTPException(status_code=400, detail="Invitation already processed")
    if invite.email.lower() != current_user.email.lower() and invite.teacher_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to respond to this invitation")
    if not _can_use_user_groups(current_user):
        raise HTTPException(
            status_code=400,
            detail="Managed student accounts cannot join user groups",
        )

    invite.status = data.status
    invite.teacher_id = current_user.id
    invite.responded_at = datetime.utcnow()

    if data.status == "accepted":
        _ensure_group_member(db, invite.group_id, current_user.id)
        if invite.target_role == "super_teacher" and current_user.role == "teacher":
            current_user.role = "super_teacher"
        _push_notification(
            db,
            invite.invited_by_id,
            "User Invitation Accepted",
            f"{current_user.full_name} joined {invite.group.name if invite.group else 'the user group'}.",
            "system",
            "teacher_group_invite",
            invite.id,
        )
    else:
        _push_notification(
            db,
            invite.invited_by_id,
            "User Invitation Rejected",
            f"{current_user.full_name} rejected the invitation to {invite.group.name if invite.group else 'the user group'}.",
            "system",
            "teacher_group_invite",
            invite.id,
        )

    _write_audit(
        db,
        current_user.id,
        f"{data.status}_teacher_group_invitation",
        "TeacherGroupInvite",
        invite.id,
        f"{current_user.email} {data.status} group invitation {invite.id}",
        request.client.host if request.client else None,
    )
    db.commit()
    db.refresh(invite)
    return _group_invite_to_response(invite)


@app.patch("/api/supervision/groups/{group_id}/members/{teacher_id}", response_model=TeacherGroupResponse, tags=["Supervision"])
async def update_teacher_group_member_role(
    group_id: int,
    teacher_id: int,
    data: TeacherGroupMemberUpdate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Promote or demote a teacher inside the supervision flow."""
    if not _can_manage_groups(current_user):
        raise HTTPException(
            status_code=403,
            detail="Only admins and super users can update user group roles",
        )

    group = db.query(TeacherGroup).filter(TeacherGroup.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="User group not found")

    member = (
        db.query(TeacherGroupMember)
        .filter(
            TeacherGroupMember.group_id == group_id,
            TeacherGroupMember.teacher_id == teacher_id,
        )
        .first()
    )
    if not member or not member.teacher:
        raise HTTPException(status_code=404, detail="User group member not found")

    member.teacher.role = data.role
    _push_notification(
        db,
        member.teacher_id,
        "Supervisor Access Updated",
        f"Your supervision role in {group.name} is now {_display_role_name(data.role)}.",
        "system",
    )
    _write_audit(
        db,
        current_user.id,
        "update_teacher_group_member_role",
        "TeacherGroup",
        group.id,
        f"Set {member.teacher.email} to {data.role} in {group.name}",
        request.client.host if request.client else None,
    )
    db.commit()
    db.refresh(group)
    return _group_to_response(group, db, current_user)


@app.post("/api/supervision/class-shares", response_model=GroupSharedClassResponse, tags=["Supervision"])
async def share_class_with_teacher_group(
    data: GroupSharedClassCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Share a class with all teachers inside a group."""
    if not _can_manage_classes(current_user):
        raise HTTPException(status_code=403, detail="Only users and admins can share classes")

    class_obj = db.query(Class).filter(Class.id == data.class_id).first()
    if not class_obj:
        raise HTTPException(status_code=404, detail="Class not found")

    group = db.query(TeacherGroup).filter(TeacherGroup.id == data.group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="User group not found")

    if not _can_edit_class(db, current_user, class_obj):
        raise HTTPException(status_code=403, detail="Only the class owner or admin can share this class")
    if not _can_manage_groups(current_user) and not _is_group_member(db, current_user.id, group.id):
        raise HTTPException(status_code=403, detail="You must belong to the user group to share into it")

    existing_share = (
        db.query(GroupSharedClass)
        .filter(
            GroupSharedClass.group_id == data.group_id,
            GroupSharedClass.class_id == data.class_id,
        )
        .first()
    )
    if existing_share:
        return _group_shared_class_to_response(existing_share)

    shared = GroupSharedClass(
        group_id=data.group_id,
        class_id=data.class_id,
        shared_by_id=current_user.id,
    )
    db.add(shared)
    db.flush()

    members = (
        db.query(TeacherGroupMember)
        .filter(TeacherGroupMember.group_id == group.id)
        .all()
    )
    for member in members:
        if member.teacher_id == current_user.id:
            continue
        _push_notification(
            db,
            member.teacher_id,
            "Class Shared With Your Group",
            f"{class_obj.name} is now available through {group.name}.",
            "system",
            "shared_class",
            shared.id,
        )

    _write_audit(
        db,
        current_user.id,
        "share_class_with_group",
        "Class",
        class_obj.id,
        f"Shared class {class_obj.name} with group {group.name}",
        request.client.host if request.client else None,
    )
    db.commit()
    db.refresh(shared)
    return _group_shared_class_to_response(shared)


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

    # Notify leave reviewers
    admins = db.query(User).filter(
        User.role.in_(list(ADMIN_ROLES | TEACHER_ROLES)),
        User.is_active == True,
    ).all()
    requester_name = current_user.full_name
    for admin in admins:
        _push_notification(
            db, admin.id,
            "New Leave Request",
            f"{requester_name} submitted a leave request for {data.leave_date.strftime('%Y-%m-%d %I:%M %p')}.",
            "leave",
            "leave_request", leave.id
        )
    db.commit()

    return _leave_to_response(leave)


@app.get("/api/leave", response_model=List[LeaveRequestResponse], tags=["Leave Requests"])
async def get_leave_requests(
    status_filter: Optional[str] = Query(None),
    student_id: Optional[int] = Query(None),
    user_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get leave requests (own for students, all for admin/teacher)"""
    query = db.query(LeaveRequest)

    if not _can_review_leave_requests(current_user):
        query = query.filter(LeaveRequest.user_id == current_user.id)
    else:
        if student_id is not None and user_id is not None:
            query = query.filter(
                or_(
                    LeaveRequest.student_id == student_id,
                    LeaveRequest.user_id == user_id,
                )
            )
        elif student_id is not None:
            query = query.filter(LeaveRequest.student_id == student_id)
        elif user_id is not None:
            query = query.filter(LeaveRequest.user_id == user_id)

    if status_filter:
        query = query.filter(LeaveRequest.status == status_filter)

    leaves = query.order_by(LeaveRequest.created_at.desc()).all()
    return [_leave_to_response(l) for l in leaves]


@app.put("/api/leave/{leave_id}", response_model=LeaveRequestResponse, tags=["Leave Requests"])
async def update_leave_request(
    leave_id: int,
    data: LeaveRequestUpdate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Update a pending leave request owned by the current requester"""
    leave = db.query(LeaveRequest).filter(LeaveRequest.id == leave_id).first()
    if not leave:
        raise HTTPException(status_code=404, detail="Leave request not found")
    if leave.submitted_by_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the requester can edit this leave request")
    if leave.status != "pending":
        raise HTTPException(status_code=400, detail="Cannot edit a reviewed leave request")

    leave.leave_date = data.leave_date
    leave.reason = data.reason
    leave.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(leave)

    _write_audit(
        db,
        current_user.id,
        "update_leave",
        "LeaveRequest",
        leave_id,
        f"Updated leave request {leave_id}",
        request.client.host if request.client else None,
    )
    db.commit()

    return _leave_to_response(leave)


@app.patch("/api/leave/{leave_id}", response_model=LeaveRequestResponse, tags=["Leave Requests"])
async def review_leave_request(
    leave_id: int,
    data: LeaveRequestReview,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Approve or reject a leave request (teacher/admin)"""
    if not _can_review_leave_requests(current_user):
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
            f"Your leave request for {leave.leave_date.strftime('%Y-%m-%d %I:%M %p')} was {action_text}."
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
    """Delete a leave request"""
    leave = db.query(LeaveRequest).filter(LeaveRequest.id == leave_id).first()
    if not leave:
        raise HTTPException(status_code=404, detail="Leave request not found")
    can_review = _can_review_leave_requests(current_user)
    if leave.submitted_by_id != current_user.id and not can_review:
        raise HTTPException(status_code=403, detail="Not authorized")
    if leave.status != "pending" and not can_review:
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
    if not _can_manage_classes(current_user):
        raise HTTPException(status_code=403, detail="Only users and admins can create classes")

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
    if not _is_admin_role(current_user):
        visible_class_ids = _shared_class_ids_for_user(db, current_user.id)
        if visible_class_ids:
            query = query.filter(
                or_(
                    Class.teacher_id == current_user.id,
                    Class.id.in_(visible_class_ids),
                )
            )
        else:
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
    if not _can_access_class(db, current_user, class_obj):
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
    if not _can_edit_class(db, current_user, class_obj):
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
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    class_obj = db.query(Class).filter(Class.id == class_id).first()
    if not class_obj:
        raise HTTPException(status_code=404, detail="Class not found")
    if not _can_access_class(db, current_user, class_obj):
        raise HTTPException(status_code=403, detail="Not authorized")

    students = db.query(Student).filter(Student.class_id == class_id).all()
    return [_student_to_response(student, request) for student in students]


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
    if not _can_access_class(db, current_user, class_obj):
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
    if not _can_access_class(db, current_user, class_obj):
        raise HTTPException(status_code=403, detail="Not authorized")

    _delete_class_with_dependencies(
        db,
        class_obj,
        actor_id=current_user.id,
        ip_address=request.client.host if request.client else None,
    )
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
    if not _can_edit_class(db, current_user, class_obj):
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
    if not _can_edit_class(db, current_user, class_obj):
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
    return _student_to_response(student, request)


@app.post("/api/students/register", response_model=StudentRegistrationResponse, tags=["Students"])
async def register_student(
    name: str = Form(...),
    class_id: int = Form(...),
    images: List[UploadFile] = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Register a new student with face images (teacher/admin)"""
    if not _can_manage_classes(current_user):
        raise HTTPException(status_code=403, detail="Only users and admins can register students")

    class_obj = db.query(Class).filter(Class.id == class_id).first()
    if not class_obj:
        raise HTTPException(status_code=404, detail="Class not found")
    if not _can_edit_class(db, current_user, class_obj):
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
    if not _can_manage_classes(current_user):
        raise HTTPException(status_code=403, detail="Only users and admins can import students")

    class_obj = db.query(Class).filter(Class.id == class_id).first()
    if not class_obj:
        raise HTTPException(status_code=404, detail="Class not found")
    if not _can_edit_class(db, current_user, class_obj):
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
