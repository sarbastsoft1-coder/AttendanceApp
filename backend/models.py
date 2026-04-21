"""
Pydantic models for request/response validation
"""
from datetime import datetime
from typing import Optional, List, Any
from pydantic import BaseModel, EmailStr, Field


# ========================
# TOKEN SCHEMAS
# ========================

class Token(BaseModel):
    """JWT Token response"""
    access_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    """Token payload data"""
    user_id: Optional[int] = None
    email: Optional[str] = None


# ========================
# USER SCHEMAS
# ========================

class UserBase(BaseModel):
    """Base user schema"""
    email: EmailStr
    full_name: str


class UserCreate(UserBase):
    """User registration request"""
    password: str = Field(..., min_length=6)
    phone: Optional[str] = None
    department: Optional[str] = None


class ManagedUserCreate(UserCreate):
    """Admin-created user request"""
    role: str = Field(
        default="teacher",
        pattern="^(teacher|super_teacher|admin|super_admin)$",
    )
    admin_access_key: Optional[str] = Field(default=None, min_length=4)


class UserLogin(BaseModel):
    """User login request"""
    email: EmailStr
    password: str
    admin_access_key: Optional[str] = None


class UserUpdate(BaseModel):
    """User update request"""
    full_name: Optional[str] = None
    phone: Optional[str] = None
    department: Optional[str] = None
    is_active: Optional[bool] = None
    role: Optional[str] = None


class UserResponse(UserBase):
    """User response"""
    id: int
    phone: Optional[str] = None
    department: Optional[str] = None
    role: str
    face_image_path: Optional[str] = None
    face_image_url: Optional[str] = None
    has_registered_face: bool
    is_active: bool
    is_verified: bool
    created_at: datetime

    class Config:
        from_attributes = True


class UserWithToken(BaseModel):
    """User response with token"""
    user: UserResponse
    token: Token


# ========================
# PASSWORD RESET SCHEMAS
# ========================

class ForgotPasswordRequest(BaseModel):
    """Forgot password request"""
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    """Reset password with token"""
    token: str
    new_password: str = Field(..., min_length=6)


class ChangePasswordRequest(BaseModel):
    """Change password (authenticated)"""
    current_password: str
    new_password: str = Field(..., min_length=6)


class PasswordResetTokenResponse(BaseModel):
    """Password reset token response"""
    message: str
    reset_token: Optional[str] = None  # Returned only in dev/local mode


# ========================
# ATTENDANCE SCHEMAS
# ========================

class AttendanceCreate(BaseModel):
    """Attendance marking request"""
    user_id: Optional[int] = None
    confidence: Optional[float] = None
    method: Optional[str] = "face"
    location: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    notes: Optional[str] = None


class AttendanceManualCreate(BaseModel):
    """Manual attendance creation by teacher/admin"""
    user_id: Optional[int] = None
    student_id: Optional[int] = None
    class_id: Optional[int] = None
    attendance_date: Optional[datetime] = None
    status: str = Field(default="present", pattern="^(present|late|absent|half_day)$")
    check_in_time: Optional[datetime] = None
    check_out_time: Optional[datetime] = None
    notes: Optional[str] = None


class AttendanceUpdate(BaseModel):
    """Attendance status update request"""
    status: str = Field(..., pattern="^(present|late|absent|half_day)$")
    notes: Optional[str] = None


class AttendanceResponse(BaseModel):
    """Attendance record response"""
    id: int
    user_id: Optional[int] = None
    student_id: Optional[int] = None
    class_id: Optional[int] = None
    date: datetime
    check_in_time: Optional[datetime] = None
    check_out_time: Optional[datetime] = None
    confidence: Optional[float] = None
    method: str
    status: str
    location: Optional[str] = None
    notes: Optional[str] = None
    created_at: datetime

    # Include user info
    user: Optional[UserResponse] = None
    student_name: Optional[str] = None
    class_name: Optional[str] = None

    class Config:
        from_attributes = True


