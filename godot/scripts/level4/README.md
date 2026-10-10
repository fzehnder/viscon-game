# Level 4 · Chemiepraktikum

Tag-Level für zwei. Praktikum Allgemeine Chemie bei Prof. Dr. Siedler im Labor im Südflügel des Hauptgebäudes. Erst pipettieren die beiden zusammen vor der Kamera, dann retten sie das Fondue des Professors mit Pusten ins Mikrofon, dann schreibt jede Person ein Testat. Fällt jemand durch, kocht der Professor über, und das Level beginnt für beide von vorne.

Die Nummer 4 ist gewählt, weil Level 3 laut Plan etwas anderes wird. Umnummerieren: Ordner umbenennen und `"tag"` in `DEF` anpassen, mehr hängt nicht an der Zahl (die Skripte laden sich gegenseitig mit relativen Pfaden).

## So spielt es sich

- **Start** gleich hinter der Labortür (vom Südkorridor her). Im Labor und im Lager dahinter arbeiten fünf Studierende, der Professor dreht seine Runden.
- **Aufgabe 1, Pipettieren zu zweit (Kamera):** An einem der zwei freien Plätze an den vorderen Labortischen (gelbe Matte, Raute). Der Platz lässt sich von beiden Seiten des Tisches benutzen, also auch vom Gang her, aus dem man von der Tür kommt. Wer dort die Interaktionstaste drückt, nimmt die Pipette; die andere Figur muss daneben stehen und hält das Glas. Dann vor der Webcam: Die Pipetten-Person drückt Daumen und Zeigefinger genau richtig zusammen (Balken von Rot über Grün nach Rot, der Zeiger muss im Grünen stehen), die Glas-Person hält die Hand flach und waagrecht ins Bild, ohne zu zittern (Wasserwaage und Zitter-Balken). Nur solange beide gleichzeitig im Grünen sind, tropft es; ist das Glas voll (10.0 mL), ist die Aufgabe für beide erledigt.
- **Aufgabe 2, Blubber-Alarm (Mikrofon):** Zwei Sekunden nach dem Pipettieren geht der Alarm los: Der Professor hat über dem Zuschauen sein Fondue vergessen, das in Kapelle 1 (Ostwand, blinkt rot) auf dem Bunsenbrenner steht. Beide laufen hin, wer drückt, öffnet das Spiel für beide. Dann **ins Mikrofon pusten**, bis das Thermometer im Grünen ist. Ohne Mikrofon, und auch sonst jederzeit, hilft Fächeln: beide hämmern gleichzeitig auf ihre Interaktionstaste (allein bringt es nichts). Wird zu wenig gepustet und erreicht das Fondue 100 °C (im Spiel, oder weil etwa 45 Sekunden lang niemand kommt), kocht es über: **Stichflamme, beide Figuren brennen.** Dann geht nichts anderes mehr: Beide müssen unter die **Notdusche** (gleich oberhalb von Kapelle 1, Raute und Wegpfeile zeigen hin) und dort die Interaktionstaste drücken; ein Zug reicht für beide, wenn beide darunter stehen. Danach sind sie tropfnass, das Fondue blubbert wieder, und sie versuchen es nochmals. Jede Stichflamme zählt als Fehler für die Note. Wer `BURN_MAX` Sekunden brennt, ohne zu duschen, ist verkohlt: Wutanfall und Neustart.
- **Aufgabe 3, Testat:** Sobald das Fondue gerettet ist, geht der Professor nach vorne und ruft das Testat aus. Am linken Pult liegt Serie A (Stoffe und Formeln), am rechten Serie B (Labor und Reaktionen). Jedes Pult kann nur einmal benutzt werden, also schreiben die beiden zwingend verschiedene Serien. Vier Fragen, drei Antworten, ein Fehler ist erlaubt. Die Fragen sind so einfach, dass alle bestehen können (Serie A: Wasser, Eis, Salz; Serie B: Verhalten im Labor), die falschen Antworten sind offensichtlicher Unsinn. Abbrechen geht nicht.
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

Benutzt das Tracking des Teams (Autoload `Track`, `tracker/README.md`). Von den zwei Händen, die der Kamera am nächsten sind, gehört die linke im Bild Spieler 1 und die rechte Spieler 2 (`TM.pair`), egal wo genau sie sind. Der Tracker nimmt auf dem Mac von selbst die eingebaute Kamera, nicht ein iPhone in der Nähe.

