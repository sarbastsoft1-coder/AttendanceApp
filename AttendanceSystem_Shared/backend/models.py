"""
Pydantic models for request/response validation
"""
from datetime import datetime
from typing import Optional, List
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
    role: Optional[str] = "student"


class UserLogin(BaseModel):
    """User login request"""
    email: EmailStr
    password: str


class UserUpdate(BaseModel):
    """User update request"""
    full_name: Optional[str] = None
    phone: Optional[str] = None
    department: Optional[str] = None
    is_active: Optional[bool] = None


class UserResponse(UserBase):
    """User response"""
    id: int
    phone: Optional[str] = None
    department: Optional[str] = None
    role: str
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


class AttendanceUpdate(BaseModel):
    """Attendance status update request"""
    status: str = Field(..., pattern="^(present|late|absent|half_day)$")
    notes: Optional[str] = None


class AttendanceResponse(BaseModel):
    """Attendance record response"""
    id: int
    user_id: int
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


class UserFilter(BaseModel):
    """User filter for admin queries"""
    role: Optional[str] = None
    department: Optional[str] = None
    is_active: Optional[bool] = None
    has_face: Optional[bool] = None


# ========================
# CLASS AND STUDENT SCHEMAS
# ========================

class ClassCreate(BaseModel):
    """Create a new class"""
    name: str = Field(..., min_length=1, max_length=255)


class ClassResponse(BaseModel):
    """Class response"""
    id: int
    name: str
    teacher_id: int
    created_at: datetime
    student_count: Optional[int] = 0

    class Config:
        from_attributes = True


class StudentResponse(BaseModel):
    """Student response"""
    id: int
    name: str
    class_id: int
    has_registered_face: bool
    created_at: datetime

    class Config:
        from_attributes = True


class ClassResponse(BaseModel):
    """Class response"""
    id: int
    name: str
    teacher_id: int
    created_at: datetime
    student_count: int = 0

    class Config:
        from_attributes = True


class ClassCreate(BaseModel):
    """Class creation request"""
    name: str


class StudentRegistrationResponse(BaseModel):
    """Student registration response"""
    success: bool
    message: str
    student_id: int
    images_processed: int


# ========================
# EXAM PROCTORING SCHEMAS
# ========================

class DetectedObject(BaseModel):
    """Detected object in exam proctoring"""
    type: str  # "phone", "book", "paper", "person", "earbuds", "face"
    label: str  # Human-readable label
    confidence: float
    bbox: List[float]  # [x1, y1, x2, y2] normalized 0-1 coordinates
    color: str = "red"  # Display color for ESP overlay


class ExamProctorResponse(BaseModel):
    """Exam proctoring scan response"""
    student_verified: bool
    student_id: Optional[int] = None
    student_name: Optional[str] = None
    face_count: int
    gaze_direction: str  # "center", "left", "right", "up", "down"
    detected_objects: List[DetectedObject]
    suspicion_score: float  # 0-100
    violations: List[str]
    is_cheating: bool
    timestamp: datetime
    message: str


