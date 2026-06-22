# GitHub 푸시 & Docker Hub 배포 가이드

저장소: `https://github.com/skilleat-labs/skillshop-cks`
Docker Hub: `skilleat/skillshop-*`

배포는 **GitHub Actions가 자동으로** 합니다. main 브랜치에 push하면
4개 서비스를 빌드해 Docker Hub에 올려요. 아래 3단계만 하면 됩니다.

---

## 1단계 — Docker Hub 액세스 토큰 만들기

1. https://hub.docker.com → 우상단 계정 → **Account Settings → Security → New Access Token**
2. 이름 아무거나(예: `github-actions`), 권한 **Read & Write**, 생성
3. 토큰 문자열 복사 (이때 한 번만 보임)

## 2단계 — GitHub 저장소에 Secrets 등록

저장소 → **Settings → Secrets and variables → Actions → New repository secret** 에서 2개 등록:

| 이름 | 값 |
| --- | --- |
| `DOCKERHUB_USERNAME` | `skilleat` |
| `DOCKERHUB_TOKEN` | 1단계에서 복사한 토큰 |

## 3단계 — 코드 푸시

`skillshop/` 폴더에서(로컬 Mac, 터미널):

```bash
cd skillshop
git init
git add .
git commit -m "SkillShop CKS 실습용 데모 앱"
git branch -M main
git remote add origin https://github.com/skilleat-labs/skillshop-cks.git
git push -u origin main
```

push 직후 저장소 **Actions** 탭에서 빌드가 자동 시작되고,
끝나면 Docker Hub에 아래 이미지가 올라옵니다.

```
skilleat/skillshop-frontend     :1.0  :vulnerable   :2.0  :hardened
skilleat/skillshop-product-svc  :1.0  :vulnerable   :2.0  :hardened
skilleat/skillshop-order-svc    :1.0  :vulnerable   :2.0  :hardened
skilleat/skillshop-payment-svc  :1.0  :vulnerable   :2.0  :hardened
```

- `:1.0` / `:vulnerable` = 1강 "털린 상태"(root·full 이미지)
- `:2.0` / `:hardened`   = 9강 이후(non-root·멀티스테이지)
- user-db는 공식 `postgres:16`을 그대로 쓰므로 빌드 대상 아님

---

## (대안) 로컬에서 직접 빌드·푸시 — Rancher Desktop 사용 시

CI 없이 지금 당장 올리고 싶으면:

```bash
docker login                                   # skilleat 로 로그인
DOCKERHUB_NS=skilleat ./scripts/build-and-push.sh                              # 취약 1.0
DOCKERHUB_NS=skilleat TAG=2.0 DOCKERFILE=Dockerfile.hardened ./scripts/build-and-push.sh  # 하드닝 2.0
```

---

## 참고

- 자동 배포 설정 파일: `.github/workflows/docker-publish.yml`
- 비공개로 두고 싶으면 GitHub 저장소를 private으로, Docker Hub repo도 private으로 만들면 됩니다.
- 이미지를 K8s에서 당길 때는 `skilleat/skillshop-frontend:1.0` 처럼 참조합니다.
