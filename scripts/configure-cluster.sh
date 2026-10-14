#!/usr/bin/env bash
# Renders the __PLACEHOLDERS__ in gitops/ for one environment from Terraform
# outputs. None of these values are secrets (client IDs, URLs); commit the result.
#
# Usage: DOMAIN=dev.example.com ACME_EMAIL=me@example.com scripts/configure-cluster.sh dev
set -euo pipefail

ENV="${1:?usage: $0 <dev|prod>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${DOMAIN:?set DOMAIN (e.g. dev.example.com)}"
: "${ACME_EMAIL:?set ACME_EMAIL (ACME account email for Lets Encrypt)}"

for bin in terraform jq az; do
  command -v "$bin" >/dev/null || { echo "missing dependency: $bin" >&2; exit 1; }
done

OUT="$(terraform -chdir="$ROOT/terraform/envs/$ENV" output -json platform)"
get() { jq -er ".$1" <<<"$OUT"; }

declare -A VALUES=(
  [__DOMAIN__]="$DOMAIN"
  [__ACME_EMAIL__]="$ACME_EMAIL"
  [__VAULT_URL__]="$(get key_vault_uri)"
  [__ESO_CLIENT_ID__]="$(get external_secrets_client_id)"
  [__CLOUDSWEEP_CLIENT_ID__]="$(get cloudsweep_client_id)"
  [__ACR_LOGIN_SERVER__]="$(get acr_login_server)"
  [__SUBSCRIPTION_ID__]="$(az account show --query id -o tsv)"
)

mapfile -t FILES < <(grep -rl "__[A-Z_]*__" \
  "$ROOT/gitops/clusters/$ENV" \
  "$ROOT/gitops/apps/demo-api/values-$ENV.yaml" || true)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "nothing to render: gitops/clusters/$ENV is already configured"
  exit 0
fi

for f in "${FILES[@]}"; do
  for key in "${!VALUES[@]}"; do
    sed -i.bak "s|${key}|${VALUES[$key]}|g" "$f" && rm -f "$f.bak"
  done
  echo "rendered ${f#"$ROOT"/}"
done

if grep -n "__[A-Z_]*__" "${FILES[@]}"; then
  echo "WARNING: unresolved placeholders above" >&2
  exit 1
fi

echo
echo "GitHub (secure-cicd-golden-path) -> environment '$ENV' variables:"
echo "  AZURE_CLIENT_ID       = $(get github_ci_client_id)"
echo "  AZURE_TENANT_ID       = $(get tenant_id)"
echo "  AZURE_SUBSCRIPTION_ID = ${VALUES[__SUBSCRIPTION_ID__]}"
echo "  ACR_LOGIN_SERVER      = ${VALUES[__ACR_LOGIN_SERVER__]}"
echo
echo "Review with 'git diff', commit, and push: Argo CD picks it up from there."
