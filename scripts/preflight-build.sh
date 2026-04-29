#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST_FILE="$ROOT_DIR/config/hippo-repos.yaml"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

errors=()
warnings=()
asset_ok=()
asset_missing=()
setup_ok=()
setup_missing=()
INTERACTIVE_ASSETS=false
ASSET_TIMEOUT=60
SETUP_TIMEOUT=60

usage() {
    cat <<'USAGE'
Usage: scripts/preflight-build.sh [options]

Options:
  --interactive-assets     Ask before continuing when theme production assets are missing.
  --asset-timeout SECONDS  Timeout for the asset prompt. Default: 60.
  --setup-timeout SECONDS  Timeout for the setup prompt. Default: 60.
  -h, --help               Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --interactive-assets)
            INTERACTIVE_ASSETS=true
            shift
            ;;
        --asset-timeout)
            ASSET_TIMEOUT="${2:-}"
            if [[ ! "$ASSET_TIMEOUT" =~ ^[0-9]+$ ]]; then
                printf "${RED}Invalid --asset-timeout value.${NC}\n" >&2
                exit 1
            fi
            shift 2
            ;;
        --setup-timeout)
            SETUP_TIMEOUT="${2:-}"
            if [[ ! "$SETUP_TIMEOUT" =~ ^[0-9]+$ ]]; then
                printf "${RED}Invalid --setup-timeout value.${NC}\n" >&2
                exit 1
            fi
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf "${RED}Unknown option: %s${NC}\n" "$1" >&2
            usage
            exit 1
            ;;
    esac
done

require_file() {
    local path="$1"
    if [[ ! -f "$ROOT_DIR/$path" ]]; then
        errors+=("Missing required file: $path")
    fi
}

scan_setup_checks() {
    setup_ok=()
    setup_missing=()

    while IFS= read -r setup_file; do
        setup_name="${setup_file#$ROOT_DIR/}"
        has_checks=false

        while IFS=$'\t' read -r command_id check_path; do
            [[ -z "${command_id:-}" || -z "${check_path:-}" ]] && continue
            has_checks=true

            if [[ -e "$ROOT_DIR/$check_path" ]]; then
                setup_ok+=("$setup_name:$command_id -> $check_path")
            else
                setup_missing+=("$setup_name:$command_id -> $check_path")
            fi
        done < <(read_setup_checks "$setup_file")

        if [[ "$has_checks" != "true" ]]; then
            warnings+=("Setup file has no checks to verify: $setup_name")
        fi
    done < <({
        find "$ROOT_DIR/plugins" -mindepth 3 -maxdepth 3 -name setup.yaml -print 2>/dev/null
        find "$ROOT_DIR/themes" -mindepth 2 -maxdepth 2 -name setup.yaml -print 2>/dev/null
    } | sort)
}

