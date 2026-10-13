FROM python:3.12-slim

# OpenCV needs these system libs even with the "headless" wheel, plus
# ffmpeg for RTSP stream decoding.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /service

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

EXPOSE 8000

# GOOGLE_APPLICATION_CREDENTIALS should be mounted as a volume, e.g.:
#   docker run -v /path/to/serviceAccount.json:/service/serviceAccount.json:ro \
#              -e GOOGLE_APPLICATION_CREDENTIALS=/service/serviceAccount.json ...
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
