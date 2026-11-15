# Mitdenkhaus Add-ons für Home Assistant

Add-on-Repository (in neueren Home-Assistant-Versionen „Apps“) für die Zentralen
von Mitdenkhaus (Home Assistant OS auf einer Green, `aarch64`; `amd64` geht auch).

| Add-on | Slug | Zweck |
| --- | --- | --- |
| Mitdenkhaus Wartung | `mitdenkhaus_wartung` | Wartungszugang für Mitdenkhaus über Tailscale |
| Mitdenkhaus Tunnel | `mitdenkhaus_tunnel` | Zugang von unterwegs über `https://<kürzel>.mitdenkhaus.de` |

Der Vertrag zwischen App, Backend, Add-ons und Relay steht in
`docs/schnittstellen.md` im (privaten) App-Repository. Dieses Repository liegt
öffentlich unter https://github.com/mitdenkhaus/mitdenkhaus-addons; die App
kennt die URL als `ADDON_REPOSITORY`. Es enthält keine Geheimnisse – Keys und
Tokens liefert das Backend erst zur Laufzeit.

## Repository in Home Assistant hinzufügen

**Automatisch über die App** (Normalfall): Die App ruft über den WebSocket von
Home Assistant `supervisor/api` auf – `POST /store/repositories` mit der URL,
dann `POST /store/addons/<slug>/install`, `POST /addons/<slug>/options` und
`POST /addons/<slug>/start`.

**Von Hand:**

1. *Einstellungen → Apps (Add-ons) → App-Store / Add-on Store*.
2. Menü oben rechts (⋮) → *Repositories*.
3. URL des Repositorys eintragen, z. B.
   `https://github.com/mitdenkhaus/mitdenkhaus-addons`, und *Hinzufügen*.
4. Seite neu laden; die beiden Add-ons erscheinen unter „Mitdenkhaus Add-ons“.

Im Store heißen die Add-ons `<repo-id>_mitdenkhaus_wartung` bzw.
`<repo-id>_mitdenkhaus_tunnel`. `<repo-id>` sind die ersten 8 Zeichen des
SHA-1 der Repository-URL – ändert sich die URL, ändert sich auch die ID. Die
App sucht deshalb nach der Endung `_mitdenkhaus_wartung` bzw. `_mitdenkhaus_tunnel`.

Die Add-ons werden beim Installieren auf der Green gebaut (kein `image:` in
`config.yaml`); dabei lädt der Supervisor Tailscale bzw. frp und Caddy von
GitHub/pkgs.tailscale.com herunter und prüft die SHA-256-Prüfsummen. Das dauert
auf einer Green etwa eine bis zwei Minuten.

## Mitdenkhaus Wartung

Startet `tailscaled` (Zustand in `/data/tailscale`) und meldet die Zentrale
einmalig mit einem Auth-Key im Tailnet von Mitdenkhaus an
(`tailscale up --auth-key … --hostname … --advertise-tags … --login-server …`).
Ist die Zentrale schon angemeldet, wird der Key ignoriert und nur die
Einstellungen werden gesetzt.

Optionen:

```yaml
authkey: ""          # Einmal-Key vom Backend (POST /v1/maintenance); danach leer lassen
hostname: ""         # vom Backend vorgegeben, z. B. mdh-k7f3
login_server: "https://controlplane.tailscale.com"
tags: ["tag:kunde"]
```

Ablauf aus Sicht der App:

1. `POST /v1/maintenance` beim Backend → `authKey`, `hostname`, `tags`, `loginServer`.
2. Add-on installieren (falls nötig), Optionen setzen, starten.
3. Protokoll/Zustand prüfen; danach `authkey` wieder auf `""` setzen.
4. Widerruf: Add-on stoppen, `DELETE /v1/maintenance` (Backend entfernt das Gerät).

