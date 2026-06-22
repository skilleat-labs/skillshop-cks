# 5강 실습 — NetworkPolicy

> NetworkPolicy 를 강제하는 CNI(Calico/Cilium) 필요.

```bash
kubectl apply -f problem-1.yaml
kubectl apply -f problem-2.yaml
```

## 문제 1 — 특정 출발지만 허용 · ns `netpol-ex1`
`db` 는 `app=web` 에서 오는 것만 허용하고 나머지는 막아라.
```bash
kubectl exec -n netpol-ex1 deploy/web      -- wget -qO- --timeout=3 http://db | head -c 30   # 응답
kubectl exec -n netpol-ex1 deploy/attacker -- wget -qO- --timeout=3 http://db                # timeout
```

## 문제 2 — deny-all + DNS 허용 · ns `netpol-ex2`
네임스페이스 전체를 deny-all(Ingress+Egress)로 닫되 DNS(53)는 허용.
```bash
kubectl exec -n netpol-ex2 deploy/tester -- nslookup kubernetes.default                       # 해석됨
kubectl exec -n netpol-ex2 deploy/tester -- wget -qO- --timeout=3 http://kubernetes.default   # timeout
```

## 정리
```bash
kubectl delete -f problem-1.yaml -f problem-2.yaml
```
