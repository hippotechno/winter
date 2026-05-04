#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Build + push dev image lên Harbor.

Dev image giữ .git/docs/tests để có thể shell vào container và pull code khi đang dev.
Không dùng dev image cho production chính thức.

Usage:
  ./scripts/release-dev.sh [tag] [--platforms linux/amd64,linux/arm64] [--include-seed-assets]

Examples:
  ./scripts/release-dev.sh
  ./scripts/release-dev.sh dev
  ./scripts/release-dev.sh staging --platforms linux/amd64
USAGE
}

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET=$'\033[0m'
  C_BLUE=$'\033[34m'
  C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
else
  C_RESET=""
  C_BLUE=""
  C_YELLOW=""
  C_RED=""
  C_GREEN=""
fi

log_info() { printf "%s%s%s\n" "$C_BLUE" "$*" "$C_RESET"; }
log_warn() { printf "%s%s%s\n" "$C_YELLOW" "$*" "$C_RESET"; }
log_error() { printf "%s%s%s\n" "$C_RED" "$*" "$C_RESET" >&2; }
log_success() { printf "%s%s%s\n" "$C_GREEN" "$*" "$C_RESET"; }

format_bytes() {
  local bytes="$1"
  awk -v b="$bytes" 'function human(x){s="B KB MB GB TB"; n=split(s,u," "); i=1; while (x>=1024 && i<n){x/=1024;i++} return sprintf("%.2f %s", x, u[i])} BEGIN{print human(b)}'
}

get_image_digest() {
  local image_ref="$1"

  docker buildx imagetools inspect "$image_ref" 2>/dev/null \
    | awk '/^Digest:/ {print $2; exit}'
}

print_manifest_sizes() {
  local image_ref="$1"
  local raw total

  raw="$(docker buildx imagetools inspect "$image_ref" --raw 2>/dev/null || true)"
  if [[ -z "$raw" ]]; then
    return 0
  fi

  total="$(php -r '
    $j=json_decode(stream_get_contents(STDIN),true);
    if(!is_array($j)){exit(0);}
    if(isset($j["layers"])) {
      $sum=(int)($j["config"]["size"]??0);
      foreach($j["layers"] as $l){$sum+=(int)($l["size"]??0);}
      echo $sum;
    }
  ' <<< "$raw" 2>/dev/null || true)"

  if [[ -n "$total" && "$total" =~ ^[0-9]+$ ]]; then
    echo "==> Image size: $(format_bytes "$total") (compressed manifest)"
  fi
}

confirm_push() {
  local input

  echo
  log_warn "Chuẩn bị build dev image và push lên Harbor:"
  echo "    - Tag      : ${DEV_TAG}"
  echo "    - Platforms: ${PLATFORMS}"
  echo "    - Giữ .git/docs/tests: true"
  echo "    - Include seed assets: ${INCLUDE_SEED_ASSETS}"

  if [[ ! -t 0 ]]; then
    log_info "INFO: Không chờ nhập lựa chọn, tiếp tục build và push dev image."
    return 0
  fi

  echo
  printf "Nhấn Enter để tiếp tục build dev image, nhập n hoặc q để dừng.\n"
  printf "Nếu không nhập gì, tự tiếp tục sau 60s: "

  if ! read -r -t 60 input; then
    printf "\n"
    log_info "INFO: Hết thời gian chờ, tiếp tục build dev image."
    return 0
  fi

  input="${input//[[:space:]]/}"

  if [[ -z "$input" || "$input" == "y" || "$input" == "Y" || "$input" == "yes" || "$input" == "YES" ]]; then
    log_info "INFO: Tiếp tục build dev image."
    return 0
  fi

  if [[ "$input" == "n" || "$input" == "N" || "$input" == "no" || "$input" == "NO" || "$input" == "q" || "$input" == "Q" ]]; then
    log_error "Dừng dev release theo lựa chọn của bạn."
    exit 1
  fi

  log_warn "Không hiểu lựa chọn '$input'. Tiếp tục build dev image."
}

