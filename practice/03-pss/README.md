# 3강 실습 — Pod Security Standards (PSS)

## 방법 A — 시험 방식 (권장) · 매니페스트를 수정해서 apply
```bash
./exam-start.sh                        # 초기화 + work/ 작업파일 생성
vim work/q1-web.yaml                   # 파일 직접 수정
kubectl apply -f work/q1-web.yaml
bash verify.sh                         # 자동 채점
```
> `work/` 파일에는 **힌트가 없습니다.** 실제 시험도 필드 목록을 알려주지 않으니, 스스로 떠올리는 연습을 하세요.
> 막히면 `./exam-start.sh --hints` 로 힌트를 넣어 다시 생성하거나, `solutions/` 를 확인하면 됩니다.

- `work/q1-web.yaml` [수정] · `work/q2-namespace.yaml` [수정]
- 원본 `problem-*.yaml` 은 보존되며, `./exam-start.sh` 재실행으로 언제든 초기화됩니다.
- ⚠️ 파일만 고치고 **apply 안 하면 0점** — 채점은 클러스터 실제 상태를 봅니다.

## 방법 B — 이미 떠 있는 리소스를 직접 수정
```bash
kubectl apply -f problem-1.yaml
kubectl apply -f problem-2.yaml
kubectl edit deploy web -n pss-ex1     # vim 붙여넣기 전 :set paste
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
