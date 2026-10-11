# Aufnahmen

Das Spiel erzeugt seine Klänge sonst im Code (`scripts/sfx.gd`, `scripts/ambience.gd`). Hier liegt, was das Team als echte Aufnahme haben wollte.

| Datei | Wofür | Herkunft |
|---|---|---|
| `mensa_canteen.wav` | Raumklang der Mensa (`FILES` in `scripts/ambience.gd`, Raumart `canteen`) | Aufnahme «20131210 people eating in the canteen» (Zoom H2n), von Liam am 11.10.2026 als `freesound_community-20131210_people-eating-in-the-canteen_zoomh2nxy-33223.mp3` heruntergeladen (dem Dateinamen nach von Pixabay, Konto «freesound_community», ursprünglich Freesound). Lizenz vor einer Veröffentlichung des Spiels auf der Seite der Aufnahme nachprüfen |
| `kitchen_cooking.wav` | Küche am Polyball (Raumart `kitchen`): es brutzelt durchgehend | von Liam am 11.10.2026 als `justsomesounds-cooking-sound-442650.mp3` heruntergeladen (dem Dateinamen nach von Pixabay, Konto «justsomesounds»). Lizenz vor einer Veröffentlichung nachprüfen |
| `kitchen_clatter.wav` | Küche am Polyball: einzelne Geräusche (Geschirr, Hantieren) mit Stille dazwischen | von Liam am 11.10.2026 als `freesound_community-kitchen-29815.mp3` heruntergeladen (dem Dateinamen nach von Pixabay, Konto «freesound_community», ursprünglich Freesound). Lizenz vor einer Veröffentlichung nachprüfen |

Mensa: 15.4 s auf 14.3 s gekürzt und die letzte Sekunde über die erste geblendet, damit die Schleife keinen Sprung hat; 24 kHz, Stereo, 16 Bit. Die Lautstärke stellt `ambience.gd` ein (`KINDS`, `canteen`), nicht die Datei.

Küche, Lautstärke (so abgestimmt, dass man beides hört und nichts erschrickt):
- `kitchen_cooking.wav` war sehr leise (Effektivwert −39 dBFS) und in der ersten Hälfte 10 dB lauter als in der zweiten. Jetzt gleichmässig auf −22 dBFS gehoben (Verstärkung folgt dem Pegel in Fenstern von 0.4 s, höchstens +32 dB), Spitzen weich bei −3 dBFS begrenzt, 0.6 s überblendet: Schleife 6.3 s, Mono.
- `kitchen_clatter.wav` besteht aus einzelnen lauten Momenten (bis −20 dBFS) und fast Stille dazwischen (−60). Die Stille bleibt, das Ganze ist um 5.8 dB gehoben, Spitzen weich bei −2 dBFS begrenzt. Die Schleife beginnt in der leisesten halben Sekunde der Aufnahme (bei 22.8 s), deshalb braucht sie keine Überblendung: 26.2 s, Stereo.
- Im Spiel (`KINDS`, `kitchen` in `ambience.gd`): beide bei −19 dB, das Brutzeln liegt damit am Ausgang um −31 dB, die lauten Momente des Geschirrs um −24 dB; im Schnitt etwas unter der Mensa (−27 dB), die Musik des Balls ist in der Küche nur ein fernes Wummern darunter.

Neue Aufnahme einhängen: als 16-Bit-WAV mit dem üblichen 44-Byte-Kopf hierher legen, in `FILES` eintragen, in `KINDS` als Teppich nennen, und in `FALLBACK` sagen, was läuft, wenn die Datei fehlt.
