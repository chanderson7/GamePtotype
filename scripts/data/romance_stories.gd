## Authored candidates, story chapters, dialogue, prerequisites, choices, and reward keys
## for romance and alliance storylines. Pure authored content and definitions.
##
## Text is written the way the visits are: paragraphs split by a blank line, a paragraph
## beginning "Edda: " (or "Farah: ", "Kaede: ") is theirs, "You: " is yours, anything
## else is narration. Every choice is something the captain says ("text"), with the task
## or what it means under it ("tag"), how they look as they answer ("face", one of the
## portrait expressions) and the line the memory book keeps ("memory").
extends RefCounted

const Cultures = preload("res://scripts/data/cultures.gd")
const Relationships = preload("res://scripts/data/relationships.gd")

const EDDA := "edda"
## The legacy content key remains "farid" so existing saves keep their relationship record.
const FARAH := "farid"
const FARID := FARAH
const KAEDE := "kaede"

## Candidate definitions.
const CANDIDATES := {
	EDDA: {
		"id": EDDA,
		"content_id": EDDA,
		"name": "Edda",
		"age": 28,
		"pronouns": "she/her",
		"role": "Steward of the Ravensford household",
		"culture": Cultures.VARDISH,
		"initial_seat": "ravensford",
		"aim": "Restore the household's neglected border villages",
		"conflict": "Loyalty to relatives versus protecting villagers",
		"project": "Fund a depleted force and negotiate a defensive commitment",
		"interests": ["village records", "local accounts", "border protection"],
		"boundaries": ["opposes reckless raids", "demands kept promises"],
		"blurb": "A resolute steward overseeing the border villages of the Ravensford household. Pragmatic, thoughtful, and determined to keep war from crushing her people."
	},
	FARAH: {
		"id": FARAH,
		"content_id": FARAH,
		"name": "Farah",
		"age": 31,
		"pronouns": "she/her",
		"role": "Envoy of Qasr Hamra",
		"culture": Cultures.KHARZANI,
		"initial_seat": "qasr_hamra",
		"aim": "Keep trade and correspondence open across hostile borders",
		"conflict": "Diplomatic compromise versus family prestige",
		"project": "Reconcile an allied dispute and arrange relief funding",
		"interests": ["cross-border trade", "treaties", "correspondence"],
		"boundaries": ["rejects needless bloodshed", "values discretion"],
		"blurb": "A perceptive diplomat working to maintain merchant caravans and fragile pacts through turbulent border conflicts."
	},
	KAEDE: {
		"id": KAEDE,
		"content_id": KAEDE,
		"name": "Kaede",
		"age": 27,
		"pronouns": "she/her",
		"role": "Archivist of Kitayama",
		"culture": Cultures.RYUMON,
		"initial_seat": "kitayama",
		"aim": "Preserve an agreement that prevents a local feud",
		"conflict": "Public duty versus a personally chosen future",
		"project": "Verify competing claims and organize joint defense",
		"interests": ["ancient records", "feud arbitration", "clan lineage"],
		"boundaries": ["respects solemn oaths", "resists dishonorable deceit"],
		"blurb": "An incisive archivist and negotiator safeguarding historical covenants to avert clan strife."
	}
}

