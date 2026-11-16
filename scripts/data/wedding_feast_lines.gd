## What is said at the feast after "I do": how the night sets in, the captains' toasts
## (put together from each captain's own record, so no two companies hear the same
## speeches), the first dance, her people's custom, going round the tables, and slipping
## away. Words only; the rules are in GameState and the social sim. {name} is the one you
## married, {first} the captain speaking, {other} a second captain, {fallen} a friend who
## fell, {second} who stood with you.
extends RefCounted

const Cultures = preload("res://scripts/data/cultures.gd")
const Captains = preload("res://scripts/data/captains.gd")
const Lords = preload("res://scripts/data/lords.gd")

## How the feast sets in, by her people.
const OPEN := {
	Cultures.VARDISH: "The benches are dragged back, the second fire is lit, and somebody has found a fiddle. The hall settles in for a long night.",
	Cultures.KHARZANI: "Lanterns go up along the courtyard walls, the sweets come out on brass trays, and the drummers start before anyone asks them to.",
	Cultures.RYUMON: "The terrace is hung with paper lanterns. At the far table someone has started a verse-game, and is losing it loudly.",
}
## The night moving on, under the plate: one more for each thing done.
const NIGHT := ["the night is young", "the second cask is open", "the musicians take requests",
	"someone's under a table", "the lanterns burn low"]
const PROMPT := "The night is yours"

## What the night holds, as replies.
const THINGS := {
	"toasts": {"text": "Call for the toasts.", "tag": "your captains have been rehearsing", "icon": "cup"},
	"dance": {"text": "Ask {name} to dance.", "tag": "the first dance", "icon": "dance"},
	"tables": {"text": "Go round the tables.", "icon": "men"},
	"slip": {"text": "Slip away with {name}.", "tag": "ends the night"},
}
## The toasts with no captain to give them.
const TOASTS_NO_CAPTAINS := "a few words, and your cup"
## Her people's custom, as its reply.
const CUSTOM_THING := {
	Cultures.VARDISH: {"text": "Pay the door toll.", "tag": "the door toll"},
	Cultures.KHARZANI: {"text": "Cap the elder's verse.", "tag": "the couplet"},
	Cultures.RYUMON: {"text": "Write a wish on a lantern.", "tag": "lantern wishes"},
}
## A thing done stays in the list, ticked, with what it was.
const DONE := {"toasts": "the toasts are made", "dance": "you danced", "custom": "done", "tables": "you went round"}
const CUSTOM_DONE := {Cultures.VARDISH: "the toll is paid", Cultures.KHARZANI: "the verse is capped", Cultures.RYUMON: "the lanterns are up"}
## The night's icons, for the closing card.
const ICONS := {"toasts": "cup", "dance": "dance", "custom": "lantern", "tables": "men"}

# ---------------------------------------------------------------- the toasts

const CALL := "Who'll speak?"
const CALL_NEXT := "Who'll speak next?"
const ENOUGH := "That's enough speeches."

