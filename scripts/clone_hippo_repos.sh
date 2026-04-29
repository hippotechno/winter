#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST_FILE="$ROOT_DIR/config/hippo-repos.yaml"

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

if [[ ! -f "$MANIFEST_FILE" ]]; then
    printf "${RED}Missing repo manifest: %s${NC}\n" "$MANIFEST_FILE" >&2
    exit 1
fi

mkdir -p "$ROOT_DIR/plugins/hippo" "$ROOT_DIR/themes"

read_manifest() {
    php -r '
        $file = $argv[1];
        $lines = file($file, FILE_IGNORE_NEW_LINES);
        $section = null;
        $item = null;
        $items = [];
        $flush = function () use (&$items, &$item, &$section) {
            if ($section && is_array($item) && isset($item["folder"], $item["repo"], $item["branch"])) {
                $items[] = [$section, $item["folder"], $item["repo"], $item["branch"]];
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

clone_repo() {
    local type="$1"
    local folder="$2"
    local url="$3"
    local branch="$4"
    local base_dir target_dir current_url

    if [[ "$type" == "plugins" ]]; then
        base_dir="$ROOT_DIR/plugins/hippo"
    else
        base_dir="$ROOT_DIR/themes"
    fi
    target_dir="$base_dir/$folder"

    if [[ -d "$target_dir/.git" ]]; then
        current_url="$(git -C "$target_dir" remote get-url origin 2>/dev/null || true)"

        if [[ "$current_url" != "$url" ]]; then
            printf "${YELLOW}Skip %s: existing origin is %s, expected %s.${NC}\n" "$target_dir" "${current_url:-unknown}" "$url"
            return
        fi

        printf "${GREEN}Exists:${NC} %s\n" "$target_dir"
        return
    fi

    if [[ -e "$target_dir" ]]; then
        printf "${RED}Skip %s: path exists but is not a git repository.${NC}\n" "$target_dir"
        return
    fi

    printf "Cloning %s (%s) into %s...\n" "$url" "$branch" "$target_dir"
    git clone --branch "$branch" "$url" "$target_dir"
}

while IFS=$'\t' read -r type folder url branch; do
    [[ -z "${type:-}" ]] && continue
    clone_repo "$type" "$folder" "$url" "$branch"
done < <(read_manifest)

echo "All Hippo repositories are available."
