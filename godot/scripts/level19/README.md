# Wahlfach · Freelancing (D-MAVT)

Freiwilliges Wahlfach, nicht Teil der Story (`"block": "W"`, Nummer 19). Start über den Leistungsüberblick unter «Wahlfächer», im Menü oder im Spiel mit `L`.

## So spielt es sich

1. **Cutscene:** Das Konto ist leer, also suchen die beiden einen Freelance-Job.
2. **ETH Freelance-Börse:** vier Jobs als Karten: AMZ Racing (Telemetrie-Dashboard), ARIS (Flugsoftware für die Bergung), Swissloop Tunneling (Sensorik am Bohrkopf) und Vitalfaden AG (erfundenes MedTech-Startup, App für ein EKG-Shirt). Mit A/D oder Pfeilen wählen, E/Enter oder Klick bewirbt sich. **Nur eine Bewerbung pro Spiel:** Die Bewerbung steht im Spielstand (`Game.electives`). Danach sind die anderen Karten grau («Keine weitere Bewerbung»), auch nach einer Absage gibt es keinen zweiten Versuch, auch nicht, wenn man das Wahlfach neu öffnet. Die Bewerbung zählt ab der ersten Sekunde: Abbrechen oder das Spiel schliessen gilt als Absage. Erst ein neues Studium (START im Menü) gibt sie wieder frei. Oben rechts steht das Ergebnis.
3. **Interview als Video-Call:** Die Interviewerin sitzt in der großen Kachel, die beiden Spieler*innen rechts, mit dem echten Kamerabild, falls der Kamera-Tracker läuft, sonst als gezeichnete Figur. Sechs Fragen, jede an P1, an P2 oder an beide. Wer dran ist, **hält E bzw. Enter gedrückt und antwortet laut**. Die Antwort erscheint als Text, die erkannten Schlüsselwörter grün. Die Interviewerin nickt (grüner Haken) oder schüttelt den Kopf und sagt, was eine gute Antwort gewesen wäre.
4. Oben rechts: Fortschritt (grün/rot pro Frage) und der Balken «Eindruck». Wer mindestens 2 Sekunden spricht, wirkt selbstbewusster (+3).
5. **Fünf von sechs richtig:** Vertrag. Beide halten gleichzeitig ihre Taste, die Unterschriften zeichnen sich, Stempel «ANGESTELLT», Konfetti. **Weniger:** Absage-Mail mit den verpassten Fragen und guten Antworten, danach zurück zur Börse.
6. «Fertig für heute» (oder E/Enter auf der eigenen Karte) beendet das Wahlfach. Die Note kommt aus dem Interview (6 richtig = 6, 5 richtig = 5.25, 4 richtig = 4.25).

**Was das Interview schwer macht:**
- Fünf von sechs Fragen müssen sitzen (`PASS`).
- Gesprochene Antworten brauchen mindestens sechs Wörter (`MIN_WORDS`), sonst: «Das war mir zu knapp».
- Bei Stärke, Schwäche, Stress, Rückschlag, Projekt und Teamarbeit braucht es ein Beispiel oder einen Grund («weil», «zum Beispiel», «als ich», «bei meiner …», Liste `EXAMPLE`). «Ich bin zuverlässig und teamfähig» reicht nicht.
- Bei Fragen an beide müssen beide gut antworten.
- 12 Sekunden Zeit, um mit der Antwort anzufangen (`ANSWER_TIME`, Balken oben im Antwortfeld). Schweigen zählt als falsch.
- In der Tastenvariante sind alle drei Antworten plausibel; falsch sind die ohne Beispiel, die ausweichenden oder die arroganten.

Versteht die Spracherkennung nichts (zu leise), fragt die Interviewerin einmal nach («Die Verbindung hat kurz gehackt»). Esc im Interview bricht ab; das zählt als Bewerbung, alle offenen Fragen sind verloren.

**Ohne Spracherkennung**, oder solange das Modell noch lädt: drei Antworten zur Wahl, P1 mit 1 2 3, P2 mit 8 9 0.

## Spracherkennung

`scripts/speech.gd` (für alle Levels nutzbar) nimmt das Mikrofon in Godot auf, solange die Taste gehalten wird, schreibt eine WAV-Datei und schickt ihren Pfad an `tracker/speech.py`. Das ist Whisper (faster-whisper, Modell `base`), läuft offline und antwortet mit dem Text. Das Spiel startet den Prozess selbst, genau wie den Kamera-Tracker. Einrichtung: siehe `tracker/README.md`, Abschnitt Spracherkennung.

Geprüft: Mit der Mac-Stimme «Anna» erzeugte deutsche Sätze werden in unter einer Sekunde erkannt, mit kleinen Fehlern («farerloses», «falschirm»).

## Antworten prüfen (`jobs.gd`)

Jede Frage hat `keys`: Gruppen von Wörtern (meist Wortstämme). Die Antwort ist richtig, wenn sie aus `need` Gruppen (sonst allen) ein Wort enthält. Verglichen wird ohne Gross/Klein und Umlaute (ä = ae) und mit Tippfehlern: Ab 5 Buchstaben ist ein Fehler erlaubt, ab 8 zwei (Levenshtein, auch für den Wortanfang). Kurze, mehrdeutige Wörter («nacht» gegen «nach») gehören nicht in `keys`.

