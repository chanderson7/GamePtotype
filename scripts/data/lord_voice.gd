## How a lord looks, and how they're told of on the field: a portrait from the shared captain
## catalog, the colors of their house, and short lines by bearing for facing them and the
## battle's end. (What they say when you talk with them is in lord_lines.gd.) Presentation
## only; every fact in a line comes from the lord's own record.
extends RefCounted

const Lords = preload("res://scripts/data/lords.gd")
const Cultures = preload("res://scripts/data/cultures.gd")

## Lords use portrait ids far from any captain's, so the two never collide.
const PORTRAIT_BASE := 50000

## %s is the lord's name. Two lines for each bearing, taken in turn (see line).
const LINES := {
	"face": {
		Lords.DARING: ["%s laughs and draws steel. \"At last, a fight worth riding for!\"",
			"%s stands in the stirrups and calls for the charge before the lines have even formed."],
		Lords.CAUTIOUS: ["%s halts, counts your men twice, and only then gives the order to form up.",
			"%s keeps to the high ground and waits for you to make the first mistake."],
		Lords.HONORABLE: ["%s salutes you across the field. \"No quarter asked, none refused. Begin when ready.\"",
			"%s rides out alone to the middle of the field, bows, and rides back to the line."],
		Lords.CRUEL: ["%s smiles thinly. \"Leave none who can still crawl.\"",
			"%s has the prisoners from the last fight hung where your men can see them."],
	},
	# Facing a company they've fought before.
	"again": {
		Lords.DARING: ["%s grins in recognition. \"You again! Good. Last time was too short.\"",
			"%s whoops when your banner comes into view. \"I hoped it would be you!\""],
		Lords.CAUTIOUS: ["%s remembers your banner, and has brought more men this time.",
			"%s has studied your last fight, and it shows in how the line is drawn."],
		Lords.HONORABLE: ["%s inclines their head. \"We meet again, captain. May it end as cleanly.\"",
			"%s salutes you across the field. \"Captain. Once more, then, and cleanly.\""],
		Lords.CRUEL: ["%s knows your banner. \"I owe you for last time.\"",
			"%s points at your banner and says something that makes the whole line laugh."],
	},
	"beaten": {
		Lords.DARING: ["%s spits blood and laughs, being led away. \"Again someday!\"",
			"%s grins through a split lip as they're bound. \"Worth it. Next time I win.\""],
		Lords.CAUTIOUS: ["%s had already sent the baggage back before the end, knowing.",
			"%s yields the moment the line breaks, with a list of terms already written out."],
		Lords.HONORABLE: ["%s offers a sword hilt-first. \"Well fought. I yield.\"",
			"%s kneels and offers their sword. \"You fought well. I ask only that my wounded be tended.\""],
		Lords.CRUEL: ["%s curses you, your company and your mother as the line breaks.",
			"%s spits at your feet. \"Enjoy it. I remember faces.\""],
	},
	"victor": {
		Lords.DARING: ["%s rides past your survivors at a gallop, whooping.",
			"%s sends a rider after you with a message: \"Good fight! Again?\""],
		Lords.CAUTIOUS: ["%s lets you go, having won what was wanted.",
			"%s does not pursue. They have what they came for."],
		Lords.HONORABLE: ["%s lets your wounded be carried off the field.",
			"%s sends your fallen back under a flag of truce."],
		Lords.CRUEL: ["%s has the stragglers run down.",
			"%s leaves your dead where they fell, as a warning."],
	},
}


## The `kind` line for `lord`, by bearing. `pick` chooses which of their lines (in turn);
## left out, it follows how often you've fought and talked, so the line changes as you
## meet again.
static func line(kind: String, lord: Dictionary, pick: int = -1) -> String:
	var options: Dictionary = LINES.get(kind, {})
	var v = options.get(String(lord.get("bearing", "")), "%s says nothing.")
	var text := ""
	if v is Array and not (v as Array).is_empty():
		var n := pick
		if n < 0:
			var t: Dictionary = lord.get("talk", {}) if lord.get("talk") is Dictionary else {}
			n = int(lord.get("met_player", 0)) + int(t.get("talks", 0))
		text = String(v[posmod(n, (v as Array).size())])
	else:
		text = String(v)
	return text % String(lord.get("name", "The lord"))


## A captain-like record for the portrait catalog, stable for this lord.
static func portrait_record(lord: Dictionary) -> Dictionary:
	var colors := house_colors(lord)
	# Their bearing shows in the face, as a captain's temper does.
	var temper := ""
	var quirk := ""
	match String(lord.get("bearing", "")):
		Lords.DARING:
			quirk = "Bold"
		Lords.CAUTIOUS, Lords.HONORABLE:
			temper = "Steadfast"
		Lords.CRUEL:
			temper = "Vengeful"
	return {"id": PORTRAIT_BASE + int(lord.get("id", 0)), "culture": String(lord.get("culture", Cultures.VARDISH)),
		"name": String(lord.get("name", "")), "temperament": temper, "quirk": quirk, "woman": is_lady(lord),
		"noble": "ruler" if bool(lord.get("ruler", false)) else "lord",
		"house": (colors[0] as Color).to_html(false), "house_dark": (colors[1] as Color).to_html(false),
		"battles": 20 if int(lord.get("renown", 0)) >= 300 else 0}


## Whether a lord is a woman: her first name (after the title) is a woman's name of her land.
static func is_lady(lord: Dictionary) -> bool:
	var words := String(lord.get("name", "")).split(" ", false)
	var first := String(words[1]) if words.size() >= 2 else String(lord.get("name", ""))
	return Cultures.is_womans_name(first, String(lord.get("culture", "")))


## A lord's kinswoman's face (SocialSim.house_kin): her own record, in her lord's house
## colours, drawn as a woman of his household. `kin` is {name, relation}.
static func kin_record(lord: Dictionary, kin: Dictionary) -> Dictionary:
	var colors := house_colors(lord)
	return {"id": PORTRAIT_BASE + 20000 + int(lord.get("id", 0)), "culture": String(lord.get("culture", Cultures.VARDISH)),
		"name": String(kin.get("name", "")), "first": String(kin.get("name", "")), "noble": "lady", "kin": true,
		"house": (colors[0] as Color).to_html(false), "house_dark": (colors[1] as Color).to_html(false)}


## The colors of their house: the realm's own, turned by the house's name so houses differ.
static func house_colors(lord: Dictionary) -> Array:
	var base: Color = Cultures.color(String(lord.get("culture", Cultures.VARDISH)))
	var house := String(lord.get("house", lord.get("name", "")))
	var turn := float(abs(house.hash()) % 1000) / 1000.0
	var cloth := Color.from_hsv(fposmod(base.h + (turn - 0.5) * 0.25, 1.0), clampf(base.s * 0.9 + 0.1, 0.0, 1.0), clampf(base.v, 0.35, 0.9))
	return [cloth, cloth.darkened(0.45)]
