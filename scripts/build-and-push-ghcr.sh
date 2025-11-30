#!/usr/bin/env bash
set -Eeuo pipefail

: "${GHCR_PAT:?Set GHCR_PAT to your GitHub Packages token}"
: "${GITHUB_USERNAME:?Set GITHUB_USERNAME to your GitHub username or org}"

image="ghcr.io/${GITHUB_USERNAME}/docker-qbittorrentvpn"
platform="${PLATFORM:-linux/amd64}"

echo "Logging into GHCR as ${GITHUB_USERNAME}..."
echo "${GHCR_PAT}" | docker login ghcr.io -u "${GITHUB_USERNAME}" --password-stdin

echo "Building and pushing ${image} for platform ${platform}..."
docker buildx build \
  --platform "${platform}" \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  --cache-from "type=registry,ref=${image}:cache" \
  --cache-to "type=registry,ref=${image}:cache,mode=max" \
  -t "${image}:latest" \
  -t "${image}:cache" \
  --push \
  --progress=plain \
  .
