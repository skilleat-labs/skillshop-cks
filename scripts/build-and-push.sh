#!/usr/bin/env bash
# SkillShop 이미지 4개를 빌드해서 Docker Hub에 푸시한다. (로컬에 Docker 필요)
#
# 사용법:
#   docker login
#   # 취약 버전 (태그 1.0)
#   ./scripts/build-and-push.sh
#   # 하드닝 버전 (태그 2.0)
#   TAG=2.0 DOCKERFILE=Dockerfile.hardened ./scripts/build-and-push.sh
set -euo pipefail

NS="${DOCKERHUB_NS:-skilleat}"         # Docker Hub 네임스페이스
TAG="${TAG:-1.0}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}" # Dockerfile 또는 Dockerfile.hardened
SERVICES="frontend product-svc order-svc payment-svc"

cd "$(dirname "$0")/.."

for s in $SERVICES; do
  img="${NS}/skillshop-${s}:${TAG}"
  echo "==> building ${img}  (${DOCKERFILE})"
  docker build -f "services/${s}/${DOCKERFILE}" -t "${img}" "services/${s}"
  echo "==> pushing ${img}"
  docker push "${img}"
done
echo "완료: ${NS}/skillshop-* :${TAG}"
