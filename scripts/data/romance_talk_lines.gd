## Short lines for the romance talk: how each person greets you, by how things stand; what
## they say when you bring up a visit you shared ("Remember when…"); and what they say
## about a decision you made together. Incidental lines: they never change trust.
extends RefCounted

const GREETINGS := {
	"edda": {
		"unknown": "You must be the captain. I'm Edda. I keep the tallies here, which mostly means I know who owes whom a horse.",
		"acquainted": "Captain. Sit, if you like. The ledgers will survive a quarter of an hour without me. Probably.",
		"courting": "You came back. I counted the days, which is a habit, not a confession. Mostly a habit.",
		"committed": "There you are. I kept a chair. Don't look at it like that; it's just a chair.",
		"engaged": "The household has started asking about flowers. I've told them to ask you. You're welcome.",
		"married": "Home, then. Tell me something that isn't about the war first.",
		"friendship": "My friend. The hall is quieter when you're on the road. Not better, quieter.",
		"ended": "Captain. It's good to see you well. Truly.",
	},
	"farid": {
		"unknown": "Farah, envoy of the house. You'll forgive me for being polite; it's the only language I'm paid in.",
		"acquainted": "Captain. No petitions today, I hope. I have three already and they all disagree.",
		"courting": "I rehearsed something clever to say when you arrived. It's gone now. Hello.",
		"committed": "You look tired. Sit. I'll talk, for once, and you can just listen.",
		"engaged": "Everyone wants to know which courtesy we'll use at the ceremony. I said 'ours'.",
		"married": "There you are. I saved you the good cup. The envoy's cup. Don't tell anyone.",
		"friendship": "My friend. Tell me news that matters to no one. I've had enough of the other kind.",
		"ended": "Captain. Fair roads to you, still. I meant that before and I mean it now.",
	},
	"kaede": {
		"unknown": "Kaede. Archivist. If you're here to correct the records, take a number; it will be wrong.",
		"acquainted": "Captain. I was just disagreeing with a dead scribe. You may join in.",
		"courting": "I marked your last visit in the margin. Only the date. The rest I kept.",
		"committed": "You're early. Or I've lost track of time again. Both, probably.",
		"engaged": "I've started a page for us. Blank, for now. I'm told that's traditional.",
		"married": "Welcome home. I left the lamp lit. Not as a symbol. It's just dark in here.",
		"friendship": "My friend. I found a terrible map today. I saved it for you.",
		"ended": "Captain. I hope the roads have been kinder than the records say.",
	},
}

## What they say when you bring up a visit you shared.
const VISITS := {
	"edda_spare_spoon": "I still set the spare spoon. Last week someone used it. A clerk's cousin, if you can believe it. Someone always brings a cousin.",
	"edda_wrong_verse": "I sang the flour-bin ending to a child in the kitchen yesterday. She made me sing it twice. The miller remains floury.",
	"edda_boots_by_door": "I lined up the boots by the door again this morning. Then I noticed I was doing it and stopped. Then I finished, because it looked untidy.",
	"edda_morning_unclaimed": "I skipped a stone at the ford. Four bounces. My cousin would say three. My cousin is wrong.",
	"edda_ledger_blot": "That page is still in the ledger. I showed it to a new clerk who was crying over a mistake. It helped, I think.",
	"edda_place_no_task": "I sat for an hour last evening with nothing to do. It was dreadful. I'd like to do it again with you.",
	"farid_supper_request": "I asked for supper at the inn in eleven words yesterday. Eleven. I'm told that's a record for me.",
	"farid_two_street_names": "I walked down Crooked Lantern this morning. The new sign says South Market. The lantern is still crooked.",
	"farid_unsealed_letter": "My cousin wrote back. Two lines. I've read them more often than any treaty.",
	"farid_wrong_courtesy": "I washed dishes at a feast last month, on purpose. The host was appalled. The cook and I are friends now.",
	"farid_own_answer": "The notebook has a new page. Things I think, not things I'm asked. It's short. It's mine.",
	"farid_no_reply_required": "I have more unimportant news. The baker's cat has learned to open the gate. Nobody asked; I'm telling you anyway.",
	"kaede_useless_map": "I added a bench to the useless map. Strategically worthless. Excellent for watching ducks.",
	"kaede_bad_mystery": "I solved the bad mystery correctly by accident. I've decided not to tell anyone. Our answer was better.",
	"kaede_margin_name": "The label still has its private name. I look at it sometimes. I haven't told the scribes.",
	"kaede_missing_street": "The missing street moved again. I've stopped correcting it. I just walk it, now.",
	"kaede_kept_page": "That page is still in the record. Someone asked who wrote it. I said I did. It felt strange. Good strange.",
	"kaede_room_on_map": "Your place on the map has a little ink smudge now. I didn't fix it. It looks lived in.",
}

