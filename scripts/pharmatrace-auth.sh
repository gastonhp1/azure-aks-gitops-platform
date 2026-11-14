#!/usr/bin/env bash
# The PharmaTrace API's login and PharmaBox unlock material, as the Secret its Deployment mounts
# (charts/pharmatrace: backend.authSecret). Never in git.
#
#   scripts/pharmatrace-auth.sh init                      create what is missing, keep what exists
#   scripts/pharmatrace-auth.sh user add <user> <MSP>     asks for the password (or USER_PASSWORD)
#   scripts/pharmatrace-auth.sh user remove <user>
#   scripts/pharmatrace-auth.sh user list
#   scripts/pharmatrace-auth.sh pubkey                    the unlock public key, for the firmware
#
# Keys: session-secret (HS256 for the sessions), unlock-key.pem (ECDSA P-256 that signs unlock
# tokens) and users.json (scrypt hashes, managed with the Pharmatrace repo's backend/scripts/user.js).
# init never rotates an existing key: that would log everyone out / orphan the boxes' public key.
set -euo pipefail

PHARMATRACE=${PHARMATRACE:-../Pharmatrace}
NAMESPACE=${NAMESPACE:-pharmatrace}
SECRET=${SECRET:-pharmatrace-auth}
BACKEND=$(cd "$PHARMATRACE/backend" && pwd)

[[ -d $BACKEND/node_modules ]] || { echo "error: run 'npm ci' in $BACKEND first" >&2; exit 1; }

work=$(mktemp -d)
chmod 700 "$work"
trap 'rm -rf "$work"' EXIT

# Pulls the current entries into $work (missing ones are just absent).
fetch() {
  local json
  json=$(kubectl -n "$NAMESPACE" get secret "$SECRET" -o json 2>/dev/null) || return 0
  for key in session-secret unlock-key.pem users.json; do
    jq -er --arg k "$key" '.data[$k] // empty' <<<"$json" | base64 -d >"$work/$key" || rm -f "$work/$key"
  done
}

store() {
  kubectl -n "$NAMESPACE" create secret generic "$SECRET" \
    --from-file="session-secret=$work/session-secret" \
    --from-file="unlock-key.pem=$work/unlock-key.pem" \
    --from-file="users.json=$work/users.json" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
}

# The backend's scripts need Node >= 18 (it runs on node:22): the local one if recent enough,
# otherwise the same image in Docker, with the same paths mounted.
NODE_IMAGE=${NODE_IMAGE:-node:22-slim}
node_() {
  local major
  major=$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)
  if (( major >= 18 )); then
    (cd "$BACKEND" && node "$@")
  else
    local tty=(-i); [[ -t 0 ]] && tty+=(-t)
    docker run --rm "${tty[@]}" --user "$(id -u):$(id -g)" -e USERS_FILE -e USER_PASSWORD \
      -v "$BACKEND:$BACKEND:ro" -v "$work:$work" -w "$BACKEND" "$NODE_IMAGE" node "$@"
  fi
}

users() { USERS_FILE="$work/users.json" node_ scripts/user.js "$@"; }

cmd=${1:-}
case $cmd in
  init)
    fetch
    created=()
    if [[ ! -s $work/session-secret ]]; then
      openssl rand -base64 48 | tr -d '\n' >"$work/session-secret"; created+=(session-secret)
    fi
    if [[ ! -s $work/unlock-key.pem ]]; then
      node_ scripts/unlock-key.js generate "$work/unlock-key.pem" >/dev/null; created+=(unlock-key.pem)
    fi
    if [[ ! -s $work/users.json ]]; then
      echo '{ "users": [] }' >"$work/users.json"; created+=(users.json)
    fi
    store
    echo "ok: secret $NAMESPACE/$SECRET (created: ${created[*]:-nothing, all kept})"
    if [[ " ${created[*]} " == *" unlock-key.pem "* ]]; then
      echo ">> new unlock key: '$0 pubkey' prints it for the firmware"
    fi
    ;;
  user)
    kubectl -n "$NAMESPACE" get secret "$SECRET" >/dev/null || { echo "error: run '$0 init' first" >&2; exit 1; }
    fetch
    shift
    users "$@"
    [[ ${1:-} == list ]] || { store; echo "ok: users updated (the API picks them up within ~1 min)"; }
    ;;
  pubkey)
    fetch
    [[ -s $work/unlock-key.pem ]] || { echo "error: no unlock key yet, run '$0 init'" >&2; exit 1; }
    node_ scripts/unlock-key.js public "$work/unlock-key.pem"
    ;;
  *)
    sed -n '5,9p' "$0" | sed 's/^# //' >&2
    exit 2
    ;;
esac