Was das Add-on bewusst **nicht** tut: kein Subnet-Routing (`--advertise-routes=`),
kein Exit-Node, kein Funnel/Serve, kein Tailscale-SSH, keine DNS-Übernahme
(`--accept-dns=false`), keine Routen anderer Geräte (`--accept-routes=false`),
keine Firewall-Regeln im Host (`--netfilter-mode=off`; die ACLs des Tailnets
setzt tailscaled trotzdem durch). Protokolle werden nicht an Tailscale
hochgeladen (`--no-logs-no-support`).

Rechte und warum:

- `host_network: true` – `tailscale0` entsteht im Host, damit die Wartung
  Home Assistant (8123) und andere Dienste der Green erreicht.
- `privileged: [NET_ADMIN, NET_RAW]` und `devices: [/dev/net/tun]` – für das
  TUN-Gerät. `NET_RAW` ist ausdrücklich eingetragen, weil der Supervisor es ab
  2026.12 nicht mehr standardmäßig vergibt.
- `backup_exclude: tailscale/*` – die Geräteidentität kommt nicht in
  Sicherungen. Wird eine Sicherung auf neuer Hardware eingespielt, ist die
  Wartung einmal neu zu erlauben (statt dass zwei Geräte dieselbe Identität
  haben).

## Mitdenkhaus Tunnel

```
Handy ──TLS (SNI k7f3.mitdenkhaus.de)──▶ frps :443 ──frp──▶ frpc ─▶ Caddy :443 ─▶ homeassistant:8123
Let's Encrypt ──HTTP-01──────────────▶ frps :80  ──frp──▶ frpc ─▶ Caddy :80
```

- frpc meldet sich mit `metadatas.token` beim Relay an und richtet zwei Proxies
  ein: `<kürzel>-https` (Typ `https`) und `<kürzel>-http` (Typ `http`), beide
  mit `subdomain = <kürzel>`.
- Caddy lauscht nur auf `127.0.0.1` im Add-on, holt das Zertifikat für
  `<kürzel>.<domain>` von Let's Encrypt (gespeichert in `/data/caddy`) und
  leitet an `http://homeassistant:8123` weiter. WebSockets (`/api/websocket`)
  gehen durch.
- frpc prüft das Zertifikat des Relays gegen `rootfs/etc/frp/relay-ca.pem`
  (eigene CA von Mitdenkhaus, siehe `relay/README.md`). Fehlt die Datei, steht
  eine Warnung im Protokoll und die Verbindung ist ungeprüft.
