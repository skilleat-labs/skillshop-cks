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
# ⚠️ http://kubernetes.default (80) 로 확인하면 안 된다. 이 서비스는 443 만 열려 있어서
#    정책이 없어도 항상 실패한다 → 정책을 안 만들어도 PASS 가 되는 가짜 검사가 된다.
#    실제로 열려 있는 443 을 nc 로 찔러 egress 차단 여부를 확인한다.
if kubectl exec -n netpol-ex2 deploy/tester -- nc -z -w 3 kubernetes.default 443 >/dev/null 2>&1; then
  ng "DNS 외 egress 가 열려 있음(deny-all 미적용)"
else
  ok "DNS 외 egress 차단됨"
fi

echo "[문제3] cnp-ex · CiliumNetworkPolicy mutual auth (구조 채점)"
CNP=$(kubectl get cnp -n cnp-ex -o json 2>/dev/null)
if echo "$CNP" | grep -q '"items": \[\]' || [ -z "$CNP" ]; then
  ng "CiliumNetworkPolicy 가 없음"
else
  echo "$CNP" | grep -q '"mode": *"required"' \
    && ok "authentication.mode: required" || ng "mutual auth(required) 설정 없음"
  echo "$CNP" | grep -q '"host"' \
    && ok "fromEntities: host 허용" || ng "host 예외 없음"
  # ⚠️ JSON 에 'cnp-client' 문자열이 있는지만 보면 안 된다. 라벨 '키'가 틀려도
  #    (예: k8s: 접두사 없는 kubernetes.io/metadata.name) 값만 맞으면 통과해버린다.
  #    실제로 통신이 되는지로 채점한다. (SPIRE 활성 시에만 유효)
  if kubectl get pods -n cilium-spire --no-headers 2>/dev/null | grep -q Running; then
    if kubectl exec -n cnp-client deploy/client -- \
         wget -qO- --timeout=8 http://target.cnp-ex >/dev/null 2>&1; then
      ok "cnp-client → target 실제 통신(상호 인증 통과)"
    else
      ng "cnp-client → target 이 차단됨 — 셀렉터 라벨 키 확인 (k8s:io.kubernetes.pod.namespace)"
    fi
  else
    echo "$CNP" | grep -q 'cnp-client' \
      && ok "cnp-client 셀렉터(문자열 확인 — SPIRE 미활성이라 통신검증 불가)" \
      || ng "client 네임스페이스 셀렉터 없음"
  fi
  VALID=$(kubectl get cnp -n cnp-ex -o jsonpath='{.items[0].status.conditions[?(@.type=="Valid")].status}' 2>/dev/null)
  [ "$VALID" = "False" ] && echo "     ℹ️ VALID=False — Cilium SPIRE 미활성. 실제 enforcement 는 ./setup-mutual-auth.sh 실행 후 확인."
fi

echo ""
echo "채점 결과: PASS=$PASS  FAIL=$FAIL"
