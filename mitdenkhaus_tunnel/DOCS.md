# Mitdenkhaus Tunnel

Mit diesem Add-on erreichen Sie Ihre Zentrale von unterwegs unter
`https://<kürzel>.mitdenkhaus.de` – ohne Portfreigabe am Router.

## So funktioniert es

```
Handy ──TLS──▶ Relay (mitdenkhaus.de) ──Tunnel──▶ dieses Add-on ──▶ Home Assistant
               leitet nur weiter            Caddy entschlüsselt     homeassistant:8123
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
| `subdomain` | Kürzel der Zentrale, z. B. `k7f3` |
| `domain` | Standard `mitdenkhaus.de` |

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
- Home Assistant muss auf Port 8123 unverschlüsselt (http) antworten, so wie
  in der Grundeinstellung. Ein eigenes Zertifikat in Home Assistant
  (`ssl_certificate`) wird nicht unterstützt.

## Fehlersuche

- **„Warte auf die Verbindung zum Relay …“** dauerhaft – Token oder Kürzel
  passen nicht zusammen, oder der Relay ist nicht erreichbar. Im Protokoll
  steht die Meldung von frpc (z. B. „Token ungültig“). Tunnel in der App neu
  einrichten.
- **Zertifikatsfehler im Protokoll von Caddy** – Let's Encrypt erreicht
  `http://<kürzel>.mitdenkhaus.de` nicht über den Relay. Caddy versucht es
  selbstständig erneut.
- **„502“ im Browser** – Home Assistant antwortet nicht auf
  `http://homeassistant:8123`.
