extends RefCounted
## The four freelance jobs, their interview questions, how a spoken answer is checked, and the
## one application per game (saved with the game, see application()).
## All questions are personal, like in a real job interview: who you are, why this team,
## strengths and weaknesses, stress, teamwork, plans. Nothing technical.
##
## A question:
##   "q":     what the interviewer asks
##   "keys":  groups of words; the answer is right when it contains a word of `need` groups
##            (default: all groups). Words are compared without umlauts and a little fuzzily,
##            because the speech recognition misspells now and then ("falschirm").
##            Personal answers are open, so the lists are wide: any real answer on the topic counts.
##   "bad":   optional words that make an answer wrong anyway (plus DODGE for every question)
##   "good":  what the interviewer says to a right answer
##   "tip":   what a good answer could be (shown after a wrong one)
##   "opts":  three answers for the keyboard variant, the first one is right (shuffled on screen)
##   "who":   0 = asks P1, 1 = asks P2, -1 = both have to answer (each holds their key once)
##
## AMZ, ARIS and Swissloop Tunneling are real ETH student teams. The people and the MedTech
## startup are made up.

const KEY := "freelance"           # key of the application in Game.electives
const PASS := 5                 # right answers (of 6) for the job
const MIN_WORDS := 6            # spoken answers shorter than this are "too short"

# Dodging the question is never a good answer.
const DODGE := ["keine ahnung", "weiss nicht", "weiss ich nicht", "ist mir egal", "kein bock", "keine lust", "null bock",
	"habe keine", "keine staerke", "keine schwaeche", "ich hasse", "auf nichts", "mir nichts", "nichts besonderes",
	"lebenslauf"]

# Word lists for the usual interview questions, shared by the jobs.
const STUDY := ["studier", "studium", "informatik", "maschinenbau", "elektrotechnik", "bachelor", "master", "semester",
	"ersti", "mathe", "physik", "chemie", "biolog", "architektur", "umwelt", "material", "wirtschaft", "medizin",
	"ingenieur", "eth", "heisse", "jahre alt", "komme aus", "wohne"]
const MOTIVE := ["spannend", "interess", "faszin", "begeist", "leidenschaft", "liebe", "lernen", "erfahrung", "traum",
	"cool", "motiv", "freude", "spass", "reizt", "gerne", "mitmachen", "dabei sein", "praxis", "anwenden"]
const STRENGTH := ["zuverlaess", "teamfaeh", "teamplayer", "kreativ", "motiviert", "organis", "genau", "geduld", "neugier",
	"flexib", "belastbar", "kommunik", "ehrgeiz", "fleiss", "loesungsorient", "selbststaendig", "hilfsbereit",
	"puenktlich", "schnell lern", "staerke", "durchhalte", "ruhig", "offen", "ordentlich", "analytisch"]
const WEAKNESS := ["ungeduld", "perfektion", "manchmal", "zu viel", "arbeite daran", "verbesser", "nein sagen", "chaot",
	"nervoes", "detail", "vergess", "aufschieb", "prokrastin", "schwaeche", "zu lange", "zu genau", "unordentlich",
	"lerne", "kritisch", "schuechtern", "stur", "zu spaet", "unpuenktlich", "ungeduldig", "oft", "zu schnell"]
const STRESS := ["plan", "ruhig", "sport", "pause", "priorit", "liste", "frueh", "organis", "schlaf", "durchatm", "atmen",
	"struktur", "schritt", "spazier", "musik", "aufteil", "konzentr", "to do", "todo", "nicht aufgeben", "weitermachen",
	"weitergemacht", "gelernt", "daraus",
	"daraus lernen", "nochmal versuch", "positiv", "joggen", "weiter", "tief durch"]
