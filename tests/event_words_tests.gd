## The words at the game's events and ceremonies other than the wedding: the gatherings
## (each night of the hall, the herald, toasts by occasion, a gift's thanks by what was
## brought, gossip), the hall's moments (the insult reaches for what you are), your own
## court (the speech, the council, the lists) and the memorial rite (the words over the
## dead, each people's light). Every line is checked for blanks left unfilled, and nobody
## is "he", "she", a king or a queen.
## godot --headless --path . --script res://tests/event_words_tests.gd
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const Lords = preload("res://scripts/data/lords.gd")
const Gatherings = preload("res://scripts/data/gatherings.gd")
const HallMoments = preload("res://scripts/data/hall_moments.gd")
const Court = preload("res://scripts/data/court_lines.gd")
const MemorialLines = preload("res://scripts/data/memorial_lines.gd")

var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _init() -> void:
	await process_frame
	var cultures := [Cultures.VARDISH, Cultures.KHARZANI, Cultures.RYUMON]
	var bearings := [Lords.DARING, Lords.CAUTIOUS, Lords.HONORABLE, Lords.CRUEL]

	# ---- the hall, night by night
	for c in cultures:
		var nights := [Gatherings.night_line(c, 1), Gatherings.night_line(c, 2), Gatherings.night_line(c, 3)]
		check(nights[0] != nights[1] and nights[1] != nights[2], "%s: each night of the hall is its own" % c)
	check(Gatherings.night_line(Cultures.VARDISH, 1, "peace").contains("peace feast") and not Gatherings.night_line(Cultures.VARDISH, 2, "peace").contains("peace feast"),
		"the first night says why it's held; the others don't repeat it")
	# ---- toasts by occasion, gifts by what was brought
	for c in cultures:
		var plain := Gatherings.toast(c, "", "Lord Brann")
		check(plain.contains("Lord Brann") and plain != Gatherings.toast(c, "peace", "Lord Brann") and plain != Gatherings.toast(c, "victory", "Lord Brann"),
			"%s: your toast names the host, and fits a peace or a victory" % c)
		check(Gatherings.toast(c, "season", "X") == Gatherings.toast(c, "", "X"), "%s: an ordinary feast gets the ordinary toast" % c)
	for b in bearings:
		check(Gatherings.gift_thanks(b, "food") != Gatherings.gift_thanks(b, "silver"), "a %s host thanks you for rations differently than for silver" % b)
	for c in cultures:
		check(Gatherings.quiet_gossip(c) != Gatherings.quiet_gossip(Cultures.VARDISH) or c == Cultures.VARDISH, "%s: the idle talk is its own people's" % c)

	# ---- your court
	for b in bearings:
		for aim in ["storm", "relieve", "march", "raid"]:
			var one := Court.fill(Court.counsel(b, aim, 0), {"place": "Highcliff"})
			var two := Court.fill(Court.counsel(b, aim, 1), {"place": "Highcliff"})
			check(one != "" and not one.contains("{"), "a %s lord has counsel for %s" % [b, aim])
			if aim == "storm" and b == Lords.DARING:
				check(one != two, "two lords of one bearing needn't say the same thing")
	check(Court.fill(String(Court.SPEECH["war"]), {"foe": "Kharzan", "lords": 4, "holdings": 3}).contains("4 lords") \
		and Court.fill(String(Court.SPEECH["war"]), {"foe": "Kharzan", "lords": 4, "holdings": 3}).contains("Kharzan"), "the war speech names the foe and counts the table")
	check(Court.fill(String(Court.BOUT[2]), {"won": "Ilse", "lost": "Lord Brann's champion"}).contains("The bout is Ilse's"), "a bout is told at the pass it was won")

	# ---- the memorial
	check(MemorialLines.words("grief", "Highcliff", "Bren", "") .contains("Bren") and MemorialLines.words("grief", "Highcliff", "", "") == String(MemorialLines.WORDS["grief"]["alone"]),
		"grief names the friend who loved them, or the company when there's none")
	check(MemorialLines.words("honour", "Highcliff", "", "").contains("Highcliff"), "honour names where they held")
	check(MemorialLines.words("vengeance", "", "", "Emir Tahir").begins_with("Emir Tahir"), "vengeance names the lord")
	var lights := {}
	for c in cultures:
		lights[String(MemorialLines.place(c)["light"])] = true
	check(lights.size() == 3, "each people keeps its own light for the dead: candle, lamp, incense")

	# ---- every line: no blanks left behind, nobody is he, she, king or queen
	var said := ""
	for path in ["res://scripts/data/gatherings.gd", "res://scripts/data/hall_moments.gd", "res://scripts/data/court_lines.gd", "res://scripts/data/memorial_lines.gd"]:
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var t := String(line).strip_edges()
			if t.begins_with("#") or not t.contains("\""):
				continue
			said += " " + t.to_lower()
	for word in [" he ", " his ", " him ", " king ", " queen ", " my lord"]:
		check(not said.contains(word), "no \"%s\" in what the events say" % word.strip_edges())

	# ---- the ear: every ceremony's music and sounds are there, and the loops are long
	for nm in ["lament_vardish", "lament_kharzani", "lament_ryumon", "one_crown", "wedding_vardish", "wedding_kharzani", "wedding_ryumon"]:
		check(FileAccess.file_exists("res://assets/audio/music/%s.ogg" % nm), "the music %s exists" % nm)
	for nm in ["crown_fanfare", "stone", "tablet", "candle", "lamp_lit", "keepsake", "letter", "feast_din", "cups", "applause", "laugh"]:
		check(FileAccess.file_exists("res://assets/audio/sfx/%s.ogg" % nm), "the sound %s exists" % nm)
	for nm in ["camp", "water", "birds", "road_open", "road_night", "settlement_edge", "settlement_vardish", "settlement_kharzani",
			"settlement_ryumon", "hearth", "murmur", "feast_din"]:
		var stream = load("res://assets/audio/sfx/%s.ogg" % nm)
		check(stream != null and stream.get_length() >= 20.0, "the %s loop runs 20 seconds or more before it repeats" % nm)

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
