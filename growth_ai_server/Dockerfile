# growth_ai_server/Dockerfile
FROM python:3.11-slim

# ============================================================== 
# libgl1-mesa-glx 대신 libgl1 설치 (이전 오류 해결)
# libgthread-2.0.so.0 오류 해결을 위해 libglib2.0-0 추가 (현재 오류 해결)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libgl1 \
    libgomp1 \
    libfontconfig1 \
    libglib2.0-0 && \
    rm -rf /var/lib/apt/lists/*
# ==============================================================

# 작업 디렉토리
WORKDIR /app

# 의존성 파일 복사
COPY requirements.txt .

# 의존성 설치
RUN pip install --no-cache-dir -r requirements.txt

# 소스 전체 복사
COPY . .

# FastAPI 실행
# CMD ["uvicorn", "controller.main:app", "--host", "0.0.0.0", "--port", "8001"]

# ==============================================================
# Gunicorn으로 4개의 Uvicorn 워커를 띄워 안정성을 확보
CMD ["gunicorn", "controller.main:app", "--workers", "4", "--worker-class", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:8001"]
# ==============================================================

# 포트 노출
EXPOSE 8001