## Authored story chapters for Edda ("A Place Beneath the Banner").
const EDDA_STORY := {
	"title": "A Place Beneath the Banner",
	"chapters": {
		1: {
			"title": "An Introduction",
			"face": "thoughtful",
			"text": "In the hall of Ravensford, Edda examines tallies and ledger parchment beside maps of the border lands. An elder cousin is demanding more silver for field horses; she lets him finish.\n\nEdda: The fields feed the horses. And the villages feed themselves, apparently, since nobody else seems to.",
			"choices": [
				{"id": "work", "text": "What is it you do here, besides outlast your cousins?", "tag": "ask about her work", "face": "thoughtful",
					"response": "Her eyes sharpen.\n\nEdda: I keep the tallies, and the tallies keep the villages. Thornwall and Kettlebrook carry the scars of every raid. If no one watches for them, no victory in the field will save this valley."},
				{"id": "boast", "text": "You'll have heard of my company. We don't lose.", "tag": "talk of your victories", "face": "amused",
					"response": "She listens politely, with half a smile.\n\nEdda: Renown is good coin with the lords, captain. It buys less with a village that has just watched its thatch burn."},
				{"id": "help", "text": "If the household needs hands, mine are for hire. Or for free, depending.", "tag": "offer help", "face": "warm",
					"response": "Edda: Practical help is rare coin. I'll hold you to that when the winter stores need defending."}
			],
			"intent_prompt": "As the conversation winds down, what is your intention?",
			"intent_choices": [
				{"id": "know_better", "intent": "romantic", "text": "I'd like to know you better. Beyond the tallies.", "tag": "court her", "face": "warm",
					"response": "A subtle warmth touches her gaze.\n\nEdda: Then come back when the roads allow, captain. We'll speak of more than grain counts.",
					"memory": "The day I asked to know Edda better."},
				{"id": "offer_help", "intent": "friendship", "text": "I came to offer my sword to your cause. As a friend.", "tag": "as a friend", "face": "warm",
					"response": "She gives a firm nod.\n\nEdda: A steadfast friend is worth ten sworn knights. You're welcome at my table.",
					"memory": "The day I offered Edda my friendship."},
				{"id": "another_time", "intent": "none", "text": "We'll speak another time, steward.", "tag": "nothing decided yet", "face": "neutral",
					"response": "Edda: Fair roads and good hunting, captain.", "memory": "A first word with Edda, and nothing promised."}
			],
			"reward_key": "edda_ch1_intro",
			"trust_reward": 10,
			"standing_reward": 0
		},
		2: {
			"title": "Something of Your Own",
			"face": "thoughtful",
			"text": "You find Edda outside the hall with a bundle of parish records, the paper soft from too many hands.\n\nEdda: Every parish here had its songs, its line of weavers and smiths. When raiders burn a hall, the songs burn too, unless someone writes them down.",
			"choices": [
				{"id": "villager", "text": "Old Martha at Thornwall still remembers. I'll ride and write it down.", "tag": "ride to Thornwall for the elder's account", "face": "warm",
					"response": "Edda takes the parchment as if it might tear.\n\nEdda: She remembered the floods of forty years ago. These lines will outlast the war.",
					"memory": "The elder's account from Thornwall, written down before it was lost."},
				{"id": "news", "text": "The families from the ford. I have news of them.", "tag": "bring word of the border families", "face": "warm",
					"response": "Relief goes through her shoulders before her face admits it.\n\nEdda: Safe across the ford. That's a heavier weight off than you know.",
					"memory": "Word that the families from the ford were safe."},
				{"id": "verse", "text": "There's a verse they sing in the hills. I never understood the last line.", "tag": "share a verse of the hills", "face": "amused",
					"response": "Edda recites the companion stanza, softly, and smiles at the end of it.\n\nEdda: You listen to the quiet things between the marching drums. That's rare in a mercenary.",
					"memory": "A verse of the hills, and the stanza she knew that I didn't."}
			],
			"reward_key": "edda_ch2_personal",
			"trust_reward": 15,
			"standing_reward": 0,
			"memory": "Recovered memories and shared thoughts of home with Edda."
		},
		3: {
			"title": "An Obligation Shared",
			"face": "concerned",
			"text": "The household faces a hard season. A muster is called, but the border villages have no one to hold them.\n\nEdda: We can't ask folk to stand alone when the horn sounds. I've asked the hall. The hall has asked me to be reasonable.",
			"variants": [
				{"id": "fund_muster", "name": "Sponsor Replacements", "text": "Then I'll pay for the muster.", "tag": "into the district's fund", "face": "warm",
					"response": "Your coin raises sturdy recruits to guard the homes. Edda watches the new muster take its posts.\n\nEdda: I'll see every one of them fed. You've my word on that, which I give rarely.",
					"memory": "The muster I paid for, standing watch over the villages."},
				{"id": "defend_district", "name": "Defend the Valley", "text": "We'll hold the valley ourselves.", "tag": "your company guards Ravensford's roads", "face": "warm",
					"promise": "Edda: Then the valley roads are yours until the raiders are gone. Thornwall first; they always come for Thornwall first.",
					"response": "Your warband drives the raiders off. The villagers meet Edda on the road with bread and blessings for the company.\n\nEdda: They'll tell this one at the hearth for years, and they'll get your name wrong. I won't.",
					"memory": "The day the company held the valley."},
				{"id": "correspondence", "name": "Broker an Accord", "text": "Give me the letters. I ride tonight.", "tag": "carry word to the allied houses", "face": "amused",
					"promise": "She presses the sealed letters into your hand, the wax still soft.\n\nEdda: One reply from each house. Don't let anyone talk you into carrying a fourth.",
					"response": "You deliver the dispatch intact and bring back pledges of grain and defence, without a drop of blood spilt.\n\nEdda: Three houses agreeing on paper. I'd have bet the ledgers against it.",
					"memory": "The letters I carried, and the pledges that came back."}
			],
			"reward_key": "edda_ch3_shared",
			"trust_reward": 15,
			"standing_reward": 15
		},
		4: {
			"title": "Between Two Loyalties",
			"face": "concerned",
			"text": "A bitter disagreement splits the hall. The house head wants the riders for an offensive march and the valley stripped of guards; Edda has pleaded for a garrison. Both look to you.\n\nEdda: Say what you think, captain. Not what he wants to hear, and not what I do.",
			"choices": [
				{"id": "negotiate", "text": "Keep a garrison here and send the rest. Neither of you gets everything.", "tag": "a compromise · Edda and the house both content", "face": "thoughtful",
					"trust": 15, "standing": 10,
					"response": "Both sides hear reason. The household leaves guards at home and commits a limited column to the field.\n\nEdda: Half of what I wanted, and all of what the valley needed. I can live with that.",
					"reward_key": "edda_ch4_negotiate", "memory": "The compromise I spoke for in the council."},
				{"id": "support_edda", "text": "The valley comes first. I stand with Edda.", "tag": "Edda's trust · the elders' displeasure", "face": "warm",
					"trust": 15, "standing": -10,
					"response": "Edda stands taller beside you. The elders scowl, but the villages will not be abandoned.\n\nEdda: You'll have made enemies in this hall today. I'll make up the difference.",
					"reward_key": "edda_ch4_support", "memory": "The day I stood with Edda against the hall."},
				{"id": "break_promise", "text": "The house head is right. We march.", "tag": "breaks your word to Edda · the house's favour", "face": "concerned",
					"trust": -10, "standing": 10, "strained": true, "strained_reason": "broken_promise",
					"response": "The elders cheer. Edda goes pale and leaves without a word. You have broken your word to her.",
					"reward_key": "edda_ch4_breach", "memory": "The council where I broke my word to Edda."},
				{"id": "decline", "text": "I won't choose between you today.", "tag": "nothing decided", "tone": "plain", "face": "thoughtful",
					"trust": 0, "standing": 0,
					"response": "You step back. The dispute goes on unresolved, waiting on your counsel.",
					"reward_key": "", "memory": ""}
			],
			"repair": {"id": "repair_promise", "text": "I failed you in the hall. Let me make it right, at my own cost.", "tag": "mends it", "face": "thoughtful",
				"trust": 25, "standing": 0,
				"response": "Edda listens in silence, and lets the silence go on a while.\n\nEdda: It takes something to admit a fault and mend it with deeds instead of words. I'll trust you again, captain. Slowly.",
				"reward_key": "edda_ch4_repaired", "memory": "The debt I paid to mend my word to Edda."}
		},
		5: {
			"title": "What We Choose",
			"face": "warm",
			"text": "The seasons have turned, and trust has been tested by fire and bread alike. In the quiet courtyard under the banners, Edda turns to you.\n\nEdda: We've walked a hard road together, captain. Where do we stand now?",
			"final_choices": [
				{"id": "marry_public", "text": "Marry me. Before your house and everyone.", "tag": "before her house", "face": "warm",
					"response": "Edda: Yes. Obviously, yes. Give me a moment; I'm going to need a list."},
				{"id": "marry_private", "text": "Let's make our vows quietly. Just us.", "tag": "tonight, by one candle · her house not asked", "face": "warm",
					"response": "Edda: No cousins. No list. I could weep."},
				{"id": "friendship", "text": "Let's swear friendship, and stand by each other's houses.", "tag": "a pact between your houses", "face": "warm",
					"response": "Edda: Done. I'll have it written, and I'll have it kept."},
				{"id": "remain_close", "text": "Let's stay close, and let time decide.", "tag": "no promises yet", "face": "thoughtful",
					"response": "Edda: Time's a poor steward, but all right. I'll keep the chair."},
				{"id": "part_respectfully", "text": "I think our roads part here.", "tag": "for good", "face": "concerned",
					"response": "Edda: Then go well. The ledger will say you were here. So will I."}
			],
			"final_reward_key": "edda_ch5_final",
			"final_trust": 10
		}
	},
	# After the wedding or the pact: one more matter, told as a sixth chapter. Each answer
	# raises her house's standing once (standing_gain) and is kept as a memory.
	"post_project": {
		"id": "empty_chairs",
		"title": "The Empty Chairs",
		"face": "thoughtful",
		"text": "Two household captains dispute the blame for an outpost lost in the border skirmishes. Neither will sit at the same table as the other, and the hall has two empty chairs at every supper.\n\nEdda: They'll both listen to you. Neither of them listens to me, which they'll regret at the next harvest count.",
		"choices": [
			{"id": "mediate", "text": "Sit them down together. I'll hear both accounts and draw the patrols up between them.", "tag": "a common table", "face": "warm",
				"response": "You hear both captains out, one after the other and then together, and draft a patrol division neither can call the other's. The dispute is laid to rest with honour intact.\n\nEdda: Two chairs, filled. I'm putting that in the ledger in red, so it stands out.",
				"reward_key": "edda_post_empty_chairs", "standing_gain": 5,
				"memory": "The night I brought the household's captains back to one table."},
			{"id": "sergeant", "text": "Put my sergeant between them for a season. He's outlasted worse.", "tag": "lend them your sergeant", "face": "amused",
				"response": "Your sergeant rides the patrols for a month and reports that both captains are equally useless, in the same words, to both of them. They stop blaming each other and start blaming him.\n\nEdda: United against your sergeant. I'll take it.",
				"reward_key": "edda_post_empty_chairs", "standing_gain": 5,
				"memory": "The month my sergeant rode the household's patrols."}
		]
	}
}

