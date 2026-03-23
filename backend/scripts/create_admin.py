"""
Script to create admin user
Run: python scripts/create_admin.py
"""
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import SessionLocal, User, init_db
from auth import get_password_hash


def create_admin_user():
    """Create admin user if not exists"""
    # Initialize database
    init_db()
    
    db = SessionLocal()
    
    try:
        # Check if admin exists
        admin_email = "admin@example.com"
        existing_admin = db.query(User).filter(User.email == admin_email).first()
        
        if existing_admin:
            print(f"Admin user already exists: {admin_email}")
            return
        
        # Create admin user
        admin = User(
            email=admin_email,
            full_name="System Administrator",
            hashed_password=get_password_hash("admin123"),
            role="admin",
            department="Administration",
            is_active=True,
            is_verified=True
        )
        
        db.add(admin)
        db.commit()
        db.refresh(admin)
        
        print("=" * 50)
        print("Admin user created successfully!")
        print("=" * 50)
        print(f"   Email:    {admin_email}")
        print(f"   Password: admin123")
        print(f"   Role:     admin")
        print("=" * 50)
        print("Please change the password after first login!")
        print("=" * 50)
        
    except Exception as e:
        print(f"Error creating admin: {str(e)}")
        db.rollback()
    finally:
        db.close()


if __name__ == "__main__":
    create_admin_user()
