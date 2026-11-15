#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Prüft die Optionen und schreibt die Konfigurationen für frpc und Caddy.
#
# Die Optionen kommen direkt aus /data/options.json (schreibt der Supervisor),
# damit das Add-on auch ohne Supervisor getestet werden kann.
#
# Nur für Tests (nicht in den Optionen): MDH_ACME_CA und MDH_ACME_CA_ROOT
# richten Caddy auf eine andere ACME-Stelle, z. B. Pebble.
# ==============================================================================
set -o nounset -o pipefail

readonly OPTIONS=/data/options.json

opt() {
    jq -r --arg k "$1" '.[$k] // empty | tostring' "${OPTIONS}"
}

# Zeichenkette als TOML-String (JSON-Escapes sind in TOML gültig).
toml_str() {
    jq -Rn --arg v "$1" '$v'
}

if [[ ! -f "${OPTIONS}" ]]; then
    bashio::exit.nok "${OPTIONS} fehlt."
fi

server="$(opt server)"
server_port="$(opt server_port)"
token="$(opt token)"
subdomain="$(opt subdomain)"
domain="$(opt domain)"

fail=0
if ! bashio::var.has_value "${token}"; then
    bashio::log.fatal "Option 'token' fehlt (tun_… aus der Mitdenkhaus-App)."
    fail=1
fi
if ! [[ "${subdomain}" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]]; then
    bashio::log.fatal "Option 'subdomain' fehlt oder ist ungültig: '${subdomain}'."
    fail=1
fi
if ! [[ "${domain}" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ ]]; then
    bashio::log.fatal "Option 'domain' ist ungültig: '${domain}'."
    fail=1
fi
if ! [[ "${server}" =~ ^[A-Za-z0-9.-]+$ ]]; then
    bashio::log.fatal "Option 'server' ist ungültig: '${server}'."
    fail=1
fi
if ! [[ "${server_port}" =~ ^[0-9]+$ ]]; then
    bashio::log.fatal "Option 'server_port' ist ungültig: '${server_port}'."
    fail=1
fi
if [[ "${fail}" -ne 0 ]]; then
    bashio::exit.nok "Tunnel über die Mitdenkhaus-App neu einrichten."
fi

fqdn="${subdomain}.${domain}"
bashio::log.info "Tunnel für https://${fqdn} über ${server}:${server_port}"

# ------------------------------------------------------------------------------
# frpc
# ------------------------------------------------------------------------------
mkdir -p /etc/frp

# Zertifikat des Relays gegen die eigene CA von Mitdenkhaus prüfen
# (relay/tls/zertifikate.sh im App-Repository).
readonly RELAY_CA=/etc/frp/relay-ca.pem
tls_verify=""
if [[ -s "${RELAY_CA}" ]]; then
    tls_verify="transport.tls.trustedCaFile = $(toml_str "${RELAY_CA}")
transport.tls.serverName = $(toml_str "${server}")"
else
    bashio::log.warning "${RELAY_CA} fehlt: Das Zertifikat des Relays wird nicht geprüft."
fi

cat > /etc/frp/frpc.toml <<EOF
# Erzeugt von init-tunnel.sh – Änderungen gehen beim Neustart verloren.
serverAddr = $(toml_str "${server}")
serverPort = ${server_port}
# Bei Ablehnung oder fehlendem Netz weiter versuchen statt zu beenden.
loginFailExit = false
transport.tls.enable = true
${tls_verify}

# Wird beim Login an das Server-Plugin von frps (Backend) übergeben.
metadatas.token = $(toml_str "${token}")

log.to = "console"
log.level = "info"

# Nur im Add-on erreichbar; Caddy wartet hierüber auf den Tunnel.
webServer.addr = "127.0.0.1"
webServer.port = 7400

# TLS wird nicht vom Relay beendet: frps leitet nach SNI an Caddy weiter.
[[proxies]]
name = $(toml_str "${subdomain}-https")
type = "https"
subdomain = $(toml_str "${subdomain}")
localIP = "127.0.0.1"
localPort = 443

