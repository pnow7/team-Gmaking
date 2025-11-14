# Troubleshooting: Spring WebClient + multipart + Docker hostname  

## Error: `Host is not specified`

## 1. 문제 요약 (Symptom)

### 🚨 WebClient multipart 전송 시 Host 헤더가 사라지는 버그
실제로 존재하는 버그이며:
- WebClient + multipart/form-data + Docker 내부 host 이름 사용 시
- Host 헤더가 삭제되거나 null로 들어가서
- Netty 내부에서 **Host is not specified** 발생함

특히 사용하는 코드 패턴이 아래와 같다면 거의 확정:
```java
webClient.post()
  .uri("http://ai-server:8000/classify/image")
  .contentType(MediaType.MULTIPART_FORM_DATA)
  .body(BodyInserters.fromMultipartData(data))
  .retrieve()
```
이 조합에서 발생하는 ***유명한 버그***


**Spring Boot**에서 **Docker 내부 FastAPI 서버**로 `multipart/form-data` 요청을 보낼 때 다음 **오류**가 발생:
>java.lang.IllegalArgumentException: host is not specified

**Spring 로그 예시:**
>❌ 모델 서버 통신 오류: Host is not specified (엔드포인트: /classify/image)


**클라이언트 응답:**
>이미지 분류 서버에 연결할 수 없습니다. 다시 시도해 주세요.

---

###  🚨 같은 타입(WebClient) 빈이 2개인데 Bean 이름 충돌/프록시 충돌로 인해
#### Spring이 WebClientConfig 자체를 스킵해버림

WebClientConfig.java 파일 외에 IamportWebClientConfig.java 존재.

즉 최종 구조:
- IamportWebClientConfig → WebClient 빈 1개
- WebClientConfig → WebClient 빈 1개(classificationWebClient)
- Spring WebFlux AutoConfig → WebClient 빈 1개 (기본 WebClient)

총 **3개가 등록되는 상황**이 됨.

실제로 이런 경우 Spring은:

✔️ 충돌나는 WebClientConfig을 스캔은 하지만

❌ 빈 등록은 무시할 수 있다 (auto config overriding off 상태일 때)

#### 실무에서도 100% 실제로 발생하는 문제!

> 

---

## 2. 문제 재현 조건 (Reproduce Conditions)

아래 조건이 모두 충족될 때 안정적으로 재현됨:

1. Spring WebClient 사용
2. BodyInserters.fromMultipartData 로 multipart/form-data 전송
3. `.uri("http://ai_server:8000/…")` 처럼 문자열 전체 URL 전달
4. WebClientConfig 에 baseUrl 없음
5. Docker hostname(ai_server) 사용

이 조합에서 Reactor Netty 내부에서 Host 헤더가 null 이 되어 오류가 발생함.

---

## 3. 원인 (Root Cause)

### Reactor Netty + WebClient multipart 처리 중 **Host 헤더가 유실되는 버그**

WebClient가 multipart/form-data 인코딩 준비 과정에서  
요청 생성 타이밍이 어긋나며 Host 헤더가 null이 되어 아래 예외가 발생함: IllegalArgumentException: host is not specified


이 문제는 Docker hostname을 사용할 때 더 쉽게 재현되며,  
Docker 네트워크·DNS·FastAPI 문제와는 무관함.

---

## 4. 문제 분석 증거 (Evidence)

아래 테스트 모두 정상 작동:

- `ping ai_server` → 정상
- `curl http://ai_server:8000/docs` → 정상
- FastAPI 모델 서버 정상
- Docker 네트워크 정상
- multipart 제외 시 요청 정상

즉, 네트워크 계층 문제 없음 → WebClient 요청 생성 과정만 오류.

---

## 5. 해결 방법 (Solution)

### ✔ 해결 방법 1 — WebClientConfig 에 baseUrl 추가 (가장 정석, 권장)

```java
@Configuration
public class WebClientConfig {

    @Value("${model.server.url}")
    private String modelServerUrl;

    @Bean
    public WebClient customWebClient() {

        HttpClient httpClient = HttpClient.create()
                .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 30000)
                .responseTimeout(Duration.ofSeconds(60))
                .doOnConnected(conn -> conn.addHandlerLast(new ReadTimeoutHandler(60)));

        return WebClient.builder()
                .baseUrl(modelServerUrl)  // Host 헤더 자동 생성
                .clientConnector(new ReactorClientHttpConnector(httpClient))
                .build();
    }
}

```

### ✔ 해결 방법 2 — Service 단에서 전체 URL 사용 금지
기존 (문제 발생)

```java
.uri(modelServerUrl + classifyPath)
```

수정 (정상 작동)
```java
.uri(classifyPath)
```

이제 baseUrl + path 형태로 Host 헤더가 자동 구성됨.

---

## 6. 참고용 대안 (비권장)
아래 방법도 동작은 하나 장기적으로 비추천:

1) Host 헤더 강제 추가
```java
.header(HttpHeaders.HOST, "ai_server:8000")
```

