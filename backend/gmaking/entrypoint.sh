#!/bin/bash
# 환경 변수 파일이 있으면 로드
if [ -f ".env" ]; then
  export $(grep -v '^#' .env | xargs)
fi

# 실행
exec java -jar app.jar
