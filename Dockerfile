# syntax=docker/dockerfile:1

# Stage 1: Download and verify binary
FROM debian:bookworm-slim AS builder

ARG DEBIAN_FRONTEND=noninteractive
# Automatic platform ARG provided by Docker BuildKit
ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

# Download dnstt-server based on architecture.
# We try to use Docker's TARGETARCH, falling back to uname -m if not available.
RUN set -e; \
    ARCH="${TARGETARCH}"; \
    if [ -z "$ARCH" ]; then \
        U_ARCH=$(uname -m); \
        case "$U_ARCH" in \
            x86_64)        ARCH="amd64" ;; \
            aarch64|arm64) ARCH="arm64" ;; \
            armv7l|armv6l) ARCH="arm" ;; \
            i386|i686)     ARCH="386" ;; \
            *) echo "Unsupported uname arch: ${U_ARCH}"; exit 1 ;; \
        esac; \
    fi; \
    \
    echo "Detected architecture: ${ARCH}"; \
    \
    # Map to dnstt filenames \
    case "${ARCH}" in \
        "amd64") BIN_ARCH="amd64" ;; \
        "arm64") BIN_ARCH="arm64" ;; \
        "386")   BIN_ARCH="386" ;; \
        "arm")   BIN_ARCH="arm" ;; \
        *) echo "Unsupported target arch: ${ARCH}"; exit 1 ;; \
    esac; \
    \
    FILENAME="dnstt-server-linux-${BIN_ARCH}"; \
    echo "Downloading ${FILENAME} ..."; \
    \
    curl -fsSL -O "https://dnstt.network/${FILENAME}"; \
    curl -fsSL -O "https://dnstt.network/SHA256SUMS"; \
    \
    grep "${FILENAME}" SHA256SUMS | sha256sum -c -; \
    \
    mv "${FILENAME}" /tmp/dnstt-server; \
    chmod +x /tmp/dnstt-server

# Stage 2: Minimal runtime image
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create configuration directory
RUN mkdir -p /etc/dnstt

# Copy binary from builder
COPY --from=builder /tmp/dnstt-server /usr/local/bin/dnstt-server

# Copy entrypoint script
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Environment defaults
ENV DNSTT_PORT=5300
ENV CONFIG_DIR=/etc/dnstt

# Expose default UDP port
EXPOSE 5300/udp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