| Rolle | Was gemessen wird | Im Grünen, wenn |
|---|---|---|
| Pipette | `TM.pinch01(hand)`: Abstand Daumen–Zeigefinger, 0 = zusammen, 1 = weit offen | höchstens `PINCH_OK` von `PINCH_TARGET` entfernt |
| Glas halten | Neigung der Hand (Handgelenk zu Mittelfinger-Knöchel, `hand_tilt`) und Zittern der Handfläche (`TM.Jitter`) | Neigung höchstens `LEVEL_TOL` Grad und Zittern höchstens `SHAKE_LIMIT` |

- Sind beide im Grünen, füllt sich das Glas in `HOLD_TIME` Sekunden. Ist jemand draussen, läuft es langsam wieder leer (`DRAIN`); zittert die Glas-Hand stark (`SPILL_AT` mal die Grenze), wird verschüttet. Durchfallen kann man hier nicht.
- Im Kamerabild werden die Hände mit ihren Gelenken eingezeichnet. Pipette und Glas stehen **fest** am Rand des Bildes und folgen den Händen nicht (das zappelte): Die Pipette hat die Farbe davon, wie gut der Druck stimmt (Grün genau richtig, über Gelb nach Rot daneben), ihr Ballon ist so flach, wie die Finger zusammen sind. Das Glas neigt sich mit der Hand und füllt sich.
- Nichts von der Kamera wird roh benutzt: Die Werte werden über `SMOOTH` Sekunden geglättet, eine Hand, die die Kamera kurz verliert, bleibt `HOLD` Sekunden, wo sie war, und Zittern zählt erst, wenn es `SHAKE_TIME` lang anhält (ein einzelner Sprung der Kamera zählt nicht).
- Solange das Spiel offen ist, wird die Karte dahinter nicht neu gezeichnet (`_freeze_views` in `level.gd`). Die Karte kostet sonst den grössten Teil jedes Bildes, und Kamerabild und Zeiger ruckeln in ihrem Takt.
- **Einmal pro Rechner einrichten** (sonst gibt es nur die Tasten-Variante): `brew install uv`, dann im Repo `uv run tracker/tracker.py --selftest`. Beim ersten Start fragt macOS, ob Godot die Kamera benutzen darf. Bricht der Selbsttest beim Laden der Modelle mit `CERTIFICATE_VERIFY_FAILED` ab (Python von python.org ohne Zertifikate), hilft `SSL_CERT_FILE=/etc/ssl/cert.pem uv run tracker/tracker.py --selftest`.
- Das Level weckt den Tracker schon beim Start (`Track.use` in `_ready`), damit die Kamera bereit ist, wenn die beiden am Tisch ankommen, und gibt sie nach dem Pipettieren wieder frei.
- Kommt das Kamerabild erst, nachdem schon auf Tasten umgeschaltet wurde (langsamer erster Start), wechselt das Spiel von selbst zur Kamera zurück, ausser jemand hat die Tasten mit `K` gewählt.
- **Tasten-Variante** (Regel des Teams für jedes Kamera-Minigame): Kommt nach `CAM_WAIT` Sekunden kein Kamerabild oder meldet `Track` «kein Tracker» oder «keine Kamera», wird mit Tasten gespielt: Die Pipetten-Person hält die Interaktionstaste gedrückt und lässt sie los, die Glas-Person steuert die Blase der Wasserwaage mit links und rechts. `K` schaltet von Hand um.
- In `level.gd` hängt das Spiel an `start_pipette(pid, k)`; es endet mit `pipette_done` oder `pipette_aborted`. `pipette_failed(pid, k)` gibt es weiterhin als Haken (Wutanfall und Neustart), das Kamera-Spiel ruft ihn nicht auf.

## Aufgabe 2: Blubber-Alarm (`blow_game.gd`)

Benutzt das Mikrofon über `Track.use_mic` und `Track.blow` (0 bis 1, siehe `tracker/README.md`). macOS fragt beim ersten Mal, ob Godot das Mikrofon benutzen darf.

