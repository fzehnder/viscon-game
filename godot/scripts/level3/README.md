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
| **Armband fälschen** (zu zweit) | Eine Person schaut sich am Bändel-Tisch in der Eingangshalle die Vorlage an und sagt die Pfeile an, die andere tippt sie in der Bastelecke der Küche nach. **Wer baut, bekommt die Pfeile absichtlich nicht gezeigt**; unter den Tasten steht, wo sie zu finden sind. Die Vorlage zeigt mit, wie weit die andere Person ist (abgehakt, «als Nächstes», «falsch, wieder von vorne»). Das Nachbauen ist das bestehende Sequenz-Minigame, nur ohne Vorzeigen. Ein falscher Pfeil ist ein Fehler, danach geht es beim ersten Pfeil weiter. Gilt für beide. | nein |
| **Im Takt über die Tanzfläche** (zu zweit) | Beide Figuren stehen in Abendgarderobe auf der Tanzfläche in der Rotunde. Vor der Kamera gilt: **Wer zum Start die Hände hebt, tanzt.** Hebt eine Person die Hände, tanzt sie für beide; heben zwei sie gleichzeitig, tanzen beide, und trifft eine nicht, ist es ein Fehler für beide. Danach wird eine Pose nach der anderen gezeigt, und sie muss sitzen, solange der Balken grün ist. Vier Treffer. Gilt für beide. | **Körperhaltung** |
| **Prof-Badge holen** (Hauptmission) | In der Garderobe den grünen Lodenmantel finden (an einem von drei Ständern, jedes Mal an einem anderen). Dann den Badge mit zwei Fingern aus der Innentasche ziehen: Daumen und Zeigefinger zusammendrücken, Hand langsam nach oben, nicht zittern. Nur in Abendgarderobe. Gilt für beide. | **Hand** |
| **Buffet plündern** | Timing-Minigame an einem der Buffettische. Belohnung: ein Tablett, das man den Rest des Abends herumträgt. Jede Person für sich. | **Gesicht:** Mund weit auf schnappt zu, genau wie die Taste |

**Der Badge landet im Spielstand** als `prof_badge`: `Game.has_item("prof_badge")`. Level 5 kann das so abfragen. Wird Level 3 neu gestartet, ist er wieder weg.

## Kamera

Drei Aufgaben lassen sich vor der Webcam spielen (Autoload `Track`, Einrichtung in `tracker/README.md`). **Das Level ist ohne Kamera komplett spielbar:** Jede der drei hat eine Tasten-Variante.

| Aufgabe | Mit Kamera | Ohne Kamera |
|---|---|---|
| Tanzfläche | Pose mit den Armen nachmachen (ab 50 % Übereinstimmung) | beide drücken die gezeigte Richtung, solange der Balken grün ist |
| Badge | Pinch und ruhige Hand | das bestehende Sequenz-Minigame «Mantel · Innentasche · Badge» |
| Buffet | Mund auf | die Taste; beides geht gleichzeitig |

