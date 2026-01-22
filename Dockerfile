# syntax=docker/dockerfile:1
# Lightweight image to run dnstt-server inside a container (no systemd).
# The original script is targeted at host OS (systemd + iptables). In Docker we:
# - install the minimal deps
# - download and verify the official dnstt-server binary
# - run dnstt-server directly

FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        iproute2 \
        iptables \
        openssl \
        procps \
    && rm -rf /var/lib/apt/lists/*

# Copy the repo script in (kept for reference and optional interactive use)
WORKDIR /opt/dnstt-deploy
COPY dnstt-deploy.sh ./dnstt-deploy.sh
RUN chmod +x ./dnstt-deploy.sh

# Install runtime entrypoint
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create a place to persist keys/config
RUN mkdir -p /etc/dnstt

# Expose the default dnstt UDP port (override mapping via compose if DNSTT_PORT changes)
EXPOSE 5300/udp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
