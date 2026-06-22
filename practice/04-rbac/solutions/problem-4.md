# 문제 4 정답 — 과도한 권한 바인딩 제거

`dangerous-admin` 은 legacy SA 에게 네임스페이스 cluster-admin 을 준다. 삭제한다.

```bash
kubectl delete rolebinding dangerous-admin -n rbac-ex4
```

(필요하다면 최소 권한으로 다시 부여 — 예: pods get/list 만)
```bash
kubectl create role pod-reader --verb=get,list --resource=pods -n rbac-ex4
kubectl create rolebinding legacy-rb --role=pod-reader \
  --serviceaccount=rbac-ex4:legacy -n rbac-ex4
```
