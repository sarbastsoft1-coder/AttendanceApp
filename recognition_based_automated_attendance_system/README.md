# recognition_based_automated_attendance_system

Flutter frontend for the attendance system. This app can run as both a desktop
app and a web app, and both targets can use the same backend API.

## Local development

Desktop:

```bash
flutter run -d windows
```

Web against a deployed backend:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://your-backend-domain
```

## Production web build

```bash
flutter build web --release --pwa-strategy=none --dart-define=API_BASE_URL=http://your-backend-domain
```

## API base URL behavior

- Desktop defaults to `http://localhost:8000`
- Web can use a compile-time `API_BASE_URL`
- Users can still override the backend URL from the in-app settings screen

## Coolify

Deploy the web frontend as a separate application from this folder. See
[COOLIFY_FRONTEND_DEPLOY.md](/C:/AttendanceApp/COOLIFY_FRONTEND_DEPLOY.md).

## References

- https://docs.flutter.dev/deployment/web
- https://docs.flutter.dev/platform-integration/web
