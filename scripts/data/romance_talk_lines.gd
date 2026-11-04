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
