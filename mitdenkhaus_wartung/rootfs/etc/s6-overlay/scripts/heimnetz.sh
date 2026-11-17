# shellcheck shell=bash
# ==============================================================================
# Gemeinsame Funktionen für die Heimnetz-Freigabe (wird mit "source" geladen).
#
# Das Heimnetz wird über Tailscale "4via6" freigegeben: Jede Zentrale hat eine
# eigene Standort-Nummer, und Tailscale verpackt das IPv4-Heimnetz in einen
# eindeutigen IPv6-Bereich. So kollidieren gleiche Heimnetze verschiedener
# Kunden (z. B. 192.168.178.0/24) nicht. Geräte sind dann im Tailnet unter
# Namen wie 192-168-178-20-via-7 erreichbar.
# ==============================================================================

readonly HEIMNETZ_OPTIONS=/data/options.json

heimnetz_opt() {
    jq -r --arg k "$1" '.[$k] // empty | tostring' "${HEIMNETZ_OPTIONS}"
}

heimnetz_aktiv() {
    [[ "$(heimnetz_opt heimnetz_freigeben)" == "true" ]]
}

# Standort-Nummer 1–65535 oder Fehler.
heimnetz_standort() {
    local id
    id="$(heimnetz_opt standort_id)"
    [[ "${id}" =~ ^[0-9]+$ ]] && ((id >= 1 && id <= 65535)) || return 1
    echo "${id}"
}

# Netzwerkschnittstelle der Standardroute (das Heimnetz mit Router).
heimnetz_schnittstelle() {
    ip -4 route show default | awk '{for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit }}'
}

# Nur private Netze von /16 bis /30.
heimnetz_pruefen() {
    local cidr="$1" addr prefix a b
    [[ "${cidr}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]] || return 1
    addr="${cidr%/*}"
    prefix="${cidr#*/}"
    ((prefix >= 16 && prefix <= 30)) || return 1
    IFS=. read -r a b _ _ <<<"${addr}"
    ((a == 10)) || ((a == 172 && b >= 16 && b <= 31)) || ((a == 192 && b == 168)) || return 1
}

# Heimnetz als Netzadresse/Präfix, z. B. 192.168.178.0/24. Option "heimnetz"
# hat Vorrang, sonst die Adresse der Schnittstelle mit der Standardroute.
heimnetz_cidr() {
    local cidr dev addr NETWORK PREFIX
    cidr="$(heimnetz_opt heimnetz)"
    if [[ -z "${cidr}" ]]; then
        dev="$(heimnetz_schnittstelle)"
        [[ -n "${dev}" ]] || return 1
        addr="$(ip -4 -o addr show dev "${dev}" scope global | awk '{print $4; exit}')"
        [[ -n "${addr}" ]] || return 1
        cidr="${addr}"
    fi
    [[ "${cidr}" == */* ]] || return 1
    eval "$(ipcalc -n -p "${cidr}")" || return 1
    cidr="${NETWORK}/${PREFIX}"
    heimnetz_pruefen "${cidr}" || return 1
    echo "${cidr}"
}
