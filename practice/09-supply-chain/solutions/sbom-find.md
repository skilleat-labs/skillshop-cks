# 문제 3 정답 — SBOM 에서 컴포넌트 찾기

SPDX tag-value 는 `PackageName:` / `PackageVersion:` 줄로 패키지를 나열한다.

```bash
# 특정 패키지 + 바로 아래 버전 보기
grep -i -A3 "PackageName: .*openssl" /tmp/sbom.spdx

# 패키지명·버전만 추려서 보기
grep -E "PackageName:|PackageVersion:" /tmp/sbom.spdx | less

# 전체 패키지 수
grep -c "PackageName:" /tmp/sbom.spdx
```
> JSON SBOM 이면 jq 사용: `jq '.packages[] | select(.name|test("openssl"))' sbom.json`
