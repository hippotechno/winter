#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_ENV_FILE="$REPO_ROOT/.env"
DOCKER_ENV_FILE="$REPO_ROOT/docker/.env.local"

if [[ ! -f "$DOCKER_ENV_FILE" ]]; then
  DOCKER_ENV_FILE="$REPO_ROOT/docker/.env.local.example"
fi

COMPOSE_FILES=(-f "$REPO_ROOT/docker-compose.local.yml")
COMPOSE_ENV_FILES=()

if [[ -f "$APP_ENV_FILE" ]]; then
  COMPOSE_ENV_FILES+=(--env-file "$APP_ENV_FILE")
fi

if [[ -f "$DOCKER_ENV_FILE" ]]; then
  COMPOSE_ENV_FILES+=(--env-file "$DOCKER_ENV_FILE")
fi

env_value() {
  local key="$1"
  local file="${2:-$DOCKER_ENV_FILE}"

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  awk -F= -v key="$key" '
    $0 ~ "^[[:space:]]*#" { next }
    $1 == key {
      value = substr($0, index($0, "=") + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^"|"$/, "", value)
      gsub(/^'\''|'\''$/, "", value)
      print value
      found = 1
    }
    END { exit found ? 0 : 1 }
  ' "$file"
}

is_enabled() {
  case "${1:-true}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

if [[ -z "${COMPOSE_PROFILES:-}" ]]; then
  profiles=()

  if is_enabled "$(env_value LOCAL_ENABLE_POSTGRES "$DOCKER_ENV_FILE" || echo true)"; then
    profiles+=("local-postgres")
  fi

  if is_enabled "$(env_value LOCAL_ENABLE_REDIS "$DOCKER_ENV_FILE" || echo true)"; then
    profiles+=("local-redis")
  fi

  if (( ${#profiles[@]} > 0 )); then
    COMPOSE_PROFILES="$(IFS=,; echo "${profiles[*]}")"
    export COMPOSE_PROFILES
  fi
fi

if [[ $# -eq 0 ]]; then
  set -- up -d --build
fi

exec docker compose "${COMPOSE_ENV_FILES[@]}" "${COMPOSE_FILES[@]}" "$@"
