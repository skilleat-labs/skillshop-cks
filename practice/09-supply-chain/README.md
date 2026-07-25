# 9강 실습 — Supply Chain Security

> 로컬에 **trivy** 와 **bom** 이 있어야 합니다(시험장엔 설치돼 있음). 문제 5는 컨트롤플레인 노드 작업.
> 시험 중 허용 문서: trivy(aquasecurity.github.io/trivy), bom(kubernetes-sigs/bom), kubernetes.io
> **도구 일괄 설치(권장): `./install-cks-tools.sh`** — trivy·bom·kubesec·cosign·kube-bench 를 한 번에 깝니다(macOS/Linux, amd64/arm64). 특정 도구만: `./install-cks-tools.sh trivy bom`.
> 설치(수동): trivy 는 배포본/`apt`, bom 은 `go install sigs.k8s.io/bom/cmd/bom@latest` 또는 릴리스 바이너리.
> **kube-bench(CIS 벤치마크)** 는 노드 검사 도구라 Mac 설치만으론 안 됩니다 → 클러스터 Job 으로: `bash run-kube-bench.sh` (결과 `out/master.txt`, `out/node.txt`).
> **원복(깨끗이 제거): `./uninstall-cks-tools.sh`** — 설치했던 도구 제거 + `kube-bench` 네임스페이스/결과 정리. brew 로 깐 건 brew 로, 바이너리는 그 파일만(안전 경로에서만). CLI 만 지우려면 `--keep-cluster`.
> ℹ️ trivy **첫 실행 시 취약점 DB(수백 MB)를 내려받느라 시간이 걸립니다. 인터넷 연결 필요.**
> 멈춘 게 아니라 DB 받는 중이니 기다리세요. (오프라인이면 `trivy image --download-db-only` 를 미리 실행)

## 문제 1 — trivy 로 취약점 스캔 + 결과 저장
이미지의 HIGH·CRITICAL 취약점을 스캔하고, 결과를 파일로 저장하라.
```bash
trivy image --severity HIGH,CRITICAL nginx:1.18
# 결과를 파일로 (json)
trivy image --severity HIGH,CRITICAL --format json --output /tmp/scan.json nginx:1.18
# CRITICAL 개수만 빠르게
trivy image --severity CRITICAL --quiet nginx:1.18 | grep -c CVE- || true
```
정답/요령: `solutions/trivy.md`

## 문제 2 — bom 으로 SBOM(SPDX) 생성
`bom` 으로 이미지의 **SPDX 명세서(SBOM)** 를 만들어 파일로 저장하라.
```bash
bom generate --image nginx:1.18 --output /tmp/sbom.spdx
head -n 15 /tmp/sbom.spdx        # SPDXVersion: SPDX-2.x ... 이면 성공
```
> 디렉터리 대상이면 `bom generate -d . --output /tmp/sbom.spdx`. 정답: `solutions/bom.md`

## 문제 3 — SBOM 에서 컴포넌트 찾기
문제 2에서 만든 SBOM(`/tmp/sbom.spdx`)에서 특정 패키지(예: `openssl`)가 들어있는지와 **버전**을 찾아라. 전체 패키지 수도 세어보라.
```bash
grep -i -A2 "PackageName: .*openssl" /tmp/sbom.spdx     # 패키지명 + 버전
grep -c "PackageName:" /tmp/sbom.spdx                   # 총 패키지 수
```
정답/요령: `solutions/sbom-find.md`

## 문제 4 — 안전한 Dockerfile 로 고치기
`files/Dockerfile` 은 full 베이스 + root 실행이다. slim/distroless + 멀티스테이지 + 비-root `USER`(모든 `RUN` 뒤 맨 마지막)로 다시 작성하라. 정답: `solutions/Dockerfile`

## 문제 5 — ImagePolicyWebhook (노드)
> ⚠️ **수정 전 백업 필수:** `sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/kube-apiserver.yaml.bak`
> apiserver 매니페스트를 잘못 고치면 apiserver 가 죽고 `kubectl` 이 먹통이 됩니다. 되돌릴 때 백업이 필요해요.

`/etc/kubernetes/admission/config.yaml` 에서 `defaultAllow: false`(웹훅 장애 시 거부) + apiserver 에 `--admission-control-config-file` 연결 + 디렉터리 volume 마운트. 정답: `solutions/admission.md`

---
> 도구 구분(시험 단골): **trivy = CVE 스캔**, **bom = SPDX SBOM 생성**. trivy 도 SBOM 을 만들거나(`--format spdx-json`) SBOM 을 스캔(`trivy sbom <file>`)할 수 있지만, "명세서 생성"의 표준 도구로는 bom 을 묻는다.
