"""
Script to populate database with sample data for demonstration
"""
import sys
import os
from datetime import datetime, timedelta
import random

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# FORCE absolute path for database
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.environ["DATABASE_URL"] = f"sqlite:///{os.path.join(backend_dir, 'attendance.db')}"

from database import SessionLocal, User, Attendance, Class, Student, init_db
from auth import get_password_hash

def populate_data():
    init_db()
    db = SessionLocal()
    
    try:
        print("Populating sample data...")
        
        # 1. Ensure Admin exists (User ID 1)
        admin = db.query(User).filter(User.email == "admin@example.com").first()
        if not admin:
            admin = User(
                email="admin@example.com",
                full_name="System Administrator",
                hashed_password=get_password_hash("admin123"),
                role="admin",
                is_active=True,
                is_verified=True
            )
            db.add(admin)
            db.commit()
            db.refresh(admin)
        
        # 2. Add some test students (Users)
        test_emails = ["test@example.com", "test2@example.com", "student1@example.com", "student2@example.com"]
        users = []
        for email in test_emails:
            user = db.query(User).filter(User.email == email).first()
            if not user:
                user = User(
                    email=email,
                    full_name=f"Student {email.split('@')[0].capitalize()}",
                    hashed_password=get_password_hash("password123"),
                    role="student",
                    has_registered_face=True,
                    is_active=True
                )
                db.add(user)
            users.append(user)
        db.commit()
        
        # 3. Add a Class
        sample_class = db.query(Class).filter(Class.name == "Computer Science 101").first()
        if not sample_class:
            sample_class = Class(
                name="Computer Science 101",
                teacher_id=admin.id
            )
            db.add(sample_class)
            db.commit()
            db.refresh(sample_class)
            
        # 4. Add Students to Class
        student_names = ["Alice Johnson", "Bob Smith", "Charlie Brown", "David Wilson"]
        students = []
        for name in student_names:
            student = db.query(Student).filter(Student.name == name).first()
            if not student:
                student = Student(
                    name=name,
                    class_id=sample_class.id,
                    has_registered_face=True
                )
                db.add(student)
            students.append(student)
        db.commit()
        
        # 5. Add Attendance Records for the last 30 days
        print("Generating attendance records...")
        today = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
        
        # All users + admin (as student for demo purposes)
        all_target_users = db.query(User).all()
        
        statuses = ["present", "late", "absent"]
        weights = [0.7, 0.2, 0.1] # Mostly present
        
        for i in range(30):
            date = today - timedelta(days=i)
            # Skip weekends (simplified)
            if date.weekday() >= 5:
                continue
                
            for user in all_target_users:
                # Check if record exists
                exists = db.query(Attendance).filter(
                    Attendance.user_id == user.id,
                    Attendance.date >= date,
                    Attendance.date < date + timedelta(days=1)
                ).first()
                
                if not exists:
                    status = random.choices(statuses, weights=weights)[0]
                    
                    check_in = None
                    if status != "absent":
                        # Random check-in between 8:30 and 9:30
                        base_hour = 8 if status == "present" else 9
                        minute = random.randint(0, 59)
                        check_in = date.replace(hour=base_hour, minute=minute)
                    
                    attendance = Attendance(
                        user_id=user.id,
                        date=date if i > 0 else datetime.utcnow(), # Use current time for today
                        check_in_time=check_in,
                        status=status,
                        method="face",
                        confidence=0.85 + (random.random() * 0.1)
                    )
                    db.add(attendance)
        
        db.commit()
        print("Success! Database populated with sample data.")
        
    except Exception as e:
        print(f"Error: {str(e)}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    populate_data()
