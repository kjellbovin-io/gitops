#!/usr/bin/env bash
set -euo pipefail

# --- locate repo roots ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# --- load central versions file ---
if [[ -f "${SCRIPT_DIR}/vendor-versions.env" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/vendor-versions.env"
else
  echo "[✗] vendor-versions.env not found next to this script" >&2
  exit 1
fi

# --- settings ---
CHART_NAME="elasticsearch"
HELM_REPO_NAME="elastic"
HELM_REPO_URL="https://helm.elastic.co"
CHART_VERSION="${ELASTICSEARCH_CHART_VERSION:-8.5.1}"

OUT_BASE="${ROOT_DIR}/${CHART_NAME}/vendor"
OUT_DIR="${OUT_BASE}/${CHART_NAME}-${CHART_VERSION}"

log() { printf "\033[1;34m[i]\033[0m %s\n" "$*"; }
ok()  { printf "\033[1;32m[✓]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[✗]\033[0m %s\n" "$*" 1>&2; }

# idempotent
if [[ -d "$OUT_DIR" ]]; then
  ok "${CHART_NAME} -> ${OUT_DIR} (already vendored)"
  exit 0
fi

mkdir -p "$OUT_BASE"

# add & update repo
if ! helm repo list | grep -q "^${HELM_REPO_NAME}\b" ; then
  log "Adding Helm repo ${HELM_REPO_NAME}"
  helm repo add "${HELM_REPO_NAME}" "${HELM_REPO_URL}" >/dev/null
fi
log "Updating Helm repos"
helm repo update >/dev/null

# pull and stage
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

log "Vendoring ${HELM_REPO_NAME}/${CHART_NAME} ${CHART_VERSION} -> ${OUT_DIR}"
helm pull "${HELM_REPO_NAME}/${CHART_NAME}" --version "${CHART_VERSION}" --untar -d "${TMPDIR}" >/dev/null
mv "${TMPDIR}/${CHART_NAME}" "${OUT_DIR}"
ok "${CHART_NAME} -> ${OUT_DIR}"