# Für die HTTP-01-Prüfung von Let's Encrypt und die Weiterleitung auf https.
[[proxies]]
name = $(toml_str "${subdomain}-http")
type = "http"
subdomain = $(toml_str "${subdomain}")
localIP = "127.0.0.1"
localPort = 80
EOF
chmod 600 /etc/frp/frpc.toml

if ! output="$(frpc verify -c /etc/frp/frpc.toml 2>&1)"; then
    bashio::exit.nok "frpc-Konfiguration ungültig: ${output}"
fi

# ------------------------------------------------------------------------------
# Home Assistant: Port und SSL vom Supervisor (Grundeinstellung 8123, http).
# Manche Zentralen laufen auf Port 80 oder mit eigenem Zertifikat.
# ------------------------------------------------------------------------------
ha_port=8123
ha_ssl=false
if [[ -n "${SUPERVISOR_TOKEN:-}" ]]; then
    if core="$(curl -fsS --max-time 10 -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
            "http://supervisor/core/info")"; then
        ha_port="$(jq -r '.data.port // 8123' <<<"${core}" 2>/dev/null || echo 8123)"
        ha_ssl="$(jq -r '.data.ssl // false' <<<"${core}" 2>/dev/null || echo false)"
    else
        bashio::log.warning "Einstellungen von Home Assistant nicht abrufbar, nehme Port 8123."
    fi
fi
if ! [[ "${ha_port}" =~ ^[0-9]+$ ]]; then
    bashio::exit.nok "Ungültiger Port von Home Assistant: '${ha_port}'."
fi

ha_upstream="homeassistant:${ha_port}"
ha_transport=""
if [[ "${ha_ssl}" == "true" ]]; then
    # Home Assistant mit eigenem Zertifikat: Das Zertifikat lautet nicht auf
    # "homeassistant". Die Strecke verlässt die Green nicht (internes Netz).
    # TLS über den Transport statt "https://": Caddy lehnt https mit Port 80 ab.
    ha_transport=$'transport http {\n\t\t\ttls\n\t\t\ttls_insecure_skip_verify\n\t\t}'
fi
bashio::log.info "Home Assistant: ${ha_upstream} ($([[ "${ha_ssl}" == "true" ]] && echo https || echo http))"

# ------------------------------------------------------------------------------
# Caddy
# ------------------------------------------------------------------------------
acme=""
if [[ -n "${MDH_ACME_CA:-}" ]]; then
    bashio::log.warning "Test-ACME-Stelle aktiv: ${MDH_ACME_CA}"
    acme="acme_ca ${MDH_ACME_CA}"
    if [[ -n "${MDH_ACME_CA_ROOT:-}" ]]; then
        acme+=$'\n\t'"acme_ca_root ${MDH_ACME_CA_ROOT}"
    fi
fi

mkdir -p /etc/caddy /data/caddy
cat > /etc/caddy/Caddyfile <<EOF
# Erzeugt von init-tunnel.sh – Änderungen gehen beim Neustart verloren.
{
	admin off
	# Nur für frpc erreichbar, nicht im Netz von Home Assistant.
	default_bind 127.0.0.1
	http_port 80
	https_port 443
	storage file_system /data/caddy
	${acme}
	servers {
		protocols h1 h2
	}
}

${fqdn} {
	encode zstd gzip
	reverse_proxy ${ha_upstream} {
		${ha_transport}
		# Home Assistant lehnt Anfragen mit X-Forwarded-For ab, solange
		# kein vertrauenswürdiger Proxy eingetragen ist. Ohne diese Header
		# funktioniert es ohne Änderung an der http-Konfiguration.
		header_up -X-Forwarded-For
		header_up -X-Forwarded-Proto
		header_up -X-Forwarded-Host
		header_up -Forwarded
		header_up -X-Real-IP
	}
}
EOF

if ! output="$(caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile 2>&1)"; then
    bashio::exit.nok "Caddy-Konfiguration ungültig: ${output}"
fi
exit 0