const TIME := ["stund", "tag", "abend", "wochenende", "halbtag", "prozent", "nachmittag", "pro woche", "flexibel", "semesterferien"]
const TEAMWORK := ["team", "zusammen", "gruppe", "projekt", "geloest", "geholfen", "gemeinsam", "kolleg", "freund",
	"uebung", "serie", "aufgeteilt", "besprochen", "diskutiert", "zusammengearbeitet"]
const FUTURE := ["master", "job", "arbeit", "firma", "startup", "gruend", "ausland", "ingenieur", "forsch", "doktor",
	"phd", "abschluss", "eigene", "projekt", "verantwortung", "team leiten", "fuehrung", "bachelor"]
const HOBBY := ["sport", "musik", "lesen", "game", "gamen", "spiel", "kochen", "freunde", "wandern", "ski", "velo", "fahrrad",
	"reisen", "tanz", "film", "serie", "klettern", "fussball", "schwimm", "joggen", "zeichnen", "programmier", "basteln",
	"gitarre", "klavier", "fotograf", "unihockey", "volleyball", "fitness", "laufen", "malen", "singen"]
const WHY_US := ["motiv", "zuverlaess", "team", "lernbereit", "einsatz", "engag", "begeist", "leidenschaft", "erfahrung",
	"zusammen", "kreativ", "ehrgeiz", "passen", "zu zweit", "ergaenz", "freude", "neugier", "fleiss"]
const ASK_BACK := ["lohn", "gehalt", "honorar", "arbeitszeit", "team", "wann", "start", "homeoffice", "remote",
	"projekt", "aufgabe", "wie viele", "wie viel", "verdien", "wo ", "einarbeit", "erwart", "naechste", "ablauf", "welche", "wer", "was macht", "wie sieht", "arbeitstag", "typisch"]

# "Introduce yourself" needs more than the subject: semester, name, where from.
const INTRO := ["semester", "heisse", "jahre alt", "komme aus", "wohne", "mein name", "ich bin"]

# A good answer to "strength", "weakness", "project" and the like needs an example or a reason.
const EXAMPLE := ["weil", "zum beispiel", "beispiel", "als ich", "einmal", "bei meiner", "bei meinem", "letztes",
	"damals", "deshalb", "darum", "zuletzt", "im gymi", "in der schule", "im studium", "neulich", "immer wenn",
	"wenn ich", "letzte woche", "letztes jahr", "an der matura", "bei der", "bei einer", "bei einem", "vor der", "vor dem",
	"vor pruef"]

