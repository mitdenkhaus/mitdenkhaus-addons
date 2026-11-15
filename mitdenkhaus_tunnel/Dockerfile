# Caddy aus dem offiziellen Image (Multi-Arch, statisch gebaut).
FROM caddy:2.11.9-alpine AS caddy

# Basis-Image von Home Assistant (Alpine, s6-overlay v3, bashio, jq, curl).
# Seit Supervisor 2026.04 wird BUILD_FROM nicht mehr übergeben, daher fest.
FROM ghcr.io/home-assistant/base:3.24

# frpc von https://github.com/fatedier/frp/releases (Prüfsummen: frp_sha256_checksums.txt)
ARG FRP_VERSION=0.72.0
ARG FRP_SHA256_AMD64=daf719b32ca2778770bb92955e231a07414d754378b9af328aa2642862479804
ARG FRP_SHA256_ARM64=02180b857480302fd934e9ddbd50fe2f73229f99062f88756abc6de9df5e95cf

RUN set -eux; \
    case "$(apk --print-arch)" in \
        x86_64)  arch=amd64; sum="${FRP_SHA256_AMD64}" ;; \
        aarch64) arch=arm64; sum="${FRP_SHA256_ARM64}" ;; \
        *) echo "Architektur $(apk --print-arch) wird nicht unterstützt" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/frp.tgz \
        "https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_${arch}.tar.gz"; \
    echo "${sum}  /tmp/frp.tgz" | sha256sum -c -; \
    mkdir -p /tmp/frp; \
    tar -xzf /tmp/frp.tgz -C /tmp/frp --strip-components=1; \
    install -m 0755 /tmp/frp/frpc /usr/local/bin/frpc; \
    rm -rf /tmp/frp /tmp/frp.tgz; \
    frpc --version

COPY --from=caddy /usr/bin/caddy /usr/local/bin/caddy
RUN caddy version

# Zertifikate und ACME-Konto von Caddy bleiben in /data erhalten.
ENV XDG_DATA_HOME=/data \
    XDG_CONFIG_HOME=/var/lib/caddy-config

COPY rootfs /
RUN chmod a+x /etc/s6-overlay/s6-rc.d/*/run /etc/s6-overlay/s6-rc.d/*/finish /etc/s6-overlay/scripts/*.sh
