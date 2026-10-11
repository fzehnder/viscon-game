# Level 6 · Basisprüfung (Finale)

Das letzte Story-Level, nach Level 5 (Nacht am Hönggerberg). Computerprüfung in der Prüfungshalle im ONA-Gebäude: lange Fensterwand mit Sprossen, grüne Stahlstützen mit Diagonalstreben, Lüftungsrohre, Reihen von Pulten mit weissen Trennwänden und Bildschirmen. Der Streber sitzt neben ihnen, beide schreiben bei ihm ab, in der Ich-Perspektive: Jede Bildschirmhälfte ist das, was die Person sieht. **Die Kamera ist Pflicht.**

## So spielt es sich

1. **Cutscene:** Prüfungstag, nichts gelernt, aber der Streber sitzt zwischen euch.
2. **Kalibrierung:** Beide sitzen nebeneinander vor der Kamera (P1 links, P2 rechts), drehen den Kopf einmal zum Streber (P1 nach links, P2 nach rechts) und dann wieder nach vorne. Die Richtung kommt aus der Lage der Nasenspitze im Gesicht (im gespiegelten Bild wandert sie mit der Drehung mit, `_nose_turn`); erst wenn sie klar zum Streber zeigt, wird das Vorzeichen des Drehwinkels (`yaw`) festgelegt. Wer in die falsche Richtung dreht, sieht «Andere Richtung!». Ohne Kamera geht die Prüfung nicht los, der Bildschirm sagt, wie man den Tracker einrichtet.
3. **Spicken:** Kopf zum Streber drehen schwenkt den Blick über die Trennwand auf seinen Bildschirm, der eigene Monitor wandert aus dem Bild. Voll hinübergedreht füllt sich das Gedächtnis (Sprechblase). Kopf wieder nach vorne tippt es ein. Acht Antworten pro Person. Jede Hälfte zeigt klein das eigene Kamerabild; wer aus dem Bild verschwindet, sieht «Nicht im Bild!» und kann nicht lesen.
4. **Zwei Wächter, rotes Licht, grünes Licht:**
   - **Der Streber** schreibt, zuckt (gelbes «?») und schaut nach links oder rechts. Man sieht ihn am Bildrand auch beim Geradeausschauen.
   - **Die Aufsicht** vorne steht ab und zu auf (gelbes «?») und schaut dann in die Halle (rotes «!», Lichtkegel). Sie sieht beide.
   - Wer mit gedrehtem Kopf gesehen wird, ist erwischt, und **die Prüfung ist für beide vorbei.**
5. **Es wird immer schwerer** (Balken «Alarm» oben in der Mitte): kürzere Warnung, häufigere Blicke, ab einem Drittel blufft der Streber, ab knapp der Hälfte schaut er auch zweimal nacheinander, die Aufsicht steht öfter auf. Der Streber schaut öfter zu der Person, die mehr hinüberschaut. Wer hinüberschaut, während er zur anderen Seite dreht, ist ein Beinahe-Erwischt: Der Alarm steigt, und es kostet eine Viertelnote.
6. **Geschafft**, wenn beide acht Antworten haben: Cutscene mit den Noten, Siegbildschirm, Ende der Story. **Erwischt** oder **Zeit um** (4:00): Verloren-Bildschirm, R versucht es nochmals.

Für Tests ohne Kamera gibt es das Startargument `--exam-keys` (P1 hält A, P2 hält Pfeil rechts): `godot --path godot res://main.tscn -- --level=6 --exam-keys`.

## Stellschrauben (oben in `exam.gd`)

| Konstante | Wert | Wirkung |
|---|---|---|
| `ANSWERS` | 8 | Antworten pro Person |
| `READ_RATE`, `WRITE_RATE` | 0.3, 0.6 pro s | wie schnell Lesen und Eintippen gehen (Lesen langsam = länger im Risiko) |
| `EXAM_TIME` | 240 s | Prüfungszeit |
| `CALIB_DEG`, `CALIB_NOSE` | 12°, 0.08 | Kalibrierung: so weit drehen, Nase so weit (Anteil der Gesichtsbreite) Richtung Streber |
| `LOOK_DEG`, `FORWARD_DEG` | 26°, 8° | Kopfdrehung für voll hinüber und nach vorne |
| `READ_FROM`, `WRITE_BELOW`, `SEEN_FROM` | 0.8, 0.2, 0.35 | ab welchem Blickwinkel (0 bis 1) gelesen, getippt, erwischt wird |
| `WRITE_TIME`, `TELL_TIME`, `GLANCE_TIME` | 3.5–6 s, 0.8→0.3 s, 1.5–2.6 s | Rhythmus des Strebers (Warnzeit sinkt mit dem Alarm) |
| `ALERT_TIME`, `NEAR_ALERT` | 90 s, 0.15 | wie schnell der Alarm steigt, Zuschlag pro Beinahe-Erwischt |
| `FAKE_FROM`, `DOUBLE_FROM` | 0.3, 0.45 | ab welchem Alarm er blufft und zweimal schaut |
| `SUP_FIRST`, `SUP_EVERY`, `SUP_TELL`, `SUP_LOOK` | 20 s, 11–19 s, 1→0.5 s, 1.6–2.8 s | die Aufsicht: erster Blick, Abstand, Aufstehen, Schauen |
| `PAN` | 280 px | wie weit der Blick schwenkt |

## Dateien

| Datei | Inhalt |
|---|---|
| `level.gd` | `DEF`, Cutscenes vorher und am Ende der Story, Sieg und Niederlage |
| `exam.gd` | die Prüfung: Kopfdrehung, Kalibrierung, Streber, Aufsicht, Zeichnung der Halle und beider Hälften |

Gemeinsame Dateien sind nicht angefasst.

## Stand

- Per Bot geprüft (mit `--exam-keys`): Ein Bot, der nur spickt, wenn beide Wächter ruhig sind, besteht in etwa einer Minute Prüfungszeit mit Note 6; einer, der immer spickt, fliegt nach wenigen Sekunden. Ohne Kamera bleibt die Prüfung in der Kalibrierung. Screenshots: Halle, Lesen (Streber-Bildschirm in der Mitte), Aufsicht mit «!», Streber von vorne beim Blick zu P1.
- Nicht geprüft: die Kopfsteuerung mit der echten Kamera (Schwellen `LOOK_DEG`, `FORWARD_DEG`), ob die Warnzeiten für Menschen reichen.
