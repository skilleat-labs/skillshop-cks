# 문제 1 정답 — trivy 스캔 + 저장

```bash
# 사람이 보는 표 형식
trivy image --severity HIGH,CRITICAL nginx:1.18

# 파일로 저장 (json) — 제출/후처리용
trivy image --severity HIGH,CRITICAL --format json --output /tmp/scan.json nginx:1.18

# 표 형식을 파일로
trivy image --severity HIGH,CRITICAL --format table --output /tmp/scan.txt nginx:1.18

# CRITICAL 만, CVE 개수
trivy image --severity CRITICAL --quiet nginx:1.18 | grep -c "CVE-"
```
요령: `--severity`, `--format(json/table/spdx-json)`, `--output` 세 가지가 핵심. 캐시 때문에 처음만 느림.
