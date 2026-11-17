#!/command/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Geräteliste für die Werkstatt: Welche Geräte sieht die Zentrale im Heimnetz,
# welche haben eine Weboberfläche, welche sind Shellys?
#
# Läuft nur mit erlaubter Heimnetz-Freigabe. Die Liste liegt als
# /var/www/geraete/geraete.json und ist nur im Tailnet unter
# http://<zentrale>:8099/geraete.json abrufbar (tailscale serve, Regeln des
# Tailnets gelten). Alle 5 Minuten neu.
# ==============================================================================
set -o nounset -o pipefail

readonly TS=/usr/local/bin/tailscale
readonly WWW=/var/www/geraete
readonly PORT=8099
readonly INTERVALL=300
# shellcheck source=SCRIPTDIR/heimnetz.sh
source /etc/s6-overlay/scripts/heimnetz.sh

if ! heimnetz_aktiv; then
    "${TS}" serve --http="${PORT}" off >/dev/null 2>&1 || true
    exec sleep infinity
fi

standort="$(heimnetz_standort || true)"
cidr="$(heimnetz_cidr || true)"
if [[ -z "${standort}" || -z "${cidr}" ]]; then
    bashio::log.warning "Geräteliste aus: Standort oder Heimnetz fehlt."
    exec sleep infinity
fi
dev="$(heimnetz_schnittstelle)"
via="$("${TS}" debug via "${standort}" "${cidr}")"

mkdir -p "${WWW}"
echo '{"geraete":[]}' >"${WWW}/geraete.json"
if ! out="$("${TS}" serve --bg --http="${PORT}" "${WWW}" 2>&1)"; then
    bashio::log.warning "Geräteliste nicht im Tailnet bereitgestellt: ${out}"
fi

# Alle Adressen eines Netzes ab /24 anpingen, damit die Nachbarliste
# vollständig ist. Größere Netze: nur Geräte, mit denen die Zentrale ohnehin
# spricht (z. B. alle Geräte in Home Assistant).
anpingen() {
    local NETWORK PREFIX a b c d i
    eval "$(ipcalc -n -p "${cidr}")"
    ((PREFIX >= 24)) || return 0
    IFS=. read -r a b c d <<<"${NETWORK}"
    for ((i = 1; i < 2 ** (32 - PREFIX) - 1; i++)); do
        echo "${a}.${b}.${c}.$((d + i))"
    done | xargs -P 32 -n 1 ping -c 1 -W 1 -q >/dev/null 2>&1 || true
}

while true; do
    anpingen
    tmp="$(mktemp "${WWW}/.geraete.XXXXXX")"
    ip -4 neigh show dev "${dev}" \
        | awk '/lladdr/ && $NF != "FAILED" && $NF != "INCOMPLETE" {print $1, $3}' \
        | xargs -P 16 -n 2 /etc/s6-overlay/scripts/geraet-pruefen.sh "${standort}" \
        | jq -s --arg standort "${standort}" --arg heimnetz "${cidr}" --arg via "${via}" \
            --arg name "$("${TS}" status --json --peers=false | jq -r '.Self.HostName // ""')" \
            '{aktualisiert: (now | todate), name: $name, standort_id: ($standort | tonumber),
              heimnetz: $heimnetz, via: $via, geraete: sort_by(.ip | split(".") | map(tonumber))}' \
            >"${tmp}" && chmod 644 "${tmp}" && mv "${tmp}" "${WWW}/geraete.json"
    rm -f "${tmp}"
    sleep "${INTERVALL}"
done
