# Mitdenkhaus Tunnel

Mit diesem Add-on erreichen Sie Ihre Zentrale von unterwegs unter
`https://<kürzel>.mitdenkhaus.de` – ohne Portfreigabe am Router.

## So funktioniert es

```
Handy ──TLS──▶ Relay (mitdenkhaus.de) ──Tunnel──▶ dieses Add-on ──▶ Home Assistant
               leitet nur weiter            Caddy entschlüsselt     homeassistant:<port>
```

- Das Add-on baut mit [frp](https://github.com/fatedier/frp) eine Verbindung
  zum Relay auf.
- Die Verschlüsselung endet erst hier im Add-on: [Caddy](https://caddyserver.com)
  holt dafür ein Zertifikat von Let's Encrypt. Der Relay sieht nur
  verschlüsselten Verkehr.
- Zertifikate liegen in `/data` des Add-ons und sind Teil der Sicherungen.

## Optionen

Die Optionen setzt normalerweise die Mitdenkhaus-App.

| Option | Bedeutung |
| --- | --- |
| `server` | Relay, Standard `relay.mitdenkhaus.de` |
| `server_port` | Port des Relays, Standard `7000` |
| `token` | Tunnel-Token (`tun_…`) vom Mitdenkhaus-Backend |
| `access_key` | Zugangsschlüssel (`acc_…`) vom Mitdenkhaus-Backend |
| `subdomain` | Kürzel der Zentrale, z. B. `k7f3` |
| `domain` | Standard `mitdenkhaus.de` |

## Nur für die Mitdenkhaus-App

Von unterwegs kommen nur Anfragen der Mitdenkhaus-App zu Home Assistant: Die
App schickt bei jeder Anfrage den Header `X-Mitdenkhaus-Key` mit dem
Zugangsschlüssel. Alle anderen Anfragen – Browser, Scanner, Passwort-Raten –
bekommen „403 Kein Zugriff“, bevor sie Home Assistant erreichen. Das gilt auch
für WebSockets. Ist kein Schlüssel gesetzt, ist der Zugriff von unterwegs
ganz gesperrt. Im Heimnetz ändert sich nichts.

Der Schlüssel wird nicht protokolliert und nicht an Home Assistant
weitergegeben.

## Home Assistant

An der `http:`-Konfiguration von Home Assistant ist nichts zu ändern. Das
Add-on schickt keine `X-Forwarded-For`-Header. Folge: Home Assistant sieht als
Absender aller Zugriffe von unterwegs die interne Adresse dieses Add-ons
(`172.30.33.x`).

- Haben Sie die Sperre nach Fehlversuchen (`login_attempts_threshold`)
  eingeschaltet, sperrt sie im Zweifel den ganzen Fernzugang statt eines
  Angreifers.
- Tragen Sie das interne Netz `172.30.32.0/23` **nie** bei `trusted_networks`
  ein, sonst wäre der Fernzugang ohne Anmeldung offen.
- Port und Verschlüsselung von Home Assistant liest das Add-on beim Start vom
  Supervisor (Grundeinstellung 8123, http). Nach einer Änderung dort das
  Add-on neu starten.

## Fehlersuche

- **„Warte auf die Verbindung zum Relay …“** dauerhaft – Token oder Kürzel
  passen nicht zusammen, oder der Relay ist nicht erreichbar. Im Protokoll
  steht die Meldung von frpc (z. B. „Token ungültig“). Tunnel in der App neu
  einrichten.
- **Zertifikatsfehler im Protokoll von Caddy** – Let's Encrypt erreicht
  `http://<kürzel>.mitdenkhaus.de` nicht über den Relay. Caddy versucht es
  selbstständig erneut.
- **„403 Kein Zugriff“ im Browser** – gewollt: Von unterwegs geht es nur über
  die Mitdenkhaus-App. Kommt 403 auch in der App, passt der Schlüssel nicht;
  Fernzugriff in der App aus- und wieder einschalten.
- **„502“ im Browser** – Home Assistant antwortet nicht auf
  `homeassistant:<port>` (Port steht beim Start im Protokoll).
