#!/usr/bin/env bash
# Cilium mutual authentication(SPIRE) 활성화 — 문제 3 실습 전 "클러스터당 1회" 실행.
# kubectl apply 하나로는 SPIRE 를 못 깔기 때문에 helm/cilium 업그레이드로 켠다.
set -euo pipefail

echo "==> Cilium mutual auth(SPIRE) 활성화 시작"

if command -v cilium >/dev/null 2>&1; then
  echo "-- cilium CLI 사용"
  cilium upgrade --reuse-values \
    --set authentication.mutual.spire.enabled=true \
    --set authentication.mutual.spire.install.enabled=true
elif command -v helm >/dev/null 2>&1; then
  echo "-- helm 사용 (release 이름이 cilium 이 아니면 아래 cilium 부분을 바꾸세요)"
  helm upgrade cilium cilium/cilium -n kube-system --reuse-values \
    --set authentication.mutual.spire.enabled=true \
    --set authentication.mutual.spire.install.enabled=true
else
  echo "ERROR: cilium CLI 도 helm 도 없습니다. 둘 중 하나가 필요해요." >&2
  exit 1
fi

echo "==> Cilium 재기동"
kubectl -n kube-system rollout restart deploy/cilium-operator ds/cilium
kubectl -n kube-system rollout status ds/cilium --timeout=180s

echo "==> SPIRE 파드 확인 (네임스페이스: cilium-spire 또는 kube-system)"
kubectl get pods -A | grep -i spire || echo "  (아직 안 보이면 잠시 후 다시 확인)"

echo "==> 기능 플래그 확인"
kubectl -n kube-system exec ds/cilium -- cilium config 2>/dev/null | grep -i mesh-auth-mutual || true

echo
echo "완료. 이제 문제 3 적용 후 VALID 가 True 인지 확인하세요:"
echo "  kubectl apply -f problem-3.yaml"
echo "  kubectl apply -f solutions/problem-3.yaml"
echo "  kubectl get ciliumnetworkpolicy -n cnp-ex      # VALID: True"
echo "  kubectl exec -n cnp-client deploy/client -- wget -qO- --timeout=3 http://target.cnp-ex"
