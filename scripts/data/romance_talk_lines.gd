## Short lines for the romance talk: how each person greets you, by how things stand; what
## they say when you bring up a visit you shared ("Remember when…"); and what they say
## about a decision you made together. Incidental lines: they never change trust.
extends RefCounted

## Two greetings for each way things stand, taken in turn from one visit to the next.
const GREETINGS := {
	"edda": {
		"unknown": ["You must be the captain. I'm Edda. I keep the tallies here, which mostly means I know who owes whom a horse.",
			"Captain, is it? Edda. Mind the ledgers on the bench; they bite, figuratively."],
		"acquainted": ["Captain. Sit, if you like. The ledgers will survive a quarter of an hour without me. Probably.",
			"Back again, captain. Sit; I'll pretend the accounts can wait, and they'll pretend to believe me."],
		"courting": ["You came back. I counted the days, which is a habit, not a confession. Mostly a habit.",
			"There you are. I'd started a tally of the days. I've stopped it now. Don't ask what it came to."],
		"committed": ["There you are. I kept a chair. Don't look at it like that; it's just a chair.",
			"You're here. Good. I had three things to tell you and I've forgotten two of them already."],
		"engaged": ["The household has started asking about flowers. I've told them to ask you. You're welcome.",
			"My cousin wants to give a speech at the wedding. I've told him it's a short wedding. Very short."],
		"married": ["Home, then. Tell me something that isn't about the war first.",
			"Sit. Boots off. The war can knock if it wants you."],
		"friendship": ["My friend. The hall is quieter when you're on the road. Not better, quieter.",
			"My friend. You look like someone who's been arguing with roads. Sit."],
		"ended": ["Captain. It's good to see you well. Truly.",
			"Captain. The hall's well. I hope you are."],
	},
	"farid": {
		"unknown": ["Farah, envoy of the house. You'll forgive me for being polite; it's the only language I'm paid in.",
			"You'll be the captain. I am Farah; I speak for the house, which is a polite way of saying I apologise for it."],
		"acquainted": ["Captain. No petitions today, I hope. I have three already and they all disagree.",
			"Captain. Sit, please. I have just finished being diplomatic and would like a rest from it."],
		"courting": ["I rehearsed something clever to say when you arrived. It's gone now. Hello.",
			"You came. I had a speech. I'm abandoning it in favour of looking pleased."],
		"committed": ["You look tired. Sit. I'll talk, for once, and you can just listen.",
			"Sit with me. I've had a day of people meaning the opposite of what they say. Say something you mean."],
		"engaged": ["Everyone wants to know which courtesy we'll use at the ceremony. I said 'ours'.",
			"The contract is drafted. It has one clause I haven't shown anyone. It says 'yes'."],
		"married": ["There you are. I saved you the good cup. The envoy's cup. Don't tell anyone.",
			"There you are. Tea first; news after. I've been saving the unimportant kind."],
		"friendship": ["My friend. Tell me news that matters to no one. I've had enough of the other kind.",
			"My friend. Sit. I promise not to ask you for anything for at least a quarter of an hour."],
		"ended": ["Captain. Fair roads to you, still. I meant that before and I mean it now.",
			"Captain. The road is open, if you're wondering. I kept it that way."],
	},
	"kaede": {
		"unknown": ["Kaede. Archivist. If you're here to correct the records, take a number; it will be wrong.",
			"Kaede. I keep the archive. If you've come to look something up, I'm afraid it was misfiled before either of us was born."],
		"acquainted": ["Captain. I was just disagreeing with a dead scribe. You may join in.",
			"Captain. You've arrived in the middle of a footnote. Sit; it's a long one."],
		"courting": ["I marked your last visit in the margin. Only the date. The rest I kept.",
			"You're here. I had written 'perhaps tomorrow' in the margin. I'll correct it."],
		"committed": ["You're early. Or I've lost track of time again. Both, probably.",
			"I saved you the dry stair on the map. It's good in the evening. So, I've found, are you."],
		"engaged": ["I've started a page for us. Blank, for now. I'm told that's traditional.",
			"The page for us has a first line now. I won't tell you what it says. It's very short."],
		"married": ["Welcome home. I left the lamp lit. Not as a symbol. It's just dark in here.",
			"Home. The lamp's lit, the tea is bad, and the record can wait."],
		"friendship": ["My friend. I found a terrible map today. I saved it for you.",
			"My friend. I found another useless map. I've been keeping it for when you came."],
		"ended": ["Captain. I hope the roads have been kinder than the records say.",
			"Captain. The records say you're well. I'm glad they're right, for once."],
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

## The council (chapter 4), remembered as what you actually said there.
const CH4_CHOICES := {
	"edda": {
		"negotiate": "Half of what I wanted and all the valley needed. I still quote you to my cousin when he's being impossible.",
		"support_edda": "You made enemies in that hall for me. I've been making up the difference ever since. I'm nearly even.",
		"break_promise": "The council. I haven't forgotten it, and I won't pretend I have. I'm still glad you're here.",
		"repair_promise": "You paid for what you broke and didn't make a speech about it. That's how I knew you meant it.",
	},
	"farid": {
		"negotiate": "You left me room to finish my sentence in that council. I've been finishing them ever since.",
		"support_edda": "You held my family to my word, in front of them. My aunt still won't say your name. I say it twice as often.",
		"break_promise": "The council where you agreed before you refused. I needed it the other way round. I still do.",
		"repair_promise": "Trust isn't a speech. You paid for the convoy instead. I remember the sum, and that you didn't haggle.",
	},
	"kaede": {
		"negotiate": "A small covenant. It's still standing. Small documents survive; I said so, and you believed me.",
		"support_edda": "You made the record less convenient. It's the kindest thing anyone has done to it.",
		"break_promise": "You asked me to sign their version. The correction is in the record, visible. So is this.",
		"repair_promise": "You took it back before the council, in the same voice you asked it. The correction stays visible. So does what it cost you.",
	},
}

## The matter after the vows (chapter 6), remembered.
const POST := {
	"edda": "The captains eat at one table now. They argue about everything except whose fault the outpost was. I call that peace.",
	"farid": "The blank clause is still blank. Both houses check it every year. It's the most read empty space in Kharzan.",
	"kaede": "Three clans, one covenant, and a ferryman who has started charging for his memory. I paid.",
}

## Your vows by one candle, remembered.
const PRIVATE_VOWS := {
	"edda": "One candle and no cousins. I still think it's the best-run event this household has ever had.",
	"farid": "No speeches, no seals. I have never said anything so short and meant it so completely.",
	"kaede": "There's no record of that night. I check, sometimes, that there isn't. It's the only blank I like.",
}

## The wedding before her house, remembered.
const CEREMONIES := {
	"edda": "The cook wept, my cousin spoke for twice as long as I'd allowed, and I didn't mind any of it. Don't tell him.",
	"farid": "Bread, salt, a contract rewritten nine times, and you, on time. I'd sign it again.",
	"kaede": "I've written that day down three times. Each version is longer. None of them is wrong.",
}

## Your dances, first, second, third (and round again).
const DANCES := {
	"edda": ["You stepped on my foot exactly once and apologised for it for the rest of the reel. I've forgiven the foot.",
		"The second time you'd learned the turn. I noticed. The whole household noticed.",
		"I don't remember the music. I remember the room going quiet around us, which it never does."],
	"farid": ["You found me under the lanterns while I was pretending not to look for you. I still pretend. You still find me.",
		"I led, that time. You let me. It's the best negotiation I've ever won.",
		"The musicians played the slow one twice. I may have paid them. I won't say."],
	"kaede": ["The book was wrong about the third step. We were wrong about it together, which is better.",
		"You bowed correctly, that time. I almost didn't recognise you.",
		"I've stopped writing the dances down. Some things go better unrecorded."],
}

## When you've parted and come asking for time together: why not, in her words.
const PARTED := {
	"edda": "She'd rather not: \"We said what we had to, captain. Let's leave the chair where it is.\"",
	"farid": "She'd rather not: \"We parted well. Let's not make it a negotiation.\"",
	"kaede": "She'd rather not: \"The record of us is complete. I'd like to leave it that way.\"",
}

## Married or sworn: an evening together, with nothing to decide. Taken in turn.
const TOGETHER := {
	"edda": {
		"married": ["Edda reads you the week's tallies, all of them, slowly, and you fall asleep somewhere around the turnips. She leaves you there.",
			"You mend a harness together by the fire. She does it better and lets you think you helped.",
			"She tells you every cousin's latest folly, in order of folly. It takes the whole evening."],
		"friendship": ["Edda shows you the new granary at Thornwall, and its roof, and the gutter on the roof. It is a good gutter.",
			"You split the evening's bread and argue about horses. She wins.",
			"You sit over the border maps and say nothing for an hour. It's restful."],
	},
	"farid": {
		"married": ["Farah reads you the day's letters in the voices of the people who wrote them. The tax collector's is unkind and very accurate.",
			"You walk Crooked Lantern after dark. The lantern is still crooked. She checks every time.",
			"She makes the coffee badly on purpose so you'll make it instead. You know. You make it anyway."],
		"friendship": ["Farah lays out three maps that disagree and asks your opinion of each. You choose a fourth.",
			"You watch the caravans water at dusk. She names every drover.",
			"She tells you the news that matters to no one: the baker's cat, a new well, a wedding with too many cousins."],
	},
	"kaede": {
		"married": ["Kaede adds the evening to the useless map: 'sat here; good'. You watch her not erase it.",
			"You read side by side in the archive until the lamp gutters. She corrects nothing you say for a whole hour.",
			"She shows you the page with both your names on it. It has three lines now. She won't read them out."],
		"friendship": ["Kaede finds a terrible map and you spend the evening improving it. It gets worse.",
			"You sort a crate of mislabelled scrolls together. She hums. She denies humming.",
			"You watch the ducks from the bench by the lower gate. Strategically worthless. Excellent."],
	},
}
const TOGETHER_OPENER := "Sit with me a while."

## What you never said at the first audience: you bring it up, and she answers.
const INTENT_OPENER := "About what I didn't say, that first day…"
const INTENT_AGAIN := {
	"edda": "You never did say, that first day, what you meant to be to me. I've a column for it in the ledger. It's empty.",
	"farid": "You left our first audience without saying what you wanted. I have been drafting possible answers for you. Please spare me the rest.",
	"kaede": "In the first record of us there's a blank where your intention should be. I would prefer not to guess at it.",
}

## A muster paid for at her house's seat, for its good word: what you say, and her thanks.
const FAVOUR_OPENER := "Let me do something for your house."
const FAVOUR_THANKS := {
	"edda": "A muster, paid for, and no speech about it. The elders will pretend they arranged it. Let them.",
	"farid": "My family will say they negotiated it. I'll let them; it's the quickest way to make them grateful.",
	"kaede": "The council has entered your gift in the official register. I have entered it in mine. Mine is more accurate.",
}

## Chapter 3's task, promised and not yet done: what she says if you come before it is.
const TASK_WAITING := {
	"edda": {"defend_district": "Thornwall still counts its sheep every morning. Tell me when they can stop.",
		"correspondence": "No replies yet. The houses are slow, but you're not, usually."},
	"farid": {"defend_district": "The wagons are still at the crossing. The drovers are singing. Please hurry.",
		"correspondence": "Neither house has my letter yet. Both are already composing their objections."},
	"kaede": {"defend_district": "The ford is still contested, and the witnesses are still on the wrong bank.",
		"correspondence": "I have two copies and a gap where the third should be. I am trying not to fill it with guesses."},
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
		6: "The hall's quiet at supper. Too quiet. What's wrong?",
	},
	"farid": {
		1: "I was told the envoy sees everyone. I hoped that included captains.",
		2: "You said to come back when you had no speech prepared.",
		3: "The wagons are still at the crossing. Tell me what you need.",
		4: "Your relatives have been talking. I heard it from the gate.",
		5: "No letters today?",
		6: "You've left a space on that page.",
	},
	"kaede": {
		1: "I'm told the archive takes a number.",
		2: "Show me the map without roads.",
		3: "The ford. Who's holding it?",
		4: "They've put the brush in front of you, haven't they.",
		5: "Is there room in the margin?",
		6: "There's a third copy, isn't there.",
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
static func opening(candidate: String, status: String, facts: Dictionary, pick: int = 0) -> String:
	var lines: Dictionary = OPENINGS.get(candidate, {})
	var key := opening_key(candidate, facts)
	if key != "":
		var v = facts[key]
		return String(lines[key]).format({"name": str(v), "place": str(v), "days": str(v)})
	return greeting(candidate, status, pick)


## Which of `facts` their first words speak to (see opening), or "" for none.
static func opening_key(candidate: String, facts: Dictionary) -> String:
	var lines: Dictionary = OPENINGS.get(candidate, {})
	for key in OPENING_ORDER:
		var v = facts.get(key, false)
		var holds: bool = (v is bool and v) or (v is String and v != "") or ((v is int or v is float) and v > 0)
		if holds and lines.has(key):
			return String(key)
	return ""


## Their greeting for how things stand: the first of the two, or the `pick`th in turn.
static func greeting(candidate: String, status: String, pick: int = 0) -> String:
	var options := greetings(candidate, status)
	return String(options[posmod(pick, options.size())]) if not options.is_empty() else "Captain."


## Every greeting they have for how things stand.
static func greetings(candidate: String, status: String) -> Array:
	var g: Dictionary = GREETINGS.get(candidate, {})
	var v = g.get(status, g.get("acquainted", []))
	if v is Array:
		return v
	return [String(v)] if v != null else []


## Why `candidate` won't spend new time with you after you've parted.
static func parted(candidate: String) -> String:
	return String(PARTED.get(candidate, "You have parted ways."))


## An evening together, married or sworn, the `pick`th in turn.
static func together(candidate: String, status: String, pick: int) -> String:
	var options: Array = TOGETHER.get(candidate, {}).get("married" if status == "married" else "friendship", [])
	return String(options[posmod(pick, options.size())]) if not options.is_empty() else ""


## Their answer when you bring up `memory` (a memory book entry) with `candidate`.
static func callback(memory: Dictionary, candidate: String = "") -> String:
	var kind := String(memory.get("kind", "note"))
	var who := String(memory.get("candidate", candidate))
	if who == "":
		who = candidate
	if kind == "visit" and VISITS.has(String(memory.get("scene_id", ""))):
		return VISITS[String(memory["scene_id"])]
	if kind == "decision":
		var ch := int(memory.get("chapter", 0))
		var choice := String(memory.get("choice", ""))
		if ch == 4 and CH4_CHOICES.get(who, {}).has(choice):
			return String(CH4_CHOICES[who][choice])
		if ch == 6 and POST.has(who):
			return String(POST[who])
		if CHAPTERS.has(ch):
			return CHAPTERS[ch]
	if kind == "ceremony" and who != "":
		if bool(memory.get("private", false)) and PRIVATE_VOWS.has(who):
			return String(PRIVATE_VOWS[who])
		if CEREMONIES.has(who):
			return String(CEREMONIES[who])
	if kind == "dance" and DANCES.has(who):
		var steps: Array = DANCES[who]
		return String(steps[posmod(int(memory.get("dance", 1)) - 1, steps.size())])
	return String(KINDS.get(kind, KINDS["note"]))


static func story_opener(candidate: String, chapter: int) -> String:
	return String(STORY_OPENERS.get(candidate, {}).get(chapter, "There's something I wanted to ask you."))


## How you take your leave, by how things stand.
static func leaving(status: String) -> String:
	if status in ["courting", "committed", "engaged", "married"]:
		return "I can't stay. I wanted to see you."
	return "Another time."
