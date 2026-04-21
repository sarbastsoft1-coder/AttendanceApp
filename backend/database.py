"""
Database configuration with PostgreSQL and SQLAlchemy models
"""
import os
from pathlib import Path
from datetime import datetime
from dotenv import load_dotenv
from sqlalchemy import (
    create_engine, Column, Integer, String, Boolean, DateTime, Float,
    ForeignKey, Text, LargeBinary, inspect, text
)
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from sqlalchemy.pool import NullPool

load_dotenv()

_DEFAULT_SQLITE_PATH = Path(__file__).resolve().parent / "attendance.db"
_DEFAULT_SQLITE_URL = f"sqlite:///{_DEFAULT_SQLITE_PATH.as_posix()}"
_PLACEHOLDER_DB_MARKERS = (
    "your_password",
    "username:password",
    "change-this",
)


def _resolve_database_url() -> str:
    """Prefer a real DATABASE_URL, but fall back for placeholder local configs."""
    configured_url = (os.getenv("DATABASE_URL") or "").strip()
    if not configured_url:
        return _DEFAULT_SQLITE_URL

    normalized_url = configured_url.lower()
    if any(marker in normalized_url for marker in _PLACEHOLDER_DB_MARKERS):
        print(
            "DATABASE_URL contains placeholder credentials. "
            f"Falling back to local SQLite at {_DEFAULT_SQLITE_PATH}."
        )
        return _DEFAULT_SQLITE_URL

    return configured_url


# Database URL from environment - Default to SQLite for easy setup
DATABASE_URL = _resolve_database_url()

# Create engine
if DATABASE_URL.startswith("sqlite"):
    engine = create_engine(
        DATABASE_URL,
        connect_args={"check_same_thread": False},
        poolclass=NullPool,
    )
else:
    engine = create_engine(DATABASE_URL, pool_pre_ping=True)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


# ========================
# DATABASE MODELS
# ========================

class User(Base):
    """User model for students, teachers, and admins"""
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    full_name = Column(String(255), nullable=False)
    hashed_password = Column(String(255), nullable=False)

    # User details
    phone = Column(String(20), nullable=True)
    department = Column(String(100), nullable=True)

    # Role: admin, super_admin, teacher, super_teacher, student, managed_student
    role = Column(String(50), default="teacher")

    # Face recognition data
    face_encoding = Column(Text, nullable=True)  # JSON encoded face encoding
    face_image_path = Column(String(500), nullable=True)
    has_registered_face = Column(Boolean, default=False)

    # Status
    is_active = Column(Boolean, default=True)
    is_verified = Column(Boolean, default=False)
    verification_token = Column(String(64), nullable=True)
    admin_access_key_hash = Column(String(255), nullable=True)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    attendances = relationship("Attendance", back_populates="user")
    leave_requests = relationship("LeaveRequest", back_populates="user", foreign_keys="LeaveRequest.user_id")
    notifications = relationship("Notification", back_populates="user")
    audit_logs = relationship("AuditLog", back_populates="actor", foreign_keys="AuditLog.actor_id")


class Attendance(Base):
    """Attendance record model"""
    __tablename__ = "attendance"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    student_id = Column(Integer, nullable=True, index=True)
    class_id = Column(Integer, nullable=True, index=True)

    # Date and time
    date = Column(DateTime, default=datetime.utcnow, index=True)
    check_in_time = Column(DateTime, nullable=True)
    check_out_time = Column(DateTime, nullable=True)

    # Recognition details
    confidence = Column(Float, nullable=True)  # 0-1 confidence score
    method = Column(String(20), default="face")  # face, manual, qr_code, room_scan

    # Status: present, late, absent, half_day
    status = Column(String(20), default="present")

    # Location (optional)
    location = Column(String(255), nullable=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)

    # Notes
    notes = Column(String(500), nullable=True)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    user = relationship("User", back_populates="attendances")


class Class(Base):
    """Class model for grouping students"""
    __tablename__ = "classes"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    teacher_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    subject = Column(String(255), nullable=True)
    room = Column(String(255), nullable=True)
    start_time = Column(String(20), nullable=True)
    end_time = Column(String(20), nullable=True)
    meeting_days = Column(String(100), nullable=True)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    teacher = relationship("User")
    students = relationship("Student", back_populates="class_ref")
    qr_sessions = relationship("QRSession", back_populates="class_ref")


