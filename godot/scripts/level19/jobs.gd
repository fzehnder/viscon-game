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
##   "keys_en", "bad_en": the same for answers in English (Game.lang == "en", the speech
##            recognition then listens for English). The texts themselves are translated in en.gd.
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

# The same lists for answers in English.
const DODGE_EN := ["no idea", "dont know", "don t know", "do not know", "i don't care", "dont care", "whatever",
	"no strengths", "no weakness", "nothing special", "i hate", "cv", "resume"]
const STUDY_EN := ["study", "studying", "student", "computer science", "mechanical", "electrical", "engineering",
	"bachelor", "master", "semester", "first year", "fresher", "math", "physics", "chemistry", "biology",
	"architecture", "environment", "material", "economics", "medicine", "eth", "my name", "years old", "i m from", "i am from", "live in"]
const MOTIVE_EN := ["exciting", "interest", "fascinat", "passion", "love", "learn", "experience", "dream", "cool",
	"motivat", "enjoy", "fun", "excited", "like to", "be part", "practice", "practical", "apply"]
const STRENGTH_EN := ["reliable", "team player", "teamwork", "creative", "motivated", "organised", "organized", "precise",
	"patient", "curious", "flexible", "resilient", "communicat", "ambitious", "hard working", "hardworking",
	"solution", "independent", "helpful", "punctual", "fast learner", "learn quickly", "strength", "persistent",
	"calm", "open", "tidy", "analytical"]
const WEAKNESS_EN := ["impatient", "impatience", "perfection", "sometimes", "too much", "working on", "improve",
	"saying no", "say no", "chaotic", "nervous", "detail", "forget", "procrastinat", "put things off", "weakness",
	"too long", "messy", "learning", "critical", "shy", "stubborn", "late", "often", "too fast"]
const STRESS_EN := ["plan", "calm", "sport", "break", "priorit", "list", "early", "organis", "organiz", "sleep",
	"breath", "structure", "step", "walk", "music", "split", "focus", "concentrat", "to do", "todo", "give up",
	"keep going", "kept going", "learned", "learnt", "from it", "try again", "tried again", "positive", "jogging", "running"]
const TIME_EN := ["hour", "day", "evening", "weekend", "half", "percent", "afternoon", "per week", "a week", "flexible",
	"holiday", "vacation", "break"]
const TEAMWORK_EN := ["team", "together", "group", "project", "solved", "helped", "colleague", "friend", "exercise",
	"problem set", "split", "divided", "discussed", "worked with"]
const FUTURE_EN := ["master", "job", "work", "company", "startup", "found", "abroad", "engineer", "research", "doctor",
	"phd", "degree", "my own", "project", "responsib", "lead a team", "leading", "bachelor"]
const HOBBY_EN := ["sport", "music", "read", "gaming", "games", "play", "cook", "friends", "hiking", "ski", "bike",
	"cycling", "travel", "danc", "film", "movie", "series", "climb", "football", "soccer", "swim", "jogging", "drawing",
	"programming", "coding", "guitar", "piano", "photo", "floorball", "volleyball", "gym", "fitness", "running", "paint", "sing"]
const WHY_US_EN := ["motivat", "reliable", "team", "willing to learn", "commit", "engag", "passion", "experience",
	"together", "creative", "ambitious", "fit", "the two of us", "complement", "enjoy", "curious", "hard working", "hardworking"]
const ASK_BACK_EN := ["salary", "pay", "fee", "hours", "team", "when", "start", "home office", "remote", "project",
	"task", "how many", "how much", "earn", "where", "onboarding", "introduc", "expect", "next", "process", "which",
	"who", "what does", "what is", "what s", "how does", "how do", "typical", "day look"]