## How a captain starts: as your second, or by temperament (two each, by captain id).
const SECOND_OPEN := [
	"The captain asked me to stand with them today. I said yes before they'd finished asking.",
	"I was asked to stand up there, so I'm standing up here as well. Briefly.",
]
const OPENERS := {
	Captains.VENGEFUL: ["Anyone who wrongs these two answers to me. I mean that kindly.",
		"I've a short temper and a short speech. Here's the speech."],
	Captains.STEADFAST: ["I'm not one for speeches, so I'll say what I know.",
		"I'll say this plainly, because it's the only way I know how."],
	Captains.FRAGILE: ["I wrote this down, and now I can't read my own hand. All right. All right.",
		"Don't all look at me like that. I'll get through it."],
	"": ["I'll keep it short.", "Right. Cups up. I'll be quick."],
}
## What they know: the first that applies.
const WOUNDED := "I've one good arm tonight and it's holding a cup, so nobody start anything."
const SPECIALIZATION := {
	Captains.SCOUT: "I rode ahead this morning to look the place over. No ambush. Only cake.",
	Captains.QUARTERMASTER: "I counted the barrels this morning. There are enough. I counted again, in case.",
	Captains.DRILLMASTER: "I've drilled this company to stand in a line and not flinch. Today I watched the captain do it.",
	Captains.CHAMPION: "I've stood in front of the captain in every fight we've had. Tonight I'm glad to stand behind.",
}
const QUIRK := {
	Captains.LUCKY: "They call me lucky. Tonight I'd say the captain's luckier.",
	Captains.MENTOR: "I've taught half this company everything it knows. Nobody taught the captain this. Must come natural.",
	Captains.BOLD: "I've charged worse odds than a wedding. Not many.",
}
const BATTLES_MANY := "I've stood with the captain through %d battles, and this is the only day I'd do again tomorrow."
const BATTLES_SOME := "I've had %d battles with this company, and tonight beats every one of them."
const BATTLES_FEW := "I've not been with the company long, but I know a good thing when it's standing in front of me."
## How they raise it, the way it's done among their own people.
const CLOSERS := {
	Cultures.VARDISH: "To {name} and the captain. Drink!",
	Cultures.KHARZANI: "Bread and salt to your house, and a long road together. To {name}!",
	Cultures.RYUMON: "May the register never run short of pages. To {name}, and the captain.",
}
## A hero companion speaks in their own voice (by hero id).
const HERO_TOASTS := {
	"katherine": "I was cast out once for holding a gate against orders. Tonight I'd hold this door against the whole world for these two, and nobody would need to order it. To {name} and the captain!",
	"tariq": "In the sands we say a marriage is two riders sharing one waterskin. So drink slowly, both of you, and ride far. To {name}!",
	"mori": "My lord left no heir, and I have served no house since. Tonight I raise my cup to one. To {name}, and the captain.",
}
## A bonded pair toasts together, a line each in turn (the first captain first). By bond
## rank: "A", or any other.
const PAIR_TOASTS := {
	"A": ["We tossed a coin for who'd speak.", "I lost.", "So we're both doing it.",
		"To {name}, who gets the captain.", "And to the captain, who gets much the better of it."],
	"": ["We weren't going to say anything.", "Then {first} said we should.", "I said nothing of the sort.",
		"You said it twice.", "To {name} and the captain!"],
}
const NEWEST := "I've only just joined the company, and I'm already at a wedding. Is it always like this?"
const MOURNER := "{fallen} had a toast ready for tonight. Never told me what it was. So: to {fallen}'s toast, whatever it was. And to you both."

## After a toast: drink, heckle, or (after a mourner's) pour one for the fallen.
const DRINK := "Drink to that."
const DRANK := ["Cups go up all down the table.", "The table drinks, and bangs its cups down.", "Everyone drinks. Someone drinks twice."]
const HECKLE := "Heckle {first}."
const HECKLES := ["Louder, {first}! The back can't hear you.", "Is that the whole speech, {first}?", "Sit down before you cry, {first}."]
const COMEBACKS := {
	Captains.VENGEFUL: "Say that again, captain. Outside. Tomorrow. After the cake.",
	Captains.STEADFAST: "Noted, captain. We'll take it up at drill.",
	Captains.FRAGILE: "I knew I should have written it smaller.",
	"": "Everyone's a critic.",
}
const HER_LAUGH := {
	"edda": "Don't encourage them.",
	"farid": "In Qasr Hamra heckling is a sign of affection. Barely.",
	"kaede": "I'm writing that down.",
}
const POUR := "Pour one for {fallen}."
const POURED := "{first} fills a cup and sets it at the end of the table. Nobody touches it all night."

# ---------------------------------------------------------------- the first dance

const DANCE_ASK := "Dance with me."
const DANCE_YES := {
	"edda": "I warn you, I learned from my cousin, and he learned from a goat.",
	"farid": "There are eleven forms for this dance. I propose we ignore all of them.",
	"kaede": "I've read about this. Extensively. Reading turns out not to be the same thing.",
}
## Three steps, each a pair of choices.
const DANCE_STEPS := [
	[{"id": "lead", "text": "Lead."}, {"id": "follow", "text": "Let her lead."}],
	[{"id": "turn", "text": "Turn her under your arm."}, {"id": "simple", "text": "Keep it simple."}],
	[{"id": "company", "text": "Wave the company in."}, {"id": "ours", "text": "Keep this one for the two of you."}],
]
## What she says to each.
const DANCE_ANSWERS := {
	"edda": {
		"lead": "You lead the way you ride: straight at it. I like that. Mind the bench.",
		"follow": "Oh, good. I've been wanting to steer you for months.",
		"turn": "Show-off. Again.",
		"simple": "Simple's good. Simple is how I'd like the rest of it, mostly.",
		"company": "There they go. Your sergeant dances like he's fording a river.",
		"ours": "Just us, then. They can wait one song.",
	},
	"farid": {
		"lead": "Confidently wrong. It's the best way to lead anything; ask any envoy.",
		"follow": "You trust me with the steps. That's a larger concession than you know.",
		"turn": "Ah. You've been practising. Don't deny it; your sergeant told me.",
		"simple": "Simple. Yes. I've had enough of the elaborate for one lifetime.",
		"company": "Look at them. Not one of them knows the form. It's perfect.",
		"ours": "One song that belongs to no treaty. Thank you.",
	},
	"kaede": {
		"lead": "Left. No, your other left. No, that's fine, we'll make it the right way.",
		"follow": "I'll count. Out loud, I'm afraid. It's the only way I can.",
		"turn": "I didn't know you could do that. I'm amending several records.",
		"simple": "Good. I'd like to remember this one step by step.",
		"company": "Now it's a mess. A good one. Like the useless map.",
		"ours": "Just this one. I'll remember all of it.",
	},
}

