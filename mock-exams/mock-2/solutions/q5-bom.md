# q5 정답 — bom 으로 SPDX SBOM 생성 + 컴포넌트 찾기

## 1) SBOM 생성 (파일로 저장)
```bash
bom generate --image nginx:1.18 --output /tmp/m2-sbom.spdx
head -n 15 /tmp/m2-sbom.spdx        # SPDXVersion: SPDX-2.x ... 이면 성공
```
여러 이미지를 담아야 하면 **`--image` 를 반복**:
```bash
bom generate --image nginx:1.18 --image busybox:1.36 --output /tmp/m2-sbom.spdx
```
> **함정(노션):** `bom generate --image a >> file; bom generate --image b >> file` 처럼
> `>>` 로 누적하면 SPDX 구조가 깨진다. 반드시 `--image` 반복.

## 2) 컴포넌트/버전 찾기
```bash
grep -i -A2 "PackageName: .*openssl" /tmp/m2-sbom.spdx     # 패키지명 + 버전(PackageVersion)
grep -c "PackageName:" /tmp/m2-sbom.spdx                   # 총 패키지 수
# 정확한 이름 모르면 부분 검색
grep -i crypto /tmp/m2-sbom.spdx                           # libcrypto3 등
```

## 검증
```bash
test -s /tmp/m2-sbom.spdx && head -1 /tmp/m2-sbom.spdx | grep -q "SPDX" && echo "SBOM OK" || echo "FAIL"
```

> **함정:** SBOM 생성(bom) vs CVE 스캔(trivy) 을 문제 동사로 구분.
> "구성요소/명세서/SBOM" → bom, "취약점/CVE/스캔" → trivy.
