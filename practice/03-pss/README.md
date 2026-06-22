# 3강 실습 — Pod Security Standards (PSS)

```bash
kubectl apply -f problem-1.yaml
kubectl apply -f problem-2.yaml
```

## 문제 1 — 거부된 Deployment 통과 · ns `pss-ex1`, deploy `web`
`pss-ex1` 은 `enforce=restricted` 라 `web` 파드가 거부된다. restricted 4종(runAsNonRoot, seccompProfile RuntimeDefault, allowPrivilegeEscalation false, capabilities drop ALL)을 갖춰 Running 시켜라. (위치: spec.template.spec)
```bash
kubectl get pods -n pss-ex1                     # Running
# 거부 사유: kubectl get events -n pss-ex1 | grep -i forbidden
```

## 문제 2 — 네임스페이스에 정책 강제 · ns `pss-ex2`
`pss-ex2` 에 restricted 를 enforce 하고 warn 도 켜라.
```bash
kubectl get ns pss-ex2 --show-labels
```

## 정리
```bash
kubectl delete -f problem-1.yaml -f problem-2.yaml
```