## What they say about a chapter decision you made together, by chapter.
const CHAPTERS := {
	1: "You told me what you meant to be to me, that first day. I remember it more exactly than you'd like.",
	2: "You brought me something of my own. People don't, usually. I still have it.",
	3: "When the hard season came you didn't make speeches. You helped. I noticed.",
	4: "The council. I think about that day more than I say.",
	5: "We chose, in the end. I'd choose the same.",
}

## Other memories: a letter, a ceremony, a move.
const KINDS := {
	"letter": "Your letter is still on my desk. I've answered it in my head four times.",
	"ceremony": "I still remember the music. Mostly that it was too loud and that I didn't mind.",
	"move": "New walls, new windows. Some of the old things came with me. Most of the important ones.",
	"note": "I remember. It's strange what stays with you.",
}


## What you say to open the chapter, by candidate and chapter: a line, not a title.
const STORY_OPENERS := {
	"edda": {
		1: "They said the steward knows the border better than the lords do.",
		2: "What are you reading?",
		3: "I came about Thornwall.",
		4: "The hall's loud today. What's happened?",
		5: "Walk with me. There's something I want to ask.",
	},
	"farid": {
		1: "I was told the envoy sees everyone. I hoped that included captains.",
		2: "You said to come back when you had no speech prepared.",
		3: "The wagons are still at the crossing. Tell me what you need.",
		4: "Your relatives have been talking. I heard it from the gate.",
		5: "No letters today?",
	},
	"kaede": {
		1: "I'm told the archive takes a number.",
		2: "Show me the map without roads.",
		3: "The ford. Who's holding it?",
		4: "They've put the brush in front of you, haven't they.",
		5: "Is there room in the margin?",
	},
}

## What you say to spend time together: the first open visit, then a second.
const VISIT_OPENERS := ["Nothing that needs doing today. I just came.", "What were you doing before I came in?"]
const VISIT_RESUME := "Where were we?"
const LETTER_OPENER := "Your letter found me on the road."


