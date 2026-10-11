# Wahlfach · Ersti-Fest (Level 18)

Wahlfach für zwei (`"block": "W"`), nicht Teil der Story: Es steht im Leistungsüberblick unter «Wahlfächer» und wird nur von dort gestartet. Das Ersti-Fest des VSETH in der Mensa ist ausverkauft. Die beiden schmuggeln sich zu zweit in einem Mantel am Türsteher vorbei, kapern das DJ-Pult und spielen dort gegeneinander, und zum Schluss gibt es ein Dance-Battle vor der Kamera.

Die Nummer 18 ist frei gewählt (19 ist Freelancing, 20 Skifahren). Umnummerieren: Ordner umbenennen, mehr hängt nicht an der Zahl (die Skripte laden sich mit relativen Pfaden).

## So spielt es sich

- **Ladebildschirm:** der vom Hönggerberg bei Nacht aus Level 5 (`"sky": "night"`, `"ride": "ethlink"` in `DEF`), ohne das runde Motiv (`"motif": false`, neuer Schalter in `scripts/loading_screen.gd`). Beides Wunsch des Teams.
- **Start** auf der Polyterrasse vor der Mensa, abends. Vor der Tür hängt eine Kordel, davor steht der Türsteher, links wartet eine Schlange. Wer ihn anspricht, hört «Ausverkauft» und den Hinweis auf die Garderobe.
- **Aufgabe 1, Reinkommen (zusammen):** An der Garderobe rechts neben dem Eingang (Raute) steigen die beiden in einen langen Mantel, eine Person auf den Schultern der anderen. Wer die Taste drückt, ist die Beine; die andere muss daneben stehen (`PARTNER_DIST`). Im Spiel `sneak_game.gd` hält die Bein-Person «rechts» gedrückt und läuft, die obere lehnt mit links und rechts gegen das Schwanken. Jeder Schritt bringt den Turm ins Wanken; kippt er weiter als `TIP` Grad, purzeln beide aus dem Mantel, der Türsteher lacht, es zählt als Fehler, und sie fangen ein Stück weiter hinten wieder an. An der Tür nickt der Türsteher sie durch, die Kordel geht auf, und beide stehen in der Mensa.
- **Aufgabe 2, DJ-Pult kapern (gegeneinander):** Hinten in der Mensa steht das DJ-Pult. Beide müssen dort sein, dann öffnet die Interaktionstaste das DJ-Battle (`dj_game.gd`): Der Hintergrund ist das DJ-Pult mit beiden Figuren dahinter, links und rechts fallen je vier Spuren mit Noten herunter. P1 spielt A S W D, P2 die Pfeiltasten (links, unten, oben, rechts), beide bekommen dieselben Noten. Wer die Taste drückt, wenn die Note auf der Linie ist, bekommt Punkte: je genauer, desto mehr (PERFEKT 100, GUT 60, OK 30), und eine Serie ohne Fehler gibt bis zu doppelte Punkte. Nach 30 Sekunden steht fest, wer besser auflegt.
- **Aufgabe 3, Dance-Battle (gegeneinander, Kamera):** In der Mitte der Tanzfläche (Raute), wieder zu zweit. In `dance_game.gd` tanzen die beiden abwechselnd allein vor der Webcam: 3 Runden, jede Person 5 Sekunden pro Runde, mit 3 Sekunden Countdown davor. Wer das Battle startet, tanzt zuerst. Nach jedem Tanz gibt es eine Note von 0 bis 10: je verrückter, desto höher. Rechts steht die Tabelle mit allen Runden, am Schluss gewinnt die höhere Summe.
- **Ende:** Sind alle drei Aufgaben erledigt, ist das Wahlfach bestanden, egal wer die Battles gewonnen hat. Eine kurze Schlussszene nennt beide Resultate und die «Legende des Ersti-Fests» (wer mehr Battles gewonnen hat, sonst «Unentschieden»). Zeitlimit 15 Minuten, verlieren kann man nur über die Zeit.
- Alle drei Spiele lassen sich mit Esc / Backspace verlassen und danach am selben Ort wieder öffnen.

## Wie «verrückt» gemessen wird (`dance_game.gd`)

Gemessen, nicht beurteilt. Getanzt wird allein: Es zählt, wer der Kamera am nächsten ist (`TM.front(Track.poses, 1)`). Alles wird in Schulterbreiten gerechnet, damit der Abstand zur Kamera egal ist.