const INTRO_EN := ["semester", "my name", "i m ", "i am", "years old", "i m from", "i am from", "live in", "first year"]
const EXAMPLE_EN := ["because", "for example", "example", "for instance", "when i", "once", "at my", "in my", "last",
	"back then", "that s why", "that is why", "so i", "recently", "whenever", "every time", "at school", "in school",
	"in high school", "at university", "during", "before the", "before my", "exam"]

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
		"prompt_en": "I study at ETH. AMZ Racing, motorsport, team, strength, for example, because, stress, hours per week.",
		"hello": "Hoi zäme, ich bin Lea von AMZ Racing. Wir haben über hundert Bewerbungen, also überzeugt mich. Legen wir los?",
		"questions": [
			{"q": "Stell dich doch kurz vor: Wer bist du, was studierst du?", "who": 0, "keys": [STUDY, INTRO], "keys_en": [STUDY_EN, INTRO_EN],
				"good": "Cool, freut mich!",
				"tip": "Name, Studiengang und Semester in ein, zwei Sätzen: Ich heisse Tim und studiere Informatik im ersten Semester an der ETH.",
				"opts": ["Ich heisse Tim und studiere Informatik im ersten Semester", "Ich studiere halt an der ETH, mehr gibt es nicht zu sagen", "Das steht doch alles im Lebenslauf"]},
			{"q": "Warum ausgerechnet AMZ? Was reizt dich am Motorsport?", "who": 1,
				"keys": [MOTIVE + ["auto", "rennen", "motorsport", "schnell", "geschwindigkeit", "formel", "rennwagen"]],
				"keys_en": [MOTIVE_EN + ["car", "race", "racing", "motorsport", "fast", "speed", "formula"]],
				"good": "Das hört man gern. Genau dieses Feuer brauchen wir.",
				"tip": "Echte Begeisterung zeigen: Ich finde Rennautos faszinierend und will in einem Team etwas Echtes bauen.",
				"opts": ["Rennautos faszinieren mich, und ich will im Team etwas Echtes bauen", "AMZ sieht im Lebenslauf einfach gut aus", "Ich habe gehört, ihr habt gute Partys"]},
			{"q": "Was ist eure grösste Stärke? Und bitte mit einem Beispiel.", "who": -1, "keys": [STRENGTH, EXAMPLE], "keys_en": [STRENGTH_EN, EXAMPLE_EN],
				"good": "Super, und das Beispiel überzeugt.",
				"tip": "Stärke plus Beispiel: Ich bin zuverlässig, zum Beispiel habe ich jede Übungsserie pünktlich abgegeben.",
				"opts": ["Ich bin zuverlässig, zum Beispiel gebe ich jede Serie pünktlich ab", "Ich bin zuverlässig und teamfähig und motiviert", "Meine Stärke ist, dass ich keine Schwächen habe"]},
			{"q": "Vor einem Rennen wird es bei uns hektisch. Wie gehst du mit Stress um? Ein konkretes Beispiel?", "who": 0, "keys": [STRESS, EXAMPLE], "keys_en": [STRESS_EN, EXAMPLE_EN],
				"good": "Gute Strategie. Ruhe bewahren ist in der Box Gold wert.",
				"tip": "Strategie plus Situation: Vor der Basisprüfung habe ich mir einen Plan gemacht und Schritt für Schritt gelernt.",
				"opts": ["Vor Prüfungen mache ich einen Plan und gehe Schritt für Schritt vor", "Ich mache einfach einen Plan", "Stress habe ich eigentlich nie"]},
			{"q": "Wie viele Stunden pro Woche hast du neben dem Studium wirklich Zeit?", "who": 1, "keys": [TIME], "bad": ["nicht so wichtig", "je nachdem"],
				"keys_en": [TIME_EN], "bad_en": ["not that important", "not so important", "it depends", "depends"],
				"good": "Okay, damit können wir gut planen.",
				"tip": "Ehrlich und konkret: Etwa zehn Stunden pro Woche, in den Semesterferien deutlich mehr.",
				"opts": ["Etwa zehn Stunden pro Woche, in den Ferien mehr", "So viel ihr wollt, Studium ist nicht so wichtig", "Mal schauen, je nachdem"]},
			{"q": "Zum Schluss: Habt ihr noch Fragen an mich?", "who": -1, "keys": [ASK_BACK], "bad": ["nein", "keine fragen", "nö", "zusage"],
				"keys_en": [ASK_BACK_EN], "bad_en": ["no", "no questions", "nope", "offer"],
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
		"prompt_en": "ETH, ARIS, space, rocket, project, proud, weakness, for example, because, setback, in five years.",
		"hello": "Grüezi, Jonas von ARIS. Bei uns zählt, wer ihr seid, und ich frage nach. Bereit für den Countdown?",
		"questions": [
			{"q": "Erzähl mal: Was hat dich überhaupt an die ETH gebracht?", "who": 0,
				"keys": [MOTIVE + ["interess", "ruf", "beste", "zuerich", "naturwiss", "technik", "forsch", "famil", "eltern",
					"mathe", "physik", "informatik", "schweiz"]],
				"keys_en": [MOTIVE_EN + ["reputation", "best", "zurich", "science", "technology", "research", "family", "parents",
					"math", "physics", "computer", "switzerland"]],
				"good": "Schön. Ging mir genau gleich.",
				"tip": "Ehrlich erzählen, was dich interessiert: Mich haben Mathe und Technik schon immer fasziniert.",
				"opts": ["Mich haben Mathe und Technik schon im Gymi fasziniert", "Die ETH war halt in der Nähe", "Meine Kollegen sind auch alle hier"]},
			{"q": "Was fasziniert dich an der Raumfahrt?", "who": 1,
				"keys": [MOTIVE + ["weltall", "weltraum", "rakete", "stern", "planet", "mars", "mond", "raumfahrt", "astronaut", "space", "universum", "fliegen"]],
				"bad": ["nichts"],
				"keys_en": [MOTIVE_EN + ["space", "rocket", "star", "planet", "mars", "moon", "astronaut", "universe", "fly", "flying", "orbit"]],
				"bad_en": ["nothing"],
				"good": "Ja! Genau deshalb machen wir das alle.",
				"tip": "Zum Beispiel: Raketen und das Weltall haben mich schon als Kind fasziniert, ich will da mitbauen.",
				"opts": ["Das Weltall fasziniert mich seit ich klein bin, ich will mitbauen", "Raumfahrt klingt einfach gut im Lebenslauf", "Ehrlich gesagt bin ich eher wegen des Lohns da"]},
			{"q": "Was ist eure grösste Schwäche? Und woran merkt ihr das?", "who": -1, "keys": [WEAKNESS, EXAMPLE], "keys_en": [WEAKNESS_EN, EXAMPLE_EN],
				"good": "Ehrlich und reflektiert, das schätze ich.",
				"tip": "Echte Schwäche mit Beispiel: Ich bin manchmal ungeduldig, zum Beispiel wenn Code nicht läuft, aber ich arbeite daran.",
				"opts": ["Ich bin manchmal ungeduldig, zum Beispiel wenn Code nicht läuft", "Ich bin zu perfektionistisch", "Ich arbeite einfach zu viel"]},
			{"q": "Erzähl von einem Projekt, auf das du stolz bist. Was war dein Teil?", "who": 0,
				"keys": [["projekt", "gebaut", "programmiert", "gemacht", "geschafft", "entwickelt", "app", "spiel", "website",
					"roboter", "maturaarbeit", "matura", "organisiert", "hackathon"], ["ich habe", "habe ich", "mein teil", "meine aufgabe", "selbst", "ich war", "ich durfte"]],
				"keys_en": [["project", "built", "build", "programmed", "coded", "made", "developed", "app", "game", "website",
					"robot", "thesis", "organised", "organized", "hackathon"], ["i built", "i made", "i did", "i was", "my part", "my job", "my task", "myself", "i programmed", "i coded", "i wrote", "i designed"]],
				"good": "Stark. Genau solche Leute suchen wir.",
				"tip": "Konkret mit deinem Anteil: Bei meiner Maturaarbeit habe ich selbst einen kleinen Roboter gebaut und programmiert.",
				"opts": ["Bei der Maturaarbeit habe ich selbst einen Roboter gebaut und programmiert", "Wir haben in der Schule mal ein Projekt gemacht", "Ich bin stolz auf viele Sachen"]},
			{"q": "Ein Start wird abgesagt, Wochen Arbeit umsonst. Wie gehst du mit so einem Rückschlag um?", "who": 1, "keys": [STRESS, EXAMPLE], "keys_en": [STRESS_EN, EXAMPLE_EN],
				"good": "So muss es sein. Aufstehen, weitermachen.",
				"tip": "Mit Beispiel: Als ich eine Prüfung verhauen habe, habe ich daraus gelernt und weitergemacht.",
				"opts": ["Als ich eine Prüfung verhauen habe, habe ich daraus gelernt", "Ich ärgere mich halt", "Das passiert mir eigentlich nie"]},
			{"q": "Und zum Schluss: Wo seht ihr euch in fünf Jahren?", "who": -1, "keys": [FUTURE], "keys_en": [FUTURE_EN],
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
		"prompt_en": "I study at ETH. Swissloop, free time, sport, team, solved a problem, for example, because, criticism, strength.",
		"hello": "Hallo, ich bin Mara von Swissloop Tunneling. Ich will wissen, wie ihr tickt, und ich hake nach. Bereit?",
		"questions": [
			{"q": "Stell dich bitte kurz vor: Wer bist du und was studierst du?", "who": 0, "keys": [STUDY, INTRO], "keys_en": [STUDY_EN, INTRO_EN],
				"good": "Freut mich, dich kennenzulernen.",
				"tip": "Name, Studiengang und Semester: Ich heisse Tim und studiere Maschinenbau im ersten Semester.",
				"opts": ["Ich heisse Tim und studiere Maschinenbau im ersten Semester", "Ich bin halt Student", "Steht alles in meiner Bewerbung"]},
			{"q": "Was machst du in deiner Freizeit?", "who": 1, "keys": [HOBBY], "keys_en": [HOBBY_EN],
				"good": "Klingt gut. Ausgleich ist wichtig.",
				"tip": "Ein, zwei Hobbys mit etwas Farbe: Ich spiele Unihockey im Verein und koche gern mit Freunden.",
				"opts": ["Ich spiele Unihockey im Verein und koche gern", "Freizeit habe ich keine, ich lerne nur", "Nicht so viel, eigentlich chille ich"]},
			{"q": "Erzählt von einer Situation, in der ihr zusammen ein Problem gelöst habt.", "who": -1, "keys": [TEAMWORK, EXAMPLE], "keys_en": [TEAMWORK_EN, EXAMPLE_EN],
				"good": "Genau so funktioniert ein Team.",
				"tip": "Situation und Lösung: Bei einer schweren Übungsserie haben wir die Aufgaben aufgeteilt und zusammen besprochen.",
				"opts": ["Bei einer schweren Serie haben wir aufgeteilt und zusammen besprochen", "Wir sind ein gutes Team", "Meistens löse ich die Probleme allein"]},
			{"q": "Wie reagierst du, wenn jemand im Team deine Idee schlecht findet?", "who": 0,
				"keys": [["zuhoer", "diskut", "verstehen", "warum", "argument", "kompromiss", "offen", "feedback", "besprech",
					"respekt", "ueberleg", "meinung", "kritik", "nachfrag", "gruende"]],
				"keys_en": [["listen", "discuss", "understand", "why", "argument", "compromise", "open", "feedback", "talk",
					"respect", "think about", "opinion", "critic", "ask", "reasons"]],
				"good": "Sehr reif. Kritik gehört dazu.",
				"tip": "Offen bleiben: Ich höre zu, frage nach dem Warum, und wir suchen zusammen die beste Lösung.",
				"opts": ["Ich höre zu, frage warum und wir suchen zusammen eine Lösung", "Ich erkläre so lange, bis alle zustimmen", "Dann lasse ich die Idee eben fallen"]},
			{"q": "Was ist deine grösste Stärke, und wann hast du sie gezeigt?", "who": 1, "keys": [STRENGTH, EXAMPLE], "keys_en": [STRENGTH_EN, EXAMPLE_EN],
				"good": "Die können wir gut brauchen.",
				"tip": "Stärke mit Beispiel: Ich bin belastbar, als ich drei Prüfungen in einer Woche hatte, bin ich ruhig geblieben.",
				"opts": ["Ich bin belastbar, als ich drei Prüfungen hatte, blieb ich ruhig", "Ich bin belastbar und flexibel", "Ich kann eigentlich alles gut"]},
			{"q": "Warum sollten wir euch nehmen und nicht jemand anderen?", "who": -1, "keys": [WHY_US], "keys_en": [WHY_US_EN],
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
		"prompt_en": "I study at ETH. Vitalfaden, health, helping people, startup, flexible, weakness, for example, because, in five years.",
		"hello": "Hallo! Nina, CEO von Vitalfaden. Wir sind klein, jede Person zählt, darum bin ich streng. Erzählt mal!",
		"questions": [
			{"q": "Erzähl kurz von dir: Was studierst du, und was treibt dich an?", "who": 0, "keys": [STUDY, MOTIVE + ["helfen", "bauen", "ziel"]], "keys_en": [STUDY_EN, MOTIVE_EN + ["help", "build", "goal"]],
				"good": "Schön, das spürt man.",
				"tip": "Studiengang und Antrieb: Ich studiere Informatik und will Dinge bauen, die Menschen helfen.",
				"opts": ["Ich studiere Informatik und will Dinge bauen, die Menschen helfen", "Ich studiere Informatik", "Mich treibt vor allem der Lohn an"]},
			{"q": "Warum Gesundheit? Was bedeutet es dir, Menschen zu helfen?", "who": 1,
				"keys": [["helfen", "menschen", "gesund", "sinn", "leben", "patient", "famil", "wichtig", "verbesser",
					"gutes", "medizin", "herz", "etwas bewirken", "wirkung"]], "bad": ["markt", "wachstum", "google"],
				"keys_en": [["help", "people", "health", "meaning", "life", "patient", "family", "important", "improve",
					"good", "medicine", "heart", "make a difference", "impact"]], "bad_en": ["market", "growth", "google"],
				"good": "Das ist genau unsere Mission.",
				"tip": "Persönlich werden: Es ist mir wichtig, dass meine Arbeit Menschen wirklich hilft, meine Oma hat ein Herzleiden.",
				"opts": ["Es ist mir wichtig, dass meine Arbeit Menschen wirklich hilft", "Gesundheit ist ein Wachstumsmarkt", "Eigentlich wollte ich zu Google"]},
			{"q": "In einem Startup ändert sich alles ständig. Wie geht ihr damit um?", "who": -1,
				"keys": [["flexib", "anpass", "spontan", "offen", "spannend", "abwechslung", "ruhig", "plan", "lern", "neu",
					"gerne", "kein problem", "mag", "neugier", "veraender", "gut", "toll", "super"]],
				"keys_en": [["flexib", "adapt", "spontan", "open", "exciting", "variety", "calm", "plan", "learn", "new",
					"like", "no problem", "enjoy", "curious", "change", "good", "great", "fine"]],
				"good": "Perfekt, so überlebt man im Startup.",
				"tip": "Zeigen, dass dir Abwechslung gefällt: Ich bin flexibel und finde es spannend, wenn sich Dinge ändern.",
				"opts": ["Ich bin flexibel und finde Veränderungen spannend", "Mir sind klare Abläufe wichtiger", "Da muss man halt durch"]},
			{"q": "Was ist deine grösste Schwäche, und was tust du dagegen?", "who": 0, "keys": [WEAKNESS, EXAMPLE + ["arbeite daran", "dagegen", "versuche", "lerne"]],
				"keys_en": [WEAKNESS_EN, EXAMPLE_EN + ["working on", "against it", "try", "learning", "so i"]],
				"good": "Danke für die Ehrlichkeit.",
				"tip": "Ehrlich, mit Plan: Ich bin manchmal zu perfektionistisch, deshalb setze ich mir jetzt feste Zeitlimits.",
				"opts": ["Ich bin zu perfektionistisch, deshalb setze ich mir Zeitlimits", "Ich bin zu perfektionistisch", "Schwächen habe ich eigentlich keine"]},
			{"q": "Wo siehst du dich in fünf Jahren?", "who": 1, "keys": [FUTURE], "keys_en": [FUTURE_EN],
				"good": "Vielleicht ja bei uns!",
				"tip": "Ein konkretes Ziel nennen: Ich habe meinen Master und arbeite in einem jungen MedTech-Startup.",
				"opts": ["Mit dem Master in einem jungen MedTech-Startup", "Hoffentlich auf einer Insel", "Ich plane nicht so weit"]},
			{"q": "Zum Schluss: Habt ihr noch Fragen an mich?", "who": -1, "keys": [ASK_BACK], "bad": ["nein", "keine fragen", "nö"],
				"keys_en": [ASK_BACK_EN], "bad_en": ["no", "no questions", "nope"],
				"good": "Sehr gute Frage. Freut mich, dass ihr nachfragt.",
				"tip": "Immer eine echte Frage stellen: Wie sieht ein typischer Arbeitstag bei euch aus?",
				"opts": ["Wie sieht ein typischer Arbeitstag bei euch aus?", "Nein danke, alles klar", "Ist das Startup schon profitabel? Sonst nein"]},
		],
	},
]


## The words the speech recognition should expect for this job, in the language of the game.
static func prompt(j: Dictionary) -> String:
	return String(j.get("prompt_en", j["prompt"])) if Game.lang == "en" else String(j["prompt"])


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
	var en: bool = Game.lang == "en"   # answers in English are checked against the English words
	var groups: Array = q.get("keys_en", q["keys"]) if en else q["keys"]
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
	for w in (DODGE_EN + q.get("bad_en", []) if en else DODGE + q.get("bad", [])):
		var b := normalize(w).strip_edges()
		# short words only as a whole word ("nein"), longer ones also inside a word ("wachstum")
		if text.contains(" " + b + " ") or (b.length() >= 5 and text.contains(b)):
			dodged = true
	return {"ok": matched >= need and not dodged, "hits": hits, "matched": matched}


# ------------------------------------------------------------------ the application (per game)
## The applications of this game, kept in the save game (Game.elective, cleared by a new study):
## {"id": the last job applied for, "outcome": "hired" / "rejected", "grade": the best so far,
## "rejected": [ids of the companies that said no]}, or {}.
static func application() -> Dictionary:
	var a = Game.elective(KEY, {})
	return a if a is Dictionary else {}


## `rejected`: the ids of all companies that have said no so far (one application per company).
static func set_application(id: String, outcome: String, grade: float, rejected: Array = []) -> void:
	Game.set_elective(KEY, {"id": id, "outcome": outcome, "grade": grade, "rejected": rejected.duplicate()})