class AttendanceStats(BaseModel):
    """Attendance statistics"""
    user_id: int
    total_days: int
    present_days: int
    late_days: int
    absent_days: int
    attendance_percentage: float
    below_threshold: bool = False
    threshold: float = 75.0


class AttendanceReport(BaseModel):
    """Attendance report for a date range"""
    start_date: datetime
    end_date: datetime
    total_users: int
    present_count: int
    late_count: int
    absent_count: int
    attendance_list: List[AttendanceResponse]


# ========================
# PAGINATION
# ========================

class PaginatedAttendance(BaseModel):
    """Paginated attendance response"""
    items: List[AttendanceResponse]
    total: int
    page: int
    page_size: int
    total_pages: int


# ========================
# FACE RECOGNITION SCHEMAS
# ========================

class FaceRegistrationResponse(BaseModel):
    """Face registration response"""
    success: bool
    message: str
    user_id: int
    images_processed: int


class FaceRecognitionResult(BaseModel):
    """Face recognition result"""
    recognized: bool
    user_id: Optional[int] = None
    user_name: Optional[str] = None
    confidence: Optional[float] = None
    message: str


class RoomScanResponse(BaseModel):
    """Result of a group/room scan"""
    present_count: int
    absent_count: int
    total_students: int
    present_users: List[UserResponse]
    absent_users: List[UserResponse]
    message: str


# ========================
# ADMIN SCHEMAS
# ========================

class DashboardStats(BaseModel):
    """Admin dashboard statistics"""
    total_users: int
    active_users: int
    present_today: int
    late_today: int
    absent_today: int
    registered_faces: int
    pending_leaves: int = 0
    unread_notifications: int = 0


class UserFilter(BaseModel):
    """User filter for admin queries"""
    role: Optional[str] = None
    department: Optional[str] = None
    is_active: Optional[bool] = None
    has_face: Optional[bool] = None


# ========================
# CLASS AND STUDENT SCHEMAS
# ========================

class ClassBase(BaseModel):
    """Shared class fields"""
    name: str = Field(..., min_length=1, max_length=255)
    subject: Optional[str] = Field(default=None, max_length=255)
    room: Optional[str] = Field(default=None, max_length=255)
    start_time: Optional[str] = Field(default=None, max_length=20)
    end_time: Optional[str] = Field(default=None, max_length=20)
    meeting_days: Optional[List[str]] = None


class ClassCreate(ClassBase):
    """Class creation request"""


class ClassUpdate(BaseModel):
    """Class update request"""
    name: Optional[str] = Field(default=None, min_length=1, max_length=255)
    subject: Optional[str] = Field(default=None, max_length=255)
    room: Optional[str] = Field(default=None, max_length=255)
    start_time: Optional[str] = Field(default=None, max_length=20)
    end_time: Optional[str] = Field(default=None, max_length=20)
    meeting_days: Optional[List[str]] = None


class ClassResponse(BaseModel):
    """Class response"""
    id: int
    name: str
    teacher_id: int
    subject: Optional[str] = None
    room: Optional[str] = None
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    meeting_days: List[str] = []
    created_at: datetime
    student_count: int = 0

    class Config:
        from_attributes = True


class TeacherGroupCreate(BaseModel):
    """Create a school teacher group."""
    name: str = Field(..., min_length=2, max_length=255)
    description: Optional[str] = Field(default=None, max_length=1000)


class TeacherGroupInviteCreate(BaseModel):
    """Invite one or more teachers to a group by email."""
    emails: List[EmailStr]
    target_role: str = Field(default="teacher", pattern="^(teacher|super_teacher)$")
    note: Optional[str] = Field(default=None, max_length=1000)


class TeacherGroupInviteRespond(BaseModel):
    """Teacher accepts or rejects a group invitation."""
    status: str = Field(..., pattern="^(accepted|rejected)$")


