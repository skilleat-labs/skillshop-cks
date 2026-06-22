# 4강 실습 — RBAC + ServiceAccount

```bash
kubectl apply -f problem-1.yaml
kubectl apply -f problem-2.yaml
```

## 문제 1 — 와일드카드 권한 최소화 · ns `rbac-ex1`, role `app-role`
`app-role` 이 모든 자원에 모든 동작(`*`)을 허용한다. pods 를 get·list 만 가능하게 줄여라.
```bash
kubectl auth can-i list pods   --as=system:serviceaccount:rbac-ex1:app-sa -n rbac-ex1   # yes
kubectl auth can-i delete pods --as=system:serviceaccount:rbac-ex1:app-sa -n rbac-ex1   # no
```

## 문제 2 — 최소 권한 + 토큰 자동마운트 끄기 · ns `rbac-ex2`, sa `reader`
`reader` 에 pods get·list·watch 권한(Role+RoleBinding) + 토큰 자동마운트 off.
```bash
kubectl auth can-i watch pods  --as=system:serviceaccount:rbac-ex2:reader -n rbac-ex2   # yes
kubectl get sa reader -n rbac-ex2 -o jsonpath='{.automountServiceAccountToken}'          # false
```

## 정리
```bash
kubectl delete -f problem-1.yaml -f problem-2.yaml
```
