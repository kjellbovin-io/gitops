#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

bash "$DIR/argocd.sh"
bash "$DIR/metallb.sh"
# add more as you grow
# bash "$DIR/kube-state-metrics.sh"
