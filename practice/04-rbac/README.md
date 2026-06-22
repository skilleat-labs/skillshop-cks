# 4강 실습 — RBAC + ServiceAccount

```bash
kubectl apply -f start.yaml
```

## 문제 1 — 와일드카드 권한 최소화 · ns `rbac-ex1`, role `app-role`
`app-sa` 에 묶인 `app-role` 이 모든 자원에 모든 동작(`*`)을 허용한다.
**pods 를 get·list 만** 할 수 있도록 최소화하라.

검증:
```bash
kubectl auth can-i list pods   --as=system:serviceaccount:rbac-ex1:app-sa -n rbac-ex1   # yes
kubectl auth can-i delete pods --as=system:serviceaccount:rbac-ex1:app-sa -n rbac-ex1   # no
```

## 문제 2 — 최소 권한 부여 + 토큰 자동마운트 끄기 · ns `rbac-ex2`, sa `reader`
다음을 만족시켜라.
- `reader` SA 가 pods 를 get·list·watch 할 수 있도록 Role+RoleBinding 생성
- `reader` SA 의 토큰 자동 마운트를 끈다 (`automountServiceAccountToken: false`)

검증:
```bash
kubectl auth can-i watch pods  --as=system:serviceaccount:rbac-ex2:reader -n rbac-ex2  # yes
kubectl auth can-i create pods --as=system:serviceaccount:rbac-ex2:reader -n rbac-ex2  # no
kubectl get sa reader -n rbac-ex2 -o jsonpath='{.automountServiceAccountToken}'; echo   # false
```

## 정리
```bash
kubectl delete -f start.yaml
```
