#!/bin/bash
set -euo pipefail

propagate_env() {
  [[ -z "${BUILDKITE_ENV_FILE:-}" ]] && return
  local var
  for var in "$@"; do
    echo "${var}=${!var}" >> "$BUILDKITE_ENV_FILE"
  done
}
