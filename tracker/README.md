# Kamera- und Mikrofon-Tracking

Damit Minigames sehen und hören können: Gesichter, Hände und Körperhaltung über die Webcam, Pusten über das Mikrofon. Hier liegt nur das Fundament, die Minigames selbst entstehen in den Levels.

- **Kamera:** `tracker.py` läuft als zweiter Prozess neben dem Spiel, erkennt mit [MediaPipe](https://developers.google.com/edge/mediapipe/solutions/guide) (Google, Apache-2.0) Gesicht, Hand und Körper und schickt die Ergebnisse per UDP ans Spiel.
- **Mikrofon:** braucht kein Paket, das macht Godot selbst.
- **Im Spiel** ist beides über den Autoload `Track` erreichbar (`godot/scripts/tracking.gd`), fertige Auswertungen stehen in `godot/scripts/track_math.gd`.

## Einmal einrichten

1. [uv](https://docs.astral.sh/uv/) installieren: macOS `brew install uv`, Windows `winget install astral-sh.uv`.
2. Einmal von Hand starten, solange es Internet gibt:

```bash
uv run tracker/tracker.py --selftest
```

Das lädt Python-Pakete (ca. 120 MB) und drei Modelle (17 MB, nach `tracker/models/`) und meldet am Ende `RESULT ok`. Danach geht alles ohne Internet. **Auf dem Demo-Laptop vorher machen.** Steht dort `camera FAILED`, fehlt dem Terminal die Kamera-Freigabe; geladen ist trotzdem alles, und das Spiel fragt später selbst nach der Freigabe.

Ohne uv geht es auch: `python -m venv tracker/.venv`, dann `tracker/.venv/bin/pip install mediapipe==1.1.0` (Windows: `tracker\.venv\Scripts\pip`). Das Spiel findet diese `.venv` selbst.

Mehr ist nicht nötig: Das Spiel startet den Tracker, sobald ein Minigame ihn braucht, und beendet ihn wieder. Beim ersten Mal fragt das Betriebssystem, ob Godot Kamera und Mikrofon benutzen darf.

## Ausprobieren

```bash
godot --path godot res://track_debug.tscn
```

Zeigt das Kamerabild mit allem, was erkannt wird, und alle Werte live. Tasten: `1` Gesicht, `2` Hände, `3` Körper, `M` Mikrofon, `F` Köpfe einfrieren (Bewegung in cm), `P` Zielpose speichern, `Esc` beenden. Im Editor: Szene öffnen und F6.

Nur der Tracker, ohne Spiel, mit eigenem Fenster:

```bash
uv run tracker/tracker.py --show --want face,hand,pose
```

## Im Spiel benutzen

```gdscript
const TM = preload("res://scripts/track_math.gd")

func _ready() -> void:
	Track.use(self, ["face"])     # "face", "hand", "pose", auch mehrere
```

- `Track.use(self, [...])` gilt, solange der Node im Baum ist. Wird das Minigame geschlossen, geht die Kamera von selbst wieder aus.
- `Track.face(pid)`, `Track.hand(pid)`, `Track.pose(pid)` liefern, was in der Bildhälfte dieser Person zu sehen ist: **P1 sitzt links, P2 rechts**. Ist dort nichts, kommt `{}`. Bei Gesichtern und Körpern zählen dabei nur die beiden grössten im Bild, damit Zuschauer hinter den Spielenden nicht übernehmen. Mit `-1` kommt, was der Bildmitte am nächsten ist (eine Person allein).
- `Track.faces`, `Track.hands`, `Track.poses` sind alle Treffer, von links nach rechts.
- Wer ist wer, wenn die Leute nicht brav auf ihrer Seite sitzen oder Zuschauer im Bild stehen: Der Tracker meldet bis zu vier Personen. `TM.front(liste, n)` liefert die n grössten Einträge von links nach rechts, also die, die der Kamera am nächsten sind. `TM.mine(Track.faces, pid)` nimmt von den beiden grössten den in der Bildhälfte der Person und sonst den einzigen (wer allein spielt, sitzt selten auf «seiner» Seite). `TM.pair(Track.poses)` liefert für etwas, das beide gleichzeitig tun, `[Person 1, Person 2]`: die beiden grössten, links und rechts.
- Die Daten der Kamera sind unruhig: Punkte zittern, Leute fehlen für einzelne Bilder, und bei mehreren Personen ist die Reihenfolge nicht fest. Wer etwas davon anzeigt, sollte glätten und kurze Aussetzer überbrücken. Ein fertiges Beispiel ist die Klasse `Followed` in `godot/scripts/level3/kamera_spiel.gd`.
- Ein Kamera-Minigame, das den Bildschirm deckend füllt, sollte die Karte dahinter solange nicht zeichnen lassen. Sie kostet fast das ganze Bild (auf einem MacBook Pro läuft das Spiel deswegen mit etwa 37 Bildern pro Sekunde), und das Kamerabild stottert dann im selben Takt. Vorbild: `_cover` in `godot/scripts/level3/level.gd` (Tanzen damit 120 statt 32 Bilder pro Sekunde).
- `Track.preview` ist das Kamerabild als Textur (gespiegelt, 240 Pixel hoch, in der Form des Kamerabilds; `Track.aspect` ist Breite durch Höhe), zum Beispiel für ein `TextureRect`. Es kommt mit jedem Kamerabild neu, also etwa 30-mal pro Sekunde.
- `Track.alive` ist `true`, solange Ergebnisse ankommen. `Track.status` ist ein kurzer Text dazu («Kamera startet …», «läuft», «keine Kamera …»).
- Alle Positionen sind 0 bis 1 im gespiegelten Bild: x = 0 links, y = 0 oben. Wer die Hand nach rechts bewegt, bewegt den Punkt nach rechts.

**Jedes Kamera-Minigame braucht eine Tasten-Variante.** Ohne Kamera, ohne Freigabe oder ohne Tracker bleibt `Track.alive` auf `false`. Nach dem Öffnen etwa 5 Sekunden warten (der erste Start dauert), dann auf Tasten umschalten, so wie das Legi-Foto ohne Kamera eine gezeichnete Figur nimmt.

### Was in den Daten steht

| | Feld | Bedeutung |
|---|---|---|
| Gesicht | `x`, `y` | Nasenspitze |
| | `box` | `[x, y, Breite, Höhe]` |
| | `eyes` | Mitte der Augen: eigenes linkes, dann rechtes |
| | `yaw`, `pitch`, `roll` | Kopf in Grad: nach rechts drehen +, nach oben +, nach rechts neigen + (alles wie im Bild gesehen) |
| | `blink_l`, `blink_r` | 0 = Auge offen, 1 = zu (eigenes linkes / rechtes) |
| | `look_x`, `look_y` | Blickrichtung der Augen, grob: rechts +, unten + |
| | `mouth` | 0 = Mund zu, 1 = weit offen |
| | `cm_per_x`, `cm_per_y` | Massstab: so viele cm entspricht die ganze Bildbreite / Bildhöhe auf Höhe des Gesichts |
| Hand | `x`, `y` | Spitze des Zeigefingers |
| | `palm` | Mitte der Handfläche `[x, y]` |
| | `pinch` | Abstand Daumen–Zeigefinger, geteilt durch die Handgrösse: ca. 0,1 zusammen, über 1 weit offen |
| | `open` | ca. 1 = Faust, ca. 2 = flache Hand |
| | `side` | `"L"` oder `"R"` |
| | `pts` | alle 21 Punkte `[x, y]` ([Nummern](https://developers.google.com/edge/mediapipe/solutions/vision/hand_landmarker)) |
| Körper | `x`, `y` | Mitte zwischen den Schultern |
| | `pts` | alle 33 Punkte `[x, y, Sichtbarkeit]` ([Nummern](https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker)) |

### Mikrofon

```gdscript
Track.use_mic(self)
# danach jeden Frame:
Track.blow       # 0 bis 1, wie stark gepustet wird
Track.blowing    # true / false
```

## Rezepte für die geplanten Minigames

**L1 Passfoto** (Pose nachstellen). Zielpose in `track_debug` hinstellen, `P` drücken, den Inhalt von `pose_target.json` als Konstante ins Level kopieren. Wer an der Tastatur sitzt, ist für die Kamera eines Laptops zu nah: Im Bild sind nur Kopf und Schultern. Für Posen muss man zurückrücken, bis die Arme im Bild sind, und zu zweit teilt man sich die Breite. Erfahrungen und Messwerte dazu stehen in `godot/scripts/level3/README.md` (Tanzfläche); dort wird auch erklärt, warum `pose_match` allein eine falsche Pose schlecht von einer richtigen trennt.

```gdscript
Track.use(self, ["pose"])
var a := TM.pose_match(Track.pose(0), TARGET, Track.aspect)   # 0 bis 100
var b := TM.pose_match(Track.pose(1), TARGET, Track.aspect)
if minf(a, b) > 80.0: ...   # beide treffen die Pose
```

**P3 Kabelsalat** (in die Luft greifen). Die Hand ist der Zeiger, zusammengedrückte Finger halten fest.

```gdscript
Track.use(self, ["hand"])
var h := Track.hand(pid)
if not h.is_empty():
	var zeiger := TM.pointer(h, Rect2(Vector2.ZERO, canvas.size))
	var greift := TM.pinch01(h) < 0.25
```

**C3 Pipetten-Panik** (Kolben mit zwei Fingern, Zittern verschüttet).

```gdscript
var jitter := TM.Jitter.new()            # eines pro Person behalten
var h := Track.hand(pid)
if not h.is_empty():
	kolben = TM.pinch01(h)               # 0 = gedrückt, 1 = offen
	if jitter.push(Vector2(h["palm"][0], h["palm"][1]), delta) > LIMIT: ...   # zittert
```

Die Messung zittert auch bei ruhiger Hand, weiter weg von der Kamera stärker. `LIMIT` deshalb so bestimmen: in `track_debug` aus Spielabstand den Wert «Zittern» einer ruhigen Hand ablesen und deutlich darüber gehen.

**D1 Kamerakaraoke** (nicht blinzeln, nicht wegschauen). Einen genauen Punkt auf dem Bildschirm fixieren lässt sich mit einer Webcam nicht prüfen, wegschauen schon.

```gdscript
Track.use(self, ["face"])
var f := Track.face(pid)
if TM.eyes_closed(f) or TM.looking_away(f): ...   # erwischt
```

**F1 Rotlicht-Grünlicht** (stillhalten).

```gdscript
frozen = Track.face(pid).duplicate()              # in dem Moment, in dem sich der Professor umdreht
if TM.moved_cm(Track.face(pid), frozen) > 2.0: ...   # bewegt
```

**G2 Der Professor fragt** (nicken oder Kopf schütteln).

```gdscript
var ns := TM.NodShake.new()                       # eines pro Person behalten
match ns.push(Track.face(pid), delta):
	"nod": ...
	"shake": ...
```

Soll die gefilmte Person die Frage nicht sehen: Sie muss die Augen schliessen, solange die Frage auf dem Bildschirm steht, geprüft mit `TM.eyes_closed`.

**P4 Nicht abstürzen / C1 Blubber-Alarm** (pusten).

```gdscript
Track.use_mic(self)
temperatur -= Track.blow * 30.0 * delta
```

## Stellschrauben

Alle Schwellen stehen als Konstanten oben in den Dateien und sind Startwerte. Im Spieltest mit `track_debug` einstellen.

| Wo | Konstante | Wirkung |
|---|---|---|
| `track_math.gd` | `BLINK_AT` 0.5 | ab wann ein Auge als zu gilt |
| | `PINCH_CLOSED` 0.15, `PINCH_OPEN` 1.0 | welcher Fingerabstand 0 und welcher 1 ist |
| | `FIST_AT` 1.25 | ab wann die Hand eine Faust ist |
| | `LOOK_AWAY` 0.45, `HEAD_AWAY` 25° | ab wann jemand wegschaut |
| | `POSE_TOLERANCE` 55° | wie streng die Pose bewertet wird, kleiner = strenger |
| | `NodShake.SWING` 7°, `TURNS` 3, `WINDOW` 1.6 s | wie deutlich und wie schnell genickt werden muss |
| | `Jitter.WINDOW` 0.4 s | über welche Zeit das Zittern gemessen wird |
| `tracking.gd` | `BLOW_DB_MIN` −45, `BLOW_DB_MAX` −15 | welche Lautstärke 0 und welche 1 ist |
| | `BLOW_OVER_VOICE` 6 dB | wie viel lauter die tiefen Töne sein müssen als die Stimme (unterscheidet Pusten von Reden) |
| | `BLOW_ON` 0.35, `BLOW_OFF` 0.2 | ab wann `blowing` an- und ausgeht |

Die Messwerte zittern von selbst um einige Millimeter. Für Rotlicht-Grünlicht und die Pipette also nicht zu knapp einstellen.

## Wenn es nicht läuft

- **`Track.status` bleibt auf «Kamera startet …»:** Erster Start, uv lädt noch Pakete. Einmal `uv run tracker/tracker.py --selftest` von Hand laufen lassen.
- **«keine Kamera (Zugriff erlaubt?)»:** macOS: Systemeinstellungen, Datenschutz & Sicherheit, Kamera, Godot einschalten (wer Godot aus dem Terminal startet: das Terminal). Windows: Einstellungen, Datenschutz, Kamera. Oder ein anderes Programm hält die Kamera fest.
- **Falsche Kamera:** Auf dem Mac nimmt der Tracker von selbst die eingebaute Kamera und nicht ein iPhone, das sich als Kamera anbietet. `uv run tracker/tracker.py --list-cameras` zeigt, welche Kameras es gibt und welche genommen wird. Eine andere wählen: Umgebungsvariable `VISCON_CAMERA` setzen, bevor Godot startet, oder beim Start von Hand `--camera`, je mit einer Nummer oder einem Teil des Namens (`VISCON_CAMERA=iPhone`). Unter Windows und Linux gibt es keine Namen, dort gilt Kamera 0, sonst die Nummer angeben. In `track_debug` steht oben, welche Kamera läuft.
- **«kein Tracker»:** Weder uv noch eine `tracker/.venv` gefunden. Ein eigenes Python lässt sich mit der Umgebungsvariable `VISCON_PYTHON` angeben.
- **Pusten reagiert nicht:** `M` in `track_debug` zeigt die rohen Pegel. Steht «tief» fest auf −80 dB, liefert das Mikrofon nichts (Freigabe für Godot, oder `audio/driver/enable_input` fehlt in `project.godot`).
- **Mac mit Intel-Prozessor:** Für `mediapipe` 1.1.0 gibt es dort kein fertiges Paket. In der Kopfzeile von `tracker.py` eine ältere Version eintragen.
- **Exportiertes Spiel:** Der Ordner `tracker/` muss neben der ausführbaren Datei (macOS: neben der `.app`) liegen.

## Testen ohne Kamera

`--fake bild.jpg` nimmt ein Standbild statt der Kamera. Zuerst den Tracker so starten, dann das Spiel: Es benutzt einen Tracker, der schon läuft, statt selbst einen zu starten. Ein Tracker, der von Hand gestartet wurde, läuft nach dem Spielende weiter.

```bash
uv run tracker/tracker.py --fake foto.jpg
```

## Wie es gebaut ist

- UDP nur auf `127.0.0.1`. Das Spiel hört auf Port 47800, der Tracker auf 47801.
- Das Spiel schickt alle 0,5 s, was es braucht: `{"want": ["face"], "preview": true}`. Bleibt das 3 s aus, lässt der Tracker die Kamera los; nach 20 s beendet er sich, wenn das Spiel ihn gestartet hat.
- Der Tracker schickt pro Kamerabild ein Paket: erstes Byte `J`, dann JSON. Die Vorschau kommt getrennt: erstes Byte `P`, dann ein JPEG, höchstens 15 pro Sekunde.
- Die Kamera ist nur an, solange jemand `Track.use` hält. Das Legi-Foto im Menü benutzt die Kamera über Godot selbst und gibt sie vorher wieder frei.
- Vor dem ersten `Track.use` läuft nichts davon und kostet nichts.

## Spracherkennung (`speech.py`)

Für Minigames, in denen man laut antwortet (Wahlfach Freelancing). Whisper (faster-whisper, Modell `base`, etwa 150 MB) läuft offline in einem eigenen Prozess; das Spiel nimmt das Mikrofon selbst auf und schickt nur den Pfad einer WAV-Datei (UDP, localhost, Ports 47802 und 47803).

Einrichten, einmal pro Rechner (eine der beiden Arten):

```bash
uv run tracker/speech.py --selftest          # mit uv: lädt Pakete und Modell selbst
python3 -m venv tracker/.venv && tracker/.venv/bin/pip install faster-whisper==1.1.1 requests && tracker/.venv/bin/python tracker/speech.py --selftest
```

Das Spiel sucht den Prozess in derselben Reihenfolge wie den Kamera-Tracker: `VISCON_SPEECH_PYTHON`, `VISCON_PYTHON`, `tracker/.venv`, `uv`, `python3`. Achtung: Liegt in `tracker/.venv` nur Whisper, startet der Kamera-Tracker dort nicht und versucht danach von selbst `uv`.

Im Spiel: `scripts/speech.gd` als Kind-Node anhängen, `begin()` beim Drücken, `finish(prompt)` beim Loslassen, das Signal `heard(id, text)` liefert den Text. `is_ready`, `failed` und `state` für die Anzeige, `level` (0 bis 1) für eine Pegelanzeige. Ohne Spracherkennung bleibt `failed` wahr: dann eine Tastenvariante anbieten.

`--model small` erkennt Deutsch besser, ist aber langsamer (etwa 500 MB). `prompt` mit Wörtern, die in der Antwort vorkommen können, hilft Whisper bei Namen und Fachwörtern.