class TeacherGroup(Base):
    """School-level teacher group owned by the creating teacher or admin."""
    __tablename__ = "teacher_groups"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    created_by_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    created_by = relationship("User")
    memberships = relationship(
        "TeacherGroupMember",
        back_populates="group",
        cascade="all, delete-orphan",
    )
    invitations = relationship(
        "TeacherGroupInvite",
        back_populates="group",
        cascade="all, delete-orphan",
    )
    shared_classes = relationship(
        "GroupSharedClass",
        back_populates="group",
        cascade="all, delete-orphan",
    )


class TeacherGroupMember(Base):
    """Teacher membership inside a teacher group."""
    __tablename__ = "teacher_group_members"

    id = Column(Integer, primary_key=True, index=True)
    group_id = Column(Integer, ForeignKey("teacher_groups.id"), nullable=False, index=True)
    teacher_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    joined_at = Column(DateTime, default=datetime.utcnow)

    group = relationship("TeacherGroup", back_populates="memberships")
    teacher = relationship("User")


class TeacherGroupInvite(Base):
    """Invitation sent to a teacher email to join a teacher group."""
    __tablename__ = "teacher_group_invites"

    id = Column(Integer, primary_key=True, index=True)
    group_id = Column(Integer, ForeignKey("teacher_groups.id"), nullable=False, index=True)
    email = Column(String(255), nullable=False, index=True)
    invited_by_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    teacher_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    target_role = Column(String(50), default="teacher")
    status = Column(String(20), default="pending")
    note = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    responded_at = Column(DateTime, nullable=True)

    group = relationship("TeacherGroup", back_populates="invitations")
    invited_by = relationship("User", foreign_keys=[invited_by_id])
    teacher = relationship("User", foreign_keys=[teacher_id])


class GroupSharedClass(Base):
    """Class shared to every teacher who belongs to a group."""
    __tablename__ = "group_shared_classes"

    id = Column(Integer, primary_key=True, index=True)
    group_id = Column(Integer, ForeignKey("teacher_groups.id"), nullable=False, index=True)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False, index=True)
    shared_by_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    group = relationship("TeacherGroup", back_populates="shared_classes")
    class_ref = relationship("Class")
    shared_by = relationship("User", foreign_keys=[shared_by_id])


class Student(Base):
    """Student model - managed by teachers, not separate accounts"""
    __tablename__ = "students"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)
    linked_user_id = Column(Integer, nullable=True, index=True)

    # Face recognition data
    face_encoding = Column(Text, nullable=True)  # JSON encoded face encoding
    face_image_path = Column(String(500), nullable=True)
    has_registered_face = Column(Boolean, default=False)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    class_ref = relationship("Class", back_populates="students")
    leave_requests = relationship("LeaveRequest", back_populates="student", foreign_keys="LeaveRequest.student_id")


# ========================
# PASSWORD RESET
# ========================

