# 2강 실습 — SecurityContext

## 방법 A — 시험 방식 (권장) · 매니페스트 파일을 수정해서 배포
실제 CKS 시험은 "**주어진 매니페스트를 수정해 배포하라**" 형태가 가장 흔합니다. 그 손놀림 그대로 연습하는 방식이에요.

```bash
./exam-start.sh                      # 클러스터 초기화 + work/ 에 문제별 작업파일 생성
vim work/q1-api.yaml                 # 파일을 직접 수정
kubectl apply -f work/q1-api.yaml    # 배포
bash verify.sh                       # 채점
```
- 작업파일: `work/q1-api.yaml` · `work/q2-worker.yaml` · `work/q3-writer.yaml`
- 원본 `problem-*.yaml` 은 건드리지 않으므로, `./exam-start.sh` 를 다시 돌리면 언제든 처음 상태로 초기화됩니다.
- ⚠️ 파일만 고치고 **apply 를 안 하면 0점**입니다. 채점은 클러스터의 실제 상태를 봅니다.

## 방법 B — 이미 떠 있는 리소스를 직접 수정
문제에 파일이 주어지지 않고 "네임스페이스 X 의 Deployment Y 를 수정하라"만 나오는 유형 대비용.

```bash
kubectl apply -f problem-1.yaml      # 문제 1 환경
kubectl apply -f problem-2.yaml      # 문제 2 환경
kubectl apply -f problem-3.yaml      # 문제 3 환경

kubectl edit deploy api -n sc-ex1    # 직접 수정 (vim 붙여넣기 전 :set paste)
```

> 정답은 `solutions/`. 필드명·위치가 헷갈리면:
> `kubectl explain deploy.spec.template.spec.containers.securityContext`
> 타입에 `[]` 가 보이면 **리스트**입니다 (`capabilities.drop: ["ALL"]`).

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
