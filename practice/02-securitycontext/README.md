# 2강 실습 — SecurityContext

시험처럼 "주어진 워크로드를 보안 요건에 맞게 고치는" 연습입니다. 문제 3개가 각각 다른 네임스페이스에 있어요.

## 준비

```bash
kubectl apply -f start.yaml
kubectl get pods -A | grep sc-ex      # 3개 네임스페이스의 파드 확인
```

> 정답은 `solutions/` 에 있어요. 먼저 직접 풀고, 막히면 펼쳐 보세요.
> Deployment라서 `kubectl edit` 으로 고치면 바로 롤아웃됩니다. (단독 Pod였다면 `kubectl replace --force -f` 로 재생성해야 함)
> 필드명이 헷갈리면: `kubectl explain deploy.spec.template.spec.containers.securityContext`

---

## 문제 1 — non-root 실행  ·  ns: `sc-ex1`, deploy: `api`

`api` 컨테이너가 root(UID 0)로 실행되고 있다. 다음을 만족하도록 수정하라.

- root가 아닌 **UID 10001** 로 실행
- root로 뜨려 하면 거부되도록 (runAsNonRoot)

검증:
```bash
kubectl exec -n sc-ex1 deploy/api -- id
# uid=10001 ... 이면 성공 (uid=0 이면 실패)
```

## 문제 2 — immutable 컨테이너  ·  ns: `sc-ex2`, deploy: `worker`

`worker` 컨테이너를 탈취당해도 할 수 있는 게 없도록 잠가라.

- 루트 파일시스템 읽기 전용
- 권한 상승 금지
- 모든 리눅스 capability 제거

검증:
```bash
kubectl exec -n sc-ex2 deploy/worker -- touch /x
# touch: /x: Read-only file system  → 성공
kubectl get deploy worker -n sc-ex2 \
  -o jsonpath='{.spec.template.spec.containers[0].securityContext}'; echo
# readOnlyRootFilesystem:true, allowPrivilegeEscalation:false, capabilities.drop:[ALL] 확인
```

## 문제 3 — 읽기 전용 함정  ·  ns: `sc-ex3`, deploy: `writer`

`writer` 파드가 `CrashLoopBackOff` 다. (앱이 `/data/app.log` 에 쓰는데 루트FS가 읽기 전용)
**`readOnlyRootFilesystem: true` 설정은 그대로 유지하면서** 파드가 정상 기동하게 하라.

힌트: `/data` 에 쓰기 가능한 볼륨을 붙이면 된다.

검증:
```bash
kubectl get pods -n sc-ex3            # Running 확인
kubectl exec -n sc-ex3 deploy/writer -- cat /data/app.log
# started  → 성공
```

---

## 정리

```bash
kubectl delete -f start.yaml
```
