# Level 3 · Polyball

Tag-Level für zwei (es ist Abend, aber kein Schleichen im Dunkeln, sondern in einer Menge). Ende November, 9000 Gäste tanzen durchs Hauptgebäude. In der Garderobe hängt der Mantel eines Professors, mit seinem Badge in der Innentasche. Den wollt ihr haben.

## So spielt es sich

- **Verkleidung.** Jede Verkleidung gilt nur an ihrem Ort: **Abendgarderobe im Hauptgebäude** (auch auf dem Platz direkt vor dem Westeingang), **Küchenschürze in der Mensa**, die heute die Küche ist. Richtig angezogen übersehen euch alle Lichtkegel. Falsch angezogen oder im Hoodie füllt sich der Verdachtsbalken schneller als normal. Draussen spielt die Kleidung keine Rolle.
- Über dem Kopf steht «passt» (grün) oder «fällt auf» (rot, blinkt), sobald man an einem dieser Orte ist.
- **Umziehen:** stehen bleiben, wo nichts anderes in Reichweite ist, und interagieren. Unten erscheint «Umziehen: …». Das dauert einen Moment, man kann sich nicht bewegen, und wer dabei gesehen wird, fällt auf. Am Ort mit der passenden Kleidung wird Umziehen nicht angeboten, damit es nicht aus Versehen passiert.
- **Aufpasser:** Türsteher am Westeingang, Security in der Haupthalle, Garderobiere in der Garderobe, Chefkoch und Küchenhilfe in der Küche. Wen sie erwischen, den setzen sie vor die Tür: zählt als Fehler, das Level geht weiter.
- **Alte Bekannte:** Opps aus Level 1 und 2 stehen an der Bar und an der Tanzfläche, die letzten kommen suchen. In Abendgarderobe erkennen sie euch nicht. Erwischt einer von ihnen jemanden, ist das Level verloren, wie überall.
- Schritte von jemandem, der richtig angezogen ist, locken niemanden an. Fehler in einem Minigame schon.

Der Weg zwischen Mensa und Hauptgebäude ist Absicht: Für das Armband muss gleichzeitig jemand in der Küche (Schürze) und jemand im Hauptgebäude (Abendgarderobe) stehen.

## Aufgaben

| Aufgabe | Was passiert | Kamera |
|---|---|---|
| **Abendgarderobe organisieren** (zuerst, ohne sie geht nichts anderes) | In der Mensa gleich neben der Tür eine Schürze vom Haken nehmen, dann hinten rechts an der Personalgarderobe einen Kellner-Frack (Timing-Minigame). Jede Person für sich. | nein |
| **Armband fälschen** (zu zweit) | Eine Person schaut sich am Bändel-Tisch in der Eingangshalle die Vorlage an und sagt sie an, die andere baut sie in der Bastelecke der Küche nach. Das Nachbauen ist das bestehende Sequenz-Minigame, nur ohne Vorzeigen. Gilt für beide. | nein |
| **Im Takt über die Tanzfläche** (zu zweit) | Beide stehen in Abendgarderobe auf der Tanzfläche in der Rotunde. Eine Pose wird gezeigt, beide machen sie nach, und sie muss bei beiden sitzen, solange der Balken grün ist. Trifft eine Person nicht, zählt das als Fehler für beide. Vier Treffer. Gilt für beide. | **Körperhaltung** |
| **Prof-Badge holen** (Hauptmission) | In der Garderobe den grünen Lodenmantel finden (an einem von drei Ständern, jedes Mal an einem anderen). Dann den Badge mit zwei Fingern aus der Innentasche ziehen: Daumen und Zeigefinger zusammendrücken, Hand langsam nach oben, nicht zittern. Nur in Abendgarderobe. Gilt für beide. | **Hand** |
| **Buffet plündern** | Timing-Minigame an einem der Buffettische. Belohnung: ein Tablett, das man den Rest des Abends herumträgt. Jede Person für sich. | **Gesicht:** Mund weit auf schnappt zu, genau wie die Taste |