## How they open when something has happened since you last came, in order of what
## matters most. {name} is a captain, {place} a settlement, {days} a count.
const OPENING_ORDER := ["fallen", "wounded", "company_hurt", "besieged", "burned", "war", "victory", "away", "night"]
const OPENINGS := {
	"edda": {
		"fallen": "You came back with fewer than you left with. Word of {name} reached us before you did. Sit. The ledgers will keep, and so will everyone else who wants a piece of you.",
		"wounded": "{name} is hurt, they tell me. Sit down before you fall down. No, the chair. I'll move the ledgers.",
		"company_hurt": "Your company looks like it walked here on its knees. There's bread, and there's a bench, and I'll hear the rest after.",
		"besieged": "You'll have seen the camp under the walls. We're fine. I'm saying that so it becomes true.",
		"burned": "Mind the ash by the door. We're rebuilding. Everyone here has an opinion on the roof, and none of them are carpenters.",
		"war": "My cousin asked which side you're on today. I told him mine. He didn't find it funny, which is how I knew it was the right answer.",
		"victory": "The whole hall is telling your battle at {place}. They've given you a horse you don't own and a speech you never made.",
		"away": "{days} days. I didn't count. The ledger did.",
		"night": "You keep late hours, captain. So does the ledger. Sit; I'll light the other lamp.",
	},
	"farid": {
		"fallen": "I heard about {name}. I had a sentence prepared for you, and it was elegant, and I have thrown it away. Come in. Sit.",
		"wounded": "They say {name} took a wound. Sit, and don't be polite about it; I have enough people being polite at me.",
		"company_hurt": "Your company arrived looking like a treaty after a long council. Water first. Questions after.",
		"besieged": "There is an army under our walls, and the house has decided to be dignified about it. I have decided to be glad you're here. One of us is being sensible.",
		"burned": "Mind the smell of smoke; it gets into the letters. We're rebuilding. The house insists on rebuilding with a view.",
		"war": "Our realms are at war, which means every greeting I give you is technically a negotiation. Hello, captain. That one was free.",
		"victory": "The market has three versions of your battle at {place}, and in all of them you are taller. Sit. I'd like the one where you're your own height.",
		"away": "{days} days. I'm not reproaching you; I'm an envoy, we count everything. Sit.",
		"night": "The courtyard is quiet at this hour, and so is the house, which is rarer. Sit. Nobody will need a letter until morning.",
	},
	"kaede": {
		"fallen": "I heard about {name}. I have written the name in the margin, where I keep the things the record is too small for. Sit down.",
		"wounded": "{name} is wounded, I'm told. The archive has a chair that has never once been sat in. Try it.",
		"company_hurt": "Your company came in like a damaged manuscript. Recoverable, but slowly. There is tea. It is bad. Sit.",
		"besieged": "There is an army at the gate, and the council is debating what to call it. I have labelled it 'uncertain'. Sit; it can't hear us in here.",
		"burned": "Mind the scorched shelf. We lost a century of tax records and nothing of value. I am told that is a scandalous thing to say.",
		"war": "Our realms are at war, so officially you are an enemy. I have filed you under 'exceptions'. It is a growing file.",
		"victory": "The scribes are already writing your battle at {place}, and they have the ford on the wrong side. I'll correct it. Tell me where you stood.",
		"away": "{days} days. I know because I started a page, and it has stayed blank. Sit down; I'll fill it in.",
		"night": "Late. The lamp is lit; it's not a symbol, it's just dark. Sit. The dead scribes won't mind.",
	},
}


## Their first words this visit. `facts` is what has happened since you last came:
## {fallen: a captain's name or "", wounded: a captain's name or "", company_hurt: bool,
## besieged: bool, burned: bool, war: bool, victory: a place's name or "", away: days,
## night: bool}. The first that holds is what they speak to; otherwise the greeting for
## how things stand.
static func opening(candidate: String, status: String, facts: Dictionary) -> String:
	var lines: Dictionary = OPENINGS.get(candidate, {})
	for key in OPENING_ORDER:
		var v = facts.get(key, false)
		var holds: bool = (v is bool and v) or (v is String and v != "") or ((v is int or v is float) and v > 0)
		if holds and lines.has(key):
			return String(lines[key]).format({"name": str(v), "place": str(v), "days": str(v)})
	return greeting(candidate, status)


static func greeting(candidate: String, status: String) -> String:
	var g: Dictionary = GREETINGS.get(candidate, {})
	return String(g.get(status, g.get("acquainted", "Captain.")))


## Their answer when you bring up `memory` (a memory book entry).
static func callback(memory: Dictionary) -> String:
	var kind := String(memory.get("kind", "note"))
	if kind == "visit" and VISITS.has(String(memory.get("scene_id", ""))):
		return VISITS[String(memory["scene_id"])]
	if kind == "decision":
		var ch := int(memory.get("chapter", 0))
		if CHAPTERS.has(ch):
			return CHAPTERS[ch]
	return String(KINDS.get(kind, KINDS["note"]))


static func story_opener(candidate: String, chapter: int) -> String:
	return String(STORY_OPENERS.get(candidate, {}).get(chapter, "There's something I wanted to ask you."))


## How you take your leave, by how things stand.
static func leaving(status: String) -> String:
	if status in ["courting", "committed", "engaged", "married"]:
		return "I can't stay. I wanted to see you."
	return "Another time."
