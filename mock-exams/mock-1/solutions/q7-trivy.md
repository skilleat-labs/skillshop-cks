# q7 정답 — trivy 이미지 취약점 스캔 (로컬 CLI)

```bash
# HIGH·CRITICAL 만, JSON 으로 파일 저장
trivy image --severity HIGH,CRITICAL --format json --output /tmp/m1-scan.json nginx:1.18

# 화면 확인용(표 형식)
trivy image --severity HIGH,CRITICAL nginx:1.18

# CRITICAL 개수만 빠르게
trivy image --severity CRITICAL --quiet nginx:1.18 | grep -c CVE- || true
```

## 검증
```bash
test -s /tmp/m1-scan.json && echo "결과 저장 OK" || echo "FAIL"
grep -c '"VulnerabilityID"' /tmp/m1-scan.json     # 탐지된 취약점 수
```

> **함정(노션):** SBOM 생성(`bom generate`)과 헷갈리지 말 것. 이 문제 동사는 "스캔" → **trivy image**.
> 첫 실행은 취약점 DB(수백 MB) 내려받느라 시간이 걸린다(인터넷 필요).
