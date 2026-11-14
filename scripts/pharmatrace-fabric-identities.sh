#!/usr/bin/env bash
# Stores the PharmaTrace API's Fabric identities as the Secret its Deployment mounts
# (charts/pharmatrace: fabric.identitiesSecret), from the material the network's PKI issued.
#
#   scripts/pharmatrace-fabric-identities.sh <Pharmatrace>/fabric/network/organizations
#
# Keys: <org>.tlsca.crt (the TLS CA of the org's peer) and <org>.<User>.cert.pem / .key.pem for every
# client user of each org (User1, IotGateway...). Admins are left out: the API never acts as one.
# The private keys only exist in that folder and in this Secret, never in git.
set -euo pipefail

ORGS_DIR=${1:?usage: $0 <path to fabric/network/organizations>}
NAMESPACE=${NAMESPACE:-pharmatrace}
SECRET=${SECRET:-pharmatrace-fabric-identities}

args=()
for org in lab dist farma reg; do
  d="$org.pharmatrace.ar"
  base="$ORGS_DIR/peerOrganizations/$d"
  [[ -d $base ]] || { echo "error: $base not found (has the network been bootstrapped?)" >&2; exit 1; }
  args+=(--from-file="$org.tlsca.crt=$base/peers/peer0.$d/tls/ca.crt")
  for msp in "$base"/users/*@"$d"/msp; do
    user=$(basename "$(dirname "$msp")")
    user=${user%@*}
    [[ $user == Admin ]] && continue
    args+=(--from-file="$org.$user.cert.pem=$(find "$msp/signcerts" -type f | head -1)")
    args+=(--from-file="$org.$user.key.pem=$(find "$msp/keystore" -type f | head -1)")
  done
done

kubectl -n "$NAMESPACE" create secret generic "$SECRET" "${args[@]}" --dry-run=client -o yaml |
  kubectl apply -f - >/dev/null
echo "ok: secret $NAMESPACE/$SECRET with $(( ${#args[@]} )) entries"
