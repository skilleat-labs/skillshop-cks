# 4강 실습 — RBAC + ServiceAccount

## 방법 A — 시험 방식 (권장)
```bash
./exam-start.sh                        # 초기화 + work/ 작업파일 생성
vim work/q1-app-role.yaml
kubectl apply -f work/q1-app-role.yaml
bash verify.sh                         # 자동 채점(6문제)
```
> `work/` 파일에는 **힌트가 없습니다.** 실제 시험도 필드 목록을 알려주지 않으니, 스스로 떠올리는 연습을 하세요.
> 막히면 `./exam-start.sh --hints` 로 힌트를 넣어 다시 생성하거나, `solutions/` 를 확인하면 됩니다.

문제 유형별로 제공 방식이 다릅니다 (실제 시험도 이렇게 섞여 나옵니다):

| 유형 | 문제 | work 파일 |
|------|------|-----------|
| **수정** | q1(Role 축소), q3(automount) | 기존 매니페스트 제공 |
| **생성** | q2(Role+RB), q5(ClusterRole+CRB) | 요구사항만 적힌 빈 파일 |
| **삭제** | q4, q6 | 없음 — `kubectl delete` 로 해결 |

> 생성 문제는 `kubectl create ... --dry-run=client -o yaml` 로 뼈대를 뽑는 게 가장 빠릅니다.
> ⚠️ `>>` 로 두 문서를 이어붙일 땐 사이에 `echo '---'` 를 넣어야 합니다. 안 그러면 문서가 합쳐져 `unknown field "rules"` 에러가 납니다.

## 방법 B — 직접 수정
```bash
for n in 1 2 3 4 5 6; do kubectl apply -f problem-$n.yaml; done
```

> 권한 검증은 SA 가장: `kubectl auth can-i <verb> <res> --as=system:serviceaccount:<ns>:<sa> -n <ns>`

## 문제 1 — 와일드카드 권한 최소화 · ns `rbac-ex1`, role `app-role`
`app-role` 이 모든 자원에 모든 동작(`*`). pods 를 get·list 만 가능하게 줄여라. (Role 의 rules 만 수정, 바인딩은 그대로)
```bash
kubectl auth can-i list pods   --as=system:serviceaccount:rbac-ex1:app-sa -n rbac-ex1   # yes
kubectl auth can-i delete pods --as=system:serviceaccount:rbac-ex1:app-sa -n rbac-ex1   # no
```

## 문제 2 — 최소 권한 Role 생성 · ns `rbac-ex2`, sa `reader`
`reader` 가 pods 를 get·list·watch 하도록 Role + RoleBinding 생성.
```bash
kubectl auth can-i watch pods  --as=system:serviceaccount:rbac-ex2:reader -n rbac-ex2   # yes
kubectl auth can-i create pods --as=system:serviceaccount:rbac-ex2:reader -n rbac-ex2   # no
```

## 문제 3 — SA 토큰 자동마운트 끄기 · ns `rbac-ex3`, sa `robot`, deploy `client`
SA 레벨과 Pod 레벨 둘 다 automount off (Pod 레벨 우선).
```bash
kubectl get sa robot -n rbac-ex3 -o jsonpath='{.automountServiceAccountToken}'; echo          # false
kubectl exec -n rbac-ex3 deploy/client -- ls /var/run/secrets/kubernetes.io/serviceaccount    # No such file
```

## 문제 4 — 과도한 RoleBinding 제거 · ns `rbac-ex4`, sa `legacy`
`dangerous-admin`(RoleBinding) 이 legacy 에게 네임스페이스 cluster-admin 을 준다. 삭제하라.
```bash
kubectl auth can-i delete secrets --as=system:serviceaccount:rbac-ex4:legacy -n rbac-ex4   # yes -> (삭제) -> no
```

## 문제 5 — 클러스터 범위 권한 · ns `rbac-ex5`, sa `inspector`
`inspector` 가 노드를 list 하게 하라. 노드는 클러스터 범위 → ClusterRole + ClusterRoleBinding.
```bash
kubectl auth can-i list nodes --as=system:serviceaccount:rbac-ex5:inspector   # yes  (-n 없음)
```

## 문제 6 — cluster-admin 부여 찾아 제거 · ns `rbac-ex6`, sa `ci-bot`
`ci-bot` 이 **ClusterRoleBinding** 으로 클러스터 전체 cluster-admin 을 갖는다.
시스템 기본 바인딩(system:masters, kubeadm)은 두고, **SA 에 붙은 위험한 것**만 찾아 삭제하라. (선택: view 로 재부여)
```bash
kubectl get clusterrolebindings -o wide | grep cluster-admin                 # SA-bound 한 줄을 찾기
kubectl auth can-i '*' '*' --as=system:serviceaccount:rbac-ex6:ci-bot        # yes -> (삭제) -> no
```
> 대비 포인트: 문제 4 는 네임스페이스 RoleBinding, 문제 6 은 클러스터 전역 ClusterRoleBinding. 헌팅할 땐 `rolebindings -A` 와 `clusterrolebindings` 둘 다 봐야 한다.

## 정리
```bash
for n in 1 2 3 4 5 6; do kubectl delete -f problem-$n.yaml; done
kubectl delete clusterrole node-reader 2>/dev/null
kubectl delete clusterrolebinding inspector-nodes ci-bot-admin 2>/dev/null
