#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   KUBE_STATE_METRICS_CHART_VERSION=6.4.0 ./kube-state-metrics.sh
# or rely on default below.
CHART_VERSION="${KUBE_STATE_METRICS_CHART_VERSION:-6.3.0}"

CHART_NAME="kube-state-metrics"
HELM_REPO_NAME="prometheus-community"
HELM_REPO_URL="https://prometheus-community.github.io/helm-charts"
# OCI registry path for this chart
OCI_URL="oci://ghcr.io/prometheus-community/charts/${CHART_NAME}"

# Repo layout relative to this script
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_BASE="${ROOT_DIR}/${CHART_NAME}/vendor"
OUT_DIR="${OUT_BASE}/${CHART_NAME}-${CHART_VERSION}"

log() { printf "\033[1;34m[i]\033[0m %s\n" "$*"; }
ok()  { printf "\033[1;32m[✓]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[✗]\033[0m %s\n" "$*" 1>&2; }

# Idempotency
if [[ -d "$OUT_DIR" ]]; then
  ok "${CHART_NAME} -> ${OUT_DIR} (already vendored)"
  exit 0
fi

mkdir -p "$OUT_BASE"
TMPDIR="$(mktemp -d)"
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

# Always have the classic repo available for fallback
if ! helm repo list | grep -q "^${HELM_REPO_NAME}\b" ; then
  log "Adding Helm repo ${HELM_REPO_NAME}"
  helm repo add "${HELM_REPO_NAME}" "${HELM_REPO_URL}" >/dev/null
fi
log "Updating Helm repos"
helm repo update >/dev/null

pull_and_stage() {
  local src="$1"   # either oci://... or repo/chart
  log "Pulling ${src} ${CHART_VERSION} -> staging"
  helm pull "$src" --version "${CHART_VERSION}" --untar -d "${TMPDIR}" >/dev/null
  # helm --untar creates ${TMPDIR}/${CHART_NAME}
  if [[ ! -d "${TMPDIR}/${CHART_NAME}" ]]; then
    err "Expected directory ${TMPDIR}/${CHART_NAME} not found after pull"
    return 1
  fi
  mv "${TMPDIR}/${CHART_NAME}" "${OUT_DIR}"
  ok "${CHART_NAME} -> ${OUT_DIR}"
}

# Try OCI first (works for 6.4.0+); fall back to classic repo if not found
log "Vendoring ${HELM_REPO_NAME}/${CHART_NAME} ${CHART_VERSION} -> ${OUT_DIR}"
if pull_and_stage "${OCI_URL}"; then
  exit 0
else
  log "OCI pull failed; trying classic repo index"
  if pull_and_stage "${HELM_REPO_NAME}/${CHART_NAME}"; then
    exit 0
  fi
fi

err "Failed to vendor ${CHART_NAME} ${CHART_VERSION}. Try a different version or check connectivity."
exit 1
