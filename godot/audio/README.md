# Aufnahmen

Das Spiel erzeugt seine Klänge sonst im Code (`scripts/sfx.gd`, `scripts/ambience.gd`). Hier liegt, was das Team als echte Aufnahme haben wollte.

| Datei | Wofür | Herkunft |
|---|---|---|
| `mensa_canteen.wav` | Raumklang der Mensa (`FILES` in `scripts/ambience.gd`, Raumart `canteen`) | Aufnahme «20131210 people eating in the canteen» (Zoom H2n), von Liam am 11.10.2026 als `freesound_community-20131210_people-eating-in-the-canteen_zoomh2nxy-33223.mp3` heruntergeladen (dem Dateinamen nach von Pixabay, Konto «freesound_community», ursprünglich Freesound). Lizenz vor einer Veröffentlichung des Spiels auf der Seite der Aufnahme nachprüfen |

Bearbeitet: 15.4 s auf 14.3 s gekürzt und die letzte Sekunde über die erste geblendet, damit die Schleife keinen Sprung hat; 24 kHz, Stereo, 16 Bit. Die Lautstärke stellt `ambience.gd` ein (`KINDS`, `canteen`), nicht die Datei.

Neue Aufnahme einhängen: als 16-Bit-WAV mit dem üblichen 44-Byte-Kopf hierher legen, in `FILES` eintragen, in `KINDS` als Teppich nennen, und in `FALLBACK` sagen, was läuft, wenn die Datei fehlt.