# ---------------------------------------------------------------- her people's custom

## {intro: [narration], prompt, choices: [{id, text, tag, bare, line, needs}]}. A choice that
## `needs` "second" is offered only with someone beside you; its "alone" variant otherwise.
const CUSTOMS := {
	Cultures.VARDISH: {
		"intro": ["Her household has barred the hall door with a bench, as they do in the north: nobody takes the bride through it until the toll is paid.",
			"The cook names it, arms folded."],
		"prompt": "Pay the toll",
		"choices": [
			{"id": "coin", "text": "Pay in coin.", "tag": "a silver penny", "bare": true,
				"line": "You put a silver penny on the bench. The cook bites it, pockets it, and lifts the bench with one hand. Cheers."},
			{"id": "song", "text": "Pay with a song.", "tag": "badly", "bare": true,
				"line": "You sing. It is not good. The household joins in out of pity, then out of joy, and the bench is lifted in the second verse."},
			{"id": "wrestle", "text": "Send {second} to arm-wrestle the cook.", "tag": "for the company's honour", "bare": true, "needs": "second",
				"line": "{second} rolls up a sleeve. It takes a long minute. Nobody will say who won, but the bench is moved.",
				"alone": {"text": "Arm-wrestle the cook yourself.", "tag": "for your own honour",
					"line": "You roll up a sleeve. The cook lets you win, slowly enough for everyone to see it, and lifts the bench."}},
		],
	},
	Cultures.KHARZANI: {
		"intro": ["Nobody serves the sweets until the groom caps an elder's verse. The eldest aunt stands, and the courtyard goes quiet.",
			"\"The rose is shy before the dawn, and opens only once...\""],
		"prompt": "Cap the verse",
		"choices": [
			{"id": "good", "text": "...and once is all the garden needs, if the gardener is true.", "tag": "a good line",
				"line": "A murmur goes round the courtyard. The aunt sits, satisfied, and the trays come out."},
			{"id": "terrible", "text": "...unlike my horse, who opens every gate he sees.", "tag": "a terrible line",
				"line": "A silence. Then the aunt laughs so hard she has to be helped to her seat. The trays come out."},
			{"id": "whisper", "text": "Let {second} whisper you the line.", "tag": "{second} has one ready", "bare": true, "needs": "second",
				"line": "{second} leans in. You repeat it word for word. It is very good, and the aunt looks at {second} with deep suspicion. The trays come out.",
				"alone": {"text": "Let {name} whisper you the line.", "tag": "she has one ready",
					"line": "{name} murmurs it behind her sleeve. The aunt pretends not to have seen. The trays come out."}},
		],
	},
	Cultures.RYUMON: {
		"intro": ["Paper lanterns and brushes come round. Each of you writes a wish, lights it, and lets it go over the terrace rail.",
			"{name} writes hers quickly, shielding it with her sleeve."],
		"prompt": "What do you wish for?",
		"choices": [
			{"id": "her", "text": "For her.", "tag": "you write her name", "bare": true,
				"line": "You write her name and nothing else. The two lanterns go up together, turning slowly, until they're two more stars."},
			{"id": "company", "text": "For the company.", "tag": "every one of them home", "bare": true,
				"line": "You write: every one of them home. The lanterns rise over the terrace, and your captains watch them all the way up."},
			{"id": "peace", "text": "For an end to the war.", "tag": "the biggest wish", "bare": true,
				"line": "You write it small, because it's the biggest. The lanterns rise together over the water."},
		],
		"after": "{name} won't say what hers was. She looks very pleased with it.",
	},
}

# ---------------------------------------------------------------- round the tables