**Der Badge landet im Spielstand** als `prof_badge`: `Game.has_item("prof_badge")`. Level 5 kann das so abfragen. Wird Level 3 neu gestartet, ist er wieder weg.

## Kamera

Drei Aufgaben lassen sich vor der Webcam spielen (Autoload `Track`, Einrichtung in `tracker/README.md`). **Das Level ist ohne Kamera komplett spielbar:** Jede der drei hat eine Tasten-Variante.

| Aufgabe | Mit Kamera | Ohne Kamera |
|---|---|---|
| Tanzfläche | Pose nachmachen (`TM.pose_match` über 80 %) | beide drücken die gezeigte Richtung, solange der Balken grün ist |
| Badge | Pinch und ruhige Hand | das bestehende Sequenz-Minigame «Mantel · Innentasche · Badge» |
| Buffet | Mund auf | die Taste; beides geht gleichzeitig |

- **Umschalten auf Tasten** passiert von selbst, wenn die Kamera 5 Sekunden lang nichts liefert (kein Tracker, keine Kamera, keine Freigabe). Läuft die Kamera, aber jemand ist nicht im Bild, wartet das Spiel dreimal so lang. Mit der Interagieren-Taste (E / Enter) schaltet man jederzeit selbst um.
- **Der Bildschirm wird hell**, solange ein Kamera-Minigame offen ist: in der Geschichte der Scheinwerfer auf der Tanzfläche und das hell beleuchtete Buffet, im abgedunkelten Raum die Lampe, ohne die die Kamera niemanden findet. Das ist Absicht und sollte nicht dunkler werden.
- **Sitzordnung:** Person 1 sitzt links, Person 2 rechts. Die Kamera sieht im Sitzen nur Oberkörper und Arme, deshalb bestehen die Posen nur aus Armhaltungen.
- Der Tracker startet schon beim Start des Levels (`PREWARM`), die Kamera selbst geht erst in einem Kamera-Minigame an. So liefert sie etwa 2 bis 3 Sekunden nach dem Öffnen (gemessen: 2.6 s) und damit vor Ablauf der 5 Sekunden.

### Zielposen: Platzhalter

Die vier Posen (Jubel, Flieger, Disco, Kaktus) in `posen.gd` sind **Platzhalter**, aus Armrichtungen errechnet. Niemand ist dafür vor der Kamera gestanden. Echte Posen einsetzen:

1. `godot --path godot res://track_debug.tscn`, Taste 3 (Körper), Pose hinstellen, Taste P.
2. Den Inhalt der gespeicherten `pose_target.json` als Eintrag in `AUFGENOMMEN` oben in `posen.gd` kopieren und einen Namen dazuschreiben: `{"name": "Jubel", "pts": [...]}`.
3. Sobald `AUFGENOMMEN` nicht leer ist, werden nur noch diese Posen benutzt.

## Wo was ist

Es gibt keine neue Karte, nur Ball-Ausstattung im bestehenden Hauptgebäude (`build_map`).

| Ort im Level | Ort auf der Karte | Tiles |
|---|---|---|
| Saal | Haupthalle: Bar an der Stelle der Infotheke, zwei Buffettische an der Stelle der Bänke, roter Teppich, Lichterketten | 46..67, 43..48 |
| Tanzfläche | Rotunde | um (71.2, 46) |
| Türsteher, Bändel-Tisch | Westeingang und Eingangshalle | Tür bei x 38; Tisch bei (41, 48) |
| **Garderobe** | **Büro West direkt nördlich der Eingangshalle** | 40..42, 35..41, Tür bei (43, 38) |
| Küche | Mensa: Schürzenhaken neben der Tür, Herdinseln, Personalgarderobe an der Ostwand, Bastelecke an der Westwand | 13..32, 65..76 |
| Start | Polyterrasse, zwischen Westeingang und Mensa | (27, 51) |

