# Level 4 · Chemiepraktikum

Tag-Level für zwei. Praktikum Allgemeine Chemie bei Prof. Dr. Siedler im Labor im Südflügel des Hauptgebäudes. Erst pipettieren die beiden zusammen vor der Kamera, dann schreibt jede Person ein Testat. Fällt jemand durch, kocht der Professor über, und das Level beginnt für beide von vorne.

Die Nummer 4 ist gewählt, weil Level 3 laut Plan etwas anderes wird. Umnummerieren: Ordner umbenennen und `"tag"` in `DEF` anpassen, mehr hängt nicht an der Zahl (die Skripte laden sich gegenseitig mit relativen Pfaden).

## So spielt es sich

- **Start** gleich hinter der Labortür (vom Südkorridor her). Im Labor und im Lager dahinter arbeiten fünf Studierende, der Professor dreht seine Runden.
- **Aufgabe 1, Pipettieren zu zweit (Kamera):** An einem der zwei freien Plätze an den vorderen Labortischen (gelbe Matte, Raute). Der Platz lässt sich von beiden Seiten des Tisches benutzen, also auch vom Gang her, aus dem man von der Tür kommt. Wer dort die Interaktionstaste drückt, nimmt die Pipette; die andere Figur muss daneben stehen und hält das Glas. Dann vor der Webcam: Die Pipetten-Person drückt Daumen und Zeigefinger genau richtig zusammen (Balken von Rot über Grün nach Rot, der Zeiger muss im Grünen stehen), die Glas-Person hält die Hand flach und waagrecht ins Bild, ohne zu zittern (Wasserwaage und Zitter-Balken). Nur solange beide gleichzeitig im Grünen sind, tropft es; ist das Glas voll (10.0 mL), ist die Aufgabe für beide erledigt.
- **Aufgabe 2, Testat:** Sobald beide pipettiert haben, geht der Professor nach vorne und ruft das Testat aus. Am linken Pult liegt Serie A (Stoffe und Formeln), am rechten Serie B (Labor und Reaktionen). Jedes Pult kann nur einmal benutzt werden, also schreiben die beiden zwingend verschiedene Serien. Vier Fragen, drei Antworten, ein Fehler ist erlaubt. Die Fragen sind so einfach, dass alle bestehen können (Serie A: Wasser, Eis, Salz; Serie B: Verhalten im Labor), die falschen Antworten sind offensichtlicher Unsinn. Abbrechen geht nicht.
- **Durchgefallen:** Beim zweiten Fehler ist das Testat sofort vorbei. Der Raum erstarrt, dann kommt der Wutanfall (siehe unten) und danach der normale Verloren-Bildschirm: «Nochmals versuchen» oder R lädt das Level neu, M geht zum Startbildschirm.
- **Bestanden:** Haben beide bestanden, folgt eine kurze Cutscene und der Siegbildschirm mit Note.
- **Nebenbei:** Wer im Labor sprintet, wird angeschnauzt (zählt als Fehler). An der Garderobe links oben gibt es Labormantel und Schutzbrille, freiwillig. Wer ohne Mantel durchfällt, bekommt dafür eine eigene Zeile im Wutanfall. Kapellen, Gefahrstoffschrank, Gasflaschen, Glasschrank, Notdusche und Wandtafel kann man ansehen.

## Der Wutanfall (`prof_rage.gd`)

Vollbild, ungefähr 15 Sekunden, mit E / Enter Zeile für Zeile weiter, mit Esc überspringen.

1. Der Professor liest ganz ruhig das Resultat vor.
2. «Ganz ruhig, Siedler. Einatmen ... ausatmen ...»: Augen zu, ein Auge zuckt.
3. Zwei zufällige Sprüche aus `RANTS`. Das Siedler-Meter (Thermometer rechts) steigt, das Gesicht wird rot, Haare und Bart beginnen zu glühen und stehen ab, Dampf kommt aus den Ohren, er hüpft.
4. Er bläst die Backen auf, bei 100 °C platzt das Thermometer, die Brille fliegt weg: «RAUS AUS MEINEM LABOR!»
5. Stempel «DURCHGEFALLEN».

