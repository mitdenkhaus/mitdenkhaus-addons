# Basis-Image von Home Assistant (Alpine, s6-overlay v3, bashio, jq, curl).
# Seit Supervisor 2026.04 wird BUILD_FROM nicht mehr übergeben, daher fest.
FROM ghcr.io/home-assistant/base:3.24

# Statische Builds von https://pkgs.tailscale.com/stable/ (Prüfsummen: <datei>.sha256)
ARG TAILSCALE_VERSION=1.104.7
ARG TAILSCALE_SHA256_AMD64=e56693ff74a64f2591b7e819c280635a100aae1ddfb0ef058fcd052b7cd8d16c
ARG TAILSCALE_SHA256_ARM64=d6bed2720310b328b861f943d7b4016c5358a9bad60575eb51e8143b79068484

RUN set -eux; \
    case "$(apk --print-arch)" in \
        x86_64)  arch=amd64; sum="${TAILSCALE_SHA256_AMD64}" ;; \
        aarch64) arch=arm64; sum="${TAILSCALE_SHA256_ARM64}" ;; \
        *) echo "Architektur $(apk --print-arch) wird nicht unterstützt" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/tailscale.tgz \
        "https://pkgs.tailscale.com/stable/tailscale_${TAILSCALE_VERSION}_${arch}.tgz"; \
    echo "${sum}  /tmp/tailscale.tgz" | sha256sum -c -; \
    mkdir -p /tmp/tailscale; \
    tar -xzf /tmp/tailscale.tgz -C /tmp/tailscale --strip-components=1; \
    install -m 0755 /tmp/tailscale/tailscale /tmp/tailscale/tailscaled /usr/local/bin/; \
    rm -rf /tmp/tailscale /tmp/tailscale.tgz; \
    tailscale version

COPY rootfs /
RUN chmod a+x /etc/s6-overlay/s6-rc.d/*/run /etc/s6-overlay/s6-rc.d/*/finish /etc/s6-overlay/scripts/*.sh
