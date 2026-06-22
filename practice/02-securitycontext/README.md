# 2강 실습 — SecurityContext

문제마다 별도 파일입니다. 푸는 문제만 적용하세요.

```bash
kubectl apply -f problem-1.yaml      # 문제 1 환경
kubectl apply -f problem-2.yaml      # 문제 2 환경
kubectl apply -f problem-3.yaml      # 문제 3 환경
```

> 정답은 `solutions/`. Deployment라 `kubectl edit`로 고치면 바로 롤아웃됩니다.
> 필드명: `kubectl explain deploy.spec.template.spec.containers.securityContext`

## 문제 1 — non-root 실행 · ns `sc-ex1`, deploy `api`
`api` 가 root(UID 0)로 실행 중. UID 10001 non-root로 실행되게 하라. (runAsNonRoot, runAsUser)
```bash
kubectl exec -n sc-ex1 deploy/api -- id      # uid=10001 이면 성공
```

## 문제 2 — immutable 컨테이너 · ns `sc-ex2`, deploy `worker`
루트FS 읽기전용 + 권한상승 금지 + 모든 capability 제거.
```bash
kubectl exec -n sc-ex2 deploy/worker -- touch /x   # Read-only file system 이면 성공
```

## 문제 3 — 읽기전용 함정 · ns `sc-ex3`, deploy `writer`
`readOnlyRootFilesystem: true` 유지하면서 CrashLoopBackOff 를 해결하라(/data 쓰기 가능 볼륨).
```bash
kubectl get pods -n sc-ex3                          # Running
kubectl exec -n sc-ex3 deploy/writer -- cat /data/app.log   # started
```

## 정리
```bash
kubectl delete -f problem-1.yaml -f problem-2.yaml -f problem-3.yaml
```
