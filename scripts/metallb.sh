#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

: "${METALLB_CHART_VERSION:?Set METALLB_CHART_VERSION in vendor-versions.env}"

helm_repo metallb https://metallb.github.io/metallb
helm_update

vendor_chart "metallb/metallb" "$METALLB_CHART_VERSION" "metallb" "metallb"
echo "[✓] MetalLB chart -> metallb/vendor/metallb-${METALLB_CHART_VERSION}"
