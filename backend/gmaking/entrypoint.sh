#!/bin/bash
echo "Loading environment variables safely from .env..."

if [ -f ".env" ]; then
  # 주석, 빈줄, 한글 공백 제거
  while IFS= read -r line || [ -n "$line" ]; do
    # 공백 제거
    line=$(echo "$line" | tr -d '\r' | xargs)
    # 빈줄, 주석(#)으로 시작하는 줄은 무시
    if [ -z "$line" ] || [[ "$line" == \#* ]]; then
      continue
    fi
    export "$line"
  done < .env
fi

echo ".env variables loaded successfully"
exec java -jar app.jar