const FARAH_STORY := {
	"title": "Words With Their Own Weight",
	"chapters": {
		1: {"title": "A Carefully Plain Introduction", "face": "thoughtful",
			"text": "In a shaded audience room at Qasr Hamra, Farah has crossed out the opening of a trade letter three times. She looks up with a rueful smile.\n\nFarah: Every greeting sounds like a promise when two borders are armed. I would prefer to begin with the truth, but everyone has supplied me with a different one.",
			"choices": [
				{"id": "work", "text": "What keeps the road open, with a war on either side of it?", "tag": "ask about the road", "face": "thoughtful",
					"response": "Farah turns the letter toward you.\n\nFarah: Names. Bakers, drovers, widows, guards. A treaty survives when it remembers who needs the road tomorrow."},
				{"id": "boast", "text": "My word carries weight. I've won enough to make sure of it.", "tag": "offer your victories as proof", "face": "amused",
					"response": "Farah: A victory makes people listen. What you say once they are quiet will tell me rather more."},
				{"id": "help", "text": "If you need a message carried, I'll carry it. Word for word.", "tag": "offer to carry a message", "face": "warm",
					"response": "Her expression brightens.\n\nFarah: A courier who does not improve the message. You may be the rarest ally in Kharzan."}
			],
			"intent_prompt": "As the audience ends, what do you want Farah to understand?",
			"intent_choices": [
				{"id": "know_better", "intent": "romantic", "text": "I'd like to hear what you say when no court is listening.", "tag": "court her", "face": "warm",
					"response": "Farah holds your gaze.\n\nFarah: Then return when I have no speech prepared. I warn you: I may be disappointingly direct.",
					"memory": "The day I asked Farah what she says when no court is listening."},
				{"id": "offer_help", "intent": "friendship", "text": "I'd rather be a friend you can trust than another obligation.", "tag": "as a friend", "face": "warm",
					"response": "Farah: That is a welcome distinction. You may find a place at my table without bringing a petition.",
					"memory": "The day I offered Farah my friendship."},
				{"id": "another_time", "intent": "none", "text": "We'll speak when the road brings me back.", "tag": "nothing decided yet", "face": "neutral",
					"response": "Farah: Then I hope it is a kinder road next time.", "memory": "A first audience with Farah, and nothing promised."}
			]},
		2: {"title": "The Address People Use", "face": "amused",
			"text": "Farah shows you two maps of the same market quarter. One carries the official name; the other is marked Crooked Lantern in her own hand.\n\nFarah: Letters reach offices by the first name. People find one another by the second.",
			"choices": [
				{"id": "villager", "text": "Show me the quarter. I'll write down what people actually call things.", "tag": "walk the quarter with her", "face": "amused",
					"response": "Farah returns with dust on her hem and six contradictory directions.\n\nFarah: Excellent. A completely unusable map, and a perfect account of home.",
					"memory": "The map of the quarter, with the names people actually use."},
				{"id": "news", "text": "The merchants cut off by the closure. I've news of them.", "tag": "bring news from across the border", "face": "warm",
					"response": "She reads every name twice.\n\nFarah: This is why correspondence matters. Not for the seal. For the answer.",
					"memory": "News of the merchants across the closed border."},
				{"id": "verse", "text": "Which name do you use when you write home?", "tag": "ask about her letters home", "face": "amused",
					"response": "Farah: Crooked Lantern. My aunt would reject any letter addressed to somewhere respectable.",
					"memory": "The name she writes on letters home."}
			]},
		3: {"title": "A Road Kept Open", "face": "concerned",
			"text": "Two allied houses have stopped sharing escorts after a public insult. Relief wagons wait behind their quarrel. Farah sets the reports aside.\n\nFarah: Pride can survive a delay. The grain cannot.",
			"variants": [
				{"id": "fund_muster", "name": "Fund Neutral Escorts", "text": "I'll pay for guards who serve neither house.", "tag": "under a neutral seal", "face": "warm",
					"response": "Paid under a neutral seal, the escort rides without either house claiming the other bowed.\n\nFarah: You have bought a silence both houses can live inside. That is diplomacy.",
					"memory": "The neutral escort I paid for."},
				{"id": "defend_district", "name": "Ride the Relief Road", "text": "My company will take the first wagons through.", "tag": "guard the crossing yourself", "face": "amused",
					"promise": "Farah: The wagons move when you do. I have told the drovers to look for your banner, and not to sing. They sing terribly.",
					"response": "The convoy arrives intact, which gives both delegations a fact more useful than their grievance.\n\nFarah: Grain in the market. Nobody can argue with a loaf.",
					"memory": "The first wagons through the crossing."},
				{"id": "correspondence", "name": "Carry Matched Letters", "text": "Write it once. I'll carry the same words to both doors.", "tag": "deliver her proposal to both houses", "face": "thoughtful",
					"promise": "Farah writes it once, copies it once, and seals both with the same care.\n\nFarah: Identical. If either house asks what the other was offered, let them read it.",
					"response": "Neither side can pretend the other was offered better terms. The escorts return to the road.\n\nFarah: Identical letters. I have been told it is an insult to tailor nothing. It worked.",
					"memory": "The two identical letters I carried."}
			]},
		4: {"title": "The Useful Answer", "face": "concerned",
			"text": "Farah's relatives demand a triumphal agreement that would humiliate the other house. She promised the merchants a workable peace. In council, every face turns toward you before she can answer for herself.\n\nFarah: You have the floor, captain. I would have preferred to keep it.",
			"choices": [
				{"id": "negotiate", "text": "Equal obligations on both sides, and both houses keep their dignity.", "tag": "a compromise · Farah and her family both content", "face": "thoughtful",
					"response": "Farah builds on the compromise in her own words. The road opens under a compact neither side needs to disguise.\n\nFarah: You left me room to finish the sentence. Thank you.",
					"memory": "The equal compact I proposed in council."},
				{"id": "support_edda", "text": "Farah promised the merchants relief. I'll hold the house to her word.", "tag": "Farah's trust · her family's displeasure", "face": "warm",
					"response": "The elders bristle, but Farah does not soften the promise she made. The merchants receive the protection they were offered.\n\nFarah: My family will forgive you eventually. I already have.",
					"memory": "The day I held her family to Farah's promise."},
				{"id": "break_promise", "text": "Her family's terms are stronger. Take the harsher ones.", "tag": "breaks your word to Farah · her family's favour", "face": "concerned",
					"response": "Farah completes the meeting flawlessly. Only afterwards does she speak to you.\n\nFarah: I needed your honest refusal before the council, not your agreement before it.",
					"memory": "The council where I broke my word to Farah."},
				{"id": "decline", "text": "I don't understand this settlement well enough to shape it.", "tag": "nothing decided", "tone": "plain", "face": "thoughtful",
					"response": "The council adjourns without a resolution. Farah accepts your caution, though the wagons remain delayed.", "memory": ""}
			],
			"repair": {"id": "repair_promise", "text": "I broke my word in that council. The convoy I put at risk, I'll pay for.", "tag": "mends it", "face": "thoughtful",
				"response": "Farah accepts the restitution without pretending it erases the choice.\n\nFarah: Trust is not a speech. This is at least a useful sentence.",
				"memory": "The convoy I paid for, to mend my word to Farah."}},
		5: {"title": "No Reply Required", "face": "warm",
			"text": "The road is open again. Farah finds you without a letter in her hand.\n\nFarah: I have spent years making every sentence carry someone else's need. I would like this one to belong to me. I am glad you came.",
			"final_choices": [
				{"id": "marry_public", "text": "Marry me. Before your house, in front of all of them.", "tag": "before her house", "face": "warm",
					"response": "Farah: Yes. I had an elegant answer prepared. It has entirely gone."},
				{"id": "marry_private", "text": "Let's make our vows quietly. No court.", "tag": "tonight, by one candle · her house not asked", "face": "warm",
					"response": "Farah: No speeches. No seals. Yes."},
				{"id": "friendship", "text": "Let's swear friendship between our houses.", "tag": "a pact between your houses", "face": "amused",
					"response": "Farah: Then I will draft it badly, on purpose, so no one mistakes it for a treaty."},
				{"id": "remain_close", "text": "Let's stay close, and see what the road brings.", "tag": "no promises yet", "face": "thoughtful",
					"response": "Farah: The road has been kind lately. I will allow it one more decision."},
				{"id": "part_respectfully", "text": "I think this is where we part.", "tag": "for good", "face": "concerned",
					"response": "Farah: Then fair roads, captain. I meant that before, and I mean it now."}
			],
			"final_reward_key": "farid_ch5_final", "final_trust": 10}
	},
	"post_project": {
		"id": "blank_clause",
		"title": "The Blank Clause",
		"face": "thoughtful",
		"text": "The merchants want the compact renewed. Both houses want a clause naming the other as the cause of the closure. Farah has left a space on the page where the clause would go, and has not filled it.\n\nFarah: I could write something elegant there. I would rather both houses agreed to nothing at all, in writing. Help me.",
		"choices": [
			{"id": "mediate", "text": "Ride with me to both houses. We'll ask each for the same silence.", "tag": "ask both houses together", "face": "warm",
				"response": "You stand beside her in two halls on two days and hear the same objection twice. Each house agrees to leave the space blank once it is certain the other will.\n\nFarah: A treaty with a hole in it. The most honest thing I have ever sealed.",
				"reward_key": "farid_post_blank_clause", "standing_gain": 5,
				"memory": "The clause we persuaded both houses to leave blank."},
			{"id": "escort", "text": "My company takes the first guild caravan through, under both seals.", "tag": "escort the guild's caravan", "face": "amused",
				"response": "The caravan arrives under two seals and one banner, yours. By the time the houses think to argue about precedence, the goods are sold.\n\nFarah: Nobody can quarrel over a market that is already open. I should have married a convoy years ago.",
				"reward_key": "farid_post_blank_clause", "standing_gain": 5,
				"memory": "The guild caravan that went through under both seals."}
		]
	}
}

