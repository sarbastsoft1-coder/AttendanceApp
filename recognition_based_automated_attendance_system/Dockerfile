FROM ghcr.io/cirruslabs/flutter:stable AS build

ARG API_BASE_URL=

ENV CI=true \
    FLUTTER_SUPPRESS_ANALYTICS=true

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./

RUN flutter config --enable-web --no-analytics && \
    flutter pub get

COPY . .

RUN flutter build web --release --pwa-strategy=none --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginx:1.29-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