- **Umschalten auf Tasten** passiert von selbst, wenn die Kamera 5 Sekunden lang nichts liefert (kein Tracker, keine Kamera, keine Freigabe). Läuft die Kamera, aber jemand ist nicht im Bild, wartet das Spiel dreimal so lang. Mit der Interagieren-Taste (E / Enter) schaltet man jederzeit selbst um.
- **Der Bildschirm wird hell**, solange ein Kamera-Minigame offen ist: in der Geschichte der Scheinwerfer auf der Tanzfläche und das hell beleuchtete Buffet, im abgedunkelten Raum die Lampe, ohne die die Kamera niemanden findet. Das ist Absicht und sollte nicht dunkler werden.
- **Abstand:** Wer an der Tastatur sitzt, ist für die Kamera eines Laptops zu nah: Im Bild sind nur Kopf und Schultern. Fürs Tanzen muss man zurückrücken oder aufstehen, bis die erhobenen Hände im Bild sind. Deshalb beginnt der Tanz mit «Hände hoch»: Wer das schafft, steht richtig. Für Badge und Buffet kann man sitzen bleiben.
- **Wer tanzt:** Wer zum Start die Hände hebt. Alle anderen im Bild sind Zuschauer: Sie werden dünn eingezeichnet und zählen nicht, egal wie viele um den Laptop stehen. Die erste Person mit erhobenen Händen öffnet ein Fenster von anderthalb Sekunden, in dem eine zweite dazukommen kann. Von zwei Tanzenden ist die linke Person 1 und die rechte Person 2. Verlässt bei zweien jemand das Bild, wird er noch 6 Sekunden erwartet (kostet einen Takt), danach tanzt die andere Person für beide. Geht die einzige tanzende Person, übernimmt nach 3 Sekunden, wer der Kamera am nächsten ist.
- **Ruhige Anzeige:** Was die Kamera liefert, ist unruhig. Punkte zittern, Leute fehlen für einzelne Bilder, und stehen mehrere um den Laptop, meldet sie mal diese, mal jene, gelegentlich eine Person doppelt. Deshalb wird jede Person von Bild zu Bild verfolgt (wer ist wer, entscheidet der Abstand zur letzten Position), geglättet und bei kurzen Aussetzern einen Moment gehalten. Wer neu ins Bild kommt, wird eingeblendet, wer geht, ausgeblendet; was die Kamera nur für ein einzelnes Bild sieht, erscheint gar nicht. Der Hintergrund ist deckend, damit nichts vom Spiel durchscheint.
- **Was man sieht, zählt:** Der Balken unter dem Kamerabild folgt dem Wert weich. Wird er grün, sitzt die Pose, und genau das wertet das Spiel. Grün bleibt er, bis der Wert 6 Punkte unter die Marke fällt (`OK_SLACK`), denn wer eine Pose hält, wackelt um ein paar Prozent. Eine Prozentzahl gibt es nicht mehr: Sie lief ständig hin und her. Steht jemand von zweien nicht im Bild, bleibt die Zeile stehen und sagt «nicht im Bild».
- **Flüssiges Bild:** Solange ein Kamera-Minigame offen ist, wird die Karte dahinter nicht gezeichnet (`_cover` in `level.gd`): beim Tanzen beide Bildhälften, bei Badge und Buffet die Hälfte der spielenden Person. Das Zeichnen der Karte kostet fast das ganze Bild (auf einem MacBook Pro mit 120-Hz-Bildschirm läuft das Spiel deswegen mit etwa 37 Bildern pro Sekunde). Gemessen mit laufender Kamera: Tanzen 120 Bilder pro Sekunde statt 32, Badge 59 statt 39. Vorher stotterte das Kamerabild im Takt der Karte.
- **Badge und Buffet** nehmen, was im Bild ist: Der Badge bleibt bei der Hand, die ihn greift, auch wenn weitere Hände im Bild sind. Am Buffet zählt von den beiden grössten Gesichtern das auf der eigenen Seite oder das einzige.
- Der Tracker startet schon beim Start des Levels (`PREWARM`), die Kamera selbst geht erst in einem Kamera-Minigame an. So liefert sie etwa 2 bis 3 Sekunden nach dem Öffnen (gemessen: 2.6 s) und damit vor Ablauf der 5 Sekunden.

### Zielposen: Platzhalter

Die vier Posen in `posen.gd` (Hände hoch, Dach, Disco links, Disco rechts) sind **Platzhalter**, aus Armrichtungen errechnet. Sie halten die Arme oben und über den eigenen Schultern, weil alles andere aus dem Bild ragt oder der Person daneben in die Quere kommt. Eine Person hat sie vor der Kamera durchgetanzt (siehe Stand). Eigene Posen einsetzen:

1. `godot --path godot res://track_debug.tscn`, Taste 3 (Körper), Pose hinstellen, Taste P.
2. Den Inhalt der gespeicherten `pose_target.json` als Eintrag in `AUFGENOMMEN` oben in `posen.gd` kopieren und einen Namen dazuschreiben: `{"name": "Jubel", "pts": [...]}`.
3. Sobald `AUFGENOMMEN` nicht leer ist, werden nur noch diese Posen benutzt. «Hände hoch» zum Start bleibt.

