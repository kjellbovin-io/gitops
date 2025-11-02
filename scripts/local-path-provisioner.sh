#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load central versions file
source "${SCRIPT_DIR}/vendor-versions.env"

CHART_NAME="local-path-provisioner"
HELM_REPO_NAME="containeroo"
HELM_REPO_URL="https://charts.containeroo.ch"
CHART_VERSION="${LOCAL_PATH_PROVISIONER_CHART_VERSION:-0.0.33}"

OUT_BASE="${ROOT_DIR}/${CHART_NAME}/vendor"
OUT_DIR="${OUT_BASE}/${CHART_NAME}-${CHART_VERSION}"

log(){ printf "\033[1;34m[i]\033[0m %s\n" "$*"; }
ok(){  printf "\033[1;32m[✓]\033[0m %s\n" "$*"; }

[[ -d "$OUT_DIR" ]] && { ok "${CHART_NAME} -> ${OUT_DIR} (already vendored)"; exit 0; }

mkdir -p "$OUT_BASE"
helm repo list | grep -q "^${HELM_REPO_NAME}\b" || helm repo add "${HELM_REPO_NAME}" "${HELM_REPO_URL}" >/dev/null
helm repo update >/dev/null

TMPDIR="$(mktemp -d)"; trap 'rm -rf "$TMPDIR"' EXIT
log "Vendoring ${HELM_REPO_NAME}/${CHART_NAME} ${CHART_VERSION} -> ${OUT_DIR}"
helm pull "${HELM_REPO_NAME}/${CHART_NAME}" --version "${CHART_VERSION}" --untar -d "${TMPDIR}" >/dev/null
mv "${TMPDIR}/${CHART_NAME}" "${OUT_DIR}"
ok "${CHART_NAME} -> ${OUT_DIR}"
