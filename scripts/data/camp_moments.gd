## Camp moments: at most one small, optional scene at the fire, drawn from what actually
## happened to the company. A moment changes nothing; dismissing it only remembers its key
## so it isn't shown again. Every name and number comes from campaign state.
extends RefCounted

const Captains = preload("res://scripts/data/captains.gd")
const Heroes = preload("res://scripts/data/heroes.gd")

## Acknowledged keys kept in a save (oldest dropped first).
const SEEN_KEEP := 40

## Three lines per moment and captain temperament, taken in turn by the company's battle
## count so the same line never comes twice running. %s is a name.
const LINES := {
	"fallen": {
		Captains.VENGEFUL: ["%s's place at the fire stays empty. Someone sharpens a blade and swears it will be paid back.",
			"%s's place at the fire stays empty. The company's angriest sit nearest it, and say the least.",
			"%s's place at the fire stays empty. A spear is driven into the ground beside it, point up."],
		Captains.STEADFAST: ["%s's place at the fire stays empty. The company eats in silence, and keeps a cup poured.",
			"%s's place at the fire stays empty. Their squad still lines up as if they'd walk out of the dark.",
			"%s's place at the fire stays empty. Someone has set their boots beside it, cleaned."],
		Captains.FRAGILE: ["%s's place at the fire stays empty. Nobody can bring themselves to sit there.",
			"%s's place at the fire stays empty. Their squad sleeps close together tonight.",
			"%s's place at the fire stays empty. The youngest keeps glancing at it, then away."],
		"": ["%s's place at the fire stays empty.",
			"%s's place at the fire stays empty, and the company leaves it so.",
			"No one sits in %s's place tonight."],
	},
	# %s is the mourner, then the fallen.
	"mourn": {
		Captains.VENGEFUL: ["%s sits by %s's empty place, turning a blade over and over, and swears it will be paid back.",
			"%s scratches a mark on the shield for %s, and does not sleep.",
			"%s says %s's name once, quietly, like a promise, and goes to sharpen everything they own."],
		Captains.STEADFAST: ["%s keeps %s's place at the fire, and pours a cup there that no one drinks.",
			"%s takes %s's watch as well as their own, and won't hear of anyone else doing it.",
			"%s tells the recruits a story about %s, a funny one, and the camp laughs for the first time in days."],
		Captains.FRAGILE: ["%s can't look at %s's empty place. They sit with their back to it all night.",
			"%s keeps %s's cloak and wears it, though it doesn't fit.",
			"%s starts to call for %s twice before the fire has burned down."],
		"": ["%s keeps %s's place at the fire.",
			"%s sits a while by %s's empty place.",
			"%s says %s's name to the fire, and nothing more."],
	},
	"wounded": {
		Captains.VENGEFUL: ["%s lies by the fire, bandaged and furious, counting the battles until they can ride again.",
			"%s glares at the bandages as if they were the enemy, and tests the arm every hour.",
			"%s, bandaged, makes a list of who did it. The list is long and detailed."],
		Captains.STEADFAST: ["%s rests by the fire, bandaged, and tells the young ones it's nothing.",
			"%s, bandaged, still checks the sentries from a camp stool.",
			"%s lets the surgeon work without a word, then asks after the squad."],
		Captains.FRAGILE: ["%s rests by the fire, bandaged and quiet, watching the dark.",
			"%s hasn't slept. The wound's not the worst of it.",
			"%s keeps the bandaged hand hidden under the cloak, and jumps at every horn."],
		"": ["%s rests by the fire with fresh bandages.",
			"%s is bandaged and resting.",
			"%s sits out the evening with a bound wound."],
	},
	"victory": {
		Captains.VENGEFUL: ["%s is still grinning about the fight. Tonight the company drinks to it.",
			"%s tells the fight again, louder, with more of the enemy in it each time.",
			"%s raises a cup to the dead of the other side. \"They should have run sooner.\""],
		Captains.STEADFAST: ["%s walks the lines after the victory, checking every soldier by name.",
			"%s sees the wounded fed before taking a cup, and only then smiles.",
			"%s says a few plain words to the company, and the cheering that follows is all theirs."],
		Captains.FRAGILE: ["%s laughs too loud after the victory, then sits a long while alone.",
			"%s can't stop smiling, and can't stop shaking either.",
			"%s drinks to the victory, then to the fact of being alive, then goes quiet."],
		"": ["The company drinks to the victory.",
			"Songs at the fire tonight.",
			"The company is loud tonight, and has earned it."],
	},
	"defeat": {
		Captains.VENGEFUL: ["%s paces the camp after the defeat, already planning the next fight.",
			"%s throws a cup into the fire and says what everyone is thinking.",
			"%s draws the enemy's line in the dirt, and where it broke, over and over."],
		Captains.STEADFAST: ["%s keeps the camp in order after the defeat. Tomorrow they'll be ready.",
			"%s goes squad to squad after the defeat, saying the same thing to each. \"We're still here.\"",
			"%s mends harness by the fire as if nothing happened. It helps more than speeches."],
		Captains.FRAGILE: ["%s hasn't said a word since the defeat.",
			"%s sits apart from the fire, staring at their hands.",
			"%s keeps asking who else didn't come back."],
		"": ["The camp is quiet after the defeat.",
			"Nobody sings tonight.",
			"The company eats and sleeps, and says little."],
	},
}


