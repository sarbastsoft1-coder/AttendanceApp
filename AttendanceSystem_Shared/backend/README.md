# Recognition Based Automated Attendance System - Backend

A Python FastAPI backend for facial recognition attendance tracking.

## 🚀 Features

- 🔐 **JWT Authentication** - Secure token-based authentication
- 👤 **User Management** - Full CRUD for users (students, teachers, admins)
- 📊 **Attendance Tracking** - Check-in/check-out with status tracking
- 👁️ **Face Recognition** - Register and recognize faces for attendance
- 📈 **Admin Dashboard** - Statistics and reports

## 📁 Project Structure

```
backend/
├── main.py              # FastAPI application with all routes
├── database.py          # SQLAlchemy models and database setup
├── models.py            # Pydantic schemas for validation
├── auth.py              # Authentication utilities
├── face_service.py      # Face recognition service
├── requirements.txt     # Python dependencies
├── .env.example         # Environment variables template
├── .gitignore
├── scripts/
│   └── create_admin.py  # Admin user creation script
└── face_images/         # Stored face images (auto-created)
```

## 🛠️ Setup Instructions

### 1. Prerequisites

- Python 3.8+
- PostgreSQL database
- Visual Studio Build Tools (Windows, for face_recognition)

### 2. Create Virtual Environment

```bash
cd backend
python -m venv venv

# Windows
venv\Scripts\activate

# Linux/Mac
source venv/bin/activate
```

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

> **Note**: The `face-recognition` library requires `dlib`. On Windows, you may need:
> - Visual Studio Build Tools with C++ support
> - CMake

### 4. Setup PostgreSQL Database

1. Install PostgreSQL if not installed
2. Create a new database:
   ```sql
   CREATE DATABASE attendance_db;
   ```

### 5. Configure Environment

```bash
# Copy example env file
copy .env.example .env

# Edit .env with your PostgreSQL credentials
# DATABASE_URL=postgresql://postgres:YOUR_PASSWORD@localhost:5432/attendance_db
```

### 6. Initialize Database

```bash
# Create tables
python database.py

# Create admin user
python scripts/create_admin.py
```

### 7. Run the Server

```bash
# Development mode with auto-reload
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Or simply
python main.py
```

## 📚 API Documentation

Once running, access the interactive documentation:

- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

## 🔗 API Endpoints

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register new user |
| POST | `/api/auth/login` | Login (form data) |
| POST | `/api/auth/login-json` | Login (JSON body - for Flutter) |
| GET | `/api/auth/verify` | Verify token |
| GET | `/api/auth/me` | Get current user |

### Users
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/users` | List users (admin) |
| GET | `/api/users/{id}` | Get user by ID |
| PUT | `/api/users/{id}` | Update user |
| DELETE | `/api/users/{id}` | Delete user (admin) |

### Face Registration
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/users/register-face` | Register face (3-5 images) |
| DELETE | `/api/users/remove-face` | Remove face data |

### Attendance
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/attendance/mark` | Mark attendance (face recognition) |
| POST | `/api/attendance/check-out` | Check out (face recognition) |
| GET | `/api/attendance/today` | Today's attendance |
| GET | `/api/attendance/history` | Attendance history |
| GET | `/api/attendance/stats/{id}` | User statistics |

### Admin
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/admin/dashboard` | Dashboard stats |
| GET | `/api/admin/reports` | Generate reports |

## 🧪 Testing with Postman

1. **Register User**
   ```
   POST http://localhost:8000/api/auth/register
   Body (JSON):
   {
     "email": "test@example.com",
     "full_name": "Test User",
     "password": "password123"
   }
   ```

2. **Login**
   ```
   POST http://localhost:8000/api/auth/login-json
   Body (JSON):
   {
     "email": "test@example.com",
     "password": "password123"
   }
   ```

3. **Register Face** (with token)
   ```
   POST http://localhost:8000/api/users/register-face
   Headers: Authorization: Bearer <token>
   Body (form-data):
   - images: [file1.jpg]
   - images: [file2.jpg]
   - images: [file3.jpg]
   ```

4. **Mark Attendance**
   ```
   POST http://localhost:8000/api/attendance/mark
   Body (form-data):
   - image: [face_photo.jpg]
   ```

## 🔗 Connect with Flutter App

Update Flutter API configuration:

```dart
// lib/config/api_config.dart
class ApiConfig {
  static const String baseUrl = 'http://YOUR_IP:8000';
}
```

## 🔒 Security Notes

1. Change `SECRET_KEY` in production
2. Never commit `.env` file
3. Use HTTPS in production
4. Set specific CORS origins in production

## 📝 Default Admin Credentials

```
Email: admin@example.com
Password: admin123
```

**⚠️ Change these after first login!**

## 📄 License

MIT License
