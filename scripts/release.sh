#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Build + push image multi-platform lên Harbor bằng Docker Buildx.

Usage:
  ./scripts/release.sh <version> [--no-latest] [--platforms linux/amd64,linux/arm64] [--skip-vite-compile] [--include-seed-assets] [--allow-missing-github-token]

Examples:
  ./scripts/release.sh 1.0.0
  ./scripts/release.sh 1.0.1 --no-latest
  ./scripts/release.sh 1.1.0 --platforms linux/amd64
  ./scripts/release.sh 1.1.1 --skip-vite-compile
  ./scripts/release.sh 1.1.2 --include-seed-assets
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

print_manifest_sizes() {
  local image_ref="$1"
  local raw index_lines

  raw="$(docker buildx imagetools inspect "$image_ref" --raw 2>/dev/null || true)"
  if [[ -z "$raw" ]]; then
    return 0
  fi

  if php -r '$j=json_decode(stream_get_contents(STDIN),true); if(!is_array($j)){exit(1);} echo isset($j["layers"]) ? "single" : "index";' <<< "$raw" | grep -q '^single$'; then
    local total
    total="$(php -r '
      $j=json_decode(stream_get_contents(STDIN),true);
      if(!is_array($j)){exit(1);}
      $sum=0;
      if(isset($j["config"]["size"])){$sum+=(int)$j["config"]["size"];}
      if(isset($j["layers"]) && is_array($j["layers"])){foreach($j["layers"] as $l){$sum+=(int)($l["size"]??0);}}
      echo $sum;
    ' <<< "$raw" 2>/dev/null || true)"
    if [[ -n "$total" && "$total" =~ ^[0-9]+$ ]]; then
      echo "==> Image size: $(format_bytes "$total") (compressed manifest)"
    fi
    return 0
  fi

  index_lines="$(php -r '
    $j=json_decode(stream_get_contents(STDIN),true);
    if(!is_array($j) || !isset($j["manifests"]) || !is_array($j["manifests"])) { exit(0); }
    foreach ($j["manifests"] as $m) {
      $digest = $m["digest"] ?? "";
      if ($digest === "") { continue; }
      $p = $m["platform"] ?? [];
      $os = $p["os"] ?? "unknown";
      $arch = $p["architecture"] ?? "unknown";
      $variant = $p["variant"] ?? "";
      $platform = $variant !== "" ? "{$os}/{$arch}/{$variant}" : "{$os}/{$arch}";
      echo $platform . "|" . $digest . PHP_EOL;
    }
  ' <<< "$raw" 2>/dev/null || true)"

  if [[ -z "$index_lines" ]]; then
    return 0
  fi

  echo "==> Image size by platform (compressed):"
  while IFS='|' read -r platform digest; do
    [[ -z "$digest" ]] && continue
    local child_raw total
    child_raw="$(docker buildx imagetools inspect "${image_ref%%@*}@${digest}" --raw 2>/dev/null || true)"
    [[ -z "$child_raw" ]] && continue
    total="$(php -r '
      $j=json_decode(stream_get_contents(STDIN),true);
      if(!is_array($j)){exit(1);}
      $sum=0;
      if(isset($j["config"]["size"])){$sum+=(int)$j["config"]["size"];}
      if(isset($j["layers"]) && is_array($j["layers"])){foreach($j["layers"] as $l){$sum+=(int)($l["size"]??0);}}
      echo $sum;
    ' <<< "$child_raw" 2>/dev/null || true)"
    if [[ -n "$total" && "$total" =~ ^[0-9]+$ ]]; then
      echo "    - $platform: $(format_bytes "$total")"
    fi
  done <<< "$index_lines"
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

VERSION=""
PLATFORMS="linux/amd64,linux/arm64"
PUSH_LATEST="true"
RUN_VITE_COMPILE="true"
INCLUDE_SEED_ASSETS="false"
REQUIRE_GITHUB_TOKEN="true"

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
        log_error "Thiếu giá trị cho --platforms"
        exit 1
      fi
      shift 2
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
    *)
      if [[ -z "$VERSION" ]]; then
        VERSION="$1"
        shift
      else
        log_error "Tham số không hợp lệ: $1"
        usage
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  log_error "Thiếu version"
  usage
  exit 1
fi

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  log_error "Version phải theo format x.y.z (vd: 1.0.0)"
  exit 1
fi

if [[ "$PLATFORMS" == *"windows/"* ]]; then
  log_error "Image hiện tại dùng base Linux (php:8.3-apache-bookworm), không build được Windows container."
  log_error "Dùng platform Linux, ví dụ: linux/amd64,linux/arm64"
  exit 1
fi

REPO="harbor.tuimuon.xyz/library"
IMAGE_NAME="tulutala"
IMAGE="$REPO/$IMAGE_NAME"
VERSION_TAG="$IMAGE:$VERSION"
LATEST_TAG="$IMAGE:latest"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REQUIRED_GIT_TAG="v$VERSION"
BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

