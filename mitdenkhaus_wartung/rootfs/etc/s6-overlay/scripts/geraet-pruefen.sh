#!/bin/bash
# ==============================================================================
# Prüft ein Gerät im Heimnetz und gibt eine JSON-Zeile aus.
# Aufruf: geraet-pruefen.sh <standort_id> <ip> <mac>
# ==============================================================================
set -o nounset -o pipefail

standort="$1"
ip="$2"
mac="$3"

# Name per Rückwärtsauflösung beim Router (FritzBox & Co. kennen die Namen).
name="$(timeout 3 nslookup "${ip}" 2>/dev/null | awk '/name =/ {sub(/\.$/, "", $NF); print $NF; exit}')"

http_status() {
    curl -s -k -o /dev/null -m 2 -w '%{http_code}' "$1" 2>/dev/null || true
}
http="$(http_status "http://${ip}/")"
https="$(http_status "https://${ip}/")"

# Shelly (Gen 1 und Gen 2+) antwortet unter /shelly mit Typ und Modell.
shelly="$(curl -s -m 2 "http://${ip}/shelly" 2>/dev/null \
    | jq -c 'select(type == "object" and (.type // .model // .app) != null)
             | {modell: (.model // .type), app, name, gen: (.gen // 1)}' 2>/dev/null || true)"

jq -n -c \
    --arg ip "${ip}" --arg mac "${mac}" --arg name "${name}" \
    --arg http "${http}" --arg https "${https}" --argjson shelly "${shelly:-null}" \
    --arg adresse "${ip//./-}-via-${standort}" \
    '{ip: $ip, mac: $mac, name: (if $name == "" then null else $name end),
      web: {http: ($http != "000" and $http != ""), https: ($https != "000" and $https != "")},
      shelly: $shelly, adresse: $adresse}'
