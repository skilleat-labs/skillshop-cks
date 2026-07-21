#!/usr/bin/env bash
# Cilium mutual authentication(SPIRE) 활성화 — 문제 3 실습 전 "클러스터당 1회" 실행.
# kubectl apply 하나로는 SPIRE 를 못 깔기 때문에 helm/cilium 업그레이드로 켠다.
set -euo pipefail

echo "==> Cilium mutual auth(SPIRE) 활성화 시작"

# SPIRE 서버는 PVC(1Gi) 를 요구한다. kubeadm 기본 클러스터에는 동적 프로비저너가 없어서
# StorageClass 가 하나도 없으면 spire-server 가 Pending 에 걸리고, agent 는
# "Waiting for spire server to be reachable" 로 CrashLoop 에 빠진다.
if ! kubectl get sc >/dev/null 2>&1 || [ -z "$(kubectl get sc --no-headers 2>/dev/null)" ]; then
  echo "==> StorageClass 가 없어 local-path provisioner 를 설치합니다 (SPIRE 서버의 PVC 용)"
  kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.31/deploy/local-path-storage.yaml
  kubectl -n local-path-storage rollout status deploy/local-path-provisioner --timeout=120s
  kubectl patch storageclass local-path \
    -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
  echo "   local-path 를 기본 StorageClass 로 지정했습니다."
fi

# ⚠️ authentication.enabled 는 차트 기본값이 false 다. 이걸 빼고 spire 만 켜면
#    helm 검증에서 아래 에러로 막힌다:
#      "SPIRE integration requires .Values.authentication.enabled=true
#       and .Values.authentication.mutual.spire.enabled=true"
#    세 값을 반드시 함께 준다.
if command -v cilium >/dev/null 2>&1; then
  echo "-- cilium CLI 사용"
  cilium upgrade --reuse-values \
    --set authentication.enabled=true \
    --set authentication.mutual.spire.enabled=true \
    --set authentication.mutual.spire.install.enabled=true
elif command -v helm >/dev/null 2>&1; then
  echo "-- helm 사용 (release 이름이 cilium 이 아니면 아래 cilium 부분을 바꾸세요)"
  helm upgrade cilium cilium/cilium -n kube-system --reuse-values \
    --set authentication.enabled=true \
    --set authentication.mutual.spire.enabled=true \
    --set authentication.mutual.spire.install.enabled=true
else
  echo "ERROR: cilium CLI 도 helm 도 없습니다. 둘 중 하나가 필요해요." >&2
  exit 1
fi

echo "==> Cilium 재기동"
kubectl -n kube-system rollout restart deploy/cilium-operator ds/cilium
kubectl -n kube-system rollout status ds/cilium --timeout=180s

echo "==> SPIRE 파드가 Ready 될 때까지 대기 (최대 5분)"
kubectl wait --for=condition=Ready pod -n cilium-spire --all --timeout=300s || {
  echo "  ⚠️ SPIRE 가 아직 안 떴습니다. 아래로 원인을 확인하세요:"
  echo "     kubectl get pods -n cilium-spire"
  echo "     kubectl get pvc  -n cilium-spire     # Pending 이면 StorageClass 문제"
  echo "     kubectl describe pod spire-server-0 -n cilium-spire | tail -20"
  echo "  PVC 가 StorageClass 없이 이미 만들어졌다면 지우고 재생성해야 합니다:"
  echo "     kubectl delete pvc spire-data-spire-server-0 -n cilium-spire"
  echo "     kubectl delete pod spire-server-0 -n cilium-spire"
}
kubectl get pods -n cilium-spire

echo "==> 기능 플래그 확인"
kubectl -n kube-system exec ds/cilium -- cilium config 2>/dev/null | grep -i mesh-auth-mutual || true

echo
echo "완료. 이제 문제 3 적용 후 VALID 가 True 인지 확인하세요:"
echo "  kubectl apply -f problem-3.yaml"
echo "  kubectl apply -f solutions/problem-3.yaml"
echo "  kubectl get ciliumnetworkpolicy -n cnp-ex      # VALID: True"
echo "  kubectl exec -n cnp-client deploy/client -- wget -qO- --timeout=3 http://target.cnp-ex"