const TABLES_OPEN := "You go round the tables with a cup that somebody keeps refilling."
const TABLES_PROMPT := "Who do you stop with?"
const TABLES_BACK := "Back to the feast."
## A lord, by bearing: warm when he thinks well of you (Regard of LORD_WARM or more).
const LORD_WARM := 30
const LORD_LINES := {
	Lords.CAUTIOUS: {"warm": "A good match, and a careful one. I approve of both.",
		"cool": "Congratulations. I'll be watching how the pact holds, mind."},
	Lords.DARING: {"warm": "Ha! I lost a wager on you two. Best money I ever lost.",
		"cool": "A fine wedding. Too few horses in it, but fine."},
	Lords.HONORABLE: {"warm": "You kept faith with her house. I'll remember it when you need a friend.",
		"cool": "My congratulations, captain. Keep your oaths and we'll get along."},
	Lords.CRUEL: {"warm": "You've married well. Don't waste it.",
		"cool": "Enjoy tonight. Nights like this don't last."},
}
## A captain who didn't toast, by temperament.
const CAPTAIN_LINES := {
	Captains.VENGEFUL: "Best night this company's had. Nobody ruin it. I'm watching.",
	Captains.STEADFAST: "Good day, captain. Good day. Now eat something; you're swaying.",
	Captains.FRAGILE: "I cried at the vows. Don't tell anyone. Everyone saw.",
	"": "Captain! Congratulations. Have you tried the pies? Try the pies.",
}
## The gifts, as words: the host's, by her people, and the company's.
const HOST_GIFTS := {
	Cultures.VARDISH: "a pair of good grey horses",
	Cultures.KHARZANI: "a carpet that took two years to weave",
	Cultures.RYUMON: "a sword rack of black lacquer",
}
const COMPANY_GIFT := "The company passed a helmet round and bought you a copper kettle, slightly dented."
const RECEIPT := "%s kept the receipt."

# ---------------------------------------------------------------- slipping away

const SLIP_YOU := "Come on. While they're busy."
const SLIP_OUT := {
	"room": "You go up the back stair to her room. Below you the feast doesn't notice for a full quarter of an hour.",
	"place": "You slip out past the last lanterns. Behind you the feast doesn't notice for a full quarter of an hour.",
}
## What she recalls of the night: the first of these that you did (see recall).
const RECALL_ORDER := ["breath", "heckle", "dance", "custom", "vow"]
const RECALL := {
	"edda": {
		"breath": "You took a breath before you said it. A long one. I counted. I'll be telling that one for years.",
		"heckle": "You heckled your own captain at your own wedding. My cousin says it's the most Vardish thing he's ever seen.",
		"dance": "You trod on my foot exactly once. I've decided it was on purpose, so I can forgive it.",
		"custom": "The cook says you paid the toll fairly. From the cook, that's practically a blessing.",
		"vow": "You said your vow like you meant every word. I'm holding you to all of them.",
	},
	"farid": {
		"breath": "You took a breath. For one moment I thought I'd have to negotiate.",
		"heckle": "You heckled your own captain. My aunts approved. Nobody has ever made my aunts approve of anything.",
		"dance": "We ignored all eleven forms. I've never enjoyed a dance more.",
		"custom": "My aunt has asked who taught you that line. I said I did. Let her wonder.",
		"vow": "You said your vow plainly, and meant all of it. I heard every word.",
	},
	"kaede": {
		"breath": "You paused before you said it. One breath. I noticed. I'll remember it exactly.",
		"heckle": "You heckled your own captain. I wrote it down. It's going in the register's margin.",
		"dance": "You turned the wrong way twice. I've decided that's the right way now.",
		"custom": "I saw your lantern go up. I won't ask what you wrote. I'll ask in ten years.",
		"vow": "I'll check your vow against the record. I expect it to be right.",
	},
}
## The last choice of the night, and what she says to it.
const LAST := [
	{"id": "stay", "text": "Stay up until the lanterns go out."},
	{"id": "sleep", "text": "Sleep. The war will keep."},
]
const LAST_ANSWER := {
	"edda": {"stay": "All of them? There are forty. I counted those too.",
		"sleep": "Sleep. Yes. Boots off. I'll straighten them in the morning."},
	"farid": {"stay": "Until the last one. I'll tell you unimportant things until then.",
		"sleep": "The war will keep. For one night, I'm sure of it."},
	"kaede": {"stay": "I'll count them as they go. Don't let me lose my place.",
		"sleep": "Sleep. I'll wake first; I always do. I'll let you sleep."},
}

