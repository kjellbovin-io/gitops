#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERS_FILE="$ROOT_DIR/vendor-versions.env"

if [[ ! -f "$VERS_FILE" ]]; then
  echo "ERROR: $VERS_FILE not found. Create it and set versions." >&2
  exit 1
fi

# Load versions
# shellcheck disable=SC1090
source "$VERS_FILE"

: "${ARGOCD_CHART_VERSION:?Set ARGOCD_CHART_VERSION in vendor-versions.env}"
: "${METALLB_CHART_VERSION:?Set METALLB_CHART_VERSION in vendor-versions.env}"

command -v helm >/dev/null 2>&1 || { echo "ERROR: helm not found in PATH"; exit 1; }

TMP_DIR="$ROOT_DIR/.tmp"
ARGOC_VENDOR_DIR="$ROOT_DIR/argocd/vendor"
MLB_VENDOR_DIR="$ROOT_DIR/metallb/vendor"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT
mkdir -p "$TMP_DIR" "$ARGOC_VENDOR_DIR" "$MLB_VENDOR_DIR"

echo "[i] Using versions:"
echo "    ARGOCD_CHART_VERSION=${ARGOCD_CHART_VERSION}"
echo "    METALLB_CHART_VERSION=${METALLB_CHART_VERSION}"

echo "[i] Adding Helm repos and updating index..."
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo add metallb https://metallb.github.io/metallb >/dev/null
helm repo update >/dev/null

echo "[i] Vendoring Argo CD chart ${ARGOCD_CHART_VERSION} ..."
rm -rf "$TMP_DIR/argocd" && mkdir -p "$TMP_DIR/argocd"
helm pull argo/argo-cd --version "$ARGOCD_CHART_VERSION" --untar --untardir "$TMP_DIR/argocd"
test -f "$TMP_DIR/argocd/argo-cd/Chart.yaml" || { echo "ERROR: Argo CD chart missing"; exit 1; }
rm -rf "$ARGOC_VENDOR_DIR/argo-cd-$ARGOCD_CHART_VERSION"
mv "$TMP_DIR/argocd/argo-cd" "$ARGOC_VENDOR_DIR/argo-cd-$ARGOCD_CHART_VERSION"
ln -sfn "argo-cd-$ARGOCD_CHART_VERSION" "$ARGOC_VENDOR_DIR/argo-cd"   # stable symlink

echo "[i] Vendoring MetalLB chart ${METALLB_CHART_VERSION} ..."
rm -rf "$TMP_DIR/metallb" && mkdir -p "$TMP_DIR/metallb"
helm pull metallb/metallb --version "$METALLB_CHART_VERSION" --untar --untardir "$TMP_DIR/metallb"
test -f "$TMP_DIR/metallb/metallb/Chart.yaml" || { echo "ERROR: MetalLB chart missing"; exit 1; }
rm -rf "$MLB_VENDOR_DIR/metallb-$METALLB_CHART_VERSION"
mv "$TMP_DIR/metallb/metallb" "$MLB_VENDOR_DIR/metallb-$METALLB_CHART_VERSION"
ln -sfn "metallb-$METALLB_CHART_VERSION" "$MLB_VENDOR_DIR/metallb"     # stable symlink

echo "[✓] Vendoring complete:"
echo " - $ARGOC_VENDOR_DIR/argo-cd-$ARGOCD_CHART_VERSION  (symlink: vendor/argo-cd)"
echo " - $MLB_VENDOR_DIR/metallb-$METALLB_CHART_VERSION   (symlink: vendor/metallb)"
