#!/usr/bin/env bash
# Installs Argo CD once and hands control to Git (app-of-apps).
# Usage: scripts/bootstrap-argocd.sh <local|dev|prod>
set -euo pipefail

CLUSTER="${1:?usage: $0 <local|dev|prod>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

case "$CLUSTER" in local|dev|prod) ;; *) echo "unknown cluster: $CLUSTER" >&2; exit 1 ;; esac

for bin in kubectl helm envsubst; do
  command -v "$bin" >/dev/null || { echo "missing dependency: $bin" >&2; exit 1; }
done

# Use the same chart version Argo CD will later manage itself with,
# so the first self-sync is a no-op instead of an upgrade.
ARGOCD_CHART_VERSION="$(awk '/chart: argo-cd/{f=1} f && /targetRevision:/{print $2; exit}' "$ROOT/gitops/addons/argocd.yaml")"

echo ">> context: $(kubectl config current-context)"
echo ">> installing argo-cd chart $ARGOCD_CHART_VERSION"

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --version "$ARGOCD_CHART_VERSION" \
  --values "$ROOT/gitops/bootstrap/argocd-values.yaml" \
  --wait --timeout 10m

echo ">> applying root application for cluster '$CLUSTER'"
# shellcheck disable=SC2016 # literal: only substitute ${CLUSTER}
CLUSTER="$CLUSTER" envsubst '${CLUSTER}' < "$ROOT/gitops/bootstrap/root-app.yaml" | kubectl apply -f -

cat <<EOF

Argo CD is up and now reconciling gitops/clusters/$CLUSTER.

  UI:        kubectl -n argocd port-forward svc/argocd-server 8080:80   -> http://localhost:8080
  password:  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
  status:    kubectl -n argocd get applications
EOF
