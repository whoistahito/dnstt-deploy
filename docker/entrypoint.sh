#!/usr/bin/env bash
set -euo pipefail

DNSTT_BASE_URL="${DNSTT_BASE_URL:-https://dnstt.network}"
ARCH="${ARCH:-}"
DNSTT_PORT="${DNSTT_PORT:-5300}"
NS_SUBDOMAIN="${NS_SUBDOMAIN:-}"
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
    fail "Missing required env var: $name"
  fi
}

detect_arch() {
  local a
  a="$(uname -m)"
  case "$a" in
    x86_64) echo "amd64";;
    aarch64|arm64) echo "arm64";;
    armv7l|armv6l) echo "arm";;
    i386|i686) echo "386";;
    *) fail "Unsupported architecture: $a";;
  esac
}

download_and_verify_dnstt_server() {
  local arch="$1"
  local filename="dnstt-server-linux-${arch}"
  local tmpdir
  tmpdir="$(mktemp -d)"

  log "Downloading dnstt-server (${filename}) from ${DNSTT_BASE_URL}..."
  curl -fsSL -o "${tmpdir}/${filename}" "${DNSTT_BASE_URL}/${filename}"
  curl -fsSL -o "${tmpdir}/SHA256SUMS" "${DNSTT_BASE_URL}/SHA256SUMS"

  (cd "$tmpdir" && sha256sum -c <(grep "${filename}" SHA256SUMS))

  chmod +x "${tmpdir}/${filename}"
  mv "${tmpdir}/${filename}" /usr/local/bin/dnstt-server
  rm -rf "$tmpdir"

  log "Installed /usr/local/bin/dnstt-server"
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
  dnstt-server -gen-key -privkey-file "$priv" -pubkey-file "$pub"

  chmod 600 "$priv"
  chmod 644 "$pub"

  log "Public key:"
  cat "$pub"
}

main() {
  require_env NS_SUBDOMAIN

  if [[ -z "$ARCH" ]]; then
    ARCH="$(detect_arch)"
  fi

  if [[ ! -x /usr/local/bin/dnstt-server ]]; then
    download_and_verify_dnstt_server "$ARCH"
  fi

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
