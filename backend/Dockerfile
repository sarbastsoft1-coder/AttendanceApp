FROM python:3.10-slim-bookworm

WORKDIR /app

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# Runtime libs needed by OpenCV in the slim image.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    libgomp1 \
    liblapack3 \
    libopenblas0-pthread \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.deploy.txt .

RUN pip install --upgrade pip setuptools wheel && \
    pip install -r requirements.deploy.txt && \
    pip install dlib-bin==19.24.6 && \
    pip install --no-deps face-recognition==1.3.0 && \
    pip install --no-deps git+https://github.com/ageitgey/face_recognition_models

COPY . .

RUN mkdir -p /app/face_images

EXPOSE 8000

CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}"]
