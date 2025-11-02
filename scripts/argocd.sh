#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

: "${ARGOCD_CHART_VERSION:?Set ARGOCD_CHART_VERSION in vendor-versions.env}"

helm_repo argo https://argoproj.github.io/argo-helm
helm_update

vendor_chart "argo/argo-cd" "$ARGOCD_CHART_VERSION" "argocd" "argo-cd"
echo "[✓] Argo CD chart -> argocd/vendor/argo-cd-${ARGOCD_CHART_VERSION}"
