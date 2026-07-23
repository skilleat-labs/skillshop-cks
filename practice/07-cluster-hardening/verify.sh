#!/usr/bin/env bash
# 7강 채점 — 노드 작업이라 대부분 [MANUAL] 점검. 문제4 는 kubectl 로 실제 확인 가능.
set -u
PASS=0; FAIL=0
ok(){ echo "  ✅ PASS $1"; PASS=$((PASS+1)); }
ng(){ echo "  ❌ FAIL $1"; FAIL=$((FAIL+1)); }

NODE_IP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)

echo "[문제1] kubelet 익명 접근 차단 (worker-1)"
echo "  [MANUAL] curl -sk https://192.168.56.11:10250/pods  → Unauthorized"
echo "           curl -s  http://192.168.56.11:10255/pods   → 거부/무응답"

echo "[문제2·3] apiserver·etcd 하드닝 (컨트롤플레인)"
echo "  [MANUAL] grep -E 'anonymous-auth|authorization-mode' /etc/kubernetes/manifests/kube-apiserver.yaml"
echo "           grep -E 'client-cert-auth' /etc/kubernetes/manifests/etcd.yaml"

echo "[문제4] apiserver 익명 차단 + tester kubeconfig 접근"
# 4-a) 익명 인증이 막혔나 (401 이어야 성공, 403 이면 아직 익명 인증 허용중)
if [ -n "$NODE_IP" ]; then
  CODE=$(curl -sk "https://$NODE_IP:6443/api" -o /dev/null -w "%{http_code}" --max-time 6 2>/dev/null)
  if [ "$CODE" = "401" ]; then ok "익명 접근 차단됨 (401)"
  elif [ "$CODE" = "403" ]; then ng "아직 익명 인증 허용중 (403) — --anonymous-auth=false 필요"
  else echo "  ℹ️ 익명 응답코드=$CODE (401 이어야 성공)"; fi
else
  echo "  [SKIP] control-plane 노드IP 확인 불가"
fi
# 4-b) tester 가 파드 조회 가능 + 권한 밖은 거부
if [ -f /tmp/tester.kubeconfig ]; then
  R=$(kubectl --kubeconfig /tmp/tester.kubeconfig auth can-i list pods 2>/dev/null | tail -1)
  W=$(kubectl --kubeconfig /tmp/tester.kubeconfig auth can-i delete pods 2>/dev/null | tail -1)
  if [ "$R" = "yes" ] && [ "$W" = "no" ]; then ok "tester: 파드 조회 O(yes) · 삭제 X(no)"
  elif [ "$R" = "yes" ]; then ng "tester 가 삭제까지 가능(no 여야) — RBAC 를 조회만 주도록"
  else ng "tester 가 파드 조회 불가($R) — pod-reader ClusterRole + Binding(--user=tester) 확인"; fi
else
  echo "  [SKIP] /tmp/tester.kubeconfig 없음 → ./make-tester-kubeconfig.sh 먼저 실행"
fi

echo ""
echo "채점 결과: PASS=$PASS  FAIL=$FAIL   (문제1~3 은 노드 수동 점검)"
