# Level 2 · Mensa-Stau

Tag-Level für zwei. Mittag, die Schlange in der Mensa ist endlos und die Ausgabe schliesst in 3 Minuten. Hinten anstellen dauert zu lange, also drängelt ihr euch vor, holt ein Menü, setzt euch zusammen an einen Tisch und erfahrt per E-Mail, dass ihr für die Basisprüfung angemeldet seid.

## So spielt es sich

- **Die Schlange funktioniert wie ein Stau.** Rückt jemand auf, braucht die Person dahinter einen Moment, bis sie es merkt (grüne Blase mit ablaufendem Ring, grüner Kreis am Boden). Genau dann ist die Lücke frei, und sie wandert wie eine Stauwelle nach hinten.
- **Vordrängeln:** neben die Schlange stellen und im richtigen Moment in die Lücke schleichen. Wer vor jemanden tritt, der schon losläuft oder aufpasst, wird erwischt: zählt als Fehler, und die Figur wird aus der Schlange geschoben.
- **Lärm** (gehen, sprinten, Fehler im Minigame) macht die Leute aufmerksam (gelbes «!»), dann rücken sie sofort nach. Leute mit Kopfhörern brauchen länger.
- **Kassiererin:** Die vordersten vier Plätze liegen in ihrem Lichtkegel. Dort wird man immer erwischt.
- **In der Schlange** rückt man selber mit auf. Wer vor sich eine Lücke lässt, kann die andere Person hineinlassen.
- **Opps:** Vor wen ihr euch drängelt, der wird zum Opp. Wer euch erwischt, sofort; wer abgelenkt war, merkt es nach ein paar Sekunden. Opps bekommen ein rotes Namensschild, bleiben in diesem Level aber in der Schlange stehen. Sie merken sich, wer es war, und tauchen in späteren Levels wieder auf.
- **Ganz vorne:** «Menü schöpfen» (Timing-Minigame), danach trägt die Figur ein Tablett.
- **Hinsetzen:** beide an denselben Tisch. Dann kommt die Cutscene (Sprechzeilen, Handys vibrieren, E-Mail der Prüfungsplanstelle, Titelkarte «BASISPRÜFUNG») und der Siegbildschirm mit Note.

Aufgaben im HUD: Vordrängeln, Menü holen, Zusammen hinsetzen. Wer sich brav hinten anstellt und so bis zur Kasse kommt, bekommt «Vordrängeln» ebenfalls gutgeschrieben, schafft es aber in der Zeit nicht.

## Dateien

| Datei | Inhalt |
|---|---|
| `level.gd` | Beschreibung (`DEF`), Mensa-Möbel (`build_map`), Schlange, Spieler in der Schlange, Kasse, Tische, Finale, Zeichnung von Theke und Bodenmarkierung |
| `mensa_guest.gd` | ein Gast oder jemand vom Personal: läuft Wege ab und zeichnet sich samt Blase; was er tut, entscheidet `level.gd` |

Allgemeines, das für dieses Level dazukam und allen Levels gehört: `scripts/cutscene.gd`, das Accessoire `tray` in `character_art.gd`, die Sounds `buzz`, `mail`, `doom` in `sfx.gd`.

## Stellschrauben (Konstanten oben in `level.gd`)

| Konstante | Wert | Wirkung |
|---|---|---|
| `DEF.time` | 180 s | Zeitlimit |
| `N_QUEUE` | 34 | Leute in der Schlange. Muss so gross bleiben, dass ehrliches Anstehen (`N_QUEUE` mal etwa 5 s) länger dauert als das Zeitlimit |
| `REACT` | 0.9 bis 1.5 s | wie lange eine Lücke offen bleibt. Kleiner = schwerer |
| `HEADPHONES` | 1.45 | Faktor für Leute mit Kopfhörern |
| `SERVICE` | 3 bis 4 s | Zeit an der Kasse; bestimmt, wie oft eine Welle kommt und wie lange man in der Schlange wartet |
| `Q_SPEED` | 1.7 Tiles/s | Tempo beim Aufrücken |
| `ALERT` | 2.5 s | wie lange jemand nach Lärm aufpasst |
| `CONE_RANGE`, `CONE_DIR`, `CONE_HALF` | 4.1 Tiles, schräg nach rechts oben, 45 Grad | Blickfeld der Kassiererin |
| `GRUDGE` | 5 s | wie lange es dauert, bis jemand merkt, dass ihr euch unbemerkt vor ihn gestellt habt |
| `MAX_OPPS` | 3 | so viele Opps entstehen in diesem Level höchstens |
| `ENTER_D`, `LEAVE_D` | 0.22 und 0.62 Tiles | wie nah an der Mittellinie man «drin» ist und ab wann man wieder «draussen» ist |
| `PATH` | Theke, Ostwand, Nordwand, Tür, Polyterrasse | Verlauf der Schlange, Kopf zuerst |

