#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Compile Vite packages ở chế độ production.

Usage:
  ./scripts/vite-compile-production.sh [--config <file>] [--auto] [--dry-run] [--no-select] [--timeout <seconds>]

Behavior:
  - Mặc định đọc danh sách package từ file .vite-packages.production (nếu có)
  - Nếu không có file config, tự động lấy package active từ: php artisan vite:list --json
  - Mỗi package sẽ chạy: php artisan vite:compile -p <package> --production

Examples:
  ./scripts/vite-compile-production.sh
  ./scripts/vite-compile-production.sh --config .vite-packages.production
  ./scripts/vite-compile-production.sh --auto
  ./scripts/vite-compile-production.sh --dry-run
  ./scripts/vite-compile-production.sh --timeout 90
USAGE
}

CONFIG_FILE=".vite-packages.production"
FORCE_AUTO="false"
DRY_RUN="false"
ENABLE_SELECT="true"
PROMPT_TIMEOUT="60"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="${2:-}"
      if [[ -z "$CONFIG_FILE" ]]; then
        echo "Thiếu giá trị cho --config" >&2
        exit 1
      fi
      shift 2
      ;;
    --auto)
      FORCE_AUTO="true"
      shift
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --no-select)
      ENABLE_SELECT="false"
      shift
      ;;
    --timeout)
      PROMPT_TIMEOUT="${2:-}"
      if ! [[ "$PROMPT_TIMEOUT" =~ ^[0-9]+$ ]]; then
        echo "Giá trị --timeout phải là số nguyên giây." >&2
        exit 1
      fi
      shift 2
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

if ! command -v php >/dev/null 2>&1; then
  echo "Không tìm thấy php command." >&2
  exit 1
fi

if [[ ! -f artisan ]]; then
  echo "Không tìm thấy file artisan. Hãy chạy script từ root project." >&2
  exit 1
fi

echo "==> Lấy danh sách Vite packages từ artisan"
vite_json="$(php artisan vite:list --json)"

declare -a active_packages=()
while IFS= read -r pkg; do
  [[ -z "$pkg" ]] && continue
  active_packages+=("$pkg")
done < <(
  php -r '
    $json = stream_get_contents(STDIN);
    $rows = json_decode($json, true);
    if (!is_array($rows)) {
      fwrite(STDERR, "Không parse được JSON từ vite:list --json\n");
      exit(1);
    }
    foreach ($rows as $row) {
      if (!empty($row["active"]) && !empty($row["name"])) {
        echo $row["name"] . PHP_EOL;
      }
    }
  ' <<< "$vite_json"
)

if [[ ${#active_packages[@]} -eq 0 ]]; then
  echo "Không có Vite package active nào." >&2
  exit 1
fi

declare -a selected_packages=()

if [[ "$FORCE_AUTO" == "false" && -f "$CONFIG_FILE" ]]; then
  echo "==> Dùng danh sách package từ config: $CONFIG_FILE"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    [[ "${line:0:1}" == "#" ]] && continue
    selected_packages+=("$line")
  done < "$CONFIG_FILE"
else
  if [[ "$FORCE_AUTO" == "true" ]]; then
    echo "==> --auto: bỏ qua config file, dùng toàn bộ package active"
  else
    echo "==> Không có config file, dùng toàn bộ package active"
  fi
  selected_packages=("${active_packages[@]}")
fi

if [[ ${#selected_packages[@]} -eq 0 ]]; then
  echo "Danh sách package cần compile đang trống." >&2
  exit 1
fi

declare -a compile_list=()
declare -a skipped_list=()

is_active_package() {
  local needle="$1"
  local item
  for item in "${active_packages[@]}"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

for pkg in "${selected_packages[@]}"; do
  if is_active_package "$pkg"; then
    compile_list+=("$pkg")
  else
    skipped_list+=("$pkg")
  fi
done

if [[ ${#skipped_list[@]} -gt 0 ]]; then
  echo "==> Bỏ qua package không active/không tồn tại:"
  for pkg in "${skipped_list[@]}"; do
    echo " - $pkg"
  done
fi

if [[ ${#compile_list[@]} -eq 0 ]]; then
  echo "Không còn package hợp lệ để compile." >&2
  exit 1
fi

echo "==> Sẽ compile production cho ${#compile_list[@]} package(s):"
for pkg in "${compile_list[@]}"; do
  echo " - $pkg"
done

declare -a final_compile_list=("${compile_list[@]}")

if [[ "$ENABLE_SELECT" == "true" && -t 0 && -t 1 ]]; then
  echo
  echo "==> Chọn package cần compile:"
  i=1
  for pkg in "${compile_list[@]}"; do
    echo "  $i) $pkg"
    i=$((i + 1))
  done
  echo
  echo "Nhập 'all' hoặc danh sách số (vd: 1,2,5,6)."
  echo "Để trống trong ${PROMPT_TIMEOUT}s sẽ tự động chọn ALL."
  printf "> "

  user_input=""
  if ! IFS= read -r -t "$PROMPT_TIMEOUT" user_input; then
    user_input=""
  fi

  user_input="${user_input#"${user_input%%[![:space:]]*}"}"
  user_input="${user_input%"${user_input##*[![:space:]]}"}"

  if [[ -z "$user_input" || "$user_input" == "all" || "$user_input" == "ALL" || "$user_input" == "a" || "$user_input" == "A" ]]; then
    final_compile_list=("${compile_list[@]}")
    echo "==> Chọn ALL"
  else
    normalized="$(echo "$user_input" | tr -d ' ' | tr ';' ',' | tr ':' ',' )"
    IFS=',' read -r -a tokens <<< "$normalized"

    declare -a chosen=()
    seen=","
    total="${#compile_list[@]}"
    for token in "${tokens[@]}"; do
      [[ -z "$token" ]] && continue
      if ! [[ "$token" =~ ^[0-9]+$ ]]; then
        echo "Input không hợp lệ: $token" >&2
        exit 1
      fi
      if (( token < 1 || token > total )); then
        echo "Index ngoài phạm vi: $token (1..$total)" >&2
        exit 1
      fi
      if [[ "$seen" == *",$token,"* ]]; then
        continue
      fi
      seen="${seen}${token},"
      chosen+=("${compile_list[$((token - 1))]}")
    done

    if [[ ${#chosen[@]} -eq 0 ]]; then
      echo "Không có package hợp lệ được chọn." >&2
      exit 1
    fi
    final_compile_list=("${chosen[@]}")
    echo "==> Đã chọn ${#final_compile_list[@]} package"
  fi
elif [[ "$ENABLE_SELECT" == "true" ]]; then
  echo "==> Non-interactive shell: tự động chọn ALL packages."
fi

echo
echo "==> Danh sách compile cuối cùng (${#final_compile_list[@]}):"
for pkg in "${final_compile_list[@]}"; do
  echo " - $pkg"
done

if [[ "$DRY_RUN" == "true" ]]; then
  echo "==> DRY RUN: không thực thi compile."
  exit 0
fi

for pkg in "${final_compile_list[@]}"; do
  echo "==> Compile: $pkg"
  php artisan vite:compile -p "$pkg" --production
done

echo "Hoàn tất compile production Vite packages."
