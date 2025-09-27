#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION=${1:-release}
BINARY=".build/${CONFIGURATION}/kubex"

if [[ ! -x "${BINARY}" ]]; then
  echo "error: ${BINARY} not found" >&2
  exit 1
fi

"${BINARY}" --env-dump PATH SHELL HOME
echo "---"
command -v gke-gcloud-auth-plugin || echo "plugin not found"