## Dateien

| Datei | Inhalt |
|---|---|
| `level.gd` | Beschreibung (`DEF`), Ausstattung (`build_map`), Verkleidung und ihre Wirkung auf die Opps, Aufgaben, Finale, Zeichnung |
| `vorlage.gd` | die Armband-Vorlage auf der Bildschirmhälfte der Person, die sie ansieht |
| `kamera_spiel.gd` | die beiden Minigames vor der Kamera: Tanzfläche und Badge |
| `posen.gd` | Zielposen für die Tanzfläche (Platzhalter, siehe oben) |

Allgemeines, das für dieses Level dazukam: `Game.items` mit `Game.add_item` und `Game.has_item` in `game_state.gd` (eigener Commit). Sonst ist keine gemeinsame Datei angefasst.

## Stellschrauben

Oben in `level.gd`:

| Konstante | Wert | Wirkung |
|---|---|---|
| `DEF.time` | 480 s | Zeitlimit |
| `FACTOR_WRONG` | 1.8 | so viel schneller füllt sich der Balken in falscher Kleidung. 1.0 = wie normal |
| `CHANGE_TIME` | 1.6 s | wie lange Umziehen dauert |
| `GUARD_CALM` | 6 s | so lange lässt einen ein Aufpasser nach dem Rauswurf in Ruhe |
| `STUN` | 1.4 s | so lange kann man sich nach dem Rauswurf nicht bewegen |
| `METER_DECAY` | 0.35 pro s | wie schnell der Balken sinkt, wenn nur richtig Angezogene im Kegel stehen. Gleicher Wert wie in `opp.gd` |
| `FRACK_HITS`, `FRACK_SPEED` | 2, 300 | Timing-Minigame für den Frack |
| `ARMBAND_LEN` | 6 | Anzahl Zeichen auf dem Armband |
| `BADGE_SEQ` | 5 | Länge der Sequenz für die Innentasche (Tasten-Variante) |
| `BUFFET_HITS`, `BUFFET_SPEED` | 3, 280 | Timing-Minigame am Buffet. Langsamer als sonst, weil ein Mund träger ist als eine Taste |
| `MOUTH_OPEN`, `MOUTH_SHUT` | 0.45, 0.25 | wie weit der Mund aufgehen muss, damit er zuschnappt, und wie weit wieder zu, bevor er es nochmals kann |
| `TANZ_RADIUS` | 2.6 Tiles | so nah an der Mitte der Tanzfläche müssen beide stehen |
| `PREWARM` | an | Tracker schon beim Start des Levels starten |
| `ZONES`, `NEEDS` | | wo welche Verkleidung gilt |
| `GUESTS` | 39 Gäste | wo wie viele Gäste herumgehen |
| `EJECT_SAAL`, `EJECT_KUECHE` | (30.5, 46), (22.5, 61.8) | wohin man gesetzt wird |
| `DEF.npcs` | | Standort und Blickrichtung der Aufpasser. Reichweite der Kegel: `"range"` pro Person, sonst 5.5 Tiles |
| `DEF.opp_spots` | 5 Plätze | wo Opps aus früheren Levels stehen, älteste zuerst |

Oben in `kamera_spiel.gd`:

| Konstante | Wert | Wirkung |
|---|---|---|
| `CAM_WAIT` | 5 s | so lange ohne Ergebnis von der Kamera, dann übernehmen die Tasten |
| `CAM_PATIENCE` | 3 | mal so lange, wenn die Kamera läuft, aber jemand nicht im Bild ist |
| `LIGHT` | fast weiss | wie hell der Bildschirm wird |
| `POSE_OK` | 80 % | ab wann eine Pose als getroffen gilt. Kleiner = leichter |
| `BEAT` | 3.2 s | Zeit pro Pose |
| `BEAT_WINDOW` | 1.2 s | die letzten Sekunden einer Pose, in denen sie sitzen muss (Balken grün) |
| `DANCE_HITS` | 4 | so viele Posen müssen beide treffen |
| `PINCH_GRAB`, `PINCH_DROP` | 0.3, 0.6 | wie nah die Finger zusammen sein müssen, um den Badge zu halten, und ab wann er entgleitet |
| `PULL` | 0.16 | wie weit die Hand nach oben muss, in Bildhöhen |
| `JITTER_MAX`, `JITTER_TIME` | 12, 0.35 s | so zittrig darf die Hand so lange sein, sonst raschelt der Mantel (Fehler, nochmals) |
| `HAND_LOST` | 0.8 s | so lange darf die Hand aus dem Bild sein, bevor der Badge zurückrutscht |