## At the fire, a few nights on.
const CAMP_TITLE := "Still telling it"
const CAMP_RETELL := "%s is still telling the wedding toast at the fire. It gets longer every night."
const CAMP_DAYS := 7


static func fill(text: String, ctx: Dictionary) -> String:
	var out := text
	for k in ctx:
		out = out.replace("{%s}" % k, String(ctx[k]))
	return out


## A captain's toast in their own words: how they start (as your second, or by
## temperament), what they know (wounded tonight, their role, their quirk, their battles),
## and how they raise it (the way their own people do).
static func captain_toast(c: Dictionary, as_second: bool = false) -> String:
	var id := int(c.get("id", 0))
	var opens: Array = SECOND_OPEN if as_second else OPENERS.get(String(c.get("temperament", "")), OPENERS[""])
	var close := String(CLOSERS.get(String(c.get("culture", "")), CLOSERS[Cultures.VARDISH]))
	return "%s %s %s" % [String(opens[posmod(id, opens.size())]), know(c), close]


## What a captain knows to say: the first that applies.
static func know(c: Dictionary) -> String:
	if int(c.get("wounded", 0)) > 0:
		return WOUNDED
	var spec := String(c.get("specialization", ""))
	if SPECIALIZATION.has(spec):
		return String(SPECIALIZATION[spec])
	var quirk := String(c.get("quirk", ""))
	if QUIRK.has(quirk):
		return String(QUIRK[quirk])
	var n := int(c.get("battles", 0))
	if n >= 10:
		return BATTLES_MANY % n
	if n >= 3:
		return BATTLES_SOME % n
	return BATTLES_FEW


## A toast (one of GameState.wedding_toasters) as the lines said: [{who ("a", or "b" for
## a pair's second captain), text}], before {name} is filled in.
static func toast_lines(t: Dictionary) -> Array:
	var c: Dictionary = t["captain"]
	var first := String(c.get("first", c.get("name", "")))
	var own := String(HERO_TOASTS.get(String(c.get("hero_id", "")), "")) if bool(c.get("is_hero", false)) else ""
	match String(t.get("kind", "")):
		"second":
			return [{"who": "a", "text": own if own != "" else captain_toast(c, true)}]
		"hero":
			return [{"who": "a", "text": own if own != "" else captain_toast(c)}]
		"pair":
			var other: Dictionary = t.get("other", {})
			var lines: Array = PAIR_TOASTS.get(String(t.get("rank", "")), PAIR_TOASTS[""])
			var out := []
			for i in lines.size():
				out.append({"who": "a" if i % 2 == 0 else "b",
					"text": fill(String(lines[i]), {"first": first, "other": String(other.get("first", other.get("name", "")))})})
			return out
		"newest":
			return [{"who": "a", "text": "%s %s" % [NEWEST, String(CLOSERS.get(String(c.get("culture", "")), CLOSERS[Cultures.VARDISH]))]}]
		"mourner":
			return [{"who": "a", "text": fill(MOURNER, {"fallen": String(t.get("fallen", ""))})}]
	return [{"who": "a", "text": captain_toast(c)}]


## A lord's word at the tables, by bearing and how well he thinks of you.
static func lord_line(bearing: String, regard: int) -> String:
	var lines: Dictionary = LORD_LINES.get(bearing, LORD_LINES[Lords.HONORABLE])
	return String(lines["warm" if regard >= LORD_WARM else "cool"])


static func captain_line(temperament: String) -> String:
	return String(CAPTAIN_LINES.get(temperament, CAPTAIN_LINES[""]))


static func custom(culture: String) -> Dictionary:
	return CUSTOMS.get(culture, CUSTOMS[Cultures.VARDISH])


## The custom's choice with `id` as it was offered: with someone beside you (`second` is
## true) or alone. {} if there's no such choice.
static func custom_choice(culture: String, id: String, second: bool) -> Dictionary:
	for ch in custom(culture)["choices"]:
		if String(ch["id"]) != id:
			continue
		var out: Dictionary = (ch as Dictionary).duplicate()
		if String(ch.get("needs", "")) == "second" and not second:
			out.merge(ch.get("alone", {}), true)
		return out
	return {}


## What she recalls of the night: the first of RECALL_ORDER that `did` holds (true).
static func recall(cand: String, did: Dictionary) -> String:
	var lines: Dictionary = RECALL.get(cand, RECALL["edda"])
	for k in RECALL_ORDER:
		if bool(did.get(k, false)):
			return String(lines[k])
	return String(lines["vow"])