- Caddy startet erst, wenn beide Proxies am Relay stehen; so laufen keine
  ACME-Prüfungen ins Leere (Let's Encrypt begrenzt fehlgeschlagene Prüfungen).

Optionen:

```yaml
server: "relay.mitdenkhaus.de"
server_port: 7000
token: ""            # tun_… vom Backend (POST /v1/tunnel)
subdomain: ""        # k7f3
domain: "mitdenkhaus.de"
```

### Home Assistant: `http:`-Konfiguration

Es muss **nichts** eingetragen werden. Caddy entfernt `X-Forwarded-For`,
`X-Forwarded-Proto`, `X-Forwarded-Host`, `Forwarded` und `X-Real-IP`, bevor
die Anfrage Home Assistant erreicht – Home Assistant blockiert sonst Anfragen
mit `X-Forwarded-For` von nicht eingetragenen Proxies.

Die Kehrseite: Home Assistant sieht als Absender aller Zugriffe von unterwegs
die interne Adresse des Add-ons (`172.30.33.x`).

- Eine IP-Sperre nach Fehlversuchen trifft dann den ganzen Fernzugang.
- `172.30.32.0/23` darf **nie** in `trusted_networks` stehen (sonst Zugang
  ohne Anmeldung).
- Home Assistant muss auf 8123 per http antworten (Grundeinstellung). Ein
  eigenes Zertifikat in Home Assistant wird nicht unterstützt.

## Fehlersuche

Protokolle: *Einstellungen → Apps → Add-on → Protokoll*, oder per SSH
`ha addons logs <repo-id>_mitdenkhaus_tunnel`.

| Meldung | Ursache und Abhilfe |
| --- | --- |
| Wartung: „Nicht angemeldet und kein Auth-Key gesetzt.“ | Gerät nicht (mehr) im Tailnet. Wartung in der App neu erlauben. |
| Wartung: „Anmeldung abgelehnt: … invalid key …“ | Key abgelaufen (1 h) oder verbraucht. Neu anfordern. |
| Wartung: „… requested tags … are invalid or not permitted“ | Tag `tag:kunde` fehlt in `tagOwners` der Tailnet-Richtlinie oder der Key darf ihn nicht setzen. |
| Wartung: Add-on startet nicht, „/dev/net/tun“ | Gerät fehlt; Supervisor/OS aktualisieren. |
| Tunnel: „Option 'token' fehlt …“ | Tunnel in der App neu einrichten. |
| Tunnel: „Warte auf die Verbindung zum Relay …“ und frpc meldet „Token ungültig“ / „Subdomain gehört nicht …“ | Backend lehnt ab (Login bzw. NewProxy). Token und Kürzel passen nicht zusammen. |
| Tunnel: frpc „connection refused“ / „i/o timeout“ | Relay nicht erreichbar (Port 7000, DNS `relay.mitdenkhaus.de`). |
| Tunnel: Caddy „challenge failed“ | Let's Encrypt erreicht `http://<kürzel>.mitdenkhaus.de` nicht (Wildcard-DNS, Relay Port 80). Caddy versucht es erneut. |
| Browser: 502 | Home Assistant antwortet nicht auf `http://homeassistant:8123` (läuft HA mit eigenem SSL?). |
| Browser: 404 von frp | Tunnel der Zentrale ist nicht verbunden. |

## Entwicklung

Lokal bauen (amd64):

```bash
docker build -t mdh/wartung:test ha-addons/mitdenkhaus_wartung
docker build -t mdh/tunnel:test ha-addons/mitdenkhaus_tunnel
```

Beide Add-ons lesen ihre Optionen direkt aus `/data/options.json` (die Datei
schreibt der Supervisor) statt über `bashio::config`. Dadurch laufen sie auch
ohne Supervisor, z. B. mit `docker run -v ./data:/data …`.

- GitHub Actions (`.github/workflows/build.yaml`, greift, sobald der Ordner
  ein eigenes Repository ist): Shellcheck und Bau beider Add-ons auf amd64 und
  aarch64.
- Shellcheck: `docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:stable -x <skripte>`
- Ende-zu-Ende-Test (Relay + Tunnel-Add-on + Attrappen, Pebble statt
  Let's Encrypt): `relay/test/e2e/run.sh` im (privaten) App-Repository.
- Nur für Tests: Umgebungsvariablen `MDH_ACME_CA` und `MDH_ACME_CA_ROOT`
  richten Caddy auf eine andere ACME-Stelle.

Versionen aktualisieren: `ARG …_VERSION` und die Prüfsummen im jeweiligen
`Dockerfile` anpassen, `version` in `config.yaml` erhöhen, `CHANGELOG.md`
ergänzen. Bei frp zuerst den Relay (frps) aktualisieren, dann das Add-on.

Später können fertige Images (z. B. `ghcr.io/mitdenkhaus/mitdenkhaus-tunnel`)
gebaut und in `config.yaml` als `image:` eingetragen werden; dann entfällt der
Bau auf der Green.

Aufbau eines Add-ons: `config.yaml` (Metadaten, Optionen), `Dockerfile`
(Basis `ghcr.io/home-assistant/base:3.24`, s6-overlay v3), `rootfs/etc/s6-overlay/`
(Dienste), `DOCS.md` (Anzeige in Home Assistant), `translations/`.
`build.yaml` ist veraltet und wird nicht verwendet.