Wie streng die Posen bewertet werden, steckt ausserdem in `POSE_TOLERANCE` in `scripts/track_math.gd` (gilt für alle Levels).

## Wie es gebaut ist

- **Verkleidung als Faktor auf das Opp-System.** `opp.gd` ist nicht angefasst. Ein Opp füllt seinen Balken nur, solange er jemanden sieht. Nach jedem Physik-Schritt der Opps (`process_physics_priority`) nimmt `_apply_disguises`, was der Opp in diesem Schritt dazugezählt hat, und multipliziert es mit dem Wert der auffälligsten Person in seinem Blick (`suspicion`): 0 = richtig angezogen, 1 = neutraler Ort, `FACTOR_WRONG` = falsch angezogen oder gerade am Umziehen. Sehen sie nur richtig Angezogene, sinkt der Balken wie ohne Sicht.
- `opp.gd` jagt, wen es am nächsten sieht. Beginnt eine Jagd auf jemanden, der richtig angezogen ist, lenkt das Level sie im selben Schritt auf die auffällige Person um oder bricht sie ab.
- **Schritte:** `on_noise` setzt Opps, die wegen der Schritte einer richtig angezogenen Person losgegangen sind, auf ihren Stand vom Schritt davor zurück.
- **Aufpasser** sind gewöhnliche `npcs` aus `DEF`. `_ready` setzt sie auf «wachsam» (`angry`, Zustand `LAUERN`); als Opp gespeichert werden sie nie. `on_opp_catch` übernimmt ihren Rauswurf und lässt alte Opps beim Standard (Level verloren).
- **Kleidung:** `_wear` baut das Aussehen aus dem eigenen Look der Figur plus `LOOK_ABEND` (Stil `jacket`, Hemd in der Farbe der Person) oder `LOOK_SCHUERZE` (Stil `labcoat`, weiss). Dafür war kein neues Accessoire nötig.
- **Armband:** `_build` öffnet das bestehende Sequenz-Minigame über `main.open_minigame`, setzt das Muster des Armbands als Sequenz und schaltet sofort auf Eingabe. Nach einem Fehler würde das Minigame die Sequenz neu vorzeigen; `_blind` verhindert das. Die Vorlage (`vorlage.gd`) benutzt dieselben vier Richtungen.
- **Kamera-Minigames:** `kamera_spiel.gd` hält sich an den Vertrag von `minigame.gd` (Signale `finished` und `mistake`, Zähler `mistakes`). `_open_cam` trägt es so in `main.minis` ein, wie `main.gd` es mit eigenen Minigames tut. Dadurch gelten die Figuren als beschäftigt, der Bildschirm teilt sich bei einer Person, und `main._abort_mini` funktioniert. Die Kamera hält `Track.use(self, …)` und geht mit dem Schliessen von selbst wieder aus.
- **Badge:** Das Signal `fallback` schliesst das Kamera-Minigame und öffnet stattdessen das Sequenz-Minigame.
- **Buffet:** Das Timing-Minigame bleibt, wie es ist. `_snap_with_mouth` ruft bei offenem Mund dieselbe Funktion auf wie die Taste und färbt den Hintergrund des Minigames hell.
- **Gäste** sind die Studierenden des Tages: `build_map` ersetzt `student_zones`, `_dress_guests` zieht ihnen Anzug oder Kleid an.
- **Hans Muster** steht als `npcs`-Eintrag mit der id `hans_muster` an der Bar. Macht ihn ein früheres Level unter genau dieser id zum Opp, lauert er hier von Anfang an.