- Im Spiel heizt das Fondue mit `HEAT` pro Sekunde auf. Pusten kühlt mit bis zu `COOL_BLOW` pro Sekunde, schwächer als `BLOW_MIN` zählt nicht (Raumgeräusch). Der Balken «Mikrofon» zeigt, wie stark das Pusten ankommt.
- Fächeln: Jeder Tastendruck kühlt um `COOL_KEY`, aber nur, wenn die andere Person innerhalb von `TOGETHER` Sekunden auch gedrückt hat. Das geht immer, mit und ohne Mikrofon. Liefert das Mikrofon nach `MIC_WAIT` Sekunden nichts, sagt das Spiel «Kein Mikrofon gefunden».
- Gerettet bei `SAFE` oder darunter. Bei 100 kocht es über (`burnt`), und `level.gd` zündet die Figuren an (`_flare`).
- Brennen: `burning`, `burn_t`, `_update_fire`, `_pull_shower` in `level.gd`. Solange jemand brennt, wartet das Fondue (bei `FLARE_RESET`), an der Kapelle lässt sich nichts öffnen, und alle anderen Hinweise sind aus. Die Dusche läuft `SHOWER_TIME` Sekunden pro Zug, nach `SOAK` Sekunden darunter ist das Feuer aus. Flammen, Countdown, Wasser und Tropfen zeichnet `_paint_top` über den Figuren; gefärbt werden die Figuren über `modulate`, ohne `player.gd` anzufassen.
- Im Labor steigt die Temperatur ab `ALARM_START` mit `ALARM_RISE` pro Sekunde, solange niemand kühlt; die Kapelle blinkt, der Rauchmelder piept, der Professor steht daneben und wird mit dem Fondue röter. Wer das Spiel mit Esc verlässt, findet das Fondue so heiss vor, wie er es verlassen hat.
- In `level.gd`: `_start_alarm`, `_update_alarm`, `start_cooling`, `_cooled`. Die Reihenfolge des Levels steht in `phase` (`PH_PIPETTE`, `PH_ALARM`, `PH_TESTAT`).

## Dateien

| Datei | Inhalt |
|---|---|
| `level.gd` | Beschreibung (`DEF`), Fragen, Sprüche, Labor-Möbel (`build_map`), Ablauf beider Aufgaben, Professor und Studierende, Zeichnung des Labors |
| `lab_person.gd` | Professor oder Studierende: laufen Wege ab und zeichnen sich samt Blase, Dampf und Schweiss; was sie tun, entscheidet `level.gd` |
| `pipette_game.gd` | Aufgabe 1: das Kamera-Spiel für zwei samt Tasten-Variante |
| `blow_game.gd` | Aufgabe 2: das Fondue kühl pusten (Mikrofon) oder fächeln (Tasten) |
| `chem_quiz.gd` | das Testat: Fragebogen auf der Bildschirmhälfte der Figur, im Stil von `minigame.gd`, aber mit Durchfallen |
| `prof_rage.gd` | der Wutanfall als Abfolge von Beats, ähnlich wie `cutscene.gd` |
| `lab_sfx.gd` | Sounds nur für dieses Level: Pfeifkessel, Knall, Scherben, Stempel, Stimme des Professors, Tropfen |

Gemeinsame Dateien sind nicht angefasst. Das Testat konnte nicht das Quiz aus `minigame.gd` benutzen, weil dessen Fragen fest aus `characters.gd` kommen; `chem_quiz.gd` meldet sich deshalb selbst in `main.minis` an (so entsteht der Split Screen von allein).

## Stellschrauben (Konstanten oben in `level.gd`)

| Konstante | Wert | Wirkung |
|---|---|---|
| `DEF.time` | 360 s | Zeitlimit. Mit dem echten Experiment wahrscheinlich anzupassen |
| `PINCH_TARGET`, `PINCH_OK` in `pipette_game.gd` | 0.45, 0.135 | wie weit die Finger zusammen sein müssen und wie breit der grüne Bereich ist |
| `LEVEL_TOL` | 15° | wie schief die Hand sein darf |
| `SHAKE_LIMIT`, `SHAKE_TIME` | 11.0, 0.35 s | ab wann die Hand als zitternd gilt und wie lange das anhalten muss. Der Badge in Level 3, der vor der echten Kamera gespielt wurde, nimmt 12 |
| `SMOOTH`, `HOLD`, `STICKY` | 0.1 s, 0.5 s, 1.2 | Glättung, Überbrücken kurzer Aussetzer, wie viel breiter die Grenzen sind, wenn man einmal im Grünen ist |
| `HOLD_TIME`, `DRAIN`, `SPILL_AT` | 3.5 s, 0.35, 2.0 | wie lange beide richtig liegen müssen, wie schnell es wieder leer läuft, ab wann verschüttet wird |
| `CAM_WAIT` | 6 s | wie lange auf die Kamera gewartet wird, bevor die Tasten gelten |
| `KEY_SQUEEZE`, `KEY_RELAX`, `KEY_TILT`, `KEY_DRIFT` | | Schwierigkeit der Tasten-Variante |
| `HEAT`, `COOL_BLOW`, `BLOW_MIN` in `blow_game.gd` | 6.5, 30, 0.1 | wie schnell das Fondue heizt, wie stark Pusten kühlt, ab wann Pusten zählt |
| `COOL_KEY`, `TOGETHER` | 2.3, 0.45 s | Fächeln: Kühlung pro Tastendruck und wie gleichzeitig beide drücken müssen |
| `SAFE`, `MIC_WAIT` | 22, 2.5 s | ab wann es gerettet ist; wie lange auf das Mikrofon gewartet wird |
| `ALARM_START`, `ALARM_RISE` in `level.gd` | 0.38, 0.014 | wie heiss das Fondue beim Alarm ist und wie schnell es im Labor heisser wird (etwa 45 s bis angebrannt) |
| `FLARE_RESET` | 0.5 | wie heiss das Fondue nach der Stichflamme ist |
| `BURN_MAX` | 20 s | wie lange eine Figur brennen darf, bevor es zu spät ist |
| `SHOWER_TIME`, `SOAK`, `WET` | 4 s, 0.8 s, 7 s | wie lange die Notdusche läuft, wie lange man darunter stehen muss, wie lange man danach tropft |
| `FONDUE_RANTS` | 7 Sprüche | Wutanfall, wenn jemand verkohlt |
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