Beim Aufnehmen so stehen wie später beim Spielen, am besten zu zweit nebeneinander, und prüfen, dass Ellbogen und Handgelenke im Bild bleiben.

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
| `ARMBAND_SOLO` | aus | an: Wer baut, bekommt die Pfeile zuerst vorgezeigt wie im normalen Sequenz-Minigame. Zum Spielen allein; die Vorlage braucht es dann nicht |
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
| `CAM_PATIENCE` | 3 | mal so lange, wenn die Kamera läuft, aber niemand im Bild ist |
| `LIGHT` | fast weiss, deckend | wie hell der Bildschirm wird |
| `POSE_OK` | 50 % | ab wann eine Pose sitzt (eigene Skala, siehe `_arms`). Kleiner = leichter. Gemessen: gut getroffene Posen 50 bis 65 %, eine andere Pose unter 40 % |
| `OK_SLACK` | 6 Punkte | so weit darf eine Pose, die sitzt, wieder unter `POSE_OK` fallen, bevor sie nicht mehr sitzt. Grösser = ruhigerer Balken, aber er darf nicht bis zu den 40 % einer falschen Pose reichen |
| `READY_OK`, `READY_HOLD` | 42 %, 0.5 s | wie gut und wie lange «Hände hoch» sitzen muss, damit der Tanz beginnt |
| `ARM_TOLERANCE` | 70° | ab wie viel Abweichung ein Ober- oder Unterarm 0 Punkte gibt |
| `JOIN` | 1.5 s | so lange kann nach den ersten erhobenen Händen eine zweite Person dazukommen |
| `PAIR_MEMORY`, `REACQUIRE` | 6 s, 3 s | wie lange eine von zwei Tanzenden fehlen darf, bevor die andere für beide tanzt; wie lange die einzige fehlen darf, bevor jemand anderes übernimmt |
| `SMOOTH`, `HOLD` | 0.08 s, 0.5 s | wie stark erkannte Punkte geglättet werden (kleiner = schneller, aber zittriger) und wie lange jemand bei einem Aussetzer stehen bleibt (die ersten 0.2 s unverändert, dann ausblendend) |
| `BAR_SMOOTH`, `SHOW_VIS` | 0.12 s, 0.3 | wie weich die Balken folgen; ab welcher Sicherheit ein Körperpunkt eingezeichnet wird |
| `SAME_PERSON`, `REJOIN` | 0.13, 0.3 | so weit (in Bildbreiten) darf sich jemand von einem Bild zum nächsten bewegen und gilt noch als dieselbe Person; so weit, wenn die Kamera die Person eine Weile verloren hatte |
| `SAME_BODY` | 0.05 | zwei gemeldete Personen, die näher beieinander liegen, sind dieselbe (die Kamera meldet manchmal jemanden doppelt) |
| `KEEP_VIS` | 0.3 | wer schon verfolgt wird, bleibt es bis zu dieser Sicherheit der Schultern (neu dazu kommt man erst ab 0.5). So flackert niemand am Bildrand ein und aus |
| `Followed.FADE_IN` | 0.2 s | so lange dauert es, bis jemand Neues voll eingezeichnet ist |
| `BEAT` | 3.4 s | Zeit pro Pose |
| `BEAT_WINDOW` | 1.4 s | die letzten Sekunden einer Pose, in denen sie sitzen muss (Balken grün) |
| `DANCE_HITS` | 4 | so viele Posen müssen getroffen werden |
| `PINCH_GRAB`, `PINCH_DROP` | 0.3, 0.6 | wie nah die Finger zusammen sein müssen, um den Badge zu halten, und ab wann er entgleitet |
| `PULL` | 0.16 | wie weit die Hand nach oben muss, in Bildhöhen |
| `JITTER_MAX`, `JITTER_TIME` | 12, 0.35 s | so zittrig darf die Hand so lange sein, sonst raschelt der Mantel (Fehler, nochmals) |
| `HAND_LOST` | 0.8 s | so lange darf die Hand aus dem Bild sein, bevor der Badge zurückrutscht |

Die Vorgabe für das Tanzen war `TM.pose_match` über 80 %. Vor der echten Kamera kamen damit auch gut getroffene Posen nur auf 55 bis 80 %, und weil die Schulterlinie immer passt, lag eine falsche Pose nicht weit darunter. Das Tanzen wertet deshalb selbst aus (`_arms`): nur die Arme, und der schlechtere Arm zählt.

## Wie es gebaut ist