2) URI.create() 사용
```java
.uri(URI.create(modelServerUrl + classifyPath))
```

baseUrl 방식이 가장 안전하고 Spring 공식 문서에서도 권장됨.

---

## 7. 결론
Docker, FastAPI, 네트워크 문제가 아니다.

Reactor Netty 와 WebClient multipart/form-data 조합에서 Host 헤더가 유실되는 구조적 버그다.

해결 방법은 WebClientConfig 에 baseUrl 추가 + Service 단에서는 path만 전달하는 것이다.

이 두 수정만으로 오류는 완전히 해결된다.

## 8. 적용 후 기대 결과

패치 적용 후:

- FastAPI 모델 서버 통신 정상
- multipart 이미지 업로드 정상
- Host is not specified 오류 제거
- 이미지 분류 기능 정상 작동

정상 응답 예시:
```yaml
🧩 모델 서버 응답 VO: { predictedAnimal=..., confidence=0.95 }
```

---

# 추가

## 📌 1. 변경 이력(Changelog)

- ✔ FastAPI 파라미터 mismatch (`file → image`) 수정
- ✔ WebClientConfig 에 `baseUrl` 추가
- ✔ `.uri(path-only)` 방식으로 변경
- ✔ docker-compose.yml 에 `environment:` 추가
- ✔ Docker 서비스 이름 `ai_server` → `ai-server` 로 변경
- ✔ 언더바 `_` 대신 하이픈 `-` 사용 이유 정리

## ⚙️ 2. `docker-compose.yml` (최종 버전)

최종 `docker-compose.yml` 파일에는 모든 서비스(백엔드, 프론트엔드, AI 서버, 데이터베이스)의 정의와 네트워크 설정, 그리고 환경 변수 설정이 포함됩니다.

> **💡 중요:** Docker Compose 내에서 컨테이너 간 통신 시에는 `localhost` 대신 **서비스 이름**을 사용해야 합니다. (예: 백엔드에서 AI 서버 호출 시, AI 서버의 서비스 이름 사용)

```
version: "3.9"

services:
  ... (생략)

  backend:
    build: ./backend/gmaking
    container_name: gmaking-backend
    restart: always

    # 🔥 중요! Spring WebClient가 인식하도록 ENV 전달
    environment:
      MODEL_SERVER_URL: "http://ai-server:8000"
      MODEL_SERVER_CLASSIFY_PATH: "/classify/image"

    env_file:
      - ./backend/gmaking/.env

    volumes:
      - ./backend/gmaking/src/main/resources/gcp-service-key.json:/app/src/main/resources/gcp-service-key.json
    ports:
      - "8080:8080"
    depends_on:
      - db
      - ai-server
      - growth-ai-server
    networks:
      - gmaking-network

  ... (생략)

networks:
  gmaking-network:
    driver: bridge
```
> **왜 environment를 docker-compose.yml에 추가해야 했는가?***

### ❗문제원인
Spring Boot는 다음 방식의 .env를 자동으로 읽지 않음
```bash
env_file:
  - ./.env
```
`env`는
- docker-compose 컨테이너 환경변수로는 들어가지만
- **Spring Boot 환경 변수로는 전달되지 않음**

그래서 다음 값이 null로 들어왔음

- `${MODEL_SERVER_URL}`
- `${MODEL_SERVER_CLASSIFY_PATH}`

그 결과 WebClientConfig가 baseUrl을 제대로 설정하지 못함 → Host header null → `"Host is not specified"` 발생.

### ✔ 해결
**docker-compose.yml → backend → environment 에서 강제로 전달**

```yaml
environment:
  MODEL_SERVER_URL: "http://ai-server:8000"
  MODEL_SERVER_CLASSIFY_PATH: "/classify/image"
```

### 🧷 왜 Docker 서비스 이름은 `ai_server` 보다 `ai-server` 가 좋은가?
Docker Compose는 내부 DNS를 자동 생성함
서비스 이름이 곧 DNS hostname이 됨.

#### ✘ 언더바(_) 문제점
언더바는 URL/HOST 규격(RFC 952/1123)에서 비권장 문자
```nginx
ai_server   → DNS에서 종종 비표준으로 처리됨  
```
일부 라이브러리는 `_`를 만났을 때:
- Host 파싱 실패
- Host header 유실
- URL 인코딩 문제
- WebClient가 Host를 인식하지 못하는 버그 발생 가능

특히 WebClient + multipart 조합에서는 이 값이 쉽게 깨짐.

#### ✔ 하이픈(-) 권장
```
ai-server  → 100% RFC 규격 준수
```
표준 DNS 이름으로 안정적이며
WebClient, Netty, Reactor에서 모두 정상 처리됨.

#### 그래서 서비스 이름을 이렇게 수정함:
```
ai-server:
```
backend 컨테이너에서 curl도 문제 없이 됨:
```
curl http://ai-server:8000/classify/image
```


---

[⬅ 메인 README로 돌아가기](../../README.md)