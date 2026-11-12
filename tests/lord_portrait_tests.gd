## Faces from the pixel portrait kit (scripts/art/lord_portrait.gd): every lord of every land
## is drawn, always the same way, dressed as their land and house, a ruler crowned, a lady
## never bearded, and an expression only touching the face. Captains are drawn from it too,
## as CaptainFace always drew them and marked by their careers; and the feeling of a line
## (scripts/data/feeling.gd) chooses the face it's said with.
extends SceneTree

const Cultures = preload("res://scripts/data/cultures.gd")
const LordVoice = preload("res://scripts/data/lord_voice.gd")
const LordPortrait = preload("res://scripts/art/lord_portrait.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const CaptainFace = preload("res://scripts/art/captain_face.gd")
const Feeling = preload("res://scripts/data/feeling.gd")

var failures := 0


func check(ok: bool, message: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + message)
	if not ok:
		failures += 1


func _init() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.persist = false
	check(LordPortrait.available(), "the kit loads (atlas and kit.json)")
	var all_drawn := true
	var stable := true
	var ladies_bare := true
	var a_beard := false
	var rulers_crowned := true
	var realm_varied := true
	var dressed_by_land := true
	for culture in [Cultures.VARDISH, Cultures.KHARZANI, Cultures.RYUMON]:
		gs.new_campaign(culture)
		var by_realm := {}
		for l in gs.world.lords:
			var rec := LordVoice.portrait_record(l)
			var img := LordPortrait.image(rec)
			all_drawn = all_drawn and img != null and img.get_width() == 120 and img.get_height() == 160 and not img.is_invisible()
			stable = stable and img != null and img.get_data() == LordPortrait.image(rec).get_data()
			var f := LordPortrait.look(rec)
			if bool(f["lady"]):
				ladies_bare = ladies_bare and String(f["beard"]) == ""
			else:
				a_beard = a_beard or String(f["beard"]) != ""
			if bool(l.get("ruler", false)):
				rulers_crowned = rulers_crowned and String(f["hat"]) != ""
			dressed_by_land = dressed_by_land and String(f["culture"]) == String(l["culture"]) and \
				LordPortrait.CUTS[f["culture"]][f["g"]].has(f["cut"])
			if not bool(l.get("ruler", false)):
				var key := String(l["realm"])
				if not by_realm.has(key):
					by_realm[key] = {}
				by_realm[key]["%s|%s|%s" % [f["hair"], f["cut"], f["hat"]]] = true
		for realm in by_realm:
			realm_varied = realm_varied and (by_realm[realm] as Dictionary).size() >= 3
	check(all_drawn, "every lord of every land is drawn, 120 by 160")
	check(stable, "a lord looks the same every time")
	check(ladies_bare, "a lady never has a beard")
	check(a_beard, "lords may be bearded")
	check(rulers_crowned, "every ruler wears a crown, a jewelled turban, a tiara, an eboshi or golden pins")
	check(dressed_by_land, "each wears one of their own land's cuts")
	check(realm_varied, "a realm's lords are not all dressed and groomed alike")

	gs.new_campaign(Cultures.VARDISH)
	var lord: Dictionary = gs.world.lords[1]
	var rec := LordVoice.portrait_record(lord)
	var rest := LordPortrait.image(rec)
	# Expressions touch only the face.
	var only_face := true
	var all_change := true
	var faces := {}
	var moods: Array = LordPortrait.MOODS.keys()
	moods.erase("")
	for mood in moods + ["/shut", "/half", "/away", "/brow", "/talk", "warm/talk", "grim/talk,shut"]:
		var e := LordPortrait.image(rec, false, mood)
		var changed := false
		for y in 160:
			for x in 120:
				if e.get_pixel(x, y) != rest.get_pixel(x, y):
					changed = true
					if y < 36 or y > 76 or x < 34 or x > 86:
						only_face = false
		all_change = all_change and changed
		faces[e.get_data()] = true
	check(all_change, "every mood and every eye state changes the face")
	check(faces.size() == moods.size() + 7, "and no two of them are the same face (%d of %d)" % [faces.size(), moods.size() + 7])
	check(LordPortrait.image(rec, false, "warm/talk").get_data() != LordPortrait.image(rec, false, "/talk").get_data(),
		"a smile talks with a smiling mouth")
	check(only_face, "an expression changes nothing but the face")
	check(LordPortrait.image(rec, false, "blink").get_data() == LordPortrait.image(rec, false, "/shut").get_data(),
		"a blink is the resting face with the eyes shut")
	# House colours: the same lord in another house's colours looks different.
	var other := rec.duplicate()
	other["house"] = "2a6a3a" if String(rec["house"]) != "2a6a3a" else "8a2030"
	check(LordPortrait.image(other).get_data() != rest.get_data(), "a house's colour dresses its lord")
	# Kin are ladies of the house, never crowned.
	var kin := LordVoice.kin_record(lord, {"name": "Elspeth", "relation": "sister"})
	var kf := LordPortrait.look(kin)
	check(bool(kf["lady"]) and String(kf["beard"]) == "" and not String(kf["hat"]).contains("crown"),
		"a lord's kinswoman is drawn as a lady of the house, uncrowned")
	# The portrait catalog draws lords from the kit and captains as before.
	var lt := CaptainArt.texture(rec)
	check(lt != null and lt.get_width() == 120 and lt.get_height() == 160, "the portrait catalog draws lords from the kit")
	var cap := {"id": 7, "culture": Cultures.VARDISH, "first": "Ada", "name": "Ada", "type": "infantry"}
	var ct := CaptainArt.texture(cap)
	check(ct != null and ct.get_width() == 120 and ct.get_height() == 160, "and captains, from the same kit")
	var cs := CaptainArt.texture(cap, "", true)
	check(cs != null and cs.get_width() == 60 and cs.get_height() == 80, "a small slot gets head and shoulders at 60 x 80")
	check(CaptainArt.portrait(cap, Vector2(54, 72)).texture == cs and CaptainArt.portrait(cap, Vector2(150, 190)).texture == ct,
		"a little portrait shows the small picture, a big one the whole face")
	# A captain keeps the face CaptainFace gave them, and their career shows on it.
	var cf := CaptainFace.features(cap)
	var cl := LordPortrait.captain_look(cap)
	check(bool(cl["lady"]) == (Cultures.is_womans_name("Ada", Cultures.VARDISH) or bool(cf["woman"])),
		"a captain with a woman's name is drawn as a woman")
	check(String(cl["skin"]) == LordPortrait.CAPT_SKIN[int(cf["skin"])] and String(cl["hair_color"]) == LordPortrait.CAPT_HAIR_COLOR[int(cf["hair_color"])],
		"with the skin and hair CaptainFace gave them")
	var plain := LordPortrait.image(cap).get_data()
	var marked := true
	for change in [{"battles": 25}, {"wounded": 1}, {"history": {"wounds": 2}}, {"specialization": "Scout"}, {"type": "archers"}]:
		var c2 := cap.duplicate(true)
		c2.merge(change, true)
		marked = marked and LordPortrait.image(c2).get_data() != plain
	check(marked, "rank, a bandage, scars, a veteran role and the troop they lead all show")
	check(LordPortrait.image(cap).get_data() == plain, "and a captain always looks the same")
	var shy := LordPortrait.image(cap, false, "shy")
	var near_shy := LordPortrait.image(cap, false, "/away")
	var blush_on_skin := true
	var skin_only := LordPortrait.image(cap)
	for y in 160:
		for x in 120:
			if shy.get_pixel(x, y).a != skin_only.get_pixel(x, y).a:
				blush_on_skin = false
	check(blush_on_skin and shy.get_data() != near_shy.get_data(), "a shy face blushes, only on the skin")
	# The feeling of a line.
	check(Feeling.mood_of("Counts double. Pass the bread.") == "amused", "a jest is said with a smirk")
	check(Feeling.mood_of("I keep looking for your banner. It isn't there.") == "grief", "a missing friend with grief")
	check(Feeling.mood_of("How dare you come here?") == "angry", "an insult in anger")
	check(Feeling.mood_of("You flinched when the horn went.", "Vengeful") == "tease" and Feeling.mood_of("I'm afraid all the time.", "Fragile") == "worried",
		"someone else's fear is mocked; their own shows")
	check(Feeling.mood_of("Hold my hand when the horns go?", "Fragile") == "shy", "a tender word from a fragile one, with a blush")
	check(Feeling.mood_of("What else?") == "" and Feeling.mood_of("Why?") == "surprised", "a plain question is asked at rest; a bare why is taken aback")
	check(Feeling.reaction("laugh", "Ha! You should have seen it.", "Vengeful") == "laugh" and Feeling.reaction("grief") == "sad",
		"laughter is caught, grief shared")
	check(Feeling.scene("Before they rise, they speak the names of the absent: Bram.") == "sad", "the names of the absent sadden both")
	# Quick enough for a phone: a lord is put together once, then each expression is cheap.
	var t0 := Time.get_ticks_usec()
	for mood in ["", "warm", "/shut", "/half", "grim"]:
		LordPortrait.image(rec, true, mood)
	check(Time.get_ticks_usec() - t0 < 100000, "five expressions of a lord already drawn take under a tenth of a second")
	print("lord portrait tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
