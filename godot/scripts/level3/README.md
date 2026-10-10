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

| Aufgabe | Was passiert |
|---|---|
| **Abendgarderobe organisieren** (zuerst, ohne sie geht nichts anderes) | In der Mensa gleich neben der Tür eine Schürze vom Haken nehmen, dann hinten rechts an der Personalgarderobe einen Kellner-Frack (Timing-Minigame). Jede Person für sich. |
| **Armband fälschen** (zu zweit) | Eine Person schaut sich am Bändel-Tisch in der Eingangshalle die Vorlage an und sagt sie an, die andere baut sie in der Bastelecke der Küche nach. Das Nachbauen ist das bestehende Sequenz-Minigame, nur ohne Vorzeigen. Gilt für beide, sobald es gelingt. |
| **Prof-Badge holen** (Hauptmission) | In der Garderobe den grünen Lodenmantel finden (an einem von drei Ständern, jedes Mal an einem anderen), dann das bestehende Sequenz-Minigame «Mantel · Innentasche · Badge». Nur in Abendgarderobe. Gilt für beide. |
| **Buffet plündern** | Timing-Minigame an einem der Buffettische. Belohnung: ein Tablett, das man den Rest des Abends herumträgt. Jede Person für sich. |

**Der Badge landet im Spielstand** als `prof_badge`: `Game.has_item("prof_badge")`. Level 5 kann das so abfragen. Wird Level 3 neu gestartet, ist er wieder weg.

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

Allgemeines, das für dieses Level dazukam: `Game.items` mit `Game.add_item` und `Game.has_item` in `game_state.gd` (eigener Commit). Sonst ist keine gemeinsame Datei angefasst.

## Stellschrauben (Konstanten oben in `level.gd`)

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
| `BADGE_SEQ` | 5 | Länge der Sequenz für die Innentasche |
| `BUFFET_HITS`, `BUFFET_SPEED` | 3, 340 | Timing-Minigame am Buffet |
| `ZONES`, `NEEDS` | | wo welche Verkleidung gilt |
| `GUESTS` | 39 Gäste | wo wie viele Gäste herumgehen |
| `EJECT_SAAL`, `EJECT_KUECHE` | (30.5, 46), (22.5, 61.8) | wohin man gesetzt wird |
| `DEF.npcs` | | Standort und Blickrichtung der Aufpasser. Reichweite der Kegel: `"range"` pro Person, sonst 5.5 Tiles |
| `DEF.opp_spots` | 5 Plätze | wo Opps aus früheren Levels stehen, älteste zuerst |

## Wie es gebaut ist

- **Verkleidung als Faktor auf das Opp-System.** `opp.gd` ist nicht angefasst. Ein Opp füllt seinen Balken nur, solange er jemanden sieht. Nach jedem Physik-Schritt der Opps (`process_physics_priority`) nimmt `_apply_disguises`, was der Opp in diesem Schritt dazugezählt hat, und multipliziert es mit dem Wert der auffälligsten Person in seinem Blick (`suspicion`): 0 = richtig angezogen, 1 = neutraler Ort, `FACTOR_WRONG` = falsch angezogen oder gerade am Umziehen. Sehen sie nur richtig Angezogene, sinkt der Balken wie ohne Sicht.
- `opp.gd` jagt, wen es am nächsten sieht. Beginnt eine Jagd auf jemanden, der richtig angezogen ist, lenkt das Level sie im selben Schritt auf die auffällige Person um oder bricht sie ab.
- **Schritte:** `on_noise` setzt Opps, die wegen der Schritte einer richtig angezogenen Person losgegangen sind, auf ihren Stand vom Schritt davor zurück.
- **Aufpasser** sind gewöhnliche `npcs` aus `DEF`. `_ready` setzt sie auf «wachsam» (`angry`, Zustand `LAUERN`); als Opp gespeichert werden sie nie. `on_opp_catch` übernimmt ihren Rauswurf und lässt alte Opps beim Standard (Level verloren).
- **Kleidung:** `_wear` baut das Aussehen aus dem eigenen Look der Figur plus `LOOK_ABEND` (Stil `jacket`, Hemd in der Farbe der Person) oder `LOOK_SCHUERZE` (Stil `labcoat`, weiss). Dafür war kein neues Accessoire nötig.
- **Armband:** `_build` öffnet das bestehende Sequenz-Minigame über `main.open_minigame`, setzt das Muster des Armbands als Sequenz und schaltet sofort auf Eingabe. Nach einem Fehler würde das Minigame die Sequenz neu vorzeigen; `_blind` verhindert das. Die Vorlage (`vorlage.gd`) benutzt dieselben vier Richtungen.
- **Gäste** sind die Studierenden des Tages: `build_map` ersetzt `student_zones`, `_dress_guests` zieht ihnen Anzug oder Kleid an.
- **Hans Muster** steht als `npcs`-Eintrag mit der id `hans_muster` an der Bar. Macht ihn ein früheres Level unter genau dieser id zum Opp, lauert er hier von Anfang an.