confirm_setup_checks() {
    local input

    if (( ${#setup_missing[@]} == 0 )); then
        return 0
    fi

    printf "${YELLOW}Setup checks chưa đạt:${NC}\n"
    printf ' - %s\n' "${setup_missing[@]}"

    if [[ "$INTERACTIVE_ASSETS" != "true" || ! -t 0 ]]; then
        printf "\n"
        printf "${GREEN}INFO: Tiếp tục build với setup checks chưa đạt.${NC}\n"
        return 0
    fi

    printf "\n"
    printf "Bạn có muốn chạy php artisan hippo:setup --phase=build không? [Y/n]\n"
    printf "Tự tiếp tục build sau %ss nếu không nhập gì: " "$SETUP_TIMEOUT"

    if ! read -r -t "$SETUP_TIMEOUT" input; then
        printf "\n${GREEN}INFO: Tiếp tục build với setup checks chưa đạt.${NC}\n"
        return 0
    fi

    input="${input//[[:space:]]/}"

    if [[ -z "$input" || "$input" == "y" || "$input" == "Y" || "$input" == "yes" || "$input" == "YES" ]]; then
        printf "${GREEN}INFO: Chạy setup build phase.${NC}\n"
        (cd "$ROOT_DIR" && php artisan hippo:setup --phase=build)

        scan_setup_checks

        if (( ${#setup_missing[@]} > 0 )); then
            printf "${YELLOW}Setup checks vẫn chưa đạt sau khi chạy setup:${NC}\n"
            printf ' - %s\n' "${setup_missing[@]}"
            printf "${GREEN}INFO: Tiếp tục build với setup checks chưa đạt.${NC}\n"
        fi

        return 0
    fi

    if [[ "$input" == "n" || "$input" == "N" || "$input" == "no" || "$input" == "NO" ]]; then
        printf "${GREEN}INFO: Tiếp tục build với setup checks chưa đạt.${NC}\n"
        return 0
    fi

    printf "${YELLOW}Không hiểu lựa chọn '%s'. Tiếp tục build với setup checks chưa đạt.${NC}\n" "$input"
}

require_dockerignore() {
    local pattern="$1"
    if ! grep -Fxq "$pattern" "$ROOT_DIR/.dockerignore"; then
        errors+=(".dockerignore must contain: $pattern")
    fi
}

confirm_missing_assets() {
    local input
    local selected
    local n
    local theme
    local missing_not_selected=()
    local selected_map=()

    if (( ${#asset_missing[@]} == 0 )); then
        return 0
    fi

    printf "${YELLOW}Theme thiếu production assets:${NC}\n"
    for i in "${!asset_missing[@]}"; do
        printf ' %d. %s\n' "$((i + 1))" "${asset_missing[$i]}"
    done

    if [[ "$INTERACTIVE_ASSETS" != "true" || ! -t 0 ]]; then
        printf "\n"
        printf "${GREEN}Tiếp tục build với các cảnh báo trên.${NC}\n"
        return 0
    fi

    printf "\n"
    printf "Nhấn Enter để tiếp tục tất cả, nhập số để xác nhận từng theme, hoặc nhập q để dừng.\n"
    printf "Tự tiếp tục tất cả sau %ss: " "$ASSET_TIMEOUT"

    if ! read -r -t "$ASSET_TIMEOUT" input; then
        printf "\nHết thời gian chờ; tiếp tục tất cả theme thiếu assets.\n"
        return 0
    fi

    input="${input//[[:space:]]/}"
    if [[ -z "$input" ]]; then
        printf "Tiếp tục tất cả theme thiếu assets.\n"
        return 0
    fi

    if [[ "$input" == "q" || "$input" == "Q" || "$input" == "no" || "$input" == "NO" ]]; then
        printf "${RED}Dừng build theo lựa chọn của bạn.${NC}\n" >&2
        exit 1
    fi

    IFS=',' read -r -a selected <<< "$input"
    for n in "${selected[@]}"; do
        if [[ ! "$n" =~ ^[0-9]+$ || "$n" -lt 1 || "$n" -gt "${#asset_missing[@]}" ]]; then
            printf "${RED}Số theme không hợp lệ: %s${NC}\n" "$n" >&2
            exit 1
        fi
        selected_map[$((n - 1))]=1
    done

    for i in "${!asset_missing[@]}"; do
        if [[ "${selected_map[$i]:-}" != "1" ]]; then
            missing_not_selected+=("${asset_missing[$i]}")
        fi
    done

    if (( ${#missing_not_selected[@]} > 0 )); then
        printf "${RED}Dừng build vì còn theme thiếu assets chưa được xác nhận:${NC}\n" >&2
        printf ' - %s\n' "${missing_not_selected[@]}" >&2
        exit 1
    fi

    printf "Đã xác nhận tiếp tục với theme thiếu assets: "
    for theme in "${asset_missing[@]}"; do
        printf "%s " "$theme"
    done
    printf "\n"
}

read_manifest() {
    php -r '
        $file = $argv[1];
        $lines = file($file, FILE_IGNORE_NEW_LINES);
        $section = null;
        $item = null;
        $items = [];
        $flush = function () use (&$items, &$item, &$section) {
            if ($section && is_array($item) && isset($item["folder"], $item["repo"], $item["branch"])) {
                $required = $item["required"] ?? "true";
                $items[] = [$section, $item["folder"], $item["repo"], $item["branch"], $required];
            }
            $item = null;
        };
        foreach ($lines as $line) {
            $trim = trim($line);
            if ($trim === "" || str_starts_with($trim, "#")) {
                continue;
            }
            if ($trim === "plugins:" || $trim === "themes:") {
                $flush();
                $section = rtrim($trim, ":");
                continue;
            }
            if (preg_match("/^- folder:\\s*(.+)$/", $trim, $m)) {
                $flush();
                $item = ["folder" => trim($m[1], "\"'\''")];
                continue;
            }
            if (preg_match("/^(repo|branch|required):\\s*(.+)$/", $trim, $m) && is_array($item)) {
                $item[$m[1]] = trim($m[2], "\"'\''");
            }
        }
        $flush();
        foreach ($items as $entry) {
            echo implode("\t", $entry), PHP_EOL;
        }
    ' "$MANIFEST_FILE"
}

read_setup_checks() {
    local setup_file="$1"

    php -r '
        $file = $argv[1];
        $lines = file($file, FILE_IGNORE_NEW_LINES);
        $command = null;
        $inChecks = false;

        foreach ($lines as $line) {
            $trim = trim($line);
            if ($trim === "" || str_starts_with($trim, "#")) {
                continue;
            }

            if (preg_match("/^- id:\\s*(.+)$/", $trim, $m)) {
                $command = trim($m[1], "\"'\''");
                $inChecks = false;
                continue;
            }

            if ($trim === "checks:" && $command) {
                $inChecks = true;
                continue;
            }

            if ($inChecks && preg_match("/^-\\s*path:\\s*(.+)$/", $trim, $m)) {
                $path = trim($m[1], "\"'\''");
                echo $command, "\t", $path, PHP_EOL;
                continue;
            }

            if ($inChecks && !preg_match("/^\\s*-/", $line) && !preg_match("/^\\s+path:/", $line)) {
                $inChecks = false;
            }
        }
    ' "$setup_file"
}

require_file composer.json
require_file composer.lock
require_file docker/Dockerfile
require_file .dockerignore
require_file config/hippo/core/config.example.php
require_file config/hippo/core/ckfinder.example.php
require_file config/hippo-repos.yaml

if [[ -f "$ROOT_DIR/composer.json" ]]; then
    php -r 'json_decode(file_get_contents($argv[1])); if (json_last_error()) { fwrite(STDERR, json_last_error_msg().PHP_EOL); exit(1); }' "$ROOT_DIR/composer.json" \
        || errors+=("composer.json is not valid JSON")
fi

if [[ -f "$ROOT_DIR/composer.lock" ]]; then
    php -r 'json_decode(file_get_contents($argv[1])); if (json_last_error()) { fwrite(STDERR, json_last_error_msg().PHP_EOL); exit(1); }' "$ROOT_DIR/composer.lock" \
        || errors+=("composer.lock is not valid JSON")
fi

require_dockerignore ".env"
require_dockerignore ".env.*"
require_dockerignore "config/hippo/core/config.php"
require_dockerignore "config/hippo/core/ckfinder.php"
require_dockerignore "vendor"
require_dockerignore "storage"
require_dockerignore "**/.git"
require_dockerignore "**/node_modules"
require_dockerignore "**/docs"

if [[ -f "$MANIFEST_FILE" ]]; then
    missing_repos=()
    while IFS=$'\t' read -r type folder url branch required; do
        [[ -z "${type:-}" ]] && continue
        [[ "${required:-true}" == "false" ]] && continue

        if [[ "$type" == "plugins" ]]; then
            path="plugins/hippo/$folder"
            required="$path/Plugin.php"
        else
            path="themes/$folder"
            required="$path/theme.yaml"
        fi

        if [[ ! -d "$ROOT_DIR/$path" || ! -f "$ROOT_DIR/$required" ]]; then
            missing_repos+=("$type/$folder")
        fi
    done < <(read_manifest)

    if (( ${#missing_repos[@]} > 0 )); then
        printf "${YELLOW}Missing plugin/theme source. Running clone script...${NC}\n"
        "$ROOT_DIR/scripts/clone_hippo_repos.sh"
    fi

    while IFS=$'\t' read -r type folder url branch required; do
        [[ -z "${type:-}" ]] && continue
        [[ "${required:-true}" == "false" ]] && continue

        if [[ "$type" == "plugins" ]]; then
            path="plugins/hippo/$folder"
            required="$path/Plugin.php"
        else
            path="themes/$folder"
            required="$path/theme.yaml"
        fi

        if [[ ! -f "$ROOT_DIR/$required" ]]; then
            errors+=("Missing required $type source after clone: $required")
        fi
    done < <(read_manifest)
fi

while IFS= read -r package_file; do
    theme_dir="$(dirname "$package_file")"
    theme_name="$(basename "$theme_dir")"

    if [[ -d "$theme_dir/assets/dist" ]]; then
        asset_ok+=("$theme_name: OK (assets/dist)")
    elif [[ -d "$theme_dir/dist" ]]; then
        asset_ok+=("$theme_name: OK (dist)")
    else
        asset_missing+=("$theme_name")
        warnings+=("Theme '$theme_name' có package.json nhưng chưa thấy assets production (assets/dist hoặc dist). Docker sẽ copy nguyên theme hiện tại vào image, không tự build Vite.")
    fi
done < <(find "$ROOT_DIR/themes" -mindepth 2 -maxdepth 2 -name package.json -print 2>/dev/null | sort)

scan_setup_checks

if (( ${#asset_ok[@]} > 0 )); then
    printf "${GREEN}Theme production assets:${NC}\n"
    printf ' - %s\n' "${asset_ok[@]}"
fi

if (( ${#setup_ok[@]} > 0 )); then
    printf "${GREEN}Setup checks:${NC}\n"
    printf ' - %s\n' "${setup_ok[@]}"
fi

if (( ${#errors[@]} > 0 )); then
    printf "${RED}Preflight failed:${NC}\n" >&2
    printf ' - %s\n' "${errors[@]}" >&2
    exit 1
fi

if (( ${#warnings[@]} > 0 )); then
    printf "${YELLOW}Preflight warnings:${NC}\n"
    printf ' - %s\n' "${warnings[@]}"
fi

confirm_setup_checks
confirm_missing_assets

printf "${GREEN}Preflight build: OK${NC}\n"
