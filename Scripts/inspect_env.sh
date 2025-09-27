#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-release}"
BINARY=".build/${CONFIGURATION}/kubex"

if [[ ! -x "${BINARY}" ]]; then
  echo "error: ${BINARY} not found or not executable" >&2
  exit 1
fi

PATH_DUMP=$(PATH="${PATH}" "${BINARY}" --env-dump PATH)

cat <<REPORT
Kubex computed PATH:
${PATH_DUMP}

First plugin lookup:
$(PATH="${PATH}" command -v gke-gcloud-auth-plugin || echo "(not found in current shell PATH)")
REPORT
