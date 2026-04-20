#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Build image Docker cho repo WinterCMS hiện tại.

Usage:
  ./docker/build-image.sh \
    --tag ghcr.io/org/winter-app:2026.04.18 \
    [--platform linux/amd64] \
    [--push]
USAGE
}

IMAGE_TAG=""
PLATFORM=""
DO_PUSH="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --push)
            DO_PUSH="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Tham số không hợp lệ: $1" >&2
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$IMAGE_TAG" ]]; then
    echo "Thiếu --tag" >&2
    usage
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
VCS_REF="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")"

CMD=(docker build -f "$REPO_ROOT/docker/Dockerfile" --target runtime -t "$IMAGE_TAG" --build-arg "BUILD_DATE=$BUILD_DATE" --build-arg "VCS_REF=$VCS_REF")
if [[ -n "$PLATFORM" ]]; then
    CMD+=(--platform "$PLATFORM")
fi
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    CMD+=(--secret "id=github_token,env=GITHUB_TOKEN")
fi
CMD+=("$REPO_ROOT")

echo "==> Build image: $IMAGE_TAG"
DOCKER_BUILDKIT=1 "${CMD[@]}"

if [[ "$DO_PUSH" = "true" ]]; then
    echo "==> Push image: $IMAGE_TAG"
    docker push "$IMAGE_TAG"
fi

echo "Hoàn tất."
