#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Build + push image multi-platform lên Harbor bằng Docker Buildx.

Usage:
  ./release.sh <version> [--no-latest] [--platforms linux/amd64,linux/arm64]

Examples:
  ./release.sh 1.0.0
  ./release.sh 1.0.1 --no-latest
  ./release.sh 1.1.0 --platforms linux/amd64
USAGE
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

VERSION=""
PLATFORMS="linux/amd64,linux/arm64"
PUSH_LATEST="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --no-latest)
      PUSH_LATEST="false"
      shift
      ;;
    --platform|--platforms)
      PLATFORMS="${2:-}"
      if [[ -z "$PLATFORMS" ]]; then
        echo "Thiếu giá trị cho --platforms" >&2
        exit 1
      fi
      shift 2
      ;;
    *)
      if [[ -z "$VERSION" ]]; then
        VERSION="$1"
        shift
      else
        echo "Tham số không hợp lệ: $1" >&2
        usage
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  echo "Thiếu version" >&2
  usage
  exit 1
fi

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version phải theo format x.y.z (vd: 1.0.0)" >&2
  exit 1
fi

if [[ "$PLATFORMS" == *"windows/"* ]]; then
  echo "Image hiện tại dùng base Linux (php:8.3-apache-bookworm), không build được Windows container." >&2
  echo "Dùng platform Linux, ví dụ: linux/amd64,linux/arm64" >&2
  exit 1
fi

REPO="harbor.tuimuon.xyz/library"
IMAGE_NAME="tulutala"
IMAGE="$REPO/$IMAGE_NAME"
VERSION_TAG="$IMAGE:$VERSION"
LATEST_TAG="$IMAGE:latest"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
REQUIRED_GIT_TAG="v$VERSION"
BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

if ! command -v docker >/dev/null 2>&1; then
  echo "Không tìm thấy docker command" >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "Không tìm thấy git command" >&2
  exit 1
fi

if ! git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  echo "Thư mục hiện tại không phải git repository hợp lệ." >&2
  exit 1
fi

VCS_REF="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
HEAD_COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD)"

if ! git -C "$REPO_ROOT" rev-parse -q --verify "refs/tags/$REQUIRED_GIT_TAG" >/dev/null 2>&1; then
  echo "Thiếu git tag bắt buộc: $REQUIRED_GIT_TAG" >&2
  echo "Tạo tag rồi push trước khi release, ví dụ:" >&2
  echo "  git tag -a $REQUIRED_GIT_TAG -m \"Release $REQUIRED_GIT_TAG\"" >&2
  echo "  git push origin $REQUIRED_GIT_TAG" >&2
  exit 1
fi

TAG_COMMIT="$(git -C "$REPO_ROOT" rev-list -n 1 "$REQUIRED_GIT_TAG")"
if [[ -z "$HEAD_COMMIT" || "$HEAD_COMMIT" != "$TAG_COMMIT" ]]; then
  echo "Tag $REQUIRED_GIT_TAG không trỏ tới commit hiện tại (HEAD)." >&2
  echo "HEAD : $(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")" >&2
  echo "TAG  : $(git -C "$REPO_ROOT" rev-parse --short "$TAG_COMMIT" 2>/dev/null || echo "unknown")" >&2
  echo "Checkout đúng commit/tag rồi chạy lại release." >&2
  exit 1
fi

if ! docker buildx version >/dev/null 2>&1; then
  echo "Docker Buildx chưa sẵn sàng. Hãy bật Docker Desktop / cài plugin buildx." >&2
  exit 1
fi

echo "==> Kiểm tra đăng nhập Harbor: harbor.tuimuon.xyz"
if ! docker system info >/dev/null 2>&1; then
  echo "Docker daemon chưa chạy hoặc không truy cập được" >&2
  exit 1
fi

if ! docker buildx inspect >/dev/null 2>&1; then
  echo "==> Tạo buildx builder mặc định"
  docker buildx create --name tulutala-builder --use >/dev/null
fi

TAGS=(-t "$VERSION_TAG")
if [[ "$PUSH_LATEST" == "true" ]]; then
  TAGS+=(-t "$LATEST_TAG")
fi

echo "==> Build + Push image:"
if [[ "$PUSH_LATEST" == "true" ]]; then
  echo "    - Tags     : ${VERSION_TAG}, ${LATEST_TAG}"
else
  echo "    - Tags     : ${VERSION_TAG}"
fi
echo "    - Platforms: ${PLATFORMS}"

BUILD_CMD=(
  docker buildx build
  -f "$REPO_ROOT/docker/Dockerfile"
  --target runtime
  --platform "$PLATFORMS"
  --push
  --build-arg "BUILD_DATE=$BUILD_DATE"
  --build-arg "VCS_REF=$VCS_REF"
)
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  BUILD_CMD+=(--secret "id=github_token,env=GITHUB_TOKEN")
fi
BUILD_CMD+=("${TAGS[@]}")
BUILD_CMD+=("$REPO_ROOT")

DOCKER_BUILDKIT=1 "${BUILD_CMD[@]}"

echo
echo "Release hoàn tất"
echo "- Version: $VERSION_TAG"
if [[ "$PUSH_LATEST" == "true" ]]; then
  echo "- Latest : $LATEST_TAG"
fi
echo "- Platforms: $PLATFORMS"
echo
echo "Nếu chưa login Harbor, chạy: docker login harbor.tuimuon.xyz"
