# Mitdenkhaus Wartung

Dieses Add-on gibt Mitdenkhaus einen Wartungszugang zu Ihrer Zentrale – über
[Tailscale](https://tailscale.com), verschlüsselt und nur solange Sie ihn
erlauben. Sie steuern das in der Mitdenkhaus-App unter „Wartung erlauben“.

## So funktioniert es

1. Sie erlauben die Wartung in der App.
2. Die App holt beim Mitdenkhaus-Backend einen Einmal-Key, trägt ihn hier ein
   und startet das Add-on.
3. Das Add-on meldet die Zentrale damit im Tailnet von Mitdenkhaus an. Danach
   ist der Key verbraucht; die App leert das Feld wieder.
4. Nehmen Sie die Erlaubnis zurück, stoppt die App das Add-on und das Backend
   entfernt die Zentrale aus dem Tailnet.

Das Add-on richtet **kein** Subnet-Routing, **keinen** Exit-Node, **kein**
Funnel/Serve und **kein** Tailscale-SSH ein. Mitdenkhaus erreicht nur die
Zentrale selbst, nicht die anderen Geräte in Ihrem Heimnetz.

## Optionen

Die Optionen setzt normalerweise die App.

| Option | Bedeutung |
| --- | --- |
| `authkey` | Einmal-Key vom Backend. Ist die Zentrale schon angemeldet, wird er ignoriert. |
| `hostname` | Name im Tailnet, z. B. `mdh-k7f3`. |
| `login_server` | Koordinationsserver, Standard `https://controlplane.tailscale.com`. |
| `tags` | Tags im Tailnet, Standard `tag:kunde`. |

## Fehlersuche

Im Protokoll des Add-ons:

- **„Nicht angemeldet und kein Auth-Key gesetzt.“** – Die Zentrale ist nicht
  (mehr) im Tailnet. Wartung in der App erneut erlauben.
- **„Anmeldung abgelehnt: … invalid key …“** – Der Key ist abgelaufen (1 Stunde)
  oder schon verwendet. Wartung in der App erneut erlauben.
- **„Das Gerät wartet auf Freigabe im Tailnet.“** – Im Tailnet ist
  Geräte-Freigabe aktiv; das Gerät in der Tailscale-Verwaltung freigeben.
