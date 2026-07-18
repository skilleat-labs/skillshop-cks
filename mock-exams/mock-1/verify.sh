#!/usr/bin/env bash
# CKS 모의고사 1회차 자동 채점
# q1~q4: 라이브 채점 / q5·q6: [MANUAL] 점검 명령 안내 / q7: 결과파일 확인
set -u
PASS=0; FAIL=0
ok(){ echo "  ✅ PASS $1"; PASS=$((PASS+1)); }
ng(){ echo "  ❌ FAIL $1"; FAIL=$((FAIL+1)); }

echo "== q1 · Restricted PSS (m1-pss/web Running) =="
if kubectl get pods -n m1-pss -l app=web 2>/dev/null | grep -q "Running"; then ok "web Running"; else ng "web 파드가 Running 아님 (restricted 4대 필드 확인)"; fi

echo "== q2 · NetworkPolicy (trusted 허용 / intruder 차단) =="
ALLOW=$(kubectl exec -n m1-netpol-client deploy/client -- wget -qO- --timeout=3 http://db.m1-netpol 2>/dev/null | head -c 15)
if echo "$ALLOW" | grep -qi "html\|nginx\|<!"; then ok "trusted ns → db 허용됨"; else ng "trusted ns → db 접근이 안 됨"; fi
if kubectl exec -n m1-netpol deploy/intruder -- wget -qO- --timeout=3 http://db 2>/dev/null | grep -qi "html"; then ng "intruder 가 db 에 접근됨(차단 실패)"; else ok "intruder → db 차단됨"; fi

echo "== q3 · TLS Ingress (secret + tls + ssl-redirect) =="
kubectl get secret shop-tls -n m1-tls -o jsonpath='{.type}' 2>/dev/null | grep -q "kubernetes.io/tls" && ok "shop-tls Secret(TLS) 존재" || ng "shop-tls TLS Secret 없음"
kubectl get ingress shop -n m1-tls -o jsonpath='{.spec.tls[0].secretName}' 2>/dev/null | grep -q "shop-tls" && ok "Ingress tls 블록에 shop-tls" || ng "Ingress tls 블록 없음/secretName 불일치"
kubectl get ingress shop -n m1-tls -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/ssl-redirect}' 2>/dev/null | grep -q "true" && ok "ssl-redirect 어노테이션" || ng "ssl-redirect 어노테이션 없음"

echo "== q4 · RBAC (ci-bot cluster-admin 제거) =="
if kubectl auth can-i '*' '*' --as=system:serviceaccount:m1-rbac:ci-bot 2>/dev/null | grep -q "yes"; then ng "ci-bot 이 아직 cluster-admin (바인딩 삭제 필요)"; else ok "ci-bot cluster-admin 제거됨"; fi

echo "== q5 · Falco 셸 탐지 룰 (노드) =="
echo "  [MANUAL] 노드에서: systemctl list-units 'falco*'  →  /etc/falco/falco_rules.local.yaml 룰 추가 후"
echo "           sudo journalctl -fu <falco-unit> | grep -i 'Shell spawned in container'  (트리거 시 경고)"

echo "== q6 · kube-apiserver 익명차단 (노드) =="
echo "  [MANUAL] 컨트롤플레인에서: grep -E 'anonymous-auth|authorization-mode|NodeRestriction' /etc/kubernetes/manifests/kube-apiserver.yaml"
echo "           curl -sk https://localhost:6443/api  →  Unauthorized(401) 이어야 함"

echo "== q7 · trivy 스캔 결과 (로컬) =="
if [ -s /tmp/m1-scan.json ]; then ok "/tmp/m1-scan.json 존재"; else echo "  [MANUAL] 아직 스캔 안 함: trivy image --severity HIGH,CRITICAL --format json -o /tmp/m1-scan.json nginx:1.18"; fi

echo ""
echo "라이브 채점 결과: PASS=$PASS  FAIL=$FAIL  (q5·q6 는 노드 수동 점검)"
