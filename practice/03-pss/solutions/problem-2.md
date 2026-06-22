# 문제 2 정답
```bash
kubectl label ns pss-ex2 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/warn=restricted --overwrite
```
