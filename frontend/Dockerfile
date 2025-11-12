# frontend/Dockerfile
FROM node:20-alpine

# 작업 디렉토리
WORKDIR /app

# package.json과 package-lock.json 복사
COPY package*.json ./

# 의존성 설치
RUN npm install --legacy-peer-deps

# 앱 소스 전체 복사
COPY . .

# 개발 서버 실행 (Hot Reload 지원)
CMD ["npm", "start"]

# 포트 노출
EXPOSE 3000