## Wie es gebaut ist

- **Schlange:** `members` ist die Reihenfolge (Kopf zuerst) und enthält Gäste und Spieler. Jeder Gast hat `qs` (Abstand zum Kopf entlang `PATH`) und einen Zustand: `wait`, `react` (Lücke noch nicht bemerkt, das ist das Zeitfenster), `move`, `served`. `_update_queue` ist reines Hinterherlaufen mit Reaktionszeit, daraus entstehen die Stauwellen von selbst.
- **Spieler:** `_project` bestimmt, wo eine Figur relativ zur Schlange steht. Tritt sie auf die Mittellinie, entscheidet `_try_insert` anhand der Person dahinter: abgelenkt = drin, sonst erwischt, im Kegel immer erwischt, Teammate dahinter immer erlaubt.
- **Gäste sind für Spieler fest** (Kollisionslayer 32, die Spieler bekommen ihn in `_ready` in die Maske). So passt man nur in eine echte Lücke. Die Gäste selbst werden direkt gesetzt und kollidieren mit nichts.
- **Kreislauf:** Bediente Gäste tragen ihr Tablett an einen freien Platz, essen und gehen über die Polyterrasse weg. `_spawn_joiner` schickt Nachschub, sodass die Schlange bei `N_QUEUE` bleibt. Gäste lassen immer einen Tisch mit zwei freien Plätzen übrig und meiden den Tisch, an dem schon eine Spielfigur sitzt.
- **Sitzen:** Tische und Stuhllehnen sind kleine Nodes in `main.actors` und sortieren sich mit den Figuren. Wer hinter dem Tisch sitzt, steht in dessen Fläche, der Tisch verdeckt die Beine; vorne verdeckt die Stuhllehne die Beine. Sitzende Spieler haben keine Kollision, weil der hintere Platz im Kollisionsrechteck des Tisches liegt.
- **Opps:** `_make_opp` gibt dem Gast eine `opp_id` (`draengler_1` bis `draengler_3`) und einen Namen und meldet ihn mit Aussehen und Spieler bei `Game.add_opp`. Erwischt eine Person, die schon Opp ist, auch die zweite Spielfigur, kommt diese nur auf ihre Liste. Die Wiederkehr in späteren Levels erledigt das allgemeine Opp-System (`scripts/opp.gd`, `opp_spots` im jeweiligen Level).
- **Weg zur Aufgabe:** `task_targets` sagt den gestrichelten Pfeilen, wohin sie führen: zu einer Stelle neben der Schlange knapp ausserhalb des Kegels der Kassiererin, zur Kasse (sobald man in der Schlange steht) und zu einem Tisch mit zwei freien Plätzen oder zum Tisch, an dem die andere Person schon sitzt.
- **Karte:** `build_map` ersetzt die einfachen Mensa-Möbel durch Theke, Tablett-Gestell, sechs Tische und Stühle und nimmt die Mensa aus den Zonen der herumlaufenden Studierenden.

## Stand

Fertig und im Headless-Bot-Durchlauf geprüft: Schlange, erwischt werden (Gast und Kassiererin), vordrängeln mit echter Bewegung, aufrücken, Menü holen, hinsetzen, Cutscene, Siegbildschirm, Übergang von Level 1, Opps durch Vordrängeln und ihre Wiederkehr in einem Testlevel 3.

Noch nie von Menschen gespielt. Zeitlimit, Reaktionszeit und Kegel sind geschätzt und müssen im Spieltest eingestellt werden.

Offen und Ideen:
- Opps aus Level 1 (Deniz und Livia vom Lesetisch) kommen in der Mensa nicht vor, das Level hat keine `opp_spots`. Laut Vorgabe tauchen Opps erst ab Level 3 wieder auf.
- Ein Opp in der Schlange tut in diesem Level nichts weiter, er verlässt seinen Platz nicht.
- Wer in der Schlange steht und nicht aufrückt, hält alle dahinter beliebig lange auf. Es gibt keine Reaktion der Wartenden.
- Die Cutscene zeigt die sitzenden Figuren nur von oben; es gibt keine Reaktion der Figuren selbst (zum Beispiel ein «!» über den Köpfen).
