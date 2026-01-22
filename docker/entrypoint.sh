#!/usr/bin/env bash
set -euo pipefail

DNSTT_PORT="${DNSTT_PORT:-5300}"

# Accept common spellings/casing:
# - NS_SUBDOMAIN (preferred)
# - NS_subdomain (user typo but common)
# - ns_subdomain (less common)
NS_SUBDOMAIN="${NS_SUBDOMAIN:-${NS_subdomain:-${ns_subdomain:-}}}"

MTU_VALUE="${MTU_VALUE:-1232}"

# Tunnel target for dnstt-server (what the tunnel forwards to)
TUNNEL_HOST="${TUNNEL_HOST:-127.0.0.1}"
TUNNEL_PORT="${TUNNEL_PORT:-22}"

# Key paths
KEY_PREFIX="${KEY_PREFIX:-}"
CONFIG_DIR="${CONFIG_DIR:-/etc/dnstt}"

log() { echo "[dnstt] $*"; }
fail() { echo "[dnstt][ERROR] $*" 1>&2; exit 1; }

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    fail "Missing required env var: $name\n\nExamples:\n  docker run -e NS_SUBDOMAIN=t.example.com ...\n  docker compose: set environment: NS_SUBDOMAIN: 't.example.com'"
  fi
}

generate_keys_if_missing() {
  local priv="$1"
  local pub="$2"

  mkdir -p "$CONFIG_DIR"

  if [[ -f "$priv" && -f "$pub" ]]; then
    log "Using existing keys: ${priv}, ${pub}"
    return 0
  fi

  log "Generating keypair..."
  # The binary is now baked into the image at /usr/local/bin/dnstt-server
  dnstt-server -gen-key -privkey-file "$priv" -pubkey-file "$pub"

  chmod 600 "$priv"
  chmod 644 "$pub"

  log "Public key:"
  cat "$pub"
}

main() {
  require_env NS_SUBDOMAIN

  if [[ -z "$KEY_PREFIX" ]]; then
    KEY_PREFIX="${NS_SUBDOMAIN//./_}"
  fi

  local priv="${CONFIG_DIR}/${KEY_PREFIX}_server.key"
  local pub="${CONFIG_DIR}/${KEY_PREFIX}_server.pub"
  generate_keys_if_missing "$priv" "$pub"

  log "Starting dnstt-server"
  log "  NS_SUBDOMAIN=${NS_SUBDOMAIN}"
  log "  DNSTT_PORT=${DNSTT_PORT} (container listens on udp)"
  log "  MTU_VALUE=${MTU_VALUE}"
  log "  Target=${TUNNEL_HOST}:${TUNNEL_PORT}"

  exec /usr/local/bin/dnstt-server \
    -udp ":${DNSTT_PORT}" \
    -privkey-file "$priv" \
    -mtu "$MTU_VALUE" \
    "$NS_SUBDOMAIN" \
    "${TUNNEL_HOST}:${TUNNEL_PORT}"
}

main "$@"
