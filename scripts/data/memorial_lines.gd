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

## Each people's place for its dead and its rite: what the rise is called and how it looks,
## the rite and how it is done, the light kept for them (a candle, a lamp, incense), and
## what it says when there is no one there yet. Narration is plain, as at the wedding: what
## can be seen and heard.
const PLACES := {
	"vardish": {"name": "The Cairn Field", "line": "A rise past the horse lines where the company leaves each of its dead a stone. Someone always keeps a candle going.",
		"rite": "Raise the cairn",
		"rite_done": "Each of the company brings a stone from the field and sets it on the pile, the oldest first and the newest last. The last stone goes on top. Nobody speaks for a while, and then somebody does.",
		"light": "Light a candle", "lit": "A candle burns", "laid": "Laid to rest. A candle is lit at the cairn.",
		"empty": "No stones yet. Keep it that way."},
	"kharzani": {"name": "The Garden of Lamps", "line": "A walled patch of ground beside the camp with a cypress at its heart. Each of the company's dead has a white stone and a lamp.",
		"rite": "Light the lamp",
		"rite_done": "Water is poured on the stone, and the lamp is filled and lit. The company stands until the flame stops guttering and burns straight, which is how it is known they have gone on.",
		"light": "Fill the lamp", "lit": "The lamp burns", "laid": "Laid to rest. The lamp is lit in the garden.",
		"empty": "No lamps lit yet. Keep it that way."},
	"ryumon": {"name": "The Lantern Grove", "line": "Under a maple at the camp's edge, a stone lantern for each of the company's dead and a tablet with their name.",
		"rite": "Set the tablet",
		"rite_done": "The tablet is set in the earth and incense lit before it. The company bows together. The smoke goes straight up; the night is still.",
		"light": "Light incense", "lit": "Incense burns", "laid": "Laid to rest. Incense is lit before the tablet.",
		"empty": "No lanterns yet. Keep it that way."},
}

## The words said over them at a gathering: what you say, and what the epitaph becomes.
## {place} is where they fell, {friend} the one who loved them most (the "alone" line when
## there is no one), {lord} who killed them.
const WORDS := {
	"honour": {"text": "They held at {place}. None of us will forget it.", "tag": "for what they did"},
	"grief": {"text": "{friend} will keep their place by the fire, and so will we.", "alone": "We'll keep their place by the fire.", "tag": "for who they were"},
	"vengeance": {"text": "{lord} will answer for this.", "tag": "a vow"},
}


## The words for `key` over a captain who fell at `place`, loved most by `friend`, killed
## by `lord`.
static func words(key: String, place_name: String, friend: String, lord: String) -> String:
	var w: Dictionary = WORDS.get(key, WORDS["honour"])
	var text := String(w["text"])
	if friend == "" and w.has("alone"):
		text = String(w["alone"])
	return text.replace("{place}", place_name if place_name != "" else "the last fight") \
		.replace("{friend}", friend).replace("{lord}", lord if lord != "" else "Their killer")


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
