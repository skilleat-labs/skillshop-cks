# q3 정답 — PSS 네임스페이스 강제

```bash
kubectl label ns m3-pss \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/warn=restricted --overwrite
```

## 검증
```bash
kubectl get ns m3-pss --show-labels
# enforce=restricted, warn=restricted 라벨 확인
```

> 선택: `pod-security.kubernetes.io/enforce-version=latest` 도 함께 지정 가능.
> `audit=restricted` 를 요구하는 변형도 있으니 문제 지시 확인.