const JOBS := [
	{
		"id": "amz", "name": "AMZ Racing", "tagline": "Formula Student · Elektro & Driverless",
		"role": "Freelance: Telemetrie-Dashboard", "rate": 38, "color": "e3242b", "color2": "1b1b1f",
		"boss": "Lea Brunner", "boss_role": "Teamleitung Data & Telemetrie", "stars": 3,
		"prompt": "Ich studiere an der ETH. AMZ Racing, Motorsport, Team, Stärke, zum Beispiel, weil, Stress, Stunden pro Woche.",
		"hello": "Hoi zäme, ich bin Lea von AMZ Racing. Wir haben über hundert Bewerbungen, also überzeugt mich. Legen wir los?",
		"questions": [
			{"q": "Stell dich doch kurz vor: Wer bist du, was studierst du?", "who": 0, "keys": [STUDY, INTRO],
				"good": "Cool, freut mich!",
				"tip": "Name, Studiengang und Semester in ein, zwei Sätzen: Ich heisse Tim und studiere Informatik im ersten Semester an der ETH.",
				"opts": ["Ich heisse Tim und studiere Informatik im ersten Semester", "Ich studiere halt an der ETH, mehr gibt es nicht zu sagen", "Das steht doch alles im Lebenslauf"]},
			{"q": "Warum ausgerechnet AMZ? Was reizt dich am Motorsport?", "who": 1,
				"keys": [MOTIVE + ["auto", "rennen", "motorsport", "schnell", "geschwindigkeit", "formel", "rennwagen"]],
				"good": "Das hört man gern. Genau dieses Feuer brauchen wir.",
				"tip": "Echte Begeisterung zeigen: Ich finde Rennautos faszinierend und will in einem Team etwas Echtes bauen.",
				"opts": ["Rennautos faszinieren mich, und ich will im Team etwas Echtes bauen", "AMZ sieht im Lebenslauf einfach gut aus", "Ich habe gehört, ihr habt gute Partys"]},
			{"q": "Was ist eure grösste Stärke? Und bitte mit einem Beispiel.", "who": -1, "keys": [STRENGTH, EXAMPLE],
				"good": "Super, und das Beispiel überzeugt.",
				"tip": "Stärke plus Beispiel: Ich bin zuverlässig, zum Beispiel habe ich jede Übungsserie pünktlich abgegeben.",
				"opts": ["Ich bin zuverlässig, zum Beispiel gebe ich jede Serie pünktlich ab", "Ich bin zuverlässig und teamfähig und motiviert", "Meine Stärke ist, dass ich keine Schwächen habe"]},
			{"q": "Vor einem Rennen wird es bei uns hektisch. Wie gehst du mit Stress um? Ein konkretes Beispiel?", "who": 0, "keys": [STRESS, EXAMPLE],
				"good": "Gute Strategie. Ruhe bewahren ist in der Box Gold wert.",
				"tip": "Strategie plus Situation: Vor der Basisprüfung habe ich mir einen Plan gemacht und Schritt für Schritt gelernt.",
				"opts": ["Vor Prüfungen mache ich einen Plan und gehe Schritt für Schritt vor", "Ich mache einfach einen Plan", "Stress habe ich eigentlich nie"]},
			{"q": "Wie viele Stunden pro Woche hast du neben dem Studium wirklich Zeit?", "who": 1, "keys": [TIME], "bad": ["nicht so wichtig", "je nachdem"],
				"good": "Okay, damit können wir gut planen.",
				"tip": "Ehrlich und konkret: Etwa zehn Stunden pro Woche, in den Semesterferien deutlich mehr.",
				"opts": ["Etwa zehn Stunden pro Woche, in den Ferien mehr", "So viel ihr wollt, Studium ist nicht so wichtig", "Mal schauen, je nachdem"]},
			{"q": "Zum Schluss: Habt ihr noch Fragen an mich?", "who": -1, "keys": [ASK_BACK], "bad": ["nein", "keine fragen", "nö", "zusage"],
				"good": "Gute Frage! Das erkläre ich euch gleich.",
				"tip": "Immer eine echte Frage stellen: Wie sieht die Einarbeitung bei euch im Team aus?",
				"opts": ["Wie sieht die Einarbeitung bei euch im Team aus?", "Nein, ich glaube, es ist alles klar", "Wann bekommen wir die Zusage?"]},
		],
	},
	{
		"id": "aris", "name": "ARIS", "tagline": "Akademische Raumfahrt Initiative Schweiz",
		"role": "Freelance: Flugsoftware für die Bergung", "rate": 36, "color": "2c3e8f", "color2": "e8eefc",
		"boss": "Jonas Meier", "boss_role": "Leitung Avionik", "stars": 1,
		"prompt": "ETH, ARIS, Raumfahrt, Weltraum, Rakete, Projekt, stolz, Schwäche, zum Beispiel, weil, Rückschlag, in fünf Jahren.",
		"hello": "Grüezi, Jonas von ARIS. Bei uns zählt, wer ihr seid, und ich frage nach. Bereit für den Countdown?",
		"questions": [
			{"q": "Erzähl mal: Was hat dich überhaupt an die ETH gebracht?", "who": 0,
				"keys": [MOTIVE + ["interess", "ruf", "beste", "zuerich", "naturwiss", "technik", "forsch", "famil", "eltern",
					"mathe", "physik", "informatik", "schweiz"]],
				"good": "Schön. Ging mir genau gleich.",
				"tip": "Ehrlich erzählen, was dich interessiert: Mich haben Mathe und Technik schon immer fasziniert.",
				"opts": ["Mich haben Mathe und Technik schon im Gymi fasziniert", "Die ETH war halt in der Nähe", "Meine Kollegen sind auch alle hier"]},
			{"q": "Was fasziniert dich an der Raumfahrt?", "who": 1,
				"keys": [MOTIVE + ["weltall", "weltraum", "rakete", "stern", "planet", "mars", "mond", "raumfahrt", "astronaut", "space", "universum", "fliegen"]],
				"bad": ["nichts"],
				"good": "Ja! Genau deshalb machen wir das alle.",
				"tip": "Zum Beispiel: Raketen und das Weltall haben mich schon als Kind fasziniert, ich will da mitbauen.",
				"opts": ["Das Weltall fasziniert mich seit ich klein bin, ich will mitbauen", "Raumfahrt klingt einfach gut im Lebenslauf", "Ehrlich gesagt bin ich eher wegen des Lohns da"]},
			{"q": "Was ist eure grösste Schwäche? Und woran merkt ihr das?", "who": -1, "keys": [WEAKNESS, EXAMPLE],
				"good": "Ehrlich und reflektiert, das schätze ich.",
				"tip": "Echte Schwäche mit Beispiel: Ich bin manchmal ungeduldig, zum Beispiel wenn Code nicht läuft, aber ich arbeite daran.",
				"opts": ["Ich bin manchmal ungeduldig, zum Beispiel wenn Code nicht läuft", "Ich bin zu perfektionistisch", "Ich arbeite einfach zu viel"]},
			{"q": "Erzähl von einem Projekt, auf das du stolz bist. Was war dein Teil?", "who": 0,
				"keys": [["projekt", "gebaut", "programmiert", "gemacht", "geschafft", "entwickelt", "app", "spiel", "website",
					"roboter", "maturaarbeit", "matura", "organisiert", "hackathon"], ["ich habe", "habe ich", "mein teil", "meine aufgabe", "selbst", "ich war", "ich durfte"]],
				"good": "Stark. Genau solche Leute suchen wir.",
				"tip": "Konkret mit deinem Anteil: Bei meiner Maturaarbeit habe ich selbst einen kleinen Roboter gebaut und programmiert.",
				"opts": ["Bei der Maturaarbeit habe ich selbst einen Roboter gebaut und programmiert", "Wir haben in der Schule mal ein Projekt gemacht", "Ich bin stolz auf viele Sachen"]},
			{"q": "Ein Start wird abgesagt, Wochen Arbeit umsonst. Wie gehst du mit so einem Rückschlag um?", "who": 1, "keys": [STRESS, EXAMPLE],
				"good": "So muss es sein. Aufstehen, weitermachen.",
				"tip": "Mit Beispiel: Als ich eine Prüfung verhauen habe, habe ich daraus gelernt und weitergemacht.",
				"opts": ["Als ich eine Prüfung verhauen habe, habe ich daraus gelernt", "Ich ärgere mich halt", "Das passiert mir eigentlich nie"]},
			{"q": "Und zum Schluss: Wo seht ihr euch in fünf Jahren?", "who": -1, "keys": [FUTURE],
				"good": "Ehrgeizig. Das gefällt mir.",
				"tip": "Ein konkretes Ziel nennen: Ich mache meinen Master und arbeite danach in der Raumfahrt.",
				"opts": ["Ich mache den Master und arbeite danach in der Raumfahrt", "Irgendwo, wo es gut bezahlt ist", "Das kann man doch nicht wissen"]},
		],
	},
	{
		"id": "swissloop", "name": "Swissloop Tunneling", "tagline": "Tunnelbohrmaschinen · Not-a-Boring Competition",
		"role": "Freelance: Sensorik am Bohrkopf", "rate": 37, "color": "e07b1a", "color2": "2a2a2a",
		"boss": "Mara Huber", "boss_role": "Projektleitung", "stars": 2,
		"prompt": "Ich studiere an der ETH. Swissloop, Freizeit, Sport, Team, Problem gelöst, zum Beispiel, weil, Kritik, Stärke.",
		"hello": "Hallo, ich bin Mara von Swissloop Tunneling. Ich will wissen, wie ihr tickt, und ich hake nach. Bereit?",
		"questions": [
			{"q": "Stell dich bitte kurz vor: Wer bist du und was studierst du?", "who": 0, "keys": [STUDY, INTRO],
				"good": "Freut mich, dich kennenzulernen.",
				"tip": "Name, Studiengang und Semester: Ich heisse Tim und studiere Maschinenbau im ersten Semester.",
				"opts": ["Ich heisse Tim und studiere Maschinenbau im ersten Semester", "Ich bin halt Student", "Steht alles in meiner Bewerbung"]},
			{"q": "Was machst du in deiner Freizeit?", "who": 1, "keys": [HOBBY],
				"good": "Klingt gut. Ausgleich ist wichtig.",
				"tip": "Ein, zwei Hobbys mit etwas Farbe: Ich spiele Unihockey im Verein und koche gern mit Freunden.",
				"opts": ["Ich spiele Unihockey im Verein und koche gern", "Freizeit habe ich keine, ich lerne nur", "Nicht so viel, eigentlich chille ich"]},
			{"q": "Erzählt von einer Situation, in der ihr zusammen ein Problem gelöst habt.", "who": -1, "keys": [TEAMWORK, EXAMPLE],
				"good": "Genau so funktioniert ein Team.",
				"tip": "Situation und Lösung: Bei einer schweren Übungsserie haben wir die Aufgaben aufgeteilt und zusammen besprochen.",
				"opts": ["Bei einer schweren Serie haben wir aufgeteilt und zusammen besprochen", "Wir sind ein gutes Team", "Meistens löse ich die Probleme allein"]},
			{"q": "Wie reagierst du, wenn jemand im Team deine Idee schlecht findet?", "who": 0,
				"keys": [["zuhoer", "diskut", "verstehen", "warum", "argument", "kompromiss", "offen", "feedback", "besprech",
					"respekt", "ueberleg", "meinung", "kritik", "nachfrag", "gruende"]],
				"good": "Sehr reif. Kritik gehört dazu.",
				"tip": "Offen bleiben: Ich höre zu, frage nach dem Warum, und wir suchen zusammen die beste Lösung.",
				"opts": ["Ich höre zu, frage warum und wir suchen zusammen eine Lösung", "Ich erkläre so lange, bis alle zustimmen", "Dann lasse ich die Idee eben fallen"]},
			{"q": "Was ist deine grösste Stärke, und wann hast du sie gezeigt?", "who": 1, "keys": [STRENGTH, EXAMPLE],
				"good": "Die können wir gut brauchen.",
				"tip": "Stärke mit Beispiel: Ich bin belastbar, als ich drei Prüfungen in einer Woche hatte, bin ich ruhig geblieben.",
				"opts": ["Ich bin belastbar, als ich drei Prüfungen hatte, blieb ich ruhig", "Ich bin belastbar und flexibel", "Ich kann eigentlich alles gut"]},
			{"q": "Warum sollten wir euch nehmen und nicht jemand anderen?", "who": -1, "keys": [WHY_US],
				"good": "Überzeugt. Ihr ergänzt euch gut.",
				"tip": "Selbstbewusst und konkret: Wir sind motiviert, zuverlässig und ergänzen uns als Team.",
				"opts": ["Wir sind motiviert, zuverlässig und ergänzen uns als Team", "Weil wir euch wirklich brauchen", "Die anderen sind sicher schlechter"]},
		],
	},
	{
		"id": "medtech", "name": "Vitalfaden AG", "tagline": "MedTech-Startup · EKG im T-Shirt",
		"role": "Freelance: App für das EKG-Shirt", "rate": 40, "color": "17a589", "color2": "eafaf6",
		"boss": "Dr. Nina Keller", "boss_role": "CEO und Mitgründerin", "stars": 3,
		"prompt": "Ich studiere an der ETH. Vitalfaden, Gesundheit, Menschen helfen, Startup, flexibel, Schwäche, zum Beispiel, weil, in fünf Jahren.",
		"hello": "Hallo! Nina, CEO von Vitalfaden. Wir sind klein, jede Person zählt, darum bin ich streng. Erzählt mal!",
		"questions": [
			{"q": "Erzähl kurz von dir: Was studierst du, und was treibt dich an?", "who": 0, "keys": [STUDY, MOTIVE + ["helfen", "bauen", "ziel"]],
				"good": "Schön, das spürt man.",
				"tip": "Studiengang und Antrieb: Ich studiere Informatik und will Dinge bauen, die Menschen helfen.",
				"opts": ["Ich studiere Informatik und will Dinge bauen, die Menschen helfen", "Ich studiere Informatik", "Mich treibt vor allem der Lohn an"]},
			{"q": "Warum Gesundheit? Was bedeutet es dir, Menschen zu helfen?", "who": 1,
				"keys": [["helfen", "menschen", "gesund", "sinn", "leben", "patient", "famil", "wichtig", "verbesser",
					"gutes", "medizin", "herz", "etwas bewirken", "wirkung"]], "bad": ["markt", "wachstum", "google"],
				"good": "Das ist genau unsere Mission.",
				"tip": "Persönlich werden: Es ist mir wichtig, dass meine Arbeit Menschen wirklich hilft, meine Oma hat ein Herzleiden.",
				"opts": ["Es ist mir wichtig, dass meine Arbeit Menschen wirklich hilft", "Gesundheit ist ein Wachstumsmarkt", "Eigentlich wollte ich zu Google"]},
			{"q": "In einem Startup ändert sich alles ständig. Wie geht ihr damit um?", "who": -1,
				"keys": [["flexib", "anpass", "spontan", "offen", "spannend", "abwechslung", "ruhig", "plan", "lern", "neu",
					"gerne", "kein problem", "mag", "neugier", "veraender", "gut", "toll", "super"]],
				"good": "Perfekt, so überlebt man im Startup.",
				"tip": "Zeigen, dass dir Abwechslung gefällt: Ich bin flexibel und finde es spannend, wenn sich Dinge ändern.",
				"opts": ["Ich bin flexibel und finde Veränderungen spannend", "Mir sind klare Abläufe wichtiger", "Da muss man halt durch"]},
			{"q": "Was ist deine grösste Schwäche, und was tust du dagegen?", "who": 0, "keys": [WEAKNESS, EXAMPLE + ["arbeite daran", "dagegen", "versuche", "lerne"]],
				"good": "Danke für die Ehrlichkeit.",
				"tip": "Ehrlich, mit Plan: Ich bin manchmal zu perfektionistisch, deshalb setze ich mir jetzt feste Zeitlimits.",
				"opts": ["Ich bin zu perfektionistisch, deshalb setze ich mir Zeitlimits", "Ich bin zu perfektionistisch", "Schwächen habe ich eigentlich keine"]},
			{"q": "Wo siehst du dich in fünf Jahren?", "who": 1, "keys": [FUTURE],
				"good": "Vielleicht ja bei uns!",
				"tip": "Ein konkretes Ziel nennen: Ich habe meinen Master und arbeite in einem jungen MedTech-Startup.",
				"opts": ["Mit dem Master in einem jungen MedTech-Startup", "Hoffentlich auf einer Insel", "Ich plane nicht so weit"]},
			{"q": "Zum Schluss: Habt ihr noch Fragen an mich?", "who": -1, "keys": [ASK_BACK], "bad": ["nein", "keine fragen", "nö"],
				"good": "Sehr gute Frage. Freut mich, dass ihr nachfragt.",
				"tip": "Immer eine echte Frage stellen: Wie sieht ein typischer Arbeitstag bei euch aus?",
				"opts": ["Wie sieht ein typischer Arbeitstag bei euch aus?", "Nein danke, alles klar", "Ist das Startup schon profitabel? Sonst nein"]},
		],
	},
]


