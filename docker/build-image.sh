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
            log_error "Tham số không hợp lệ: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$IMAGE_TAG" ]]; then
    log_error "Thiếu --tag"
    usage
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
VCS_REF="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")"

if ! docker buildx version >/dev/null 2>&1; then
    log_error "Docker Buildx chưa sẵn sàng."
    exit 1
fi

BUILDER_NAME="winter-builder"
if ! docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
    docker buildx create --name "$BUILDER_NAME" --driver docker-container --use >/dev/null
fi
docker buildx use "$BUILDER_NAME" >/dev/null
docker buildx inspect --bootstrap "$BUILDER_NAME" >/dev/null

log_info "==> Build image: $IMAGE_TAG"
log_info "==> Platforms : $PLATFORMS"
log_info "==> Include seed assets: $INCLUDE_SEED_ASSETS"

if [[ "$REQUIRE_GITHUB_TOKEN" == "true" && -z "${GITHUB_TOKEN:-}" ]]; then
    log_error "Thiếu GITHUB_TOKEN trong shell hiện tại."
    log_error "Hãy export token trước khi build để tránh fail ở bước composer:"
    log_error "  export GITHUB_TOKEN=ghp_xxx_or_github_pat_xxx"
    log_error "Nếu build này không cần private package, chạy thêm --allow-missing-github-token."
    exit 1
fi

if [[ "$RUN_VITE_COMPILE" = "true" ]]; then
    if [[ -x "$REPO_ROOT/scripts/vite-compile-production.sh" ]]; then
        log_info "==> Compile Vite assets (production)"
        "$REPO_ROOT/scripts/vite-compile-production.sh" --config "$REPO_ROOT/.vite-packages.production"
    else
        log_warn "==> Không tìm thấy scripts/vite-compile-production.sh, bỏ qua compile Vite."
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
        log_error "Build multi-platform cần --push để xuất manifest list."
        log_error "Hoặc dùng 1 platform duy nhất khi không push."
        exit 1
    fi
    CMD+=(--load)
fi

CMD+=("$REPO_ROOT")
DOCKER_BUILDKIT=1 "${CMD[@]}"

if [[ "$DO_PUSH" = "true" ]]; then
    log_info "==> Inspect manifest: $IMAGE_TAG"
    docker buildx imagetools inspect "$IMAGE_TAG" || true
    print_manifest_sizes "$IMAGE_TAG"
else
    local_size="$(docker image inspect "$IMAGE_TAG" --format '{{.Size}}' 2>/dev/null || true)"
    if [[ -n "$local_size" && "$local_size" =~ ^[0-9]+$ ]]; then
        log_info "==> Local image size: $(format_bytes "$local_size") (uncompressed)"
    fi
fi

log_success "Hoàn tất."
