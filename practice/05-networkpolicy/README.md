# 5강 실습 — NetworkPolicy

> NetworkPolicy 를 실제로 강제하는 CNI(Calico/Cilium 등)가 있어야 동작합니다. (kubeadm + Calico면 OK)

```bash
kubectl apply -f start.yaml
```

## 문제 1 — 특정 출발지만 허용 · ns `netpol-ex1`
지금은 `web` 도 `attacker` 도 `db` 에 접근된다.
**`db` 는 `web`(app=web) 에서 오는 것만 허용**하고 나머지는 막아라.

검증:
```bash
kubectl exec -n netpol-ex1 deploy/web      -- wget -qO- --timeout=3 http://db | head -c 30   # nginx 응답 (허용)
kubectl exec -n netpol-ex1 deploy/attacker -- wget -qO- --timeout=3 http://db                # timeout (차단)
```

## 문제 2 — deny-all + DNS 허용 · ns `netpol-ex2`
네임스페이스 전체를 **deny-all(ingress+egress)** 로 닫되, **DNS(53) 이름 해석은 되게** 하라.
(Egress 를 다 막으면 이름 해석이 안 돼 통신 전체가 죽는 함정을 직접 확인)

검증:
```bash
kubectl exec -n netpol-ex2 deploy/tester -- nslookup kubernetes.default     # 해석됨 (DNS 허용)
kubectl exec -n netpol-ex2 deploy/tester -- wget -qO- --timeout=3 http://kubernetes.default  # timeout (그 외 egress 차단)
```

## 정리
```bash
kubectl delete -f start.yaml
```
