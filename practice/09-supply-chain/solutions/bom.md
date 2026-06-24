# 문제 2 정답 — bom 으로 SBOM(SPDX) 생성

```bash
# 이미지 대상
bom generate --image nginx:1.18 --output /tmp/sbom.spdx

# 디렉터리(소스) 대상
bom generate -d . --output /tmp/sbom-dir.spdx

# 확인 (SPDX 헤더)
head -n 15 /tmp/sbom.spdx
grep -m1 "SPDXVersion:" /tmp/sbom.spdx        # SPDX-2.3 등
```
> bom 은 SPDX 표준 SBOM 생성 도구(kubernetes-sigs/bom). 결과는 기본 tag-value(.spdx) 형식.
