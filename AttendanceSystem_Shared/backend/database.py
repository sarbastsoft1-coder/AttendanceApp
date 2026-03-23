"""
Database configuration with PostgreSQL and SQLAlchemy models
"""
import os
from datetime import datetime
from dotenv import load_dotenv
from sqlalchemy import create_engine, Column, Integer, String, Boolean, DateTime, Float, ForeignKey, Text, LargeBinary
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship

load_dotenv()

# Database URL from environment - Default to SQLite for easy setup
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./attendance.db")

# Create engine
if DATABASE_URL.startswith("sqlite"):
    engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
else:
    engine = create_engine(DATABASE_URL)
    
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
    
    # Role: admin, teacher, student, employee
    role = Column(String(50), default="student")
    
    # Face recognition data
    face_encoding = Column(Text, nullable=True)  # JSON encoded face encoding
    face_image_path = Column(String(500), nullable=True)
    has_registered_face = Column(Boolean, default=False)
    
    # Status
    is_active = Column(Boolean, default=True)
    is_verified = Column(Boolean, default=False)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    attendances = relationship("Attendance", back_populates="user")


class Attendance(Base):
    """Attendance record model"""
    __tablename__ = "attendance"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Date and time
    date = Column(DateTime, default=datetime.utcnow, index=True)
    check_in_time = Column(DateTime, nullable=True)
    check_out_time = Column(DateTime, nullable=True)
    
    # Recognition details
    confidence = Column(Float, nullable=True)  # 0-1 confidence score
    method = Column(String(20), default="face")  # face, manual, qr_code
    
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
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    teacher = relationship("User")
    students = relationship("Student", back_populates="class_ref")


class Student(Base):
    """Student model - managed by teachers, not separate accounts"""
    __tablename__ = "students"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    class_id = Column(Integer, ForeignKey("classes.id"), nullable=False)
    
    # Face recognition data
    face_encoding = Column(Text, nullable=True)  # JSON encoded face encoding
    face_image_path = Column(String(500), nullable=True)
    has_registered_face = Column(Boolean, default=False)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    class_ref = relationship("Class", back_populates="students")


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
    """Initialize database tables"""
    Base.metadata.create_all(bind=engine)
    print("Database tables created successfully.")


if __name__ == "__main__":
    init_db()