Im Labor selbst hüpft der Professor mit, die Studierenden zittern und ducken sich (bis auf den mit den Kopfhörern), das Glas auf den Tischen klirrt, und aus Kapelle 1 kommt eine grüne Wolke.

Ab dem zweiten Durchfallen ist der Anfall kürzer («Schon. Wieder. Versuch Nummer 2.»), und beim Neustart erinnert ein Hinweis an den Versuch. `attempts` zählt mit und wird beim Sieg zurückgesetzt.

## Aufgabe 1: Pipettieren mit der Kamera (`pipette_game.gd`)

Benutzt das Tracking des Teams (Autoload `Track`, `tracker/README.md`). Spieler 1 sitzt links im Kamerabild, Spieler 2 rechts; das Spiel nimmt die Hand in der jeweiligen Bildhälfte.

| Rolle | Was gemessen wird | Im Grünen, wenn |
|---|---|---|
| Pipette | `TM.pinch01(hand)`: Abstand Daumen–Zeigefinger, 0 = zusammen, 1 = weit offen | höchstens `PINCH_OK` von `PINCH_TARGET` entfernt |
| Glas halten | Neigung der Hand (Handgelenk zu Mittelfinger-Knöchel, `hand_tilt`) und Zittern der Handfläche (`TM.Jitter`) | Neigung höchstens `LEVEL_TOL` Grad und Zittern höchstens `SHAKE_LIMIT` |

- Sind beide im Grünen, füllt sich das Glas in `HOLD_TIME` Sekunden. Ist jemand draussen, läuft es langsam wieder leer (`DRAIN`); zittert die Glas-Hand stark (`SPILL_AT` mal die Grenze), wird verschüttet. Durchfallen kann man hier nicht.
- Im Kamerabild werden die Handgelenke eingezeichnet, dazu eine Pipette zwischen den Fingern und das Glas auf der Hand.
- **Einmal pro Rechner einrichten** (sonst gibt es nur die Tasten-Variante): `brew install uv`, dann im Repo `uv run tracker/tracker.py --selftest`. Beim ersten Start fragt macOS, ob Godot die Kamera benutzen darf. Bricht der Selbsttest beim Laden der Modelle mit `CERTIFICATE_VERIFY_FAILED` ab (Python von python.org ohne Zertifikate), hilft `SSL_CERT_FILE=/etc/ssl/cert.pem uv run tracker/tracker.py --selftest`.
- Das Level weckt den Tracker schon beim Start (`Track.use` in `_ready`), damit die Kamera bereit ist, wenn die beiden am Tisch ankommen, und gibt sie nach dem Pipettieren wieder frei.
- Kommt das Kamerabild erst, nachdem schon auf Tasten umgeschaltet wurde (langsamer erster Start), wechselt das Spiel von selbst zur Kamera zurück, ausser jemand hat die Tasten mit `K` gewählt.
- **Tasten-Variante** (Regel des Teams für jedes Kamera-Minigame): Kommt nach `CAM_WAIT` Sekunden kein Kamerabild oder meldet `Track` «kein Tracker» oder «keine Kamera», wird mit Tasten gespielt: Die Pipetten-Person hält die Interaktionstaste gedrückt und lässt sie los, die Glas-Person steuert die Blase der Wasserwaage mit links und rechts. `K` schaltet von Hand um.
- In `level.gd` hängt das Spiel an `start_pipette(pid, k)`; es endet mit `pipette_done` oder `pipette_aborted`. `pipette_failed(pid, k)` gibt es weiterhin als Haken (Wutanfall und Neustart), das Kamera-Spiel ruft ihn nicht auf.

## Dateien

| Datei | Inhalt |
|---|---|
| `level.gd` | Beschreibung (`DEF`), Fragen, Sprüche, Labor-Möbel (`build_map`), Ablauf beider Aufgaben, Professor und Studierende, Zeichnung des Labors |
| `lab_person.gd` | Professor oder Studierende: laufen Wege ab und zeichnen sich samt Blase, Dampf und Schweiss; was sie tun, entscheidet `level.gd` |
| `pipette_game.gd` | Aufgabe 1: das Kamera-Spiel für zwei samt Tasten-Variante |
| `chem_quiz.gd` | das Testat: Fragebogen auf der Bildschirmhälfte der Figur, im Stil von `minigame.gd`, aber mit Durchfallen |
| `prof_rage.gd` | der Wutanfall als Abfolge von Beats, ähnlich wie `cutscene.gd` |
| `lab_sfx.gd` | Sounds nur für dieses Level: Pfeifkessel, Knall, Scherben, Stempel, Stimme des Professors, Tropfen |

