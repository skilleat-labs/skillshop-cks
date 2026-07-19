#!/usr/bin/env bash
# 5강 자동 채점 — 실제 통신을 찔러서 확인한다 (정책 존재 여부가 아니라 동작으로 채점)
set -u
PASS=0; FAIL=0
ok(){ echo "  ✅ PASS $1"; PASS=$((PASS+1)); }
ng(){ echo "  ❌ FAIL $1"; FAIL=$((FAIL+1)); }
# 통신 성공이면 0, 실패/타임아웃이면 non-zero
reach(){ kubectl exec -n "$1" "deploy/$2" -- wget -qO- --timeout=3 "$3" >/dev/null 2>&1; }

echo "[문제1] netpol-ex1 · db 는 app=web 에서 오는 것만 허용"
reach netpol-ex1 web http://db      && ok "web → db 허용됨"     || ng "web → db 가 막힘(너무 과하게 차단)"
reach netpol-ex1 attacker http://db && ng "attacker → db 가 뚫림" || ok "attacker → db 차단됨"

echo "[문제2] netpol-ex2 · deny-all + DNS(53)만 허용"
# ⚠️ busybox nslookup 은 search 도메인을 안 붙인다. 짧은 이름(kubernetes.default)으로 조회하면
#    DNS 가 정상인데도 NXDOMAIN + 종료코드 1 이 나와 오탐이 된다. 반드시 FQDN 으로 확인할 것.
if kubectl exec -n netpol-ex2 deploy/tester -- \
     nslookup kubernetes.default.svc.cluster.local 2>/dev/null | grep -q "Address"; then
  ok "DNS 해석 동작"
else
  ng "DNS 가 막힘 (egress 53 UDP/TCP 허용 필요)"
fi
reach netpol-ex2 tester http://kubernetes.default \
  && ng "HTTP 가 뚫림(deny-all 미적용)" || ok "HTTP 차단됨"

echo "[문제3] cnp-ex · CiliumNetworkPolicy mutual auth (구조 채점)"
CNP=$(kubectl get cnp -n cnp-ex -o json 2>/dev/null)
if echo "$CNP" | grep -q '"items": \[\]' || [ -z "$CNP" ]; then
  ng "CiliumNetworkPolicy 가 없음"
else
  echo "$CNP" | grep -q '"mode": *"required"' \
    && ok "authentication.mode: required" || ng "mutual auth(required) 설정 없음"
  echo "$CNP" | grep -q '"host"' \
    && ok "fromEntities: host 허용" || ng "host 예외 없음"
  echo "$CNP" | grep -q 'cnp-client' \
    && ok "cnp-client 네임스페이스 셀렉터" || ng "client 네임스페이스 셀렉터 없음"
  VALID=$(kubectl get cnp -n cnp-ex -o jsonpath='{.items[0].status.conditions[?(@.type=="Valid")].status}' 2>/dev/null)
  [ "$VALID" = "False" ] && echo "     ℹ️ VALID=False — Cilium SPIRE 미활성. 실제 enforcement 는 ./setup-mutual-auth.sh 실행 후 확인."
fi

echo ""
echo "채점 결과: PASS=$PASS  FAIL=$FAIL"
