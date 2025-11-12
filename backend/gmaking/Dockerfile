# syntax=docker/dockerfile:1

FROM gradle:8.10.0-jdk17 AS builder
WORKDIR /app

COPY build.gradle settings.gradle gradlew /app/
COPY gradle /app/gradle

RUN gradle dependencies --no-daemon || return 0

COPY . .

# 환경변수 파일 복사 
RUN gradle clean build -x test --no-daemon

# 실제 실행 환경
FROM eclipse-temurin:17-jdk-jammy
WORKDIR /app

# jar 파일 복사
COPY --from=builder /app/build/libs/*.jar app.jar

COPY src/main/resources/application.properties ./src/main/resources/application.properties
COPY .env ./.env

# entrypoint 스크립트 복사 및 실행 권한 부여
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

# 포트 노출
EXPOSE 8080

# 실행
ENTRYPOINT ["./entrypoint.sh"]
