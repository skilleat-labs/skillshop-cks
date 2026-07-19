#!/usr/bin/env bash
# 4강 자동 채점 — 여섯 문제를 한 번에 점검
set -u
PASS=0; FAIL=0
ok(){ echo "  ✅ PASS $1"; PASS=$((PASS+1)); }
ng(){ echo "  ❌ FAIL $1"; FAIL=$((FAIL+1)); }
cani(){ kubectl auth can-i "$@" 2>/dev/null | tail -1; }

echo "[문제1] rbac-ex1/app-role 을 pods get·list 로 축소"
[ "$(cani list pods --as=system:serviceaccount:rbac-ex1:app-sa -n rbac-ex1)" = "yes" ] \
  && ok "list pods 허용" || ng "list pods 가 막힘(너무 좁게 줄임)"
[ "$(cani delete pods --as=system:serviceaccount:rbac-ex1:app-sa -n rbac-ex1)" = "no" ] \
  && ok "delete pods 차단" || ng "delete pods 가 아직 허용됨(와일드카드 남음)"

echo "[문제2] rbac-ex2/reader 에 pods get·list·watch Role+RoleBinding"
[ "$(cani watch pods --as=system:serviceaccount:rbac-ex2:reader -n rbac-ex2)" = "yes" ] \
  && ok "watch pods 허용" || ng "watch pods 불가(Role 또는 RoleBinding 누락)"
[ "$(cani create pods --as=system:serviceaccount:rbac-ex2:reader -n rbac-ex2)" = "no" ] \
  && ok "create pods 차단" || ng "create pods 가 허용됨(권한 과다)"

echo "[문제3] rbac-ex3 SA·Pod 양쪽 automount 비활성화"
kubectl get sa robot -n rbac-ex3 -o jsonpath='{.automountServiceAccountToken}' 2>/dev/null | grep -q false \
  && ok "SA automount=false" || ng "SA automount 미설정"
kubectl get deploy client -n rbac-ex3 -o jsonpath='{.spec.template.spec.automountServiceAccountToken}' 2>/dev/null | grep -q false \
  && ok "Pod automount=false" || ng "Pod automount 미설정"
if kubectl exec -n rbac-ex3 deploy/client -- ls /var/run/secrets/kubernetes.io/serviceaccount >/dev/null 2>&1; then
  ng "컨테이너에 토큰이 아직 마운트돼 있음"
else
  ok "컨테이너에 토큰 없음"
fi

echo "[문제4] rbac-ex4 위험한 RoleBinding(dangerous-admin) 제거"
[ "$(cani delete secrets --as=system:serviceaccount:rbac-ex4:legacy -n rbac-ex4)" = "no" ] \
  && ok "legacy 의 과도한 권한 제거됨" || ng "legacy 가 아직 secrets 삭제 가능"

echo "[문제5] rbac-ex5/inspector 가 노드 list (클러스터 범위)"
[ "$(cani list nodes --as=system:serviceaccount:rbac-ex5:inspector)" = "yes" ] \
  && ok "list nodes 허용" || ng "list nodes 불가 (ClusterRole+ClusterRoleBinding 필요)"

echo "[문제6] rbac-ex6/ci-bot 의 cluster-admin 제거"
[ "$(cani '*' '*' --as=system:serviceaccount:rbac-ex6:ci-bot)" = "no" ] \
  && ok "ci-bot cluster-admin 제거됨" || ng "ci-bot 이 아직 cluster-admin (ClusterRoleBinding 삭제 필요)"

echo ""
echo "채점 결과: PASS=$PASS  FAIL=$FAIL"