## The `kind` line for a captain of `temperament`: the `pick`th of its three, in turn.
static func line(kind: String, temperament: String, name: String, other: String = "", pick: int = 0) -> String:
	var options: Dictionary = LINES.get(kind, {})
	var v = options.get(temperament, options.get("", "%s"))
	var text := ""
	if v is Array and not (v as Array).is_empty():
		text = String(v[posmod(pick, (v as Array).size())])
	else:
		text = String(v)
	if other != "":
		return text % [name, other]
	return text % name if text.contains("%s") else text


## As line, but a hero speaks in their own voice ("victory", "defeat", "wounded", "mourn").
static func line_for(kind: String, captain, name: String, other: String = "", pick: int = 0) -> String:
	if captain is Dictionary and bool(captain.get("is_hero", false)):
		var own := Heroes.camp_line(String(captain.get("hero_id", "")), kind)
		if own != "":
			return own % [name, other] if other != "" else own % name
	return line(kind, String(captain.get("temperament", "")) if captain is Dictionary else "", name, other, pick)


## A captain still with the company, by id.
static func _living(gs, id: int):
	for s in gs.army:
		var c = s.get("captain")
		if c is Dictionary and int(c.get("id", -1)) == id:
			return c
	return null


## A living captain who was bonded to the fallen `f`: the one to mourn them.
## The captain who mourns the fallen `f` most (the first bond of theirs still in the
## company), or null.
static func mourner(gs, f: Dictionary):
	return _mourner(gs, f)


static func _mourner(gs, f: Dictionary):
	for entry in f.get("bonds", []):
		var first := String(entry).split(" (")[0]
		for s in gs.army:
			var c = s.get("captain")
			if c is Dictionary and String(c.get("first", "")) == first:
				return c
	return null


static func _captain_name(c) -> String:
	return String(c.get("first", c.get("name", "A captain"))) if c is Dictionary else "A captain"


## The first moment the player hasn't dismissed, or {} for a quiet visit.
## {key, kind, title, text, action, captain_id, a_id, b_id}. Reading it changes nothing.
static func pick(gs) -> Dictionary:
	for m in candidates(gs):
		if not gs.camp_seen.has(m["key"]):
			return m
	return {}