const KAEDE_STORY := {
	"title": "The Account We Choose",
	"chapters": {
		1: {"title": "An Unfinished Record", "face": "thoughtful",
			"text": "In Kitayama's archive, Kaede has placed two contradictory clan accounts side by side.\n\nKaede: Both are accurate about the banners. Neither mentions who opened the gate before the feud became a siege. Omissions are where trouble waits.",
			"choices": [
				{"id": "work", "text": "How do you tell an error from a lie?", "tag": "ask about her work", "face": "thoughtful",
					"response": "Kaede: Patiently, and with less confidence than people expect. Certainty is an attractive annotation. It is not always an honest one."},
				{"id": "boast", "text": "I've decided a few battles. I can tell you how they're really won.", "tag": "offer a commander's account", "face": "amused",
					"response": "Kaede reaches for a clean page.\n\nKaede: Good. Begin with where you stood. Every witness forgets that part first."},
				{"id": "help", "text": "There'll be witnesses outside the two halls. I can find them.", "tag": "offer to find witnesses", "face": "warm",
					"response": "Kaede: Speak to the ferrymen. They remember who crossed before anyone decided what the crossing meant."}
			],
			"intent_prompt": "Before you leave the archive, what do you ask of Kaede?",
			"intent_choices": [
				{"id": "know_better", "intent": "romantic", "text": "I'd like to know what you choose when the record is only yours.", "tag": "court her", "face": "warm",
					"response": "Kaede pauses longer than the question requires.\n\nKaede: I am not practised at answering that. I would like another opportunity.",
					"memory": "The day I asked Kaede what she chooses when the record is only hers."},
				{"id": "offer_help", "intent": "friendship", "text": "Let me help, as a friend. I don't need a place in the account.", "tag": "as a friend", "face": "warm",
					"response": "Kaede: A friend still appears in the margins. But I accept the distinction.",
					"memory": "The day I offered Kaede my friendship."},
				{"id": "another_time", "intent": "none", "text": "I'll leave the archive to its work.", "tag": "nothing decided yet", "face": "neutral",
					"response": "Kaede: And I will try not to finish your conclusions for you.", "memory": "A first word with Kaede, and nothing promised."}
			]},
		2: {"title": "A Map of Useless Places", "face": "amused",
			"text": "Kaede shows you a private map without roads or borders. It marks a dry stair, a wall warmed by afternoon sun, and a cat whose attendance is carefully labelled uncertain.\n\nKaede: It is not an official document. It is allowed to prefer things.",
			"choices": [
				{"id": "villager", "text": "There's a bench by the lower gate where people sit when no one's watching. Put that on.", "tag": "add a place townsfolk rest", "face": "amused",
					"response": "Kaede records the bench, then adds 'good in late light'. The opinion seems to surprise and please her.",
					"memory": "The bench I added to her map of useless places."},
				{"id": "news", "text": "Who taught you to draw maps like this?", "tag": "ask who taught her", "face": "warm",
					"response": "Kaede: No one. That was their appeal.\n\nShe shows you a childhood plan of three excellent hiding places and one unreliable cupboard.",
					"memory": "Her childhood map: three hiding places and one unreliable cupboard."},
				{"id": "verse", "text": "I'd mark the ford below Marchgate. The water's warm there in the evening.", "tag": "offer a place of your own", "face": "warm",
					"response": "Kaede listens without correcting the distance.\n\nKaede: Then it belongs here. This map is allowed to prefer things.",
					"memory": "The place of mine she put on her map."}
			]},
		3: {"title": "Witnesses at the Ford", "face": "concerned",
			"text": "The rival clans agree on one fact: neither trusts the other's copy of the old covenant. Kaede needs testimony, and a joint defence, before the next provocation hardens into violence.\n\nKaede: I can prove what the covenant said. I cannot prove it to people who are busy fighting.",
			"variants": [
				{"id": "fund_muster", "name": "Fund a Joint Watch", "text": "I'll pay for a watch drawn from both villages.", "tag": "for a mixed patrol", "face": "amused",
					"response": "The shared watch makes cooperation a daily practice before the council gives it a grander name.\n\nKaede: They have started arguing about the rota instead of the covenant. That is progress.",
					"memory": "The joint watch I paid for."},
				{"id": "defend_district", "name": "Hold the Ford", "text": "My company holds the ford while they talk.", "tag": "guard the crossing yourself", "face": "warm",
					"promise": "Kaede: Hold it until the witnesses have crossed and spoken. I will write down everything, including who arrives late.",
					"response": "Fighting beside one another gives the rivals a new event they cannot record separately.\n\nKaede: One account, for once. Yours. I have written it down.",
					"memory": "The day the company held the ford."},
				{"id": "correspondence", "name": "Gather Independent Copies", "text": "Temples, ferries, households. I'll bring you every copy there is.", "tag": "carry her requests for the other copies", "face": "amused",
					"promise": "Kaede hands you a list of every temple, ferry and household that might keep a copy, ordered by how much they will resent being asked.\n\nKaede: Start with the ferrymen. They resent nothing. They simply charge.",
					"response": "Three incomplete copies overlap around the same promise. Kaede can finally show what none proves alone.\n\nKaede: Three liars, agreeing by accident. I could kiss the ferryman.",
					"memory": "The three copies I gathered, which agreed by accident."}
			]},
		4: {"title": "The Line in Her Hand", "face": "concerned",
			"text": "The Kitayama council wants Kaede to certify the version that favours their own clan. She promised both villages an honest comparison. The official brush is placed before her.\n\nKaede: They are waiting for me to pick it up. So, I notice, are you.",
			"choices": [
				{"id": "negotiate", "text": "Write a covenant that says only what the surviving records agree on.", "tag": "a compromise · Kaede and the council both content", "face": "thoughtful",
					"response": "Kaede drafts a narrow promise both sides can actually keep, and labels every uncertainty rather than hiding it.\n\nKaede: It is a small document. Small documents survive.",
					"memory": "The narrow covenant I argued for."},
				{"id": "support_edda", "text": "Kaede won't certify a lie, and she shouldn't have to.", "tag": "Kaede's trust · the council's displeasure", "face": "warm",
					"response": "She signs her own finding. The council loses its easy victory; the villages keep an honest peace.\n\nKaede: You have made the record less convenient. Thank you.",
					"memory": "The day I stood with Kaede against the council."},
				{"id": "break_promise", "text": "Sign their version. Unity now matters more than a dead clause.", "tag": "breaks your word to Kaede · the council's favour", "face": "concerned",
					"response": "Kaede sets the brush down.\n\nKaede: You asked me to make the record useful by making it false. I cannot call that unity.",
					"memory": "The council where I broke my word to Kaede."},
				{"id": "decline", "text": "Neither version yet. We need more than two copies.", "tag": "nothing decided", "tone": "plain", "face": "thoughtful",
					"response": "The decision waits. Kaede respects the caution, though she cannot promise the clans will remain patient.", "memory": ""}
			],
			"repair": {"id": "repair_promise", "text": "I'll take back what I asked, in front of them, and pay for every record to be copied.", "tag": "mends it", "face": "thoughtful",
				"response": "Kaede notes the retraction in the same hand as the original demand.\n\nKaede: A correction must remain visible. Now we can continue.",
				"memory": "The retraction I made before the council, to mend my word to Kaede."}},
		5: {"title": "Room in the Margin", "face": "warm",
			"text": "The new covenant is signed, with its uncertainties left visible. Kaede closes the official box and unrolls her private map.\n\nKaede: This record does not require witnesses. I would still like you to be part of it.",
			"final_choices": [
				{"id": "marry_public", "text": "Marry me. Let the whole archive witness it.", "tag": "before her house", "face": "warm",
					"response": "Kaede: Yes. I will need to start a page. A long one."},
				{"id": "marry_private", "text": "Let's make our vows quietly. Just us, and no record.", "tag": "tonight, by one candle · her house not asked", "face": "warm",
					"response": "Kaede: No record. I have never said that about anything. Yes."},
				{"id": "friendship", "text": "Let's swear friendship between our houses.", "tag": "a pact between your houses", "face": "amused",
					"response": "Kaede: I shall put it in the margin, where the important things go."},
				{"id": "remain_close", "text": "Let's stay close, and let time decide.", "tag": "no promises yet", "face": "thoughtful",
					"response": "Kaede: Time is a careless archivist. I will keep my own notes."},
				{"id": "part_respectfully", "text": "I think our roads part here.", "tag": "for good", "face": "concerned",
					"response": "Kaede: Then I will record it accurately. Including the good parts."}
			],
			"final_reward_key": "kaede_ch5_final", "final_trust": 10}
	},
	"post_project": {
		"id": "third_copy",
		"title": "The Third Copy",
		"face": "concerned",
		"text": "A third clan has come to Kitayama with a copy of the covenant that names them too. It may be true. It may also be a very good forgery, and the first two clans have already begun to sharpen things.\n\nKaede: I would like to be right about this before I am kind about it. Help me find out which.",
		"choices": [
			{"id": "mediate", "text": "Let's ask the ferrymen again. They remember who crossed.", "tag": "find the witnesses", "face": "thoughtful",
				"response": "The oldest ferryman remembers three boats, not two, and the colour of the third one's sail. The copy is genuine, and badly kept.\n\nKaede: Three clans, then. I will need a wider page.",
				"reward_key": "kaede_post_third_copy", "standing_gain": 5,
				"memory": "The ferryman who remembered the third boat."},
			{"id": "stand", "text": "Tell them what you find. I'll stand beside you while you do.", "tag": "stand with her before the clans", "face": "warm",
				"response": "Kaede reads her finding aloud with you at her shoulder. Nobody interrupts her, which she says has never once happened.\n\nKaede: I have recorded that they listened. I may frame it.",
				"reward_key": "kaede_post_third_copy", "standing_gain": 5,
				"memory": "The day the clans let Kaede finish."}
		]
	}
}


