# Coolify Deployment

This repository is now prepared for a Coolify deployment from a public Git repository using Docker Compose.

## What gets deployed

- `backend`: the FastAPI API
- `db`: PostgreSQL

The Flutter app in `recognition_based_automated_attendance_system/` is still a client application. Deploy the backend on Coolify, then point the Flutter app to the deployed API URL.

## Files Coolify should use

- Base Directory: `/`
- Docker Compose file: `/docker-compose.yml`

## Environment variables

Use the values in `.env.backend.example` as your starting point inside Coolify.

You must set at least these before production use:

- `POSTGRES_DB`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `SECRET_KEY`
- `ALLOWED_ORIGINS`

Recommended production example:

```env
POSTGRES_DB=attendance_db
POSTGRES_USER=attendance_user
POSTGRES_PASSWORD=use-a-long-random-password
BACKEND_PORT=8000
PROJECT_NAME=Recognition Based Automated Attendance System
SECRET_KEY=use-a-long-random-secret-key
ACCESS_TOKEN_EXPIRE_MINUTES=10080
FACE_RECOGNITION_TOLERANCE=0.6
ALLOWED_ORIGINS=https://your-frontend-domain.com
```

## Coolify setup

1. Create a new application from your public repository.
2. Choose the `Docker Compose` build pack.
3. Keep the base directory as `/`.
4. Set the compose file path to `/docker-compose.yml`.
5. Add the environment variables from `.env.backend.example`.
6. Assign your public domain to the `backend` service and use internal port `8000`.
7. Deploy.

## After deploy

- Open `https://your-domain/health` to confirm the backend is healthy.
- In the Flutter app settings, change the API base URL from `http://localhost:8000` to your deployed backend URL.

## Notes

- PostgreSQL is not published to the server publicly in this setup.
- The backend is still reachable locally on `127.0.0.1:${BACKEND_PORT}` if you run the stack outside Coolify.