## Stand

Per Bot von Start bis Siegbildschirm durchgespielt: im Hoodie in der Küche erwischt und rausgeworfen, Schürze, Frack, draussen umziehen, in Abendgarderobe von Security übersehen, in der Schürze im Saal rausgeworfen, Armband zu zweit über den geteilten Bildschirm (mit einem Fehler), Buffet, falscher und richtiger Ständer, Badge im Spielstand, Finale. Dazu geprüft: Opps aus Level 1 und 2 erscheinen an ihren Plätzen, übersehen Abendgarderobe und erwischen den Hoodie; alle Orte sind zu Fuss erreichbar. Das Aussehen ist an Screenshots geprüft.

Kamera-Aufgaben: Der Bot hat sie mit eingespeisten Kameradaten gespielt (Tanzen mit einer falschen Pose und bis zum Erfolg, Badge mit Zittern, Loslassen und ruhiger Hand, Buffet nur mit dem Mund) und alle drei Tasten-Varianten. Mit der echten Kamera ist nur geprüft, dass sie rechtzeitig liefert (2.6 s nach dem Öffnen) und dass die Bildschirme stimmen. **Vor der echten Kamera hat noch niemand getanzt, gegriffen oder zugeschnappt.**

**Noch nie von Menschen gespielt.** Zeitlimit, `FACTOR_WRONG`, die Standorte der Aufpasser und alle Kamera-Schwellen sind geschätzt.

## Offen

- **Zielposen sind Platzhalter** (siehe oben). Ob sich 80 % mit ihnen bequem treffen lassen, zeigt erst ein Versuch vor der Kamera; sonst `POSE_OK` senken.
- **`JITTER_MAX` ist geraten.** Die Messung zittert auch bei ruhiger Hand, weiter weg von der Kamera stärker. In `track_debug` aus Spielabstand den Wert «Zittern» einer ruhigen Hand ablesen und deutlich darüber gehen.
- **Mund am Buffet:** Erkennung und Mundbewegung brauchen einen Moment, man muss etwas früher aufmachen als drücken. Wenn das nervt: `BUFFET_SPEED` senken.
- Ursprünglich war nur ein Kamera-Moment pro Level geplant, damit sich die Mechanik nicht abnutzt. Auf Wunsch (10.10.2026) sind es jetzt drei, jeder mit einer anderen Erkennung (Körper, Hand, Gesicht).
- **«Relay-Prinzip aus Level 1»:** Im Code ist «Legi validieren» ein Timing-Minigame für eine Person, ein Relay gibt es dort nicht. Das Armband benutzt deshalb das bestehende Sequenz-Minigame für die bauende Person und eine eigene kleine Anzeige für die Vorlage.
- **Hans Muster** gibt es bisher in keinem Level als Opp. Welche id er bekommt, muss mit `HANS_ID` übereinstimmen.
- **Küchenschürze** sieht aus wie eine weisse Kochjacke (`labcoat`). Eine echte Schürze wäre ein neues Accessoire in `character_art.gd`.
- Ein Haken in `opp.gd` (zum Beispiel ein Faktor pro Person in `_watch` und in `hear`) würde das nachträgliche Korrigieren in `_apply_disguises` und `on_noise` ersetzen. Es funktioniert ohne, hängt aber an Einzelheiten von `opp.gd`: an der Sinkrate 0.35 und daran, dass der Balken nur in `_watch` steigt.
- Nebeneingänge (Nord, Süd, Rotunde) sind unbewacht. Wer im Hoodie hineinkommt, fällt drinnen trotzdem auf.
- Mitten in einer Jagd hilft die richtige Kleidung nicht mehr; abschütteln geht nur ausser Sicht.