static func candidate_data(id: String) -> Dictionary:
	return CANDIDATES.get(id, {})


## The matter after the wedding or the pact (a sixth chapter), or {}.
static func post_project(candidate_id: String) -> Dictionary:
	return story_data(candidate_id).get("post_project", {})


static func story_data(candidate_id: String) -> Dictionary:
	match candidate_id:
		EDDA: return EDDA_STORY
		FARAH: return FARAH_STORY
		KAEDE: return KAEDE_STORY
		_: return {}


## The authored choice `choice_id` of `candidate_id`'s story (a topic, an intent, a chapter
## choice, a variant, the repair or a final choice), or {}.
static func choice_data(candidate_id: String, choice_id: String) -> Dictionary:
	var story := story_data(candidate_id)
	for n in story.get("chapters", {}):
		var ch: Dictionary = story["chapters"][n]
		var options: Array = []
		for key in ["choices", "intent_choices", "variants", "final_choices"]:
			options.append_array(ch.get(key, []))
		if ch.has("repair"):
			options.append(ch["repair"])
		for o in options:
			if String(o.get("id", "")) == choice_id:
				return o
	return {}


## Authored text as beats: [{speaker ("Narrator", "You" or their name), text}].
static func beats(text: String) -> Array:
	var out := []
	for para in text.split("\n\n", false):
		var line := String(para).strip_edges()
		if line == "":
			continue
		var speaker := "Narrator"
		for name in ["Edda", "Farah", "Kaede", "You"]:
			if line.begins_with(name + ": "):
				speaker = name
				line = line.trim_prefix(name + ": ")
				break
		out.append({"speaker": speaker, "text": line})
	return out


## Authored text as prose: their words in quotes, narration as it is.
static func plain(text: String) -> String:
	var parts := PackedStringArray()
	for b in beats(text):
		parts.append(("\"%s\"" % b["text"]) if b["speaker"] != "Narrator" else String(b["text"]))
	return " ".join(parts)
