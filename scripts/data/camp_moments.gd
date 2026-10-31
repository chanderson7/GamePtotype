## Camp moments: at most one small, optional scene at the fire, drawn from what actually
## happened to the company. A moment changes nothing; dismissing it only remembers its key
## so it isn't shown again. Every name and number comes from campaign state.
extends RefCounted

const Captains = preload("res://scripts/data/captains.gd")

## Acknowledged keys kept in a save (oldest dropped first).
const SEEN_KEEP := 40

## One line per moment, with a variant for each captain temperament. %s is a name.
const LINES := {
	"fallen": {
		Captains.VENGEFUL: "%s's place at the fire stays empty. Someone sharpens a blade and swears it will be paid back.",
		Captains.STEADFAST: "%s's place at the fire stays empty. The company eats in silence, and keeps a cup poured.",
		Captains.FRAGILE: "%s's place at the fire stays empty. Nobody can bring themselves to sit there.",
		"": "%s's place at the fire stays empty.",
	},
	"wounded": {
		Captains.VENGEFUL: "%s lies by the fire, bandaged and furious, counting the battles until they can ride again.",
		Captains.STEADFAST: "%s rests by the fire, bandaged, and tells the young ones it's nothing.",
		Captains.FRAGILE: "%s rests by the fire, bandaged and quiet, watching the dark.",
		"": "%s rests by the fire with fresh bandages.",
	},
	"victory": {
		Captains.VENGEFUL: "%s is still grinning about the fight. Tonight the company drinks to it.",
		Captains.STEADFAST: "%s walks the lines after the victory, checking every man by name.",
		Captains.FRAGILE: "%s laughs too loud after the victory, then sits a long while alone.",
		"": "The company drinks to the victory.",
	},
	"defeat": {
		Captains.VENGEFUL: "%s paces the camp after the defeat, already planning the next fight.",
		Captains.STEADFAST: "%s keeps the camp in order after the defeat. Tomorrow they'll be ready.",
		Captains.FRAGILE: "%s hasn't said a word since the defeat.",
		"": "The camp is quiet after the defeat.",
	},
}


static func line(kind: String, temperament: String, name: String) -> String:
	var options: Dictionary = LINES.get(kind, {})
	var text := String(options.get(temperament, options.get("", "%s")))
	return text % name if text.contains("%s") else text


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
	# A captain who fell in the last battle.
	for f in gs.fallen:
		if int(f.get("battle", -1)) == gs.battles and gs.battles > 0:
			out.append({"key": "fallen_%d" % int(f.get("id", 0)), "kind": "fallen", "title": "An empty place",
				"text": line("fallen", String(f.get("temperament", "")), _captain_name(f)),
				"action": "memorial", "captain_id": int(f.get("id", 0))})
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
		var lead = null
		for s in gs.army:
			if s.get("captain") is Dictionary and int(s["captain"].get("wounded", 0)) == 0:
				lead = s["captain"]
				break
		out.append({"key": "battle_%d" % gs.battles, "kind": "victory" if won else "defeat",
			"title": "After the victory" if won else "After the defeat",
			"text": line("victory" if won else "defeat", String(lead.get("temperament", "")) if lead != null else "", _captain_name(lead)) \
				+ " Lost %d, cut down %d." % [int(last.get("lost", 0)), int(last.get("killed", 0))],
			"action": "captain" if lead != null else "", "captain_id": int(lead.get("id", 0)) if lead != null else -1})
	# A captain recovering from a wound.
	for s in gs.army:
		var c = s.get("captain")
		if c is Dictionary and int(c.get("wounded", 0)) > 0:
			out.append({"key": "wound_%d_%d" % [int(c.get("id", 0)), int(c.get("battles", 0))], "kind": "wounded",
				"title": "Resting", "text": line("wounded", String(c.get("temperament", "")), _captain_name(c)) \
					+ " %d %s to go." % [int(c["wounded"]), "battle" if int(c["wounded"]) == 1 else "battles"],
				"action": "captain", "captain_id": int(c.get("id", 0))})
			break
	return out


## Remember that a moment was seen, so the same one never returns.
static func dismiss(gs, key: String) -> void:
	if key == "" or gs.camp_seen.has(key):
		return
	gs.camp_seen.append(key)
	while gs.camp_seen.size() > SEEN_KEEP:
		gs.camp_seen.pop_front()