class TeacherGroupMemberUpdate(BaseModel):
    """Update the role of a teacher inside the supervision flow."""
    role: str = Field(..., pattern="^(teacher|super_teacher)$")


class GroupSharedClassCreate(BaseModel):
    """Share a class with all teachers in a group."""
    class_id: int
    group_id: int


class TeacherGroupMemberResponse(BaseModel):
    """Member inside a teacher group."""
    id: int
    teacher_id: int
    teacher_name: str
    teacher_email: str
    teacher_role: str
    joined_at: datetime


class TeacherGroupInviteResponse(BaseModel):
    """Teacher group invitation."""
    id: int
    group_id: int
    email: str
    invited_by_id: int
    invited_by_name: Optional[str] = None
    teacher_id: Optional[int] = None
    teacher_name: Optional[str] = None
    target_role: str
    status: str
    note: Optional[str] = None
    created_at: datetime
    responded_at: Optional[datetime] = None


class GroupSharedClassResponse(BaseModel):
    """Class shared with a teacher group."""
    id: int
    group_id: int
    class_id: int
    class_name: str
    shared_by_id: int
    shared_by_name: Optional[str] = None
    created_at: datetime


class TeacherGroupResponse(BaseModel):
    """Teacher group with current members, invitations, and shared classes."""
    id: int
    name: str
    description: Optional[str] = None
    created_by_id: int
    created_by_name: Optional[str] = None
    can_manage: bool = False
    created_at: datetime
    updated_at: datetime
    members: List[TeacherGroupMemberResponse] = []
    invitations: List[TeacherGroupInviteResponse] = []
    shared_classes: List[GroupSharedClassResponse] = []


class SupervisionOverviewResponse(BaseModel):
    """Supervisor hub payload."""
    can_create_groups: bool = False
    can_manage_groups: bool
    can_share_classes: bool
    pending_leave_count: int = 0
    groups: List[TeacherGroupResponse] = []
    invitations: List[TeacherGroupInviteResponse] = []
    shareable_classes: List[ClassResponse] = []


class StudentResponse(BaseModel):
    """Student response"""
    id: int
    name: str
    class_id: int
    linked_user_id: Optional[int] = None
    face_image_path: Optional[str] = None
    face_image_url: Optional[str] = None
    has_registered_face: bool
    created_at: datetime

    class Config:
        from_attributes = True


class StudentRegistrationResponse(BaseModel):
    """Student registration response"""
    success: bool
    message: str
    student_id: int
    images_processed: int


# ========================
# LEAVE REQUEST SCHEMAS
# ========================

class LeaveRequestCreate(BaseModel):
    """Create a leave request"""
    user_id: Optional[int] = None
    student_id: Optional[int] = None
    leave_date: datetime
    reason: str = Field(..., min_length=5)


class LeaveRequestReview(BaseModel):
    """Admin/teacher reviewing a leave request"""
    status: str = Field(..., pattern="^(approved|rejected)$")
    review_note: Optional[str] = None


class LeaveRequestUpdate(BaseModel):
    """Requester updating a pending leave request"""
    leave_date: datetime
    reason: str = Field(..., min_length=5)


class LeaveRequestResponse(BaseModel):
    """Leave request response"""
    id: int
    user_id: Optional[int] = None
    student_id: Optional[int] = None
    submitted_by_id: int
    leave_date: datetime
    reason: str
    status: str
    reviewed_by_id: Optional[int] = None
    reviewed_at: Optional[datetime] = None
    review_note: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    # Embedded names for display
    user_name: Optional[str] = None
    student_name: Optional[str] = None
    submitted_by_name: Optional[str] = None
    reviewed_by_name: Optional[str] = None

    class Config:
        from_attributes = True


# ========================
# SETTINGS SCHEMAS
# ========================

class SettingUpdate(BaseModel):
    """Update a single setting"""
    value: str


class SettingResponse(BaseModel):
    """Setting key-value response"""
    key: str
    value: str
    description: Optional[str] = None
    updated_at: datetime

    class Config:
        from_attributes = True