- **Verkleidung als Faktor auf das Opp-System.** `opp.gd` ist nicht angefasst. Ein Opp füllt seinen Balken nur, solange er jemanden sieht. Nach jedem Physik-Schritt der Opps (`process_physics_priority`) nimmt `_apply_disguises`, was der Opp in diesem Schritt dazugezählt hat, und multipliziert es mit dem Wert der auffälligsten Person in seinem Blick (`suspicion`): 0 = richtig angezogen, 1 = neutraler Ort, `FACTOR_WRONG` = falsch angezogen oder gerade am Umziehen. Sehen sie nur richtig Angezogene, sinkt der Balken wie ohne Sicht.
- `opp.gd` jagt, wen es am nächsten sieht. Beginnt eine Jagd auf jemanden, der richtig angezogen ist, lenkt das Level sie im selben Schritt auf die auffällige Person um oder bricht sie ab.
- **Schritte:** `on_noise` setzt Opps, die wegen der Schritte einer richtig angezogenen Person losgegangen sind, auf ihren Stand vom Schritt davor zurück.
- **Aufpasser** sind gewöhnliche `npcs` aus `DEF`. `_ready` setzt sie auf «wachsam» (`angry`, Zustand `LAUERN`); als Opp gespeichert werden sie nie. `on_opp_catch` übernimmt ihren Rauswurf und lässt alte Opps beim Standard (Level verloren).
- **Kleidung:** `_wear` baut das Aussehen aus dem eigenen Look der Figur plus `LOOK_ABEND` (Stil `jacket`, Hemd in der Farbe der Person) oder `LOOK_SCHUERZE` (Stil `labcoat`, weiss). Dafür war kein neues Accessoire nötig.
- **Armband:** `_build` öffnet das bestehende Sequenz-Minigame über `main.open_minigame`, setzt das Muster des Armbands als Sequenz und schaltet sofort auf Eingabe. Nach einem Fehler würde das Minigame die Sequenz neu vorzeigen; `_blind` verhindert das. Die Vorlage (`vorlage.gd`) benutzt dieselben vier Richtungen. `_build_info` schreibt den Text unter den Tasten, `_view_info` den Stand auf der Vorlage. Solange niemand angefangen hat, schickt die Wegführung (Tab / Komma) die Person, die näher am Eingang steht, zur Vorlage und die andere in die Bastelecke.
- **Tanzen:** `_follow_bodies` verfolgt jede Person im Bild (Klasse `Followed`: geglättet, bei Aussetzern gehalten, ein- und ausgeblendet), `_ready_up` nimmt ins Team, wer die Hände hebt, `_team_poses` liefert während des Tanzes die Posen der Tanzenden. `_arms` vergleicht pro Arm die Richtung von Ober- und Unterarm mit der Zielpose; `sits` hält fest, ob die Pose gerade sitzt (das, was der Balken zeigt).
- **Kamera-Minigames:** `kamera_spiel.gd` hält sich an den Vertrag von `minigame.gd` (Signale `finished` und `mistake`, Zähler `mistakes`). `_open_cam` trägt es so in `main.minis` ein, wie `main.gd` es mit eigenen Minigames tut. Dadurch gelten die Figuren als beschäftigt, der Bildschirm teilt sich bei einer Person, und `main._abort_mini` funktioniert. Die Kamera hält `Track.use(self, …)` und geht mit dem Schliessen von selbst wieder aus. `_cover` stellt für die Dauer das Zeichnen der verdeckten Bildhälften ab (`main.vps[i].render_target_update_mode`) und beim Schliessen wieder an.
- **Badge:** Das Signal `fallback` schliesst das Kamera-Minigame und öffnet stattdessen das Sequenz-Minigame.
- **Buffet:** Das Timing-Minigame bleibt, wie es ist. `_snap_with_mouth` ruft bei offenem Mund dieselbe Funktion auf wie die Taste und färbt den Hintergrund des Minigames hell.
- **Gäste** sind die Studierenden des Tages: `build_map` ersetzt `student_zones`, `_dress_guests` zieht ihnen Anzug oder Kleid an.
- **Hans Muster** steht als `npcs`-Eintrag mit der id `hans_muster` an der Bar. Macht ihn ein früheres Level unter genau dieser id zum Opp, lauert er hier von Anfang an.

## Stand

Das Armband ist zusätzlich mit echten Tastendrücken geprüft (E am Tisch, Enter in der Bastelecke, Pfeiltasten, ein falscher Pfeil, dann richtig). Allein lässt es sich spielen, indem man eine Figur an der Vorlage stehen lässt und mit der anderen baut.

Per Bot von Start bis Siegbildschirm durchgespielt: im Hoodie in der Küche erwischt und rausgeworfen, Schürze, Frack, draussen umziehen, in Abendgarderobe von Security übersehen, in der Schürze im Saal rausgeworfen, Armband zu zweit über den geteilten Bildschirm (mit einem Fehler), Buffet, falscher und richtiger Ständer, Badge im Spielstand, Finale. Dazu geprüft: Opps aus Level 1 und 2 erscheinen an ihren Plätzen, übersehen Abendgarderobe und erwischen den Hoodie; alle Orte sind zu Fuss erreichbar. Das Aussehen ist an Screenshots geprüft.