## Every moment the company's state supports right now, most important first.
static func candidates(gs) -> Array:
	var out: Array = []
	var turn: int = int(gs.battles)
	# A captain who fell and hasn't been mourned at the fire yet, however many battles
	# have passed (memorials from before this was kept: the last battle's only).
	for f in gs.fallen:
		var waiting: bool = (f.has("mourned") and not bool(f["mourned"])) or (int(f.get("battle", -1)) == gs.battles and gs.battles > 0)
		if waiting and not gs.camp_seen.has("fallen_%d" % int(f.get("id", 0))):
			var mourner = _mourner(gs, f)
			var text := line("fallen", String(f.get("temperament", "")), _captain_name(f), "", turn)
			if mourner != null:
				text = line_for("mourn", mourner, _captain_name(mourner), _captain_name(f), turn)
			out.append({"key": "fallen_%d" % int(f.get("id", 0)), "kind": "fallen", "title": "An empty place",
				"text": text, "action": "memorial", "captain_id": int(f.get("id", 0))})
	# A bond that reached a new rank and is waiting to be seen.
	for e in gs.bond_events:
		if String(e.get("kind", "")) == "rank":
			out.append({"key": "bond_%d_%d_%s" % [int(e.get("a_id", 0)), int(e.get("b_id", 0)), String(e.get("rank", ""))],
				"kind": "bond", "title": "A bond grows", "text": "%s have grown closer: rank %s." % [String(e.get("pair", "Two captains")), String(e.get("rank", ""))],
				"action": "bond", "a_id": int(e.get("a_id", 0)), "b_id": int(e.get("b_id", 0))})
			break
	# Real shortages.
	if gs.world != null and (gs.food < gs.total_men() or gs.silver < gs.daily_wages()):
		var day := int(gs.world.hour / 24.0)
		var what := "food" if gs.food < gs.total_men() else "silver for wages"
		out.append({"key": "short_%d" % day, "kind": "shortage", "title": "Short of %s" % what,
			"text": "The men whisper about the %s. Some may leave if it runs out." % what, "action": "map"})
	# The last battle.
	var last: Dictionary = gs.last_result
	if not last.is_empty() and gs.battles > 0:
		var won := bool(last.get("won", false))
		# The captain who did the most, if they're still with the company; else anyone fit.
		var lead = null
		var best := -1
		for row in last.get("captains", []):
			var c = _living(gs, int(row.get("id", -1)))
			if c != null and String(row.get("fate", "")) != "killed" and int(row.get("kills", 0)) > best:
				best = int(row.get("kills", 0))
				lead = c
		if lead == null:
			for s in gs.army:
				if s.get("captain") is Dictionary and int(s["captain"].get("wounded", 0)) == 0:
					lead = s["captain"]
					break
		out.append({"key": "battle_%d" % gs.battles, "kind": "victory" if won else "defeat",
			"title": "After the victory" if won else "After the defeat",
			"text": line_for("victory" if won else "defeat", lead, _captain_name(lead), "", turn) \
				+ (" The fight near %s: lost %d, cut down %d." % [_place_name(String(last.get("place", ""))), int(last.get("lost", 0)), int(last.get("killed", 0))]
					if String(last.get("place", "")) != "" else " Lost %d, cut down %d." % [int(last.get("lost", 0)), int(last.get("killed", 0))]),
			"action": "captain" if lead != null else "", "captain_id": int(lead.get("id", 0)) if lead != null else -1})
	# A captain recovering from a wound.
	for s in gs.army:
		var c = s.get("captain")
		if c is Dictionary and int(c.get("wounded", 0)) > 0:
			out.append({"key": "wound_%d_%d" % [int(c.get("id", 0)), int(c.get("battles", 0))], "kind": "wounded",
				"title": "Resting", "text": line_for("wounded", c, _captain_name(c), "", turn + int(c.get("id", 0))) \
					+ " %d %s to go." % [int(c["wounded"]), "battle" if int(c["wounded"]) == 1 else "battles"],
				"action": "captain", "captain_id": int(c.get("id", 0))})
			break
	return out


static func _place_name(id: String) -> String:
	const WorldData = preload("res://scripts/world/world_data.gd")
	return String(WorldData.settlement(id)["name"]) if WorldData.SETTLEMENTS.has(id) else id


## Remember that a moment was seen, so the same one never returns. The oldest are let go
## first, but a mourning is kept longest: its memorial waits until it's seen.
static func dismiss(gs, key: String) -> void:
	if key == "" or gs.camp_seen.has(key):
		return
	gs.camp_seen.append(key)
	while gs.camp_seen.size() > SEEN_KEEP:
		var drop := 0
		for i in gs.camp_seen.size():
			if not String(gs.camp_seen[i]).begins_with("fallen_"):
				drop = i
				break
		gs.camp_seen.remove_at(drop)
