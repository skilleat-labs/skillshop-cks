# 문제 6 정답 — 과도한 ClusterRoleBinding 찾아 제거

## 1) 찾기 (시스템 기본은 무시)
```bash
kubectl get clusterrolebindings -o wide | grep cluster-admin
```
- `cluster-admin` (→ system:masters), `kubeadm:cluster-admins` (→ kubeadm 그룹) = 기본, 건드리지 말 것
- `ci-bot-admin` (→ ServiceAccount rbac-ex6/ci-bot) = 범인 (subject 가 SA)

정확히 보려면:
```bash
kubectl get clusterrolebindings -o custom-columns=\
'NAME:.metadata.name,ROLE:.roleRef.name,SUBJECT:.subjects[*].name,KIND:.subjects[*].kind'
```

## 2) 확정
```bash
kubectl auth can-i '*' '*' --as=system:serviceaccount:rbac-ex6:ci-bot   # yes -> admin
```

## 3) 제거
```bash
kubectl delete clusterrolebinding ci-bot-admin
```

## 4) (선택) 최소 권한으로 재부여 — 네임스페이스 안에서 읽기 전용(view)
```bash
kubectl create rolebinding ci-bot-view --clusterrole=view \
  --serviceaccount=rbac-ex6:ci-bot -n rbac-ex6
```
