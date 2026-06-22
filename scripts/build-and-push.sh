#!/usr/bin/env bash
# SkillShop 이미지 4개를 멀티 아키텍처(amd64+arm64)로 빌드해 Docker Hub에 푸시.
# 로컬에 Docker(Rancher Desktop) + buildx 필요. 멀티아키 이미지는 빌드와 동시에 push됨.
#
# 사용법:
#   docker login
#   ./scripts/build-and-push.sh                                      # 취약 1.0
#   TAG=2.0 DOCKERFILE=Dockerfile.hardened ./scripts/build-and-push.sh   # 하드닝 2.0
set -euo pipefail

NS="${DOCKERHUB_NS:-skilleat}"
TAG="${TAG:-1.0}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
SERVICES="frontend product-svc order-svc payment-svc"

cd "$(dirname "$0")/.."
docker buildx create --use --name skillshop-builder 2>/dev/null || docker buildx use skillshop-builder

for s in $SERVICES; do
  img="${NS}/skillshop-${s}:${TAG}"
  echo "==> buildx (${PLATFORMS}) ${img}  (${DOCKERFILE})"
  docker buildx build \
    --platform "${PLATFORMS}" \
    -f "services/${s}/${DOCKERFILE}" \
    -t "${img}" \
    --push \
    "services/${s}"
done
echo "완료: ${NS}/skillshop-* :${TAG}  (${PLATFORMS})"
