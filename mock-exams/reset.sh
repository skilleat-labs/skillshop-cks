#!/usr/bin/env bash
# 모든 모의고사 리소스 정리 (m1-*, m2-*, m3-* 네임스페이스 + 남는 ClusterRoleBinding)
set -u
echo "==> 모의고사 네임스페이스 삭제"
kubectl delete ns \
  m1-pss m1-netpol m1-netpol-client m1-tls m1-rbac \
  m2-cnp m2-cnp-client m2-sc m2-sa \
  m3-istio m3-pss m3-tls m3-falco \
  --ignore-not-found --wait=false

echo "==> 남는 ClusterRoleBinding 삭제 (mock-1 q4)"
kubectl delete clusterrolebinding m1-ci-bot-admin --ignore-not-found

echo "==> 임시 인증서/스캔 결과 삭제"
rm -f /tmp/m1.key /tmp/m1.crt /tmp/m3.key /tmp/m3.crt /tmp/m1-scan.json /tmp/m2-sbom.spdx 2>/dev/null

echo "완료. (네임스페이스 삭제는 백그라운드로 진행됨 — kubectl get ns 로 확인)"
