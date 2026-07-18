# q4 정답 — 위험한 ClusterRoleBinding 제거

## 1) 헌팅 — SA 에 붙은 cluster-admin 바인딩 찾기
```bash
kubectl get clusterrolebindings -o wide | grep cluster-admin
# 출력에서 SUBJECT 가 ServiceAccount m1-rbac/ci-bot 인 줄을 찾는다 → m1-ci-bot-admin
```
> 시스템 기본(`cluster-admin` → Group system:masters, kubeadm 관련)은 **건드리지 말 것.**
> SA 로 바인딩된 것만 삭제한다.

## 2) 삭제
```bash
kubectl delete clusterrolebinding m1-ci-bot-admin
```

## 3) 검증
```bash
kubectl auth can-i '*' '*' --as=system:serviceaccount:m1-rbac:ci-bot   # no
```

> 대비 포인트: 네임스페이스 범위는 `rolebindings -A`, 클러스터 범위는 `clusterrolebindings`.
> 헌팅할 땐 둘 다 봐야 한다.
