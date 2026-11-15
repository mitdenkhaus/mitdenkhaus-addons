#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Meldet die Green im Tailnet an (einmal mit Auth-Key) bzw. setzt bei bereits
# angemeldeten Geräten nur die Einstellungen. Kein Subnet-Routing, kein
# Exit-Node, kein Funnel/Serve, kein Tailscale-SSH.
#
# Die Optionen kommen direkt aus /data/options.json (schreibt der Supervisor),
# damit das Skript auch ohne Supervisor getestet werden kann.
# ==============================================================================
set -o nounset -o pipefail

readonly OPTIONS=/data/options.json
readonly TS=/usr/local/bin/tailscale

opt() {
    jq -r --arg k "$1" '.[$k] // empty | if type == "array" then join(",") else tostring end' "${OPTIONS}"
}

# tailscale up mit gefilterter Ausgabe (der Hinweis zu netfilter=off ist gewollt).
ts_up() {
    local out rc
    out="$("${TS}" up "$@" 2>&1)"
    rc=$?
    grep -v 'netfilter=off' <<<"${out}" || true
    return "${rc}"
}

backend_state() {
    "${TS}" status --json --peers=false 2>/dev/null | jq -r '.BackendState // empty' 2>/dev/null
}

if [[ ! -f "${OPTIONS}" ]]; then
    bashio::exit.nok "${OPTIONS} fehlt."
fi

authkey="$(opt authkey)"
hostname="$(opt hostname)"
login_server="$(opt login_server)"
tags="$(opt tags)"
login_server="${login_server:-https://controlplane.tailscale.com}"

# Auf tailscaled warten, bis ein stabiler Zustand vorliegt.
# NoState kann ohne Netz länger anhalten, daher nach 60 s weiter.
state=""
for _ in $(seq 1 60); do
    state="$(backend_state)"
    case "${state}" in
        NeedsLogin | NeedsMachineAuth | Stopped | Running | Starting) break ;;
    esac
    sleep 1
done
bashio::log.info "Zustand von Tailscale: ${state:-unbekannt}"

# Alle Einstellungen bei jedem Start vollständig setzen (--reset), damit
# nichts von früheren Läufen übrig bleibt.
options=(
    --reset
    "--login-server=${login_server}"
    "--advertise-tags=${tags}"
    --accept-dns=false
    --accept-routes=false
    --advertise-exit-node=false
    --advertise-routes=
    --exit-node=
    --ssh=false
    # Keine Firewall-Regeln im Host von Home Assistant OS anfassen. Die
    # Zugriffsregeln (ACL) des Tailnets setzt tailscaled trotzdem durch.
    --netfilter-mode=off
)
if bashio::var.has_value "${hostname}"; then
    options+=("--hostname=${hostname}")
fi

case "${state}" in
    Running | Starting | Stopped | NeedsMachineAuth)
        # Bereits angemeldet: ein gesetzter Key wird ignoriert.
        if bashio::var.has_value "${authkey}"; then
            bashio::log.notice "Gerät ist schon angemeldet, der Auth-Key wird ignoriert."
        fi
        if [[ "${state}" == "NeedsMachineAuth" ]]; then
            bashio::log.warning "Das Gerät wartet auf Freigabe im Tailnet."
        fi
        if ! output="$(ts_up "${options[@]}" --timeout=60s)"; then
            bashio::log.warning "tailscale up meldet: ${output}"
            bashio::log.warning "tailscaled verbindet sich weiter selbstständig."
        fi
        ;;
    *)
        if ! bashio::var.has_value "${authkey}"; then
            bashio::log.fatal "Nicht angemeldet und kein Auth-Key gesetzt."
            bashio::log.fatal "Wartung in der Mitdenkhaus-App erneut erlauben."
            bashio::exit.nok
        fi
        bashio::log.info "Melde die Zentrale im Tailnet an (${login_server}) …"
        attempt=1
        until output="$(ts_up "${options[@]}" "--auth-key=${authkey}" --timeout=90s)"; do
            if [[ "${output}" == *"invalid key"* || "${output}" == *"key"*"expired"* \
                || "${output}" == *"not valid"* || "${output}" == *"requested tags"* ]]; then
                bashio::log.fatal "Anmeldung abgelehnt: ${output}"
                bashio::exit.nok "Neuen Auth-Key über die Mitdenkhaus-App anfordern."
            fi
            if [[ "${attempt}" -ge 10 ]]; then
                bashio::log.fatal "Anmeldung nach ${attempt} Versuchen fehlgeschlagen: ${output}"
                bashio::exit.nok
            fi
            bashio::log.warning "Anmeldung fehlgeschlagen (Versuch ${attempt}/10): ${output}"
            attempt=$((attempt + 1))
            sleep 30
        done
        bashio::log.info "Angemeldet. Der Auth-Key wird nicht mehr gebraucht."
        ;;
esac

if ip="$("${TS}" ip -4 2>/dev/null)"; then
    bashio::log.info "Tailscale-Adresse: ${ip}"
fi
exit 0
