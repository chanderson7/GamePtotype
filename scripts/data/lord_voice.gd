## How a lord looks and sounds: a portrait from the shared captain catalog, the colors of
## their house, and short lines by bearing for meeting them, facing them and the battle's end.
## Presentation only; every fact in a line comes from the lord's own record.
extends RefCounted

const Lords = preload("res://scripts/data/lords.gd")
const Cultures = preload("res://scripts/data/cultures.gd")

## Lords use portrait ids far from any captain's, so the two never collide.
const PORTRAIT_BASE := 50000

## %s is the lord's name.
const LINES := {
	"greet": {
		Lords.DARING: "%s grins down from the saddle. \"Ride with me sometime, sellsword. The war's more fun at the front.\"",
		Lords.CAUTIOUS: "%s keeps the escort close while greeting you. \"Fair roads, captain. Mind the passes.\"",
		Lords.HONORABLE: "%s raises a gauntleted hand in greeting. \"Well met. The roads are safer with companies like yours on them.\"",
		Lords.CRUEL: "%s looks your men over like cattle at a fair. \"Useful. For now.\"",
	},
	"face": {
		Lords.DARING: "%s laughs and draws steel. \"At last, a fight worth riding for!\"",
		Lords.CAUTIOUS: "%s halts, counts your men twice, and only then gives the order to form up.",
		Lords.HONORABLE: "%s salutes you across the field. \"No quarter asked, none refused. Begin when ready.\"",
		Lords.CRUEL: "%s smiles thinly. \"Leave none who can still crawl.\"",
	},
	"beaten": {
		Lords.DARING: "%s spits blood and laughs, being led away. \"Again someday!\"",
		Lords.CAUTIOUS: "%s had already sent the baggage back before the end, knowing.",
		Lords.HONORABLE: "%s offers a sword hilt-first. \"Well fought. I yield.\"",
		Lords.CRUEL: "%s curses you, your company and your mother as the line breaks.",
	},
	"victor": {
		Lords.DARING: "%s rides past your survivors at a gallop, whooping.",
		Lords.CAUTIOUS: "%s lets you go, having won what was wanted.",
		Lords.HONORABLE: "%s lets your wounded be carried off the field.",
		Lords.CRUEL: "%s has the stragglers run down.",
	},
}


static func line(kind: String, lord: Dictionary) -> String:
	var options: Dictionary = LINES.get(kind, {})
	var text := String(options.get(String(lord.get("bearing", "")), "%s says nothing."))
	return text % String(lord.get("name", "The lord"))


## A captain-like record for the portrait catalog, stable for this lord.
static func portrait_record(lord: Dictionary) -> Dictionary:
	return {"id": PORTRAIT_BASE + int(lord.get("id", 0)), "culture": String(lord.get("culture", Cultures.VARDISH)),
		"name": String(lord.get("name", ""))}


## The colors of their house: the realm's own, turned by the house's name so houses differ.
static func house_colors(lord: Dictionary) -> Array:
	var base: Color = Cultures.color(String(lord.get("culture", Cultures.VARDISH)))
	var house := String(lord.get("house", lord.get("name", "")))
	var turn := float(abs(house.hash()) % 1000) / 1000.0
	var cloth := Color.from_hsv(fposmod(base.h + (turn - 0.5) * 0.25, 1.0), clampf(base.s * 0.9 + 0.1, 0.0, 1.0), clampf(base.v, 0.35, 0.9))
	return [cloth, cloth.darkened(0.45)]
