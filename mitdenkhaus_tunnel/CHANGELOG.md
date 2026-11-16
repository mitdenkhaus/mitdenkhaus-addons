# Änderungen

## 0.2.0

- Neue Option `access_key`: Von unterwegs kommen nur Anfragen mit dem Header
  `X-Mitdenkhaus-Key` (aus der Mitdenkhaus-App) zu Home Assistant, alles andere
  bekommt 403 – auch WebSockets. Ohne Schlüssel ist der Zugriff gesperrt.
  Port 80 (Let's Encrypt, Umleitung auf https) bleibt offen.

## 0.1.2

- frpc prüft das Zertifikat des Relays gegen die CA von Mitdenkhaus
  (`/etc/frp/relay-ca.pem`, gültig bis 2046).

## 0.1.1

- Port und SSL von Home Assistant werden beim Start vom Supervisor gelesen
  (bisher fest 8123). Zentralen mit Port 80 oder eigenem Zertifikat gehen jetzt.

## 0.1.0

- Erste Version.