static func job(id: String) -> Dictionary:
	for j in JOBS:
		if j["id"] == id:
			return j
	return {}


# ------------------------------------------------------------------ checking an answer
## Lower case, umlauts written out, punctuation gone, single spaces.
static func normalize(t: String) -> String:
	var s := t.to_lower()
	for pair in [["ä", "ae"], ["ö", "oe"], ["ü", "ue"], ["ß", "ss"], ["é", "e"], ["è", "e"], ["à", "a"]]:
		s = s.replace(pair[0], pair[1])
	var out := ""
	for ch in s:
		var c := ch.unicode_at(0)
		var keep := (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or ch == "+"
		out += ch if keep else " "
	while out.contains("  "):
		out = out.replace("  ", " ")
	return " " + out.strip_edges() + " "


## True if the word (or phrase) is in the text, allowing small spelling mistakes in longer words.
static func has_word(text: String, word: String) -> bool:
	var w := normalize(word).strip_edges()
	if w == "":
		return false
	if w.length() <= 3:
		return text.contains(" " + w + " ") or text.contains(" " + w)
	if text.contains(w):
		return true
	if w.contains(" "):
		return false
	if w.length() < 5:
		return false
	var allowed := 1 if w.length() < 8 else 2
	for part in text.split(" ", false):
		if part.length() < 4:
			continue
		# the beginning of the word (keywords are often stems: "elektr", "fahrerlos"), or a word
		# that is one letter short ("pyton")
		for n in [w.length(), w.length() + 1]:
			if n <= part.length() and _edits(part.substr(0, n), w) <= allowed:
				return true
		if part.length() == w.length() - 1 and _edits(part, w) <= 1:
			return true
	return false


## Levenshtein distance: letters to add, remove or change to get from a to b.
static func _edits(a: String, b: String) -> int:
	var prev: Array = range(b.length() + 1)
	for i in range(1, a.length() + 1):
		var cur: Array = [i]
		for j in range(1, b.length() + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			cur.append(mini(mini(int(cur[j - 1]) + 1, int(prev[j]) + 1), int(prev[j - 1]) + cost))
		prev = cur
	return int(prev[b.length()])


## The words of the answer that matched, per group (empty group = not matched).
static func check(q: Dictionary, answer: String) -> Dictionary:
	var text := normalize(answer)
	var groups: Array = q["keys"]
	var hits: Array = []
	var matched := 0
	for g in groups:
		var found := ""
		for w in g:
			if has_word(text, w):
				found = w
				break
		hits.append(found)
		if found != "":
			matched += 1
	var need: int = q.get("need", groups.size())
	var dodged := false
	for w in DODGE + q.get("bad", []):
		var b := normalize(w).strip_edges()
		# short words only as a whole word ("nein"), longer ones also inside a word ("wachstum")
		if text.contains(" " + b + " ") or (b.length() >= 5 and text.contains(b)):
			dodged = true
	return {"ok": matched >= need and not dodged, "hits": hits, "matched": matched}


# ------------------------------------------------------------------ the application (per game)
## The one application of this game, kept in the save game (Game.elective, cleared by a new
## study): {"id": job id, "outcome": "hired" / "rejected", "grade": float}, or {}.
static func application() -> Dictionary:
	var a = Game.elective(KEY, {})
	return a if a is Dictionary else {}


static func set_application(id: String, outcome: String, grade: float) -> void:
	Game.set_elective(KEY, {"id": id, "outcome": outcome, "grade": grade})
