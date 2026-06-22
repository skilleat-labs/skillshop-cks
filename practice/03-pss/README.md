# 3강 실습 — Pod Security Standards (PSS)

```bash
kubectl apply -f start.yaml
```

## 문제 1 — 거부된 Deployment 통과시키기 · ns `pss-ex1`, deploy `web`
`pss-ex1` 은 `enforce=restricted` 가 걸려 있어 `web` 파드가 생성되지 않는다.
`web` 을 restricted 기준에 맞게 고쳐 Running 시켜라. (필수 4종: runAsNonRoot, seccompProfile RuntimeDefault, allowPrivilegeEscalation false, capabilities drop ALL — 위치 주의: securityContext 는 `spec.template.spec` 아래)

검증:
```bash
kubectl get pods -n pss-ex1            # Running
# 거부 사유 확인: kubectl get events -n pss-ex1 | grep -i forbidden
```

## 문제 2 — 네임스페이스에 정책 강제 · ns `pss-ex2`
`pss-ex2` 에 restricted 를 **강제(enforce)** 하고, 경고(warn)도 함께 켜라. (`app` 은 이미 compliant 라 안 깨진다)

검증:
```bash
kubectl get ns pss-ex2 --show-labels
# pod-security.kubernetes.io/enforce=restricted, .../warn=restricted 확인
```

## 정리
```bash
kubectl delete -f start.yaml
```