class SettingsBulkUpdate(BaseModel):
    """Bulk update settings"""
    settings: dict  # {key: value}


class AppSettings(BaseModel):
    """Parsed app settings for easy consumption"""
    late_threshold_hour: int = 9
    late_threshold_minute: int = 0
    min_face_images: int = 2
    max_face_images: int = 10
    attendance_alert_pct: float = 75.0
    qr_session_minutes: int = 15
    allow_manual_entry: bool = True
    allow_qr_attendance: bool = True
    allow_face_attendance: bool = True
    app_name: str = "Face Attendance System"


# ========================
# AUDIT LOG SCHEMAS
# ========================

class AuditLogResponse(BaseModel):
    """Audit log entry response"""
    id: int
    actor_id: Optional[int] = None
    actor_name: Optional[str] = None
    action: str
    target_type: Optional[str] = None
    target_id: Optional[int] = None
    detail: Optional[str] = None
    ip_address: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class PaginatedAuditLog(BaseModel):
    """Paginated audit log"""
    items: List[AuditLogResponse]
    total: int
    page: int
    page_size: int
    total_pages: int


# ========================
# QR SESSION SCHEMAS
# ========================

class QRSessionCreate(BaseModel):
    """Create a QR attendance session"""
    class_id: int
    duration_minutes: Optional[int] = None  # override default setting


class QRSessionResponse(BaseModel):
    """QR session response"""
    id: int
    class_id: int
    class_name: Optional[str] = None
    token: str
    expires_at: datetime
    is_active: bool
    session_date: datetime
    created_at: datetime
    qr_url: Optional[str] = None  # full URL to encode into QR

    class Config:
        from_attributes = True


class QRAttendanceRequest(BaseModel):
    """Student submitting QR scan for attendance"""
    token: str
    student_id: Optional[int] = None  # for class-student model
    user_id: Optional[int] = None     # for user-model


# ========================
# NOTIFICATION SCHEMAS
# ========================

class NotificationResponse(BaseModel):
    """Notification response"""
    id: int
    user_id: int
    title: str
    message: str
    type: str
    is_read: bool
    related_type: Optional[str] = None
    related_id: Optional[int] = None
    created_at: datetime

    class Config:
        from_attributes = True


class NotificationMarkRead(BaseModel):
    """Mark notifications as read"""
    notification_ids: Optional[List[int]] = None  # None = mark all


class UnreadCountResponse(BaseModel):
    """Unread notification count"""
    count: int


# ========================
# ROLL CALL SCHEMAS
# ========================

class RollCallEntry(BaseModel):
    """Single entry in a manual roll call"""
    student_id: Optional[int] = None
    user_id: Optional[int] = None
    status: str = Field(..., pattern="^(present|late|absent|half_day)$")
    notes: Optional[str] = None


class RollCallSubmit(BaseModel):
    """Submit a complete roll call for a class"""
    class_id: int
    attendance_date: Optional[datetime] = None
    entries: List[RollCallEntry]


class RollCallResponse(BaseModel):
    """Roll call submission result"""
    marked_count: int
    skipped_count: int
    message: str


# ========================
# BULK IMPORT SCHEMAS
# ========================

class BulkImportResponse(BaseModel):
    """Response after bulk student import"""
    success_count: int
    error_count: int
    errors: List[str]
    message: str


# ========================
# EXAM PROCTORING SCHEMAS
# ========================

class DetectedObject(BaseModel):
    """Detected object in exam proctoring"""
    type: str
    label: str
    confidence: float
    bbox: List[float]
    color: str = "red"


class ExamProctorResponse(BaseModel):
    """Exam proctoring scan response"""
    student_verified: bool
    student_id: Optional[int] = None
    student_name: Optional[str] = None
    face_count: int
    gaze_direction: str
    detected_objects: List[DetectedObject]
    suspicion_score: float
    violations: List[str]
    is_cheating: bool
    timestamp: datetime
    message: str