TAG="dev"
PLATFORMS="linux/amd64"
INCLUDE_SEED_ASSETS="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --platform|--platforms)
      PLATFORMS="${2:-}"
      if [[ -z "$PLATFORMS" ]]; then
        log_error "Thiếu giá trị cho --platforms"
        exit 1
      fi
      shift 2
      ;;
    --include-seed-assets)
      INCLUDE_SEED_ASSETS="true"
      shift
      ;;
    --no-seed-assets)
      INCLUDE_SEED_ASSETS="false"
      shift
      ;;
    *)
      if [[ "$TAG" == "dev" ]]; then
        TAG="$1"
        shift
      else
        log_error "Tham số không hợp lệ: $1"
        usage
        exit 1
      fi
      ;;
  esac
done

if [[ "$TAG" == *":"* || "$TAG" == *"/"* ]]; then
  log_error "Dev tag không được chứa ':' hoặc '/'."
  exit 1
fi

if [[ "$PLATFORMS" == *"windows/"* ]]; then
  log_error "Image hiện tại dùng base Linux, không build được Windows container."
  exit 1
fi

REPO="harbor.tuimuon.xyz/library"
IMAGE_NAME="tulutala"
IMAGE="$REPO/$IMAGE_NAME"
DEV_TAG="$IMAGE:$TAG"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
VCS_REF="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
IMAGE_VERSION="${TAG}-${VCS_REF}"

if ! command -v docker >/dev/null 2>&1; then
  log_error "Không tìm thấy docker command"
  exit 1
fi

if ! docker system info >/dev/null 2>&1; then
  log_error "Docker daemon chưa chạy hoặc không truy cập được"
  exit 1
fi

if ! docker buildx version >/dev/null 2>&1; then
  log_error "Docker Buildx chưa sẵn sàng."
  exit 1
fi

log_info "==> Kiểm tra đăng nhập Harbor: harbor.tuimuon.xyz"
AUTH_CHECK_OUTPUT="$(docker buildx imagetools inspect "$IMAGE:latest" 2>&1 || true)"
if echo "$AUTH_CHECK_OUTPUT" | grep -Eqi 'unauthorized|authentication required|no basic auth credentials|denied'; then
  log_error "Chưa đăng nhập Harbor hoặc credentials không hợp lệ: harbor.tuimuon.xyz"
  log_error "Chạy trước: docker login harbor.tuimuon.xyz"
  exit 1
fi

BUILDER_NAME="tulutala-builder"
if ! docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
  log_info "==> Tạo buildx builder: $BUILDER_NAME (docker-container)"
  docker buildx create --name "$BUILDER_NAME" --driver docker-container --use >/dev/null
fi
docker buildx use "$BUILDER_NAME" >/dev/null
docker buildx inspect --bootstrap "$BUILDER_NAME" >/dev/null

log_info "==> Dev release target:"
echo "    - Tag      : ${DEV_TAG}"
echo "    - Platforms: ${PLATFORMS}"

"$REPO_ROOT/scripts/preflight-build.sh" --interactive-assets --asset-timeout 60

confirm_push

BUILD_CMD=(
  docker buildx build
  -f "$REPO_ROOT/docker/Dockerfile"
  --target dev-runtime
  --platform "$PLATFORMS"
  --push
  --build-arg "BUILD_DATE=$BUILD_DATE"
  --build-arg "VCS_REF=$VCS_REF"
  --build-arg "IMAGE_VERSION=$IMAGE_VERSION"
  --build-arg "PRUNE_DEV_ARTIFACTS=false"
  --build-arg "INCLUDE_SEED_ASSETS=$INCLUDE_SEED_ASSETS"
  -t "$DEV_TAG"
)

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  BUILD_CMD+=(--secret "id=github_token,env=GITHUB_TOKEN")
fi

BUILD_CMD+=("$REPO_ROOT")

DOCKER_BUILDKIT=1 "${BUILD_CMD[@]}"

log_info "==> Inspect manifest: $DEV_TAG"
docker buildx imagetools inspect "$DEV_TAG" || true
print_manifest_sizes "$DEV_TAG"

DEV_DIGEST="$(get_image_digest "$DEV_TAG" || true)"

echo
log_success "Dev release hoàn tất"
echo "- Dev image: $DEV_TAG"
if [[ -n "$DEV_DIGEST" ]]; then
  echo "- Dev digest: $DEV_DIGEST"
fi
echo "- Platforms: $PLATFORMS"
echo "- Include seed assets: $INCLUDE_SEED_ASSETS"
echo "- Giữ .git/docs/tests: true"