class PasswordResetToken(Base):
    """Password reset token model"""
    __tablename__ = "password_reset_tokens"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    token = Column(String(64), unique=True, index=True, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    used = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User")


# ========================
# LEAVE REQUESTS
# ========================

class LeaveRequest(Base):
    """Leave/absence request submitted by a user or for a student"""
    __tablename__ = "leave_requests"

    id = Column(Integer, primary_key=True, index=True)

    # Either a User (registered account) or a Student (teacher-managed) can have a leave request
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    student_id = Column(Integer, ForeignKey("students.id"), nullable=True)

    # Who submitted this request (teacher submitting for student, or user themselves)
    submitted_by_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    leave_date = Column(DateTime, nullable=False)
    reason = Column(Text, nullable=False)

    # Status: pending, approved, rejected
    status = Column(String(20), default="pending")

    # Reviewer
    reviewed_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    reviewed_at = Column(DateTime, nullable=True)
    review_note = Column(Text, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    user = relationship("User", back_populates="leave_requests", foreign_keys=[user_id])
    student = relationship("Student", back_populates="leave_requests", foreign_keys=[student_id])
    submitted_by = relationship("User", foreign_keys=[submitted_by_id])
    reviewed_by = relationship("User", foreign_keys=[reviewed_by_id])


# ========================
# SYSTEM SETTINGS
# ========================

class Setting(Base):
    """System-wide configurable settings"""
    __tablename__ = "settings"

    id = Column(Integer, primary_key=True, index=True)
    key = Column(String(100), unique=True, index=True, nullable=False)
    value = Column(Text, nullable=False)
    description = Column(String(500), nullable=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    updated_by_id = Column(Integer, ForeignKey("users.id"), nullable=True)

    updated_by = relationship("User")


# ========================
# AUDIT LOG
# ========================

class AuditLog(Base):
    """Audit trail of admin/teacher actions"""
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    actor_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # nullable for system actions
    action = Column(String(100), nullable=False)   # e.g. "delete_student", "update_attendance"
    target_type = Column(String(50), nullable=True)  # e.g. "Student", "Attendance"
    target_id = Column(Integer, nullable=True)
    detail = Column(Text, nullable=True)           # JSON or plain description
    ip_address = Column(String(50), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)

    actor = relationship("User", back_populates="audit_logs", foreign_keys=[actor_id])


# ========================
# QR SESSIONS
# ========================

class QRSession(Base):
    """Short-lived QR code session for a class attendance check-in"""
    __tablename__ = "qr_sessions"

    id = Column(Integer, primary_key=True, index=True)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)
    teacher_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    token = Column(String(64), unique=True, index=True, nullable=False)
    expires_at = Column(DateTime, nullable=False)
    is_active = Column(Boolean, default=True)
    # Date this session is for
    session_date = Column(DateTime, default=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)

    class_ref = relationship("Class", back_populates="qr_sessions")
    teacher = relationship("User")


# ========================
# NOTIFICATIONS
# ========================

class Notification(Base):
    """In-app notifications for users"""
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    title = Column(String(255), nullable=False)
    message = Column(Text, nullable=False)
    # Types: attendance, leave, system, alert
    type = Column(String(50), default="system")
    is_read = Column(Boolean, default=False)
    # Optional link data
    related_type = Column(String(50), nullable=True)  # e.g. "leave_request"
    related_id = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)

    user = relationship("User", back_populates="notifications")


# ========================
# DATABASE UTILITIES
# ========================

def get_db():
    """Dependency to get database session"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    """Initialize database tables and seed default settings"""
    Base.metadata.create_all(bind=engine)
    _ensure_schema_updates()
    print("Database tables created successfully.")

    # Seed default settings if they don't exist
    db = SessionLocal()
    try:
        defaults = [
            ("late_threshold_hour",   "9",    "Hour (0-23) after which check-in is considered late"),
            ("late_threshold_minute", "0",    "Minute after which check-in is considered late"),
            ("min_face_images",       "2",    "Minimum face images required for registration"),
            ("max_face_images",       "10",   "Maximum face images allowed for registration"),
            ("attendance_alert_pct",  "75",   "Attendance percentage below which an alert is triggered"),
            ("qr_session_minutes",    "15",   "Minutes a QR attendance session stays valid"),
            ("allow_manual_entry",    "true", "Allow users to manually mark attendance"),
            ("allow_qr_attendance",   "true", "Allow QR code attendance"),
            ("allow_face_attendance", "true", "Allow face recognition attendance"),
            ("app_name",              "Face Attendance System", "Application display name"),
        ]
        for key, value, description in defaults:
            existing = db.query(Setting).filter(Setting.key == key).first()
            if not existing:
                db.add(Setting(key=key, value=value, description=description))
        db.commit()
        print("Default settings seeded.")
    except Exception as e:
        print(f"Warning: Could not seed settings: {e}")
        db.rollback()
    finally:
        db.close()


def _ensure_schema_updates():
    """Add newer columns for existing databases without full migrations."""
    inspector = inspect(engine)

    desired_columns = {
        "attendance": {
            "student_id": "INTEGER",
            "class_id": "INTEGER",
        },
        "students": {
            "linked_user_id": "INTEGER",
        },
        "classes": {
            "subject": "VARCHAR(255)",
            "room": "VARCHAR(255)",
            "start_time": "VARCHAR(20)",
            "end_time": "VARCHAR(20)",
            "meeting_days": "VARCHAR(100)",
        },
        "users": {
            "admin_access_key_hash": "VARCHAR(255)",
        },
    }

    with engine.begin() as connection:
        for table_name, columns in desired_columns.items():
            existing_columns = {col["name"] for col in inspector.get_columns(table_name)}
            for column_name, column_type in columns.items():
                if column_name in existing_columns:
                    continue
                connection.execute(
                    text(f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_type}")
                )
                print(f"Added column {table_name}.{column_name}")


if __name__ == "__main__":
    init_db()
