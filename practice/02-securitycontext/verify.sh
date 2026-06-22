#!/usr/bin/env bash
# 세 문제 정답 여부를 한 번에 점검
set -u
echo "[문제1] sc-ex1/api 실행 UID"
kubectl exec -n sc-ex1 deploy/api -- id 2>/dev/null | grep -q "uid=10001" \
  && echo "  PASS (uid=10001)" || echo "  FAIL"

echo "[문제2] sc-ex2/worker 읽기전용"
kubectl exec -n sc-ex2 deploy/worker -- touch /x 2>&1 | grep -qi "read-only" \
  && echo "  PASS (read-only)" || echo "  FAIL"

echo "[문제3] sc-ex3/writer 정상 기동 + 로그"
kubectl exec -n sc-ex3 deploy/writer -- cat /data/app.log 2>/dev/null | grep -q "started" \
  && echo "  PASS (running, log ok)" || echo "  FAIL"