if ! command -v docker >/dev/null 2>&1; then
  log_error "Không tìm thấy docker command"
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  log_error "Không tìm thấy git command"
  exit 1
fi

if ! git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  log_error "Thư mục hiện tại không phải git repository hợp lệ."
  exit 1
fi

VCS_REF="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
HEAD_COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD)"

if ! git -C "$REPO_ROOT" rev-parse -q --verify "refs/tags/$REQUIRED_GIT_TAG" >/dev/null 2>&1; then
  log_error "Thiếu git tag bắt buộc: $REQUIRED_GIT_TAG"
  log_error "Tạo tag rồi push trước khi release, ví dụ:"
  log_error "  git tag -a $REQUIRED_GIT_TAG -m \"Release $REQUIRED_GIT_TAG\""
  log_error "  git push origin $REQUIRED_GIT_TAG"
  exit 1
fi

TAG_COMMIT="$(git -C "$REPO_ROOT" rev-list -n 1 "$REQUIRED_GIT_TAG")"
if [[ -z "$HEAD_COMMIT" || "$HEAD_COMMIT" != "$TAG_COMMIT" ]]; then
  log_error "Tag $REQUIRED_GIT_TAG không trỏ tới commit hiện tại (HEAD)."
  log_error "HEAD : $(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
  log_error "TAG  : $(git -C "$REPO_ROOT" rev-parse --short "$TAG_COMMIT" 2>/dev/null || echo "unknown")"
  log_error "Checkout đúng commit/tag rồi chạy lại release."
  exit 1
fi

if ! docker buildx version >/dev/null 2>&1; then
  log_error "Docker Buildx chưa sẵn sàng. Hãy bật Docker Desktop / cài plugin buildx."
  exit 1
fi

log_info "==> Kiểm tra đăng nhập Harbor: harbor.tuimuon.xyz"
if ! docker system info >/dev/null 2>&1; then
  log_error "Docker daemon chưa chạy hoặc không truy cập được"
  exit 1
fi

AUTH_CHECK_OUTPUT="$(docker buildx imagetools inspect "$IMAGE:latest" 2>&1 || true)"
if echo "$AUTH_CHECK_OUTPUT" | grep -Eqi 'unauthorized|authentication required|no basic auth credentials|denied'; then
  log_error "Chưa đăng nhập Harbor hoặc credentials không hợp lệ: harbor.tuimuon.xyz"
  log_error "Chạy trước: docker login harbor.tuimuon.xyz"
  exit 1
fi

if [[ "$REQUIRE_GITHUB_TOKEN" == "true" && -z "${GITHUB_TOKEN:-}" ]]; then
  log_error "Thiếu GITHUB_TOKEN trong shell hiện tại."
  log_error "Hãy export token trước khi release để tránh fail ở bước composer:"
  log_error "  export GITHUB_TOKEN=ghp_xxx_or_github_pat_xxx"
  log_error "Nếu release này không cần private package, chạy thêm --allow-missing-github-token."
  exit 1
fi

BUILDER_NAME="tulutala-builder"
if ! docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
  log_info "==> Tạo buildx builder: $BUILDER_NAME (docker-container)"
  docker buildx create --name "$BUILDER_NAME" --driver docker-container --use >/dev/null
fi
docker buildx use "$BUILDER_NAME" >/dev/null
docker buildx inspect --bootstrap "$BUILDER_NAME" >/dev/null

TAGS=(-t "$VERSION_TAG")
if [[ "$PUSH_LATEST" == "true" ]]; then
  TAGS+=(-t "$LATEST_TAG")
fi

if [[ "$RUN_VITE_COMPILE" == "true" ]]; then
  if [[ -x "$REPO_ROOT/scripts/vite-compile-production.sh" ]]; then
    log_info "==> Compile Vite assets (production)"
    "$REPO_ROOT/scripts/vite-compile-production.sh" --config "$REPO_ROOT/.vite-packages.production"
  else
    log_warn "==> Không tìm thấy scripts/vite-compile-production.sh, bỏ qua compile Vite."
  fi
fi

log_info "==> Build + Push image:"
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
  --build-arg "INCLUDE_SEED_ASSETS=$INCLUDE_SEED_ASSETS"
)
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  BUILD_CMD+=(--secret "id=github_token,env=GITHUB_TOKEN")
fi
BUILD_CMD+=("${TAGS[@]}")
BUILD_CMD+=("$REPO_ROOT")

DOCKER_BUILDKIT=1 "${BUILD_CMD[@]}"

log_info "==> Inspect manifest: $VERSION_TAG"
docker buildx imagetools inspect "$VERSION_TAG" || true
print_manifest_sizes "$VERSION_TAG"

echo
log_success "Release hoàn tất"
echo "- Version: $VERSION_TAG"
if [[ "$PUSH_LATEST" == "true" ]]; then
  echo "- Latest : $LATEST_TAG"
fi
echo "- Platforms: $PLATFORMS"
echo "- Include seed assets: $INCLUDE_SEED_ASSETS"