## Stand

Per Bot von Start bis Siegbildschirm durchgespielt: im Hoodie in der Küche erwischt und rausgeworfen, Schürze, Frack, draussen umziehen, in Abendgarderobe von Security übersehen, in der Schürze im Saal rausgeworfen, Armband zu zweit über den geteilten Bildschirm (mit einem Fehler), Buffet, falscher und richtiger Ständer, Badge im Spielstand, Finale. Dazu geprüft: Opps aus Level 1 und 2 erscheinen an ihren Plätzen, übersehen Abendgarderobe und erwischen den Hoodie; alle Orte sind zu Fuss erreichbar. Das Aussehen ist an Screenshots geprüft.

**Noch nie von Menschen gespielt.** Zeitlimit, `FACTOR_WRONG` und die Standorte der Aufpasser sind geschätzt.

## Offen

- **Tanzfläche (Kamera-Minigame) fehlt.** Als das Level gebaut wurde, war der Autoload `Track` noch nicht auf `level-base`, deshalb ist dieser Schritt ausgelassen. Seit dem 10.10.2026 ist `Track` da (siehe `tracker/README.md`); die Tanzfläche in der Rotunde ist aber weiterhin nur Dekoration. Zu bauen: Aufgabe in `DEF.tasks` ergänzen, auf der Tanzfläche `Track.use(self, ["pose"])` und `TM.pose_match`, Zielposen aus `track_debug` (Taste P), Bildschirm hell färben (Scheinwerfer), Tasten-Variante bei `Track.alive == false` oder nach 5 Sekunden ohne Ergebnis.
- **«Relay-Prinzip aus Level 1»:** Im Code ist «Legi validieren» ein Timing-Minigame für eine Person, ein Relay gibt es dort nicht. Das Armband benutzt deshalb das bestehende Sequenz-Minigame für die bauende Person und eine eigene kleine Anzeige für die Vorlage.
- **Hans Muster** gibt es bisher in keinem Level als Opp. Welche id er bekommt, muss mit `HANS_ID` übereinstimmen.
- **Küchenschürze** sieht aus wie eine weisse Kochjacke (`labcoat`). Eine echte Schürze wäre ein neues Accessoire in `character_art.gd`.
- Ein Haken in `opp.gd` (zum Beispiel ein Faktor pro Person in `_watch` und in `hear`) würde das nachträgliche Korrigieren in `_apply_disguises` und `on_noise` ersetzen. Es funktioniert ohne, hängt aber an Einzelheiten von `opp.gd`: an der Sinkrate 0.35 und daran, dass der Balken nur in `_watch` steigt.
- Nebeneingänge (Nord, Süd, Rotunde) sind unbewacht. Wer im Hoodie hineinkommt, fällt drinnen trotzdem auf.
- Mitten in einer Jagd hilft die richtige Kleidung nicht mehr; abschütteln geht nur ausser Sicht.
