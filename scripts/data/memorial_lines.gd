## The fallen remembered (scenes/memorial.tscn): what the company calls the rise where it
## sets out its dead's stones, in its own culture's way; the rite at a gathering; the words
## said over them; and the epitaphs those words make. The rules are GameState's
## (memorial_gather, light_candle, memorial_epitaph).
extends RefCounted

const Captains = preload("res://scripts/data/captains.gd")

## How many stones stand large on the hill (the rest are the old stones further up), how
## many names the roll shows before folding the rest, how long a candle burns, and the bond
## two survivors find in mourning the same friend.
const SHOWN_STONES := 7
const ROLL_FOLD := 12
const CANDLE_DAYS := 3
const SHARED_GRIEF := 1.0

const PLACES := {
	"vardish": {"name": "The Cairn Field", "line": "A rise past the horse lines, where the company leaves its dead a stone each. Someone always keeps a candle going.",
		"rite": "Raise the cairn", "rite_done": "Stone by stone, the company raises the cairn. The last stone is set, and nobody speaks for a while.",
		"empty": "No stones yet. Keep it that way."},
	"kharzani": {"name": "The Garden of Lamps", "line": "A walled patch of ground beside the camp, a cypress at its heart. Each of the company's dead has a white stone and a lamp.",
		"rite": "Light the lamp", "rite_done": "The lamp is filled and lit. Its small flame steadies, and the company stands until it does.",
		"empty": "No lamps lit yet. Keep it that way."},
	"ryumon": {"name": "The Lantern Grove", "line": "Under a maple at the camp's edge, a stone lantern for each of the company's dead and a tablet with their name.",
		"rite": "Set the tablet", "rite_done": "The tablet is set in the earth and incense lit before it. The smoke goes straight up; the night is still.",
		"empty": "No lanterns yet. Keep it that way."},
}

## The words said over them at a gathering: what you say, and what the epitaph becomes.
const WORDS := {
	"honour": {"text": "They held when it mattered.", "tag": "for what they did"},
	"grief": {"text": "We'll keep their place by the fire.", "tag": "for who they were"},
	"vengeance": {"text": "{lord} will answer for this.", "tag": "a vow"},
}

## Epitaphs, by the words said and the captain's temperament. {first} {company} {place}
## {lord} {battles} {kills} are filled in.
const EPITAPHS := {
	"honour": {
		Captains.VENGEFUL: ["First into the fight, last to leave it.", "{kills} foes, and not one of them easy.", "Never once gave ground they could keep."],
		Captains.STEADFAST: ["Held the line at {place}.", "{battles} battles, and the line held in every one.", "Where {first} stood, the company stood."],
		Captains.FRAGILE: ["Afraid, and went anyway.", "Stood at {place} when running was easier.", "Braver than they ever believed."],
		"": ["Led {company} with honour.", "{battles} battles in the company's service.", "Fell at {place}, facing the enemy."],
	},
	"grief": {
		Captains.VENGEFUL: ["Too fierce for this world, too dear for the next.", "The fire's quieter without them.", "Still owed a rematch."],
		Captains.STEADFAST: ["Kept the watch so we could sleep.", "Their cup is still poured.", "The steadiest hand we had."],
		Captains.FRAGILE: ["Gentle in a hard trade.", "We should have kept them closer.", "Loved by {company}, every one."],
		"": ["Their place by the fire is kept.", "Missed at every fire since.", "Remembered."],
	},
	"vengeance": {
		"": ["{lord} owes for this.", "Not forgotten. Not forgiven.", "Until {lord} answers."],
	},
}

## The epitaph a record's words make, the same each time for the same captain.
static func epitaph(m: Dictionary, words: String, place_name: String, lord: String) -> String:
	var by: Dictionary = EPITAPHS.get(words, EPITAPHS["honour"])
	var lines: Array = by.get(String(m.get("temperament", "")), by.get("", by.values()[0]))
	var pick := absi(String(m.get("name", "")).hash()) % lines.size()
	var first := String(m.get("first", m.get("name", "They")))
	return String(lines[pick]).replace("{first}", first).replace("{company}", String(m.get("company", "the company"))) \
		.replace("{place}", place_name).replace("{lord}", lord if lord != "" else "Their killer") \
		.replace("{battles}", str(int(m.get("battles", 0)))).replace("{kills}", str(int(m.get("kills", 0))))


static func place(culture: String) -> Dictionary:
	return PLACES.get(culture, PLACES["vardish"])
