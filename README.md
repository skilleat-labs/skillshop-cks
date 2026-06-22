# SkillShop — CKS 실습용 데모 애플리케이션

온라인 강의 쇼핑몰 **스킬샵**을 실제로 구현한 마이크로서비스 앱입니다.
CKS 강의의 스토리("해킹당한 스킬샵을 한 겹씩 방어한다")를 **진짜로 돌아가는 클러스터**에서
재현하기 위해, **의도적으로 취약하게** 만들어 두었습니다.

> ⚠️ 교육용입니다. 카드번호 평문 저장 등 실제 서비스에서 절대 하면 안 되는 패턴이 일부러 들어 있습니다.

---

## 구성 (교안의 skillshop 네임스페이스와 동일)

| 서비스 | 역할 | 민감도 | 기술 |
|--------|------|--------|------|
| `frontend` | 화면·진입점 (강의 목록/수강신청 UI) | 일반 | Flask + Jinja |
| `product-svc` | 강의 목록 제공 | 일반 | Flask |
| `order-svc` | 수강 신청 처리 → 결제 호출 → 수강생 저장 | 일반 | Flask + SQLAlchemy |
| `payment-svc` | 카드 결제 처리·저장 | **민감** | Flask + SQLAlchemy |
| `user-db` | 수강생·결제(카드) 데이터 | **민감** | PostgreSQL |

**통신 흐름**
```
브라우저 → frontend ─▶ product-svc        (강의 목록)
                    └▶ order-svc ─▶ product-svc  (가격 조회)
                                 ─▶ payment-svc  (결제)
                                 ─▶ user-db      (수강생 저장)
                       payment-svc ─▶ user-db    (결제·카드 저장)
```

---

## 로컬 실행 (Rancher Desktop / Docker)

```bash
cd skillshop
docker compose up --build
# 브라우저에서 http://localhost:8080
```

종료: `docker compose down -v`

`docker-compose.yml`은 기본적으로 **취약 버전**(각 서비스의 `Dockerfile`)으로 빌드합니다.
PostgreSQL은 `postgres:16` 공식 이미지를 사용하며, 테이블은 서비스가 기동 시 자동 생성합니다.

### 동작 확인 (예시)

```bash
curl http://localhost:8080/health
curl http://localhost:8080/            # 강의 목록 페이지
# 수강 신청은 브라우저 UI에서. API 직접 호출도 가능:
curl -X POST http://localhost:8080/enroll \
  --data-urlencode 'name=홍길동' --data-urlencode 'email=hong@test.com' \
  --data-urlencode 'card_number=4111111111111111' --data-urlencode 'course_id=3'
```

---

## 의도된 취약점 → 어느 강의에서 막는가

| 취약점 (1강 "털린 상태") | 위치 | 방어 강의 |
|--------------------------|------|-----------|
| 컨테이너가 root로 실행, securityContext 없음 | 모든 Dockerfile / k8s | **2·3강** SecurityContext / PSS |
| 와일드카드 RBAC, SA 토큰 자동 마운트 | k8s | **4강** RBAC |
| 서비스 간 통신 무제한 (누구나 payment·user-db 접근) | k8s | **5강** NetworkPolicy |
| 평문 HTTP, 외부 TLS 없음 | k8s Ingress | **6강** TLS |
| 카드번호 평문 저장 + `GET /cards` 평문 노출 | `payment-svc/app.py` | 6강 + 5강(접근차단) |
| full 베이스 이미지·root 빌드·취약점 다수 | `Dockerfile` | **9강** Supply Chain |
| audit/런타임 탐지 없음 | k8s | **8·10강** Audit / Falco |

`payment-svc`의 `GET /cards`가 해커가 횡적 이동 후 빼가는 **카드정보 유출** 데모입니다.

---

## 이미지 빌드 & Docker Hub 푸시

```bash
docker login

# 취약 버전 (태그 1.0)
DOCKERHUB_NS=<네임스페이스> ./scripts/build-and-push.sh

# 하드닝 버전 (태그 2.0, 멀티스테이지·non-root)
DOCKERHUB_NS=<네임스페이스> TAG=2.0 DOCKERFILE=Dockerfile.hardened ./scripts/build-and-push.sh
```

생성 이미지: `<네임스페이스>/skillshop-frontend`, `-product-svc`, `-order-svc`, `-payment-svc`

---

## 두 가지 이미지 변형

| | `Dockerfile` (취약) | `Dockerfile.hardened` (하드닝) |
|--|--------------------|-------------------------------|
| 베이스 | `python:3.12` (full) | `python:3.12-slim` 멀티스테이지 |
| 사용자 | root | **UID 10001 non-root** |
| 서버 | Flask 개발 서버 | **gunicorn** |
| 용도 | 1강 사건 재현 | 9강 이후 공급망·컨테이너 보안 |

---

## 디렉터리 구조

```
skillshop/
├─ docker-compose.yml          # 로컬 전체 기동
├─ services/
│  ├─ frontend/                # 화면 (Flask + templates/)
│  ├─ product-svc/             # 강의 목록
│  ├─ order-svc/               # 수강 신청
│  └─ payment-svc/             # 결제 (민감)
│     └─ 각 서비스: app.py · requirements.txt · Dockerfile · Dockerfile.hardened
├─ k8s/
│  ├─ 00-vulnerable/           # (다음 단계) 취약 매니페스트
│  └─ 99-hardened/             # (다음 단계) 하드닝 매니페스트
└─ scripts/build-and-push.sh   # 이미지 빌드·푸시
```

## 환경 변수

| 서비스 | 변수 | 기본값(로컬) |
|--------|------|--------------|
| frontend | `PRODUCT_SVC_URL`, `ORDER_SVC_URL` | `http://product-svc:8080` 등 |
| order-svc | `PRODUCT_SVC_URL`, `PAYMENT_SVC_URL`, `DATABASE_URL` | — |
| payment-svc | `DATABASE_URL` | `sqlite:////tmp/skillshop.db` |
| 공통 | `PORT` | `8080` |

`DATABASE_URL`은 로컬 단독 실행 시 SQLite, compose/K8s에서는 PostgreSQL을 가리킵니다.
예: `postgresql+psycopg2://skillshop:skillshop123@user-db:5432/skillshop`
