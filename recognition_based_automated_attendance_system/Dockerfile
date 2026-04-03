FROM debian:bookworm-slim AS build

ARG API_BASE_URL=

ENV DEBIAN_FRONTEND=noninteractive \
    PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    libglu1-mesa \
    unzip \
    xz-utils \
    zip \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch stable https://github.com/flutter/flutter.git /opt/flutter

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./

RUN flutter config --enable-web && \
    flutter precache --web && \
    flutter pub get

COPY . .

RUN flutter build web --release --pwa-strategy=none --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginx:1.29-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