| Anteil | Was | Voll bei |
|---|---|---|
| `W_ENERGY` 65 % | Tempo: Mittel der `TOP` 5 schnellsten Punkte (von Nase, Ellbogen, Handgelenken, Knien, Knöcheln), gemittelt über die ganzen 5 Sekunden, in Schulterbreiten pro Sekunde. Sind weniger als 5 im Bild, zählen die fehlenden als 0 | `E_FULL` 5.5 |
| `W_REACH` 20 % | Raum: wie gross das Feld ist, das jede Hand überstreicht (Mittel beider Hände, Schulterbreiten im Quadrat) | `REACH_FULL` 6 |
| `W_TRAVEL` 15 % | Weg: wie weit sich der Körper selbst bewegt (Schultermitte) | `TRAVEL_FULL` 1.8 |

- Die drei Anteile zusammen (0 bis 1) werden mit `CURVE` 1.4 potenziert und geben mal 10 die Note: Mittelmässiges fällt dadurch tiefer aus. **Eine 10 braucht alle drei gleichzeitig und über den ganzen Tanz**, also etwa: beide Arme kreisen ganz, rund einmal pro Sekunde, und der Körper springt dazu hin und her.
- Raum und Weg zählen keine einzelnen Ausreisser: Von allen Bildern werden an beiden Enden `TRIM` 10 % weggelassen (`_span`). Vorher war es der Kasten um alles, was je gesehen wurde, und ein einziges Bild, in dem die Kamera eine Hand in die Ecke setzt, gab vollen Raum. Eine gehaltene Pose gibt nichts.
- Zeit, in der niemand im Bild ist, zählt als Stillstand. Punkte, bei denen sich die Kamera unsicher ist (`MIN_VIS`), zählen nicht; ein einzelner Sprung der Kamera ist bei `SPEED_CAP` gedeckelt.
- Was die Rechnung mit künstlichen Skeletten ergibt (30 Bilder pro Sekunde, keine echte Kamera):

| Tanz | Tempo | Raum | Weg | Note |
|---|---|---|---|---|
| steht, Arme hängen | 0.2 | 0.0 | 0.1 | 0.1 |
| Arme schwingen 50 Grad, 1.2 mal pro Sekunde | 2.3 | 0.5 | 0.4 | 2.0 |
| Arme schwingen 90 Grad, 1.2 mal pro Sekunde, wippt | 4.2 | 1.2 | 0.7 | 4.8 |
| beide Arme kreisen ganz, 0.7 mal pro Sekunde, hüpft | 4.9 | 8.0 | 1.0 | 8.1 |
| beide Arme kreisen ganz, 1 mal pro Sekunde, springt hin und her | 6.2 | 7.8 | 1.8 | 10.0 |
| grosse Pose, still gehalten | 0.0 | 0.0 | 0.0 | 0.0 |
| steht, die Kamera setzt eine Hand ab und zu in die Ecke | 0.4 | 0.0 | 0.1 | 0.2 |

- Das eingezeichnete Skelett ist geglättet (`SMOOTH`) und bleibt `HOLD` Sekunden stehen, wenn die Kamera die Person kurz verliert. Der Balken «Verrücktheit» zeigt die Bewegung im Moment.
- **Tasten-Variante** (Regel des Teams): Kommt nach `CAM_WAIT` Sekunden kein Kamerabild, oder meldet `Track` «kein Tracker» bzw. «keine Kamera», tanzt die Figur auf den Tasten der Person, die dran ist. Jede neue Taste gibt 1 Punkt, dieselbe nochmals `KEY_SAME`, `KEY_FULL` Punkte sind eine 10. `K` schaltet während des Countdowns von Hand um.
- Das Level weckt die Kamera schon nach dem DJ-Battle (`Track.use(self, ["pose"], false)`), damit sie bereit ist, wenn die beiden auf der Tanzfläche ankommen, und gibt sie nach dem Dance-Battle wieder frei.
- Einmal pro Rechner einrichten wie für die anderen Kamera-Spiele: siehe `tracker/README.md` (`uv run tracker/tracker.py --selftest`).

## Dateien

| Datei | Inhalt |
|---|---|
| `level.gd` | `DEF`, Umbau der Mensa zum Club (`build_map`), Türsteher, DJ, Gäste, die drei Aufgaben (`_use_rack`, `_use_dj`, `_use_floor`), Schlussszene (`finale`), zeichnet Nacht, Lichterkette, Neonschrift, Tanzfläche und Möbel |
| `sneak_game.gd` | zu zweit im Mantel am Türsteher vorbei |
| `dj_game.gd` | DJ-Battle |
| `dance_game.gd` | Dance-Battle mit Kamera oder Tasten |
| `fest_person.gd` | Türsteher, DJ und Gäste (tanzen im Takt, kleine Sprechblase) |
| `fest_sfx.gd` | der Beat (Schleife mit 120 BPM) und die Geräusche, alles im Code erzeugt |
| `en.gd` | Englisch für alle Texte des Levels. Wortwahl (Wunsch des Teams): Ersti bleibt Ersti, das Fest heisst «Ersti Fest (ESF)» |

