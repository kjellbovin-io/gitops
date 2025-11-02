#!/usr/bin/env bash
set -euo pipefail

# Repo root (two dirs up from this file)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$ROOT_DIR/.tmp"
VERS_FILE="vendor-versions.env"

[[ -f "$VERS_FILE" ]] || { echo "ERROR: $VERS_FILE not found"; exit 1; }
# shellcheck disable=SC1090
source "$VERS_FILE"

mkdir -p "$TMP_DIR"

# Add a Helm repo if missing; keep output quiet and idempotent
helm_repo() {
  local name="$1" url="$2"
  helm repo add "$name" "$url" >/dev/null 2>&1 || true
}

helm_update() {
  helm repo update >/dev/null
}

# Vendor a chart into <app>/vendor/<chart>-<version>
# usage: vendor_chart <repo/name> <version> <dest_app_dir> <final_dir_name>
vendor_chart() {
  local chart="$1" version="$2" app_dir="$3" final_name="$4"
  local dest_dir="$ROOT_DIR/$app_dir/vendor"
  local work="$TMP_DIR/${final_name}"

  mkdir -p "$dest_dir"
  rm -rf "$work" && mkdir -p "$work"

  echo "[i] Vendoring ${chart} ${version} -> ${app_dir}/vendor/${final_name}-${version}"
  helm pull "$chart" --version "$version" --untar --untardir "$work"

  # The untarred dir is the last path component of the chart (after '/')
  local base="${chart##*/}"

  rm -rf "$dest_dir/${final_name}-${version}"
  mv "$work/$base" "$dest_dir/${final_name}-${version}"
  rm -rf "$work"
}
