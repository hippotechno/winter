#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Build image Docker cho repo WinterCMS hiện tại.

Usage:
  ./docker/build-image.sh \
    --tag ghcr.io/org/winter-app:2026.04.18 \
    [--platforms linux/amd64,linux/arm64] \
    [--skip-vite-compile] \
    [--include-seed-assets] \
    [--allow-missing-github-token] \
    [--push]
USAGE
}

IMAGE_TAG=""
PLATFORMS="linux/amd64"
DO_PUSH="false"
RUN_VITE_COMPILE="true"
INCLUDE_SEED_ASSETS="false"
REQUIRE_GITHUB_TOKEN="true"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --platform|--platforms)
            PLATFORMS="$2"
            shift 2
            ;;
        --push)
            DO_PUSH="true"
            shift
            ;;
        --skip-vite-compile)
            RUN_VITE_COMPILE="false"
            shift
            ;;
        --include-seed-assets)
            INCLUDE_SEED_ASSETS="true"
            shift
            ;;
        --allow-missing-github-token)
            REQUIRE_GITHUB_TOKEN="false"
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

if ! docker buildx version >/dev/null 2>&1; then
    echo "Docker Buildx chưa sẵn sàng." >&2
    exit 1
fi

BUILDER_NAME="winter-builder"
if ! docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
    docker buildx create --name "$BUILDER_NAME" --driver docker-container --use >/dev/null
fi
docker buildx use "$BUILDER_NAME" >/dev/null
docker buildx inspect --bootstrap "$BUILDER_NAME" >/dev/null

echo "==> Build image: $IMAGE_TAG"
echo "==> Platforms : $PLATFORMS"
echo "==> Include seed assets: $INCLUDE_SEED_ASSETS"

if [[ "$REQUIRE_GITHUB_TOKEN" == "true" && -z "${GITHUB_TOKEN:-}" ]]; then
    echo "Thiếu GITHUB_TOKEN trong shell hiện tại." >&2
    echo "Hãy export token trước khi build để tránh fail ở bước composer:" >&2
    echo "  export GITHUB_TOKEN=ghp_xxx_or_github_pat_xxx" >&2
    echo "Nếu build này không cần private package, chạy thêm --allow-missing-github-token." >&2
    exit 1
fi

if [[ "$RUN_VITE_COMPILE" = "true" ]]; then
    if [[ -x "$REPO_ROOT/scripts/vite-compile-production.sh" ]]; then
        echo "==> Compile Vite assets (production)"
        "$REPO_ROOT/scripts/vite-compile-production.sh" --config "$REPO_ROOT/.vite-packages.production"
    else
        echo "==> Không tìm thấy scripts/vite-compile-production.sh, bỏ qua compile Vite."
    fi
fi

CMD=(
    docker buildx build
    -f "$REPO_ROOT/docker/Dockerfile"
    --target runtime
    --platform "$PLATFORMS"
    --build-arg "BUILD_DATE=$BUILD_DATE"
    --build-arg "VCS_REF=$VCS_REF"
    --build-arg "INCLUDE_SEED_ASSETS=$INCLUDE_SEED_ASSETS"
    -t "$IMAGE_TAG"
)
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    CMD+=(--secret "id=github_token,env=GITHUB_TOKEN")
fi

if [[ "$DO_PUSH" = "true" ]]; then
    CMD+=(--push)
else
    if [[ "$PLATFORMS" == *,* ]]; then
        echo "Build multi-platform cần --push để xuất manifest list." >&2
        echo "Hoặc dùng 1 platform duy nhất khi không push." >&2
        exit 1
    fi
    CMD+=(--load)
fi

CMD+=("$REPO_ROOT")
DOCKER_BUILDKIT=1 "${CMD[@]}"

if [[ "$DO_PUSH" = "true" ]]; then
    echo "==> Inspect manifest: $IMAGE_TAG"
    docker buildx imagetools inspect "$IMAGE_TAG" || true
fi

echo "Hoàn tất."
