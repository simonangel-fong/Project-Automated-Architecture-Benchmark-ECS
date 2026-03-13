FROM python:3.12

# Environment
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    TZ=America/Toronto \
    DEBIAN_FRONTEND=noninteractive

# default 2 workers
ENV WORKER=2

# Set timezone data
RUN apt-get update && \
    apt-get install -y --no-install-recommends tzdata curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install dependencies (leverages Docker layer caching)
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app ./app

# Create a non-root user
RUN adduser --disabled-password --gecos "" appuser && \
    chown -R appuser /app
USER appuser

EXPOSE 8000

# Run FastAPI with uvicorn, uvloop + httptools
CMD ["sh", "-c", "uvicorn app.main:app \
  --host 0.0.0.0 \
  --port 8000 \
  --workers ${WORKER:-1} \
  --loop uvloop \
  --http httptools"]