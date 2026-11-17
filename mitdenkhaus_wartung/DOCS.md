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

Das Add-on richtet **keinen** Exit-Node, **kein** Funnel und **kein**
Tailscale-SSH ein. Mitdenkhaus erreicht nur die Zentrale selbst, nicht die
anderen Geräte in Ihrem Heimnetz – es sei denn, Sie erlauben das ausdrücklich
(„Heimnetz freigeben“, siehe unten).

## Heimnetz freigeben

Manche Wartung braucht Zugriff auf andere Geräte, etwa die Weboberfläche eines
Shelly. Mit `heimnetz_freigeben` bietet die Zentrale Ihr Heimnetz im Tailnet
von Mitdenkhaus an:

- Das Heimnetz erkennt das Add-on selbst (Netz mit Router); `heimnetz`
  überschreibt das bei Bedarf.
- Jede Zentrale hat eine eigene Standort-Nummer (`standort_id`). Tailscale
  verpackt das Heimnetz damit in einen eigenen Adressbereich („4via6“), so
  kommen sich gleiche Heimnetze verschiedener Kunden nicht in die Quere.
- Mitdenkhaus schaltet das Heimnetz im Tailnet nur für die Dauer einer Wartung
  frei; erreichbar ist es nur für Mitarbeiter von Mitdenkhaus, nie für andere
  Kunden.
- Für die Wartung stellt die Zentrale im Tailnet eine Liste der Geräte bereit,
  die sie im Heimnetz sieht (Adresse, Name, ob es eine Weboberfläche hat,
  Shelly-Modell).

Ohne diese Erlaubnis bietet das Add-on kein Heimnetz an und erstellt keine
Geräteliste.

## Optionen

Die Optionen setzt normalerweise die App.

| Option | Bedeutung |
| --- | --- |
| `authkey` | Einmal-Key vom Backend. Ist die Zentrale schon angemeldet, wird er ignoriert. |
| `hostname` | Name im Tailnet, z. B. `mdh-k7f3`. |
| `login_server` | Koordinationsserver, Standard `https://controlplane.tailscale.com`. |
| `tags` | Tags im Tailnet, Standard `tag:kunde`. |
| `heimnetz_freigeben` | Heimnetz für die Wartung anbieten, Standard aus. |
| `standort_id` | Eindeutige Standort-Nummer 1–65535, vergibt das Backend. |
| `heimnetz` | Heimnetz von Hand, z. B. `192.168.178.0/24` (nur private Netze /16–/30). |

## Fehlersuche

Im Protokoll des Add-ons:

- **„Nicht angemeldet und kein Auth-Key gesetzt.“** – Die Zentrale ist nicht
  (mehr) im Tailnet. Wartung in der App erneut erlauben.
- **„Anmeldung abgelehnt: … invalid key …“** – Der Key ist abgelaufen (1 Stunde)
  oder schon verwendet. Wartung in der App erneut erlauben.
- **„Das Gerät wartet auf Freigabe im Tailnet.“** – Im Tailnet ist
  Geräte-Freigabe aktiv; das Gerät in der Tailscale-Verwaltung freigeben.
