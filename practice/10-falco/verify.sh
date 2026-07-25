#!/usr/bin/env bash
# 10강 자동 채점 — kubectl 로 확인 가능한 부분만.
#   Falco 룰의 "발화"는 노드 journalctl 에서만 보이므로 여기서 채점하지 않는다.
#   여기서는: 워크로드 존재(문제2 대상), 문제3 대응(intruder scale 0)을 확인한다.
set -u
NS=falco-ex
pass=0; fail=0
ok(){ echo "  ✅ $1"; pass=$((pass+1)); }
no(){ echo "  ❌ $1"; fail=$((fail+1)); }

echo "== 문제 1 — Falco 서비스 확인 (노드 작업, 참고만)"
if [ -f /tmp/falco-service.txt ] && [ -s /tmp/falco-service.txt ]; then
  ok "/tmp/falco-service.txt 기록됨 → $(tr -d '\n' </tmp/falco-service.txt)"
else
  echo "  ℹ️  /tmp/falco-service.txt 없음 — 이 파일은 '노드'에서 만들어야 함(Mac 이면 정상)."
fi

echo "== 문제 2 — 탐지 대상(suspicious) 워크로드"
if kubectl get deploy suspicious -n $NS >/dev/null 2>&1; then
  ok "deploy/suspicious 존재 (셸 실행 → 룰 발화는 노드 journalctl 로 확인)"
else
  no "deploy/suspicious 없음 — kubectl apply -f workload.yaml 했는지 확인"
fi

echo "== 문제 3 — /dev/mem 탐지 후 대응 (intruder scale 0)"
if ! kubectl get deploy intruder -n $NS >/dev/null 2>&1; then
  no "deploy/intruder 없음 — workload.yaml 적용 필요(또는 이미 삭제로 대응함)"
else
  rep="$(kubectl get deploy intruder -n $NS -o jsonpath='{.spec.replicas}' 2>/dev/null)"
  running="$(kubectl get pods -n $NS -l app=intruder --no-headers 2>/dev/null | grep -c Running)"
  if [ "${rep:-1}" = "0" ] && [ "${running:-0}" = "0" ]; then
    ok "intruder Deployment scale 0 + 실행 중 파드 없음 → 대응 완료"
  else
    no "intruder 아직 replicas=$rep, running=$running — kubectl scale deploy/intruder -n $NS --replicas=0"
  fi
fi

echo ""
echo "결과: PASS=$pass FAIL=$fail"
echo "※ 룰 발화(셸/dev/mem 탐지)는 노드에서:  sudo journalctl -fu <falco유닛> | grep -iE 'shell|/dev/mem'"
[ $fail -eq 0 ]