Neue Fragen: `q`, `who`, `keys`, `good`, `tip`, `opts` (drei Antworten, die erste ist richtig), optional `bad`. Danach prüfen, dass jede `tip` als Antwort durchgeht und keine falsche Option (`opts[1]`, `opts[2]`).

`prompt` pro Job gibt Whisper Wörter vor, die vorkommen können (Firmennamen, Fachwörter). Das verbessert die Erkennung deutlich.

## Stellschrauben

| Wo | Konstante | Wert | Wirkung |
|---|---|---|---|
| `jobs.gd` | `PASS` | 5 | richtige Antworten (von 6) für den Job |
| | `MIN_WORDS` | 6 | so viele Wörter braucht eine gesprochene Antwort |
| | `EXAMPLE`, `DODGE` | | Wörter für ein Beispiel, Ausweich-Floskeln |
| `interview.gd` | `ANSWER_TIME` | 12 s | Zeit, um mit der Antwort anzufangen |
| `interview.gd` | `MIN_TALK`, `MAX_TALK` | 0.6 s, 15 s | kürzere Aufnahmen zählen als nichts gesagt, längere werden abgeschnitten |
| | `GOOD_POINTS`, `BAD_POINTS`, `TALK_BONUS` | 17, -6, 3 | Balken «Eindruck» (nur Anzeige, entscheidend sind die richtigen Antworten) |
| | `SIGN_TIME` | 1.4 s | so lange halten beide zum Unterschreiben |
| | `TYPE_SPEED` | 42 | Buchstaben pro Sekunde, wenn die Interviewerin spricht |
| `speech.gd` | `LEVEL_DB` | -55 bis -15 dB | Lautstärke, die als 0 und als 1 gilt (Pegelanzeige) |
| `speech.py` | `--model` | base | `small` erkennt Deutsch besser, ist aber langsamer und 500 MB gross |

## Speichern

Die Bewerbung gehört zum Spiel: `Game.electives["freelance"] = {"id", "outcome" ("hired" oder "rejected"), "grade"}` in `user://save.cfg`. `Game.new_game()` löscht sie, ein Levelstart nicht. `Game.elective(key)` und `Game.set_elective(key, value)` stehen allen Wahlfächern offen. `--nosave` speichert nichts.

## Dateien

| Datei | Inhalt |
|---|---|
| `level.gd` | `DEF`, Cutscene, öffnet die Börse im Vollbild, eigener Siegbildschirm |
| `interview.gd` | Börse, Video-Call, Antworten aufnehmen und prüfen, Vertrag und Absage |
| `jobs.gd` | die vier Jobs mit Fragen, Antwortprüfung, Speichern der Jobs |

Ausserhalb des Ordners: `scripts/speech.gd` (neu), `tracker/speech.py` (neu). Gemeinsame Dateien sind nicht angefasst.

## Die Fragen

Alle Fragen sind persönlich, wie in einem echten Bewerbungsgespräch, nichts Technisches: sich vorstellen, warum gerade dieses Team (AMZ: Motorsport, ARIS: Raumfahrt, Vitalfaden: Menschen helfen), Stärke, Schwäche, Umgang mit Stress und Rückschlägen, Teamarbeit und Kritik, Freizeit, Zeit pro Woche, wo in fünf Jahren, warum gerade ihr, und zum Schluss: «Habt ihr noch Fragen an mich?».

Weil persönliche Antworten offen sind, sind die Wortlisten breit (gemeinsame Listen wie `STRENGTH`, `STRESS`, `HOBBY` oben in `jobs.gd`): Jede echte, ausführliche Antwort zum Thema zählt, bei den Beispiel-Fragen nur mit Beispiel. Durch fallen Ausweichen («keine Ahnung», «ist mir egal», Liste `DODGE`), Verneinungen («ich habe keine Stärken») und bei der Rückfrage ein «Nein» (`bad` der Frage). Nach einer schwachen Antwort sagt die Interviewerin, wie eine gute geklungen hätte.

Geprüft: jede Musterantwort (`tip`) und die richtige Option gehen durch, keine der beiden plausiblen falschen Optionen.

AMZ, ARIS und Swissloop Tunneling sind echte Studierendenteams der ETH. Die Personen und Vitalfaden AG sind erfunden.

## Stand

- Per Bot geprüft: Cutscene, Börse, ein ganzes Interview (gesprochene Antworten über die Prüfung, Tastenvariante), Vertrag mit Unterschrift, Siegbildschirm mit Note. Spracherkennung im Spiel: Prozess startet selbst, Modell nach etwa 4 s bereit, eine WAV kommt als richtiger Text zurück.
- Nicht geprüft: echtes Sprechen ins Mikrofon (die Aufnahme in Godot selbst), Lautstärke-Schwellen, ob zwei Personen nebeneinander sich gegenseitig ins Mikrofon reden.