Kamera-Aufgaben: Der Bot hat sie mit eingespeisten Kameradaten gespielt und alle drei Tasten-Varianten. Tanzen: eine Person nah am Laptop mit unruhiger Kamera (Aussetzer, Zittern, etwas, das nur ein Bild lang erkannt wird, eine doppelt gemeldete Person, jemand am Rand mit unsicheren Schultern, ein schneller Schritt zur Seite), vier Personen um den Laptop, von denen die Kamera abwechselnd welche auslässt, eine von vieren hebt die Hände und tanzt für beide, zwei heben sie nacheinander, eine von zweien macht die falsche Pose, geht kurz aus dem Bild und kommt einen Schritt daneben zurück, geht ganz, und eine Pose, die um die Marke herum wackelt (der Wert kreuzte sie fünfmal, der Balken wechselte einmal die Farbe). Badge mit zwei Händen im Bild und Aussetzern, Buffet nur mit dem Mund.

Mit der echten Kamera (MacBook, 10.10.2026): Sie liefert 1.5 bis 3.8 s nach dem Öffnen. Vor dem Umbau der Anzeige hat eine Person den Tanz zu Ende getanzt (vier Treffer, ein Fehler, 15 Sekunden), und mit vier Personen um den Laptop meldete die Kamera in 19 Sekunden 60-mal eine andere Zahl von Leuten, die Anzeige sprang entsprechend. Nach dem Umbau: eine Person 22 Sekunden lang im Bild, ein einziger verfolgter Körper, die Anzeige wechselte nur beim Erscheinen; der Badge wurde vor der Kamera herausgezogen (ohne Fehler, 4 Sekunden nach dem ersten Griff). **Getanzt hat seit dem Umbau auf «wer die Hände hebt, tanzt» vor der echten Kamera noch niemand**, auch nicht in einer Gruppe; das ist nur mit eingespeisten Daten geprüft. Das Buffet mit dem Mund hat vor der Kamera noch niemand probiert.

Das Level als Ganzes hat noch niemand in einem Zug durchgespielt. Zeitlimit, `FACTOR_WRONG` und die Standorte der Aufpasser sind geschätzt, ebenso die Schwellen für Badge und Buffet.

## Offen

- **Zielposen sind Platzhalter** (siehe oben). «Dach» lag im Versuch am knappsten (44 bis 60 %); wenn es zu oft daneben geht, `POSE_OK` weiter senken.
- **Tanzen zu zweit** braucht Platz: Beide müssen mit erhobenen Armen ins Bild passen, also etwa anderthalb Meter Abstand zur Kamera.
- **`JITTER_MAX` ist geraten.** Die Messung zittert auch bei ruhiger Hand, weiter weg von der Kamera stärker. In `track_debug` aus Spielabstand den Wert «Zittern» einer ruhigen Hand ablesen und deutlich darüber gehen.
- **Mund am Buffet:** Erkennung und Mundbewegung brauchen einen Moment, man muss etwas früher aufmachen als drücken. Wenn das nervt: `BUFFET_SPEED` senken.
- Ursprünglich war nur ein Kamera-Moment pro Level geplant, damit sich die Mechanik nicht abnutzt. Auf Wunsch (10.10.2026) sind es jetzt drei, jeder mit einer anderen Erkennung (Körper, Hand, Gesicht).
- **«Relay-Prinzip aus Level 1»:** Im Code ist «Legi validieren» ein Timing-Minigame für eine Person, ein Relay gibt es dort nicht. Das Armband benutzt deshalb das bestehende Sequenz-Minigame für die bauende Person und eine eigene kleine Anzeige für die Vorlage.
- **Hans Muster** gibt es bisher in keinem Level als Opp. Welche id er bekommt, muss mit `HANS_ID` übereinstimmen.
- **Küchenschürze** sieht aus wie eine weisse Kochjacke (`labcoat`). Eine echte Schürze wäre ein neues Accessoire in `character_art.gd`.
- Ein Haken in `opp.gd` (zum Beispiel ein Faktor pro Person in `_watch` und in `hear`) würde das nachträgliche Korrigieren in `_apply_disguises` und `on_noise` ersetzen. Es funktioniert ohne, hängt aber an Einzelheiten von `opp.gd`: an der Sinkrate 0.35 und daran, dass der Balken nur in `_watch` steigt.
- Nebeneingänge (Nord, Süd, Rotunde) sind unbewacht. Wer im Hoodie hineinkommt, fällt drinnen trotzdem auf.
- Mitten in einer Jagd hilft die richtige Kleidung nicht mehr; abschütteln geht nur ausser Sicht.
