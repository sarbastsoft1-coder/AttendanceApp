# Coolify Frontend Deployment

Deploy the Flutter web frontend as a second Coolify application from the same repository.

## Purpose

- `backend` + `db` stay in the existing Docker Compose deployment
- the website frontend is deployed separately from `recognition_based_automated_attendance_system/`
- the desktop app can continue to run at the same time against the same backend

## Coolify settings

Create a new application with these values:

- Repository: `https://github.com/sarbastsoft1-coder/AttendanceApp`
- Build Pack: `Dockerfile`
- Base Directory: `/recognition_based_automated_attendance_system`
- Dockerfile Location: `/Dockerfile`

## Environment variables

Set this in the frontend Coolify app:

```env
API_BASE_URL=http://your-backend-domain
```

Use the backend domain that is already working in Coolify.

## Backend CORS

After you know the frontend domain, update the backend app's `ALLOWED_ORIGINS` to include it instead of `*`.

Example:

```env
ALLOWED_ORIGINS=http://your-frontend-domain,http://your-backend-domain
```

## Desktop app

The desktop app can use the same backend by:

- changing the API base URL from the in-app settings screen
- or building/running it with `--dart-define=API_BASE_URL=http://your-backend-domain`

Example:

```bash
flutter run -d windows --dart-define=API_BASE_URL=http://your-backend-domain
```

## Verification

Frontend:

- open the frontend domain
- open `/health` on the frontend domain to confirm Nginx is serving

Backend:

- open `/health` on the backend domain
- log in from both the website and desktop app against the same backend

## Notes

- The web build is compiled at deploy time inside the frontend Docker image.
- The frontend defaults to `API_BASE_URL` when provided.
- If `API_BASE_URL` is not set for a web build, the app falls back to the current browser origin.