**Erste Rückmeldung vor der echten Kamera (10.10.2026):** Der Tracker nahm das iPhone statt der Kamera des MacBooks (inzwischen im Tracker behoben), und das Pipettieren wirkte «buggy»: Pipette und Glas hingen an den erkannten Händen und zappelten mit. Daraufhin: feste, farbige Pipette, festes Glas, Glättung, Überbrücken von Aussetzern, Zittern erst nach `SHAKE_TIME`, grosszügigere Schwellen, Karte dahinter angehalten. Das ist per Bot mit künstlichen Händen geprüft; ob es sich vor der Kamera jetzt gut anfühlt, ist noch nicht zurückgemeldet.

**Zweite Rückmeldung (10.10.2026):** Das Pipettieren «sieht super aus», soll aber eine Spur schwieriger sein: `PINCH_OK` 0.16 auf 0.135, `LEVEL_TOL` 18 auf 15 Grad, `SHAKE_LIMIT` 12 auf 11, `HOLD_TIME` 3 auf 3.5 s, `STICKY` 1.25 auf 1.2. Dazu kam der Blubber-Alarm als neue Aufgabe zwischen Pipettieren und Testat.

Der Blubber-Alarm ist per Bot mit echten Tastendrücken geprüft (von der Tür über das Pipettieren zur Kapelle und weiter ins Testat): Mikrofon-Weg mit **künstlichem** Pusten (`Track.blow` von Hand gesetzt), Raumgeräusch kühlt nicht, Verlassen und Wiederkommen, Fächeln allein bringt nichts, Fächeln zu zweit rettet. Zu wenig gepustet: Stichflamme, beide brennen, an der Kapelle geht nichts mehr, zu Fuss unter die Notdusche, ein Zug löscht beide, zurück zur Kapelle, zweiter Versuch gelingt, danach das Testat. Niemand kommt: Stichflamme nach etwa 45 s, und wer dann 20 s nicht duscht, löst den Wutanfall aus. **Mit einem echten Mikrofon und echtem Pusten ist er noch nie gelaufen**; laut Team ist `Track.blow` bisher nur mit Raumgeräusch geprüft.

**Dritte Rückmeldung (10.10.2026):** Wer zu wenig pustet, soll brennen und unter die Notdusche müssen. Vorher führte das Überkochen direkt zum Wutanfall und Neustart; jetzt gibt es die Stichflamme und einen zweiten Versuch, und der Wutanfall kommt nur noch, wenn jemand zu lange brennt.

Von der Person, die das Level gebaut hat, einmal angespielt (dabei fiel der Fehler oben auf). Zeitlimit, Anzahl Fragen und Länge des Wutanfalls sind ebenfalls geschätzt.

Offen und Ideen:
- Kamera-Schwellen (`PINCH_TARGET`, `LEVEL_TOL`, vor allem `SHAKE_LIMIT`) im Spieltest einstellen.
- Wer die Hand «waagrecht» mit den Fingern zur Kamera hält statt quer durchs Bild, wird von der Neigungsmessung nicht richtig erfasst; die Anleitung im Spiel sagt nur «flach und waagrecht».
- Läuft die Zeit ab, kommt der normale «Zeit abgelaufen»-Bildschirm ohne Wutanfall.
- Die Sounds des Wutanfalls sind nur im Code geprüft, nicht mit Ohren.
- Kein Bezug zum Opp-System: Das Level hat keine `opp_spots`, Opps aus früheren Levels tauchen hier nicht auf.
- Der Wutanfall selbst ist nur auf der alten Karte Bild für Bild angeschaut; er ist ein Vollbild-Overlay und hängt nicht an der Karte.
