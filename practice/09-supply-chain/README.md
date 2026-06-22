# 9강 실습 — Supply Chain Security

> Docker(또는 Rancher Desktop) + trivy 가 로컬에 있어야 합니다. 일부는 컨트롤플레인 노드 작업.

## 문제 1 — 이미지 취약점 스캔
아무 이미지나 골라 HIGH/CRITICAL 취약점을 스캔하라.
```bash
trivy image --severity HIGH,CRITICAL nginx:1.18
```
(개수가 많이 나오는 걸 확인 → 왜 최신·슬림 이미지를 써야 하는지 체감)

## 문제 2 — 안전한 Dockerfile 로 고치기
`files/Dockerfile` 은 full 베이스 + root 실행이다. 다음을 만족하게 다시 작성하라.
- slim(또는 distroless) 베이스 + 멀티스테이지
- 비-root 실행 (`USER`)
- `USER` 는 모든 `RUN` 이 끝난 **맨 마지막**에

정답: `solutions/Dockerfile`

## 문제 3 — ImagePolicyWebhook (컨트롤플레인, 노드 작업)
`/etc/kubernetes/admission/config.yaml` 에서 `defaultAllow: false` 로 두어, 웹훅 장애 시 이미지를 **거부**하도록 한다. (apiserver 에 `--admission-control-config-file` 연결 + 디렉토리 volume 마운트)
정답 스니펫: `solutions/admission.md`

> 구분: `trivy` = CVE 스캔, `bom` = SPDX 명세(SBOM) 생성. 시험에서 자주 헷갈림.
