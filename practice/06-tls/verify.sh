#!/usr/bin/env bash
# 6강 자동 채점 — Secret 타입 · Ingress 설정 · 실제 TLS 핸드셰이크까지 확인
set -u
PASS=0; FAIL=0
ok(){ echo "  ✅ PASS $1"; PASS=$((PASS+1)); }
ng(){ echo "  ❌ FAIL $1"; FAIL=$((FAIL+1)); }

echo "[문제1] tls-ex/shop-tls TLS Secret 생성"
kubectl get secret shop-tls -n tls-ex -o jsonpath='{.type}' 2>/dev/null | grep -q "kubernetes.io/tls" \
  && ok "shop-tls (kubernetes.io/tls)" || ng "shop-tls 없음 또는 타입이 tls 가 아님"

echo "[문제2] tls-ex/shop Ingress 에 tls + ssl-redirect"
kubectl get ingress shop -n tls-ex -o jsonpath='{.spec.tls[0].secretName}' 2>/dev/null | grep -q "shop-tls" \
  && ok "tls 블록에 shop-tls 연결" || ng "Ingress tls 블록 없음/secretName 불일치"
kubectl get ingress shop -n tls-ex \
  -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/ssl-redirect}' 2>/dev/null | grep -q "true" \
  && ok "ssl-redirect 어노테이션" || ng "ssl-redirect 어노테이션 없음"

echo "[문제3] tls-ex2/api-tls 를 지정된 이름 그대로 생성"
kubectl get secret api-tls -n tls-ex2 -o jsonpath='{.type}' 2>/dev/null | grep -q "kubernetes.io/tls" \
  && ok "api-tls (kubernetes.io/tls)" || ng "api-tls 없음 또는 타입 불일치"
kubectl get ingress api -n tls-ex2 -o jsonpath='{.spec.tls[0].secretName}' 2>/dev/null | grep -q "api-tls" \
  && ok "Ingress 는 그대로(secretName=api-tls)" || ng "Ingress 가 변경됨(건드리지 말 것)"

# 실제 핸드셰이크까지 확인 (컨트롤러가 있을 때만)
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
PORT=$(kubectl -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}' 2>/dev/null)
if [ -n "$NODE_IP" ] && [ -n "$PORT" ] && command -v curl >/dev/null 2>&1; then
  echo "[추가] 실제 TLS 핸드셰이크 (노드 $NODE_IP:$PORT)"
  for h in shop.example.com api.example.com; do
    SUBJ=$(curl -vk --max-time 8 "https://$h:$PORT" --resolve "$h:$PORT:$NODE_IP" 2>&1 \
           | grep -m1 "subject:" | sed 's/.*CN=//')
    if [ "$SUBJ" = "$h" ]; then ok "$h → 내 인증서(CN=$SUBJ)"
    else ng "$h → CN=${SUBJ:-확인불가} (기본/가짜 인증서일 수 있음)"; fi
  done
else
  echo "[추가] ingress-nginx NodePort 를 못 찾아 핸드셰이크 검증은 건너뜀"
fi

echo ""
echo "채점 결과: PASS=$PASS  FAIL=$FAIL"
