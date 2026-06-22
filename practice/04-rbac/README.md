# 4강 실습 — RBAC + ServiceAccount

```bash
kubectl apply -f problem-1.yaml
kubectl apply -f problem-2.yaml
kubectl apply -f problem-3.yaml
kubectl apply -f problem-4.yaml
kubectl apply -f problem-5.yaml
```

> 권한 검증은 SA 가장(impersonation): `kubectl auth can-i <verb> <res> --as=system:serviceaccount:<ns>:<sa> -n <ns>`

## 문제 1 — 와일드카드 권한 최소화 · ns `rbac-ex1`, role `app-role`
`app-role` 이 모든 자원에 모든 동작(`*`)을 허용한다. pods 를 get·list 만 가능하게 줄여라.
```bash
kubectl auth can-i list pods   --as=system:serviceaccount:rbac-ex1:app-sa -n rbac-ex1   # yes
kubectl auth can-i delete pods --as=system:serviceaccount:rbac-ex1:app-sa -n rbac-ex1   # no
```

## 문제 2 — 최소 권한 Role 생성 · ns `rbac-ex2`, sa `reader`
`reader` 가 pods 를 get·list·watch 할 수 있도록 Role + RoleBinding 을 만들어라.
```bash
kubectl auth can-i watch pods  --as=system:serviceaccount:rbac-ex2:reader -n rbac-ex2   # yes
kubectl auth can-i create pods --as=system:serviceaccount:rbac-ex2:reader -n rbac-ex2   # no
```

## 문제 3 — SA 토큰 자동마운트 끄기 · ns `rbac-ex3`, sa `robot`, deploy `client`
`client` 파드가 `robot` SA 토큰을 자동 마운트하고 있다. **SA 레벨과 Pod 레벨 둘 다** 꺼라. (Pod 레벨이 최종 우선)
```bash
kubectl get sa robot -n rbac-ex3 -o jsonpath='{.automountServiceAccountToken}'; echo          # false
kubectl exec -n rbac-ex3 deploy/client -- ls /var/run/secrets/kubernetes.io/serviceaccount    # No such file -> 성공
```

## 문제 4 — 과도한 권한 바인딩 제거 · ns `rbac-ex4`, sa `legacy`
`legacy` SA 가 `dangerous-admin` RoleBinding 으로 네임스페이스 cluster-admin 권한을 갖는다. 이 과도한 바인딩을 제거하라.
```bash
# 제거 전
kubectl auth can-i delete secrets --as=system:serviceaccount:rbac-ex4:legacy -n rbac-ex4   # yes
# 제거 후
kubectl auth can-i delete secrets --as=system:serviceaccount:rbac-ex4:legacy -n rbac-ex4   # no
```

## 문제 5 — 클러스터 범위 권한 · ns `rbac-ex5`, sa `inspector`
`inspector` 가 **노드 목록**을 볼 수 있게 하라. 노드는 클러스터 범위 자원이라 Role 로는 안 되고 **ClusterRole + ClusterRoleBinding** 이 필요하다.
```bash
kubectl auth can-i list nodes --as=system:serviceaccount:rbac-ex5:inspector   # yes
```

## 정리
```bash
kubectl delete -f problem-1.yaml -f problem-2.yaml -f problem-3.yaml -f problem-4.yaml -f problem-5.yaml
kubectl delete clusterrole node-reader clusterrolebinding inspector-nodes 2>/dev/null
```
