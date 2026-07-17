#!/usr/bin/env bash
# ingress-nginx 컨트롤러 설치 — 6강(TLS + Ingress) 실습 전 1회.
# baremetal(kubeadm) 클러스터용: NodePort 로 노출된다.
#   테스트 시 노드IP + NodePort 를 curl --resolve 로 지정하면 된다.
set -euo pipefail

echo "==> ingress-nginx 컨트롤러 설치 (baremetal provider)"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml

echo "==> 컨트롤러 파드가 Ready 될 때까지 대기 (최대 180s)"
kubectl wait --namespace ingress-nginx \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

echo ""
echo "==> HTTPS(443) NodePort 확인 — curl --resolve 에 이 포트를 쓴다"
HTTPS_PORT=$(kubectl -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "   NODE_IP=${NODE_IP}  HTTPS_NODEPORT=${HTTPS_PORT}"
echo "   예) curl -vk https://shop.example.com:${HTTPS_PORT} --resolve shop.example.com:${HTTPS_PORT}:${NODE_IP}"
