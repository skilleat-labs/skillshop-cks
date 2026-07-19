#!/usr/bin/env bash
# 3강 자동 채점 — 두 문제를 한 번에 점검
set -u
PASS=0; FAIL=0
ok(){ echo "  ✅ PASS $1"; PASS=$((PASS+1)); }
ng(){ echo "  ❌ FAIL $1"; FAIL=$((FAIL+1)); }

echo "[문제1] pss-ex1/web 이 restricted 를 만족해 Running 인가"
PHASE=$(kubectl get pods -n pss-ex1 -l app=web -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
if [ "$PHASE" = "Running" ]; then
  ok "web Running"
else
  ng "web 이 Running 아님 (현재: ${PHASE:-파드없음})"
  # 왜 막혔는지 힌트까지 보여준다 — admission 거부인지 kubelet 거부인지 구분
  if [ -z "$PHASE" ]; then
    echo "     → 파드가 아예 없음 = PodSecurity(admission) 거부. 확인:"
    echo "       kubectl get events -n pss-ex1 | grep -i forbidden"
  else
    echo "     → 파드는 있는데 컨테이너가 안 뜸 = kubelet 런타임 거부. 확인:"
    echo "       kubectl describe pod -n pss-ex1 -l app=web | grep -A1 Warning"
    echo "       (runAsNonRoot 만 있고 runAsUser 가 없으면 이 에러가 난다)"
  fi
fi

echo "[문제2] pss-ex2 네임스페이스에 restricted enforce + warn 라벨"
LBL=$(kubectl get ns pss-ex2 -o jsonpath='{.metadata.labels}' 2>/dev/null)
echo "$LBL" | grep -q '"pod-security.kubernetes.io/enforce":"restricted"' \
  && ok "enforce=restricted" || ng "enforce=restricted 라벨 없음"
echo "$LBL" | grep -q '"pod-security.kubernetes.io/warn":"restricted"' \
  && ok "warn=restricted" || ng "warn=restricted 라벨 없음"

echo ""
echo "채점 결과: PASS=$PASS  FAIL=$FAIL"
