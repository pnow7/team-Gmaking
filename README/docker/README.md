# 🐋 Docker 배포 가이드 - Gmaking 프로젝트

본 문서는 **Spring Boot**, **React**, **FastAPI 모델 서버**, **MySQL**로 구성된 Gmaking 프로젝트 전체를 **Docker 기반**으로 실행하고 배포하기 위한 가이드입니다.

--- 
## Docker 인프라 구성 (by 박현재)
### 🧱 구성요소
- backend (Spring Boot)

- frontend (React)

- ai-server (FastAPI + YOLOv8)

- growth-ai-server (FastAPI)

- mysql 8.4

- docker network: `gmaking-network`

### 🔥 통신 구조
```
frontend → backend → ai-server
                     ↳ growth-ai-server
backend ↔ mysql
```

---

## 📁 1. 프로젝트 구조

프로젝트의 핵심 구성 요소 및 파일 구조는 다음과 같습니다.
```
team-Gmaking/
│
├─ backend/
│   └─ gmaking/
│       ├─ Dockerfile
│       ├─ .env
│       ├─ src/main/java/com/project/gmaking/...
│       └─ src/main/resources/gcp-service-key.json
│
├─ frontend/
│   ├─ Dockerfile
│   └─ .env
│
├─ ai_server/
│   ├─ Dockerfile
│   └─ model_server.py
│
├─ growth_ai_server/
│   ├─ Dockerfile
│   └─ growth_ai_server.py
│
├─ db_init/
│   └─ init.sql
│
└─ docker-compose.yml
```

---

## ⚙️ 2. `docker-compose.yml` (최종 버전)

최종 `docker-compose.yml` 파일에는 모든 서비스(백엔드, 프론트엔드, AI 서버, 데이터베이스)의 정의와 네트워크 설정, 그리고 환경 변수 설정이 포함됩니다.

> **💡 중요:** Docker Compose 내에서 컨테이너 간 통신 시에는 `localhost` 대신 **서비스 이름**을 사용해야 합니다. (예: 백엔드에서 AI 서버 호출 시, AI 서버의 서비스 이름 사용)

---

## 🔑 3. 각 서비스 `Dockerfile` 예시

각 구성 요소의 빌드 과정을 정의하는 `Dockerfile`의 위치입니다.

* **백엔드 (Spring Boot):** `backend/gmaking/Dockerfile`
* **프론트엔드 (React):** `frontend/Dockerfile`
* **AI 서버 1 (FastAPI):** `ai_server/Dockerfile`
* **AI 서버 2 (FastAPI):** `growth_ai_server/Dockerfile`

---

## 🐳 4. 실행 방법

프로젝트 전체를 빌드하고 실행하는 명령어입니다.

### 1) 도커 이미지 빌드 + 시작

프로젝트 루트 디렉토리 (`team-Gmaking/`)에서 다음 명령어를 실행합니다.

```sh
# 1. 실행 중인 컨테이너 및 네트워크 중지 및 삭제 (선택 사항이지만 권장)
docker-compose down

# 2. 모든 이미지 새로 빌드 (--no-cache 옵션으로 캐시 사용 방지)
docker-compose build --no-cache

# 3. 모든 서비스 백그라운드에서 실행 (-d 옵션: Detached mode)
docker-compose up -d
```
---

[⬅ 메인 README로 돌아가기](../../README.md)

---

[⬅ Docker Trouble Shooting README 보러가기](../troubleshooting/README.md)