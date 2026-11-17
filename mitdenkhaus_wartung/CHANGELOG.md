# Änderungen

## 0.2.0

- Heimnetz-Freigabe (Option `heimnetz_freigeben`, standardmäßig aus): Das
  Heimnetz wird über Tailscale 4via6 mit der Standort-Nummer `standort_id`
  angeboten. Gleiche Heimnetze verschiedener Kunden kollidieren so nicht.
- Geräteliste im Tailnet unter `http://<zentrale>:8099/geraete.json`
  (Name, Weboberfläche, Shelly-Modell), nur mit erlaubter Freigabe.

## 0.1.0

- Erste Version.