Gemeinsame Dateien sind nicht angefasst. Das Testat konnte nicht das Quiz aus `minigame.gd` benutzen, weil dessen Fragen fest aus `characters.gd` kommen; `chem_quiz.gd` meldet sich deshalb selbst in `main.minis` an (so entsteht der Split Screen von allein).

## Stellschrauben (Konstanten oben in `level.gd`)

| Konstante | Wert | Wirkung |
|---|---|---|
| `DEF.time` | 300 s | Zeitlimit. Mit dem echten Experiment wahrscheinlich anzupassen |
| `PINCH_TARGET`, `PINCH_OK` in `pipette_game.gd` | 0.45, 0.13 | wie weit die Finger zusammen sein müssen und wie breit der grüne Bereich ist |
| `LEVEL_TOL` | 18° | wie schief die Hand sein darf |
| `SHAKE_LIMIT` | 5.0 | ab wann die Hand als zitternd gilt. Geschätzt: in `track_debug.tscn` den Wert «Zittern» einer ruhigen Hand aus Spielabstand ablesen und deutlich darüber gehen |
| `HOLD_TIME`, `DRAIN`, `SPILL_AT` | 3 s, 0.35, 2.2 | wie lange beide richtig liegen müssen, wie schnell es wieder leer läuft, ab wann verschüttet wird |
| `CAM_WAIT` | 6 s | wie lange auf die Kamera gewartet wird, bevor die Tasten gelten |
| `KEY_SQUEEZE`, `KEY_RELAX`, `KEY_TILT`, `KEY_DRIFT` | | Schwierigkeit der Tasten-Variante |
| `REACH` in `level.gd` | 0.85 Tiles | wie nah man an einem Laborplatz oder Pult stehen muss, egal von welcher Seite |
| `PARTNER_DIST` in `level.gd` | 2.6 Tiles | wie nah die zweite Figur zum Pipettieren stehen muss |
| `Q_COUNT` | 4 | Fragen pro Figur, zufällig aus der Serie des Pults |
| `Q_ALLOWED` | 1 | erlaubte Fehler im Testat. 0 = jeder Fehler ist das Ende |
| `SET_A`, `SET_B` | je 8 Fragen | `[Frage, [Antworten], Index der richtigen]`, die Antworten werden gemischt |
| `RANTS` | 8 Sprüche | Wutanfall, zwei pro Anfall, einer bei Wiederholung |
| `RUN_SCOLD` | 5 s | Abstand zwischen zwei Anschnauzern fürs Rennen |
| `PROF_SPEED`, `PROF_PAUSE`, `PATROL` | 44 px/s, 1.4 bis 3 s | Runde des Professors |
| `BENCHES`, `STATION_X`, `DESKS`, `HOODS` und die übrigen Rechtecke | | wo was steht, in Tiles |
| `WORK`, `COOL_ONE`, `WALKER`, `WALK_STOPS` | | Plätze der Studierenden, wer Kopfhörer trägt, wer herumläuft |
| `SWELL_TIME` in `prof_rage.gd` | 1.1 s | Pause mit aufgeblasenen Backen vor dem Knall |
| `MARKS` in `prof_rage.gd` | | Beschriftung des Siedler-Meters |

## Wie es gebaut ist

