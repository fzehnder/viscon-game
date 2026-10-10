# Level 4 · Chemiepraktikum

Tag-Level für zwei. Praktikum Allgemeine Chemie bei Prof. Dr. Siedler im Labor im Südflügel des Hauptgebäudes. Erst pipettieren beide, dann schreiben beide das Testat. Fällt jemand durch, kocht der Professor über, und das Level beginnt für beide von vorne.

Die Nummer 4 ist gewählt, weil Level 3 laut Plan etwas anderes wird. Umnummerieren: Ordner umbenennen und `"tag"` in `DEF` anpassen, mehr hängt nicht an der Zahl (die Skripte laden sich gegenseitig mit relativen Pfaden).

## So spielt es sich

- **Start** gleich hinter der Labortür (vom Südkorridor her). Im Labor und im Lager dahinter arbeiten fünf Studierende, der Professor dreht seine Runden.
- **Aufgabe 1, Pipettieren:** An den zwei freien Plätzen an den vorderen Labortischen (gelbe Matte, Raute). Jede Figur braucht einen eigenen Platz. Das Glas füllt sich, die Matte bekommt die Farbe der Figur.
- **Aufgabe 2, Testat:** Sobald beide pipettiert haben, geht der Professor nach vorne und ruft das Testat aus. Am linken Pult liegt Serie A (Stoffe und Formeln), am rechten Serie B (Labor und Reaktionen). Jedes Pult kann nur einmal benutzt werden, also schreiben die beiden zwingend verschiedene Serien. Vier Fragen, drei Antworten, ein Fehler ist erlaubt. Abbrechen geht nicht.
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

## Aufgabe 1 ist ein Platzhalter

Das echte Experiment (die richtige Menge ins Glas pipettieren) wird später gebaut. Bis dahin steht ein Timing-Minigame an seiner Stelle. Der ganze Platzhalter ist die Funktion `start_pipette(pid, k)` in `level.gd`. Was immer sie später tut, sie muss mit genau einem dieser Aufrufe enden:

| Aufruf | Bedeutung |
|---|---|
| `pipette_done(pid, k)` | richtige Menge im Glas, Aufgabe erledigt |
| `pipette_failed(pid, k)` | daneben: Wutanfall und Neustart wie beim Testat, mit eigenem Text |
| `pipette_aborted(pid, k)` | Figur ist weggegangen, nichts passiert |

`pid` ist die Figur (0 oder 1), `k` der Platz (0 links, 1 rechts). Solange das Experiment läuft, zeigt der Platz tropfende Flüssigkeit (`st_busy[k]`). Der Platzhalter ruft `pipette_failed` nie auf: Im Moment kann man nur im Testat durchfallen.

## Dateien

| Datei | Inhalt |
|---|---|
| `level.gd` | Beschreibung (`DEF`), Fragen, Sprüche, Labor-Möbel (`build_map`), Ablauf beider Aufgaben, Professor und Studierende, Zeichnung des Labors |
| `lab_person.gd` | Professor oder Studierende: laufen Wege ab und zeichnen sich samt Blase, Dampf und Schweiss; was sie tun, entscheidet `level.gd` |
| `chem_quiz.gd` | das Testat: Fragebogen auf der Bildschirmhälfte der Figur, im Stil von `minigame.gd`, aber mit Durchfallen |
| `prof_rage.gd` | der Wutanfall als Abfolge von Beats, ähnlich wie `cutscene.gd` |
| `lab_sfx.gd` | Sounds nur für dieses Level: Pfeifkessel, Knall, Scherben, Stempel, Stimme des Professors, Tropfen |

Gemeinsame Dateien sind nicht angefasst. Das Testat konnte nicht das Quiz aus `minigame.gd` benutzen, weil dessen Fragen fest aus `characters.gd` kommen; `chem_quiz.gd` meldet sich deshalb selbst in `main.minis` an (so entsteht der Split Screen von allein).

## Stellschrauben (Konstanten oben in `level.gd`)

| Konstante | Wert | Wirkung |
|---|---|---|
| `DEF.time` | 300 s | Zeitlimit. Mit dem echten Experiment wahrscheinlich anzupassen |
| `Q_COUNT` | 4 | Fragen pro Figur, zufällig aus der Serie des Pults |
| `Q_ALLOWED` | 1 | erlaubte Fehler im Testat. 0 = jeder Fehler ist das Ende |
| `SET_A`, `SET_B` | je 7 Fragen | `[Frage, [Antworten], Index der richtigen]`, die Antworten werden gemischt |
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

Gebaut auf dem alten Hauptgebäude, nach dem Kartenumbau (echter Grundriss) für den neuen, kleineren Raum neu eingerichtet. Fertig und auf der neuen Karte mit einem Headless-Bot durchgespielt: Pult vor dem Pipettieren gesperrt, Anschnauzer fürs Rennen, Labormantel, beide pipettieren, Testat wird ausgerufen, beide Serien im Split Screen, ein Fehler erlaubt, Bestehen bis zum Siegbildschirm, Durchfallen mit Wutanfall bis zum Verloren-Bildschirm. Lab, Testat und Wutanfall auf Screenshots geprüft.

Noch nie von Menschen gespielt. Zeitlimit, Anzahl Fragen und Länge des Wutanfalls sind geschätzt.

Offen und Ideen:
- Aufgabe 1 ist der Platzhalter von oben.
- Läuft die Zeit ab, kommt der normale «Zeit abgelaufen»-Bildschirm ohne Wutanfall.
- Die Sounds des Wutanfalls sind nur im Code geprüft, nicht mit Ohren.
- Kein Bezug zum Opp-System: Das Level hat keine `opp_spots`, Opps aus früheren Levels tauchen hier nicht auf.
- Der Wutanfall selbst ist nur auf der alten Karte Bild für Bild angeschaut; er ist ein Vollbild-Overlay und hängt nicht an der Karte.