Raumklang (`scripts/ambience.gd`): Draussen läuft der Nachtklang des Spiels (Wind, Grillen, Eule), in der Mensa nichts davon, dort macht `fest_sfx.gd` den Beat; Musik von aussen ist für das Level abgestellt (`"ambience"` in `DEF`).

Die Mensa wird in `build_map` leergeräumt (Theke und Tische weg) und bekommt eigene Möbel (`l18_*`), die das Level selbst zeichnet. Die Nacht ist ein dunkles Blatt, das `level.gd` über die Tageskarte und unter die Figuren legt (`z_index = -5`). Solange eines der drei Spiele offen ist, wird die Karte dahinter nicht neu gezeichnet (`_open` / `_close`).

## Stellschrauben

| Wo | Konstante | Wirkung |
|---|---|---|
| `level.gd` | `REACH`, `PARTNER_DIST` | wie nah man an einem Ort bzw. an der anderen Person stehen muss |
| `sneak_game.gd` | `WALK` | Tempo im Mantel (Anteil des Wegs pro Sekunde) |
| | `TIP` | Neigung in Grad, bei der beide umfallen |
| | `WOBBLE`, `STEP_PUSH`, `GRAVITY` | wie stark der Turm schwankt: im Stand, pro Schritt, und je schiefer desto schneller |
| | `STEER`, `DAMP` | wie stark die obere Person dagegenhalten kann |
| | `BACK` | wie weit zurück es nach einem Sturz geht |
| `dj_game.gd` | `SONG`, `FALL` | Länge des Battles, Fallzeit einer Note |
| | `HITS` | Zeitfenster und Punkte für PERFEKT, GUT, OK |
| | `COMBO_STEP`, `COMBO_GAIN`, `COMBO_MAX` | Bonus für Serien |
| | `ON_BEAT`, `OFF_BEAT` | wie dicht die Noten kommen |
| `dance_game.gd` | `ROUNDS`, `DANCE_TIME`, `READY_TIME` | 3 Runden zu 5 Sekunden, Countdown |
| | `E_FULL`, `REACH_FULL`, `TRAVEL_FULL`, `W_*` | was als völlig verrückt gilt und wie viel es zählt |
| | `TOP`, `TRIM`, `SPEED_CAP`, `MIN_VIS` | wie viele Punkte das Tempo bestimmen, wie viele Ausreisser wegfallen, was als Fehler der Kamera gilt |
| | `CURVE` | wie streng die Mitte bewertet wird (1 = linear, grösser = strenger) |
| | `KEY_FULL`, `KEY_SAME` | Tasten-Variante |

## Geprüft und offen

Per Bot geprüft, zu Fuss mit echten Tastendrücken vom Startpunkt an, auf Deutsch und Englisch: Kordel hält, Türsteher antwortet, allein geht der Mantel nicht auf, im Mantel umfallen und danach bis zur Tür, DJ-Battle (eine Person trifft alles, die andere lässt jede dritte Note aus), Dance-Battle mit Tasten und mit künstlichen Kamera-Daten (eine Person wirbelt, die andere steht), Schlussszene bis zum Siegbildschirm.

Offen:
- Das Level ist von Menschen gespielt worden, mit echter Kamera (11.10.2026, «fast perfekt»). Das Dance-Battle wurde danach zweimal strenger gestellt («nur wirklich verrückte Bewegungen sollen eine 10 bekommen»): zuerst `E_FULL` 2.4 → 3.4, `REACH_FULL` 9 → 12, `TRAVEL_FULL` 1.6 → 2.2, `KEY_FULL` 40 → 50, `CURVE` 1.2; dann die Fassung oben (Tempo der 5 schnellsten Punkte, Raum pro Hand, Ausreisser weg, `KEY_FULL` 60, `CURVE` 1.4). **Die letzte Fassung ist nur mit künstlichen Skeletten gerechnet, vor der Kamera noch nicht ausprobiert.** Wenn niemand mehr über 6 kommt: `E_FULL` senken (4.5); wenn es immer noch 10er regnet: `E_FULL` erhöhen.
- Das DJ-Battle läuft nach der Uhr des Spiels, nicht nach der Tonausgabe. Hängt der Ton auf einem Rechner hörbar hinterher, `LEAD_IN` bzw. die Linie anpassen.
- Level 18 ist ein Wahlfach und setzt nichts aus anderen Levels voraus (keine Opps, keine Gegenstände).