- **Karte:** `build_map` räumt das Robotik-Labor im Südflügel leer und richtet es neu ein. Im Labor (Tiles 69..86 / 57..64): Wandtafel und Testat-Pulte vorne, zwei Labortische mit den freien Plätzen, zwei Kapellen, Spüle, Glasschrank, Garderobe, Notdusche. Im Pavillon dahinter (78..86 / 66..70) das Lager: dritter Labortisch, dritte Kapelle, Gefahrstoffschrank, Kanister, Gasflaschen. Jedes Möbel ragt nur in eine Kachelzeile, damit die Wegfindung nichts abschneidet. Alle Arten heissen `l4_...`, `world.gd` kennt sie nicht und gibt ihnen nur Kollision und A*-Sperre; gezeichnet wird alles in `level.gd` (`_draw`, `z_index -5`). Wandtafel, Periodensystem, Uhr und Notfallschild sind auf die Wandreihe gemalt.
- **Testat-Pulte** sind kleine Nodes in `main.actors` und verdecken die Beine der sitzenden Figur. Solange sie sitzt, hat sie keine Kollision (der Sitzplatz liegt im Kollisionsrechteck des Pults).
- **Professor und Studierende** haben keine Kollision, man läuft durch sie hindurch wie durch die Studierenden in Level 1.
- **Kamera:** Der Zoom in Wutanfall und Finale läuft über `main.zoom`, nie über eine einzelne Kamera.
- **Durchfallen:** `_fail` setzt `main.state = "cutscene"` (die Uhr steht), spielt den Wutanfall und setzt danach `main.state = "lost"` mit `hud.show_overlay(..., "lose")`. Ab da greift der normale Ablauf von `main.gd` (R, M, Button).
- **Rennen:** `on_noise` erkennt Sprint-Schritte im Raum am Radius.

## Stand

Fertig und auf der neuen Karte mit einem Headless-Bot durchgespielt: Pult vor dem Pipettieren gesperrt, Anschnauzer fürs Rennen, Labormantel, Testat in zwei Serien im Split Screen, ein Fehler erlaubt, Bestehen bis zum Siegbildschirm, Durchfallen mit Wutanfall bis zum Verloren-Bildschirm.

Das Kamera-Pipettieren ist per Bot geprüft: allein am Tisch geht es nicht, Abbrechen, Tasten-Variante mit echten Tastendrücken bis zum vollen Glas, und der Kamera-Weg mit **künstlichen Handdaten** (offene Hand, schiefes Glas, zitterndes Glas, beide richtig, wieder leer laufen). Mit dem echten Tracker ist die Kette Spiel und Tracker auf einem Standbild geprüft (`--fake`: 20 Bilder pro Sekunde, Vorschau kommt an, das Spiel wechselt in den Kamera-Modus und verlangt «Hand ins Bild halten»). **Mit einer echten Kamera und echten Händen ist es noch nie gelaufen.** Alle Kamera-Schwellen sind deshalb geschätzt.

**Behobener Fehler (10.10.2026):** Die Laborplätze reagierten nur von der Nordseite des Tisches. Wer von der Tür durch den Gang kam, also alle, bekam keinen Hinweis und konnte weder pipettieren noch danach das Testat öffnen. Die früheren Bot-Läufe hatten das nicht bemerkt, weil sie die Figuren an den Platz teleportierten. Seither läuft der Bot den Weg mit echten Tastendrücken (laufen, Interaktionstaste) bis ins Testat, auch in einem echten Fenster.

Von der Person, die das Level gebaut hat, einmal angespielt (dabei fiel der Fehler oben auf). Zeitlimit, Anzahl Fragen und Länge des Wutanfalls sind ebenfalls geschätzt.

Offen und Ideen:
- Kamera-Schwellen (`PINCH_TARGET`, `LEVEL_TOL`, vor allem `SHAKE_LIMIT`) im Spieltest einstellen.
- Wer die Hand «waagrecht» mit den Fingern zur Kamera hält statt quer durchs Bild, wird von der Neigungsmessung nicht richtig erfasst; die Anleitung im Spiel sagt nur «flach und waagrecht».
- Läuft die Zeit ab, kommt der normale «Zeit abgelaufen»-Bildschirm ohne Wutanfall.
- Die Sounds des Wutanfalls sind nur im Code geprüft, nicht mit Ohren.
- Kein Bezug zum Opp-System: Das Level hat keine `opp_spots`, Opps aus früheren Levels tauchen hier nicht auf.
- Der Wutanfall selbst ist nur auf der alten Karte Bild für Bild angeschaut; er ist ein Vollbild-Overlay und hängt nicht an der Karte.
