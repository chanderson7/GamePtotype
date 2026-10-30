## Authored candidates, story chapters, dialogue, prerequisites, choices, and reward keys
## for romance and alliance storylines. Pure authored content and definitions.
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
		"blurb": "A resolute steward overseeing the border villages of House Caldmoor. Pragmatic, thoughtful, and determined to keep war from crushing her people."
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
			"text": "In the hall of Ravensford, Edda examines tallies and ledger parchment beside maps of the border lands. She sighs as an elder cousin demands more silver for field horses.\n\n'The fields feed the horses,' she remarks quietly as you approach, 'and yet the villages are left to fend for themselves.'",
			"choices": [
				{
					"id": "work",
					"text": "Ask about her duties and the state of the border villages.",
					"response": "Edda's eyes sharpen with interest. 'Few commanders look past the vanguard. The villages of Thornwall and Kettlebrook carry the scars of every raid. If someone does not watch for them, no victory in the field will save this valley.'"
				},
				{
					"id": "boast",
					"text": "Speak of your warband's victories in the realm's service.",
					"response": "She listens politely with a wry half-smile. 'Renown is good coin with the lords, captain. But a name won in battle means little if you leave burned thatch and empty storehouses behind you.'"
				},
				{
					"id": "help",
					"text": "Offer practical assistance to her and the household.",
					"response": "'Practical help is rare coin,' she says with genuine warmth. 'I will hold you to that offer when the winter stores need defending.'"
				}
			],
			"intent_prompt": "As the conversation winds down, what is your intention?",
			"intent_choices": [
				{
					"id": "know_better",
					"intent": "romantic",
					"text": "I would like to know you better, beyond estate tallies.",
					"response": "A subtle warmth touches her gaze. 'Then come back when the roads allow, captain. We will speak of more than grain counts.'"
				},
				{
					"id": "offer_help",
					"intent": "friendship",
					"text": "I came to offer my sword and service to your cause as a friend.",
					"response": "She gives a firm, respectful nod. 'A steadfast friend is worth ten sworn knights. You are welcome at my table, captain.'"
				},
				{
					"id": "another_time",
					"intent": "none",
					"text": "We will speak another time, steward.",
					"response": "'Fair roads and good hunting, captain.'"
				}
			],
			"reward_key": "edda_ch1_intro",
			"trust_reward": 10,
			"standing_reward": 0
		},
		2: {
			"title": "Something of Your Own",
			"text": "You find Edda outside the hall, reviewing records from the parish folk. 'Every parish here had its songs, its lineage of weavers and smiths,' she murmurs. 'When raiders burn a hall, the songs burn too unless someone writes them down.'",
			"choices": [
				{
					"id": "villager",
					"text": "Travel to nearby Thornwall to recover an old elder's written account.",
					"response": "Edda accepts the parchment with gentle reverence. 'Old Martha remembered the floods of forty years ago. These lines will outlast the war.'"
				},
				{
					"id": "news",
					"text": "Bring word of families from the border she inquired after.",
					"response": "Relief visibly washes over her shoulders. 'Safe across the ford... that is a heavier burden lifted than you know.'"
				},
				{
					"id": "verse",
					"text": "Share a local verse of the hills and discuss its meaning.",
					"response": "Edda recites the companion stanza softly, smiling. 'You listen to the quiet things between the marching drums. That is rare in a mercenary.'"
				}
			],
			"reward_key": "edda_ch2_personal",
			"trust_reward": 15,
			"standing_reward": 0,
			"memory": "Recovered memories and shared thoughts of home with Edda."
		},
		3: {
			"title": "An Obligation Shared",
			"text": "The household faces a hard season. A muster is called, but the border villages lack defenses. 'We cannot ask folk to stand alone when the horn sounds,' Edda tells you.",
			"variants": [
				{
					"id": "fund_muster",
					"name": "Sponsor Replacements",
					"text": "Sponsor up to 300 silver into an escrow fund to raise replacements for the district.",
					"response": "Your coin pays for sturdy recruits to guard the homes. Edda watches the new muster take post with profound relief."
				},
				{
					"id": "defend_district",
					"name": "Defend the Valley",
					"text": "Help defend a district village or protect the roads of Ravensford.",
					"response": "Your warband drives off the threat. The villagers greet Edda with baskets of bread and blessings for the company."
				},
				{
					"id": "correspondence",
					"name": "Broker an Accord",
					"text": "Carry urgent correspondence between the household and allied contacts.",
					"response": "You deliver the dispatch intact, securing pledges of mutual grain and defense without a single drop of blood."
				}
			],
			"reward_key": "edda_ch3_shared",
			"trust_reward": 15,
			"standing_reward": 15
		},
		4: {
			"title": "Between Two Loyalties",
			"text": "A bitter disagreement splits the hall. The house head demands an aggressive offensive march, leaving the local valley stripped of guards. Edda has pleaded to keep a defensive detachment behind.\n\nBoth look to you to speak before the council.",
			"choices": [
				{
					"id": "negotiate",
					"text": "Propose a compromise: a bounded defense agreement for Ravensford and Thornwall.",
					"trust": 15,
					"standing": 10,
					"response": "Both sides hear reason. The household agrees to leave garrison guards while committing limited riders to the field.",
					"reward_key": "edda_ch4_negotiate",
					"memory": "Negotiated a fair compromise between Edda and the house head."
				},
				{
					"id": "support_edda",
					"text": "Publicly support Edda: the home valley must come first, whatever the lords desire.",
					"trust": 15,
					"standing": -10,
					"response": "Edda stands taller beside you. The house elders scowl, but the villagers will not be abandoned.",
					"reward_key": "edda_ch4_support",
					"memory": "Stood with Edda against the elders' reckless offensive."
				},
				{
					"id": "break_promise",
					"text": "Sway toward the house head's demand for glory, setting aside Edda's plea.",
					"trust": -10,
					"standing": 10,
					"strained": true,
					"strained_reason": "broken_promise",
					"response": "The house elders cheer, but Edda turns pale and steps away without a word. You have broken your word to her.",
					"reward_key": "edda_ch4_breach",
					"memory": "Failed Edda in the council, siding with the house's offensive plan."
				},
				{
					"id": "decline",
					"text": "Decline to take sides in the family dispute for now.",
					"trust": 0,
					"standing": 0,
					"response": "You step back. The dispute continues unresolved, awaiting your counsel.",
					"reward_key": "",
					"memory": ""
				}
			],
			"repair": {
				"id": "repair_promise",
				"text": "Acknowledge your failure to Edda and fulfill a concrete replacement service at your own expense.",
				"trust": 25,
				"standing": 0,
				"response": "Edda listens in silence. 'It takes courage to admit a fault and mend it with deeds, not words. I will trust you again, captain.'",
				"reward_key": "edda_ch4_repaired",
				"memory": "Repaired your breach of trust with Edda through honest restitution."
			}
		},
		5: {
			"title": "What We Choose",
			"text": "The seasons have turned, and trust has been tested by fire and bread alike. In the quiet courtyard under the banners, Edda turns to you.\n\n'We have walked a hard road together, captain. Where do we stand now?'",
			"final_reward_key": "edda_ch5_final",
			"final_trust": 10
		}
	},
	"post_project": {
		"id": "empty_chairs",
		"title": "The Empty Chairs",
		"text": "Two household captains dispute the blame for an outpost lost in the border skirmishes. Edda asks if you will help bring them to a common table.",
		"choices": [
			{
				"id": "mediate",
				"text": "Convene both captains, hear their accounts, and draft a mutual patrol division.",
				"response": "The dispute is laid to rest with honor intact. Both captains pledge mutual vigilance.",
				"reward_key": "edda_post_empty_chairs",
				"standing_gain": 5
			}
		]
	}
}

const FARAH_STORY := {
	"title": "Words With Their Own Weight",
	"chapters": {
		1: {"title": "A Carefully Plain Introduction",
			"text": "In a shaded audience room at Qasr Hamra, Farah has crossed out the opening of a trade letter three times. She looks up with a rueful smile.\n\n'Every greeting sounds like a promise when two borders are armed,' she says. 'I would prefer to begin with the truth, but everyone has supplied me with a different one.'",
			"choices": [
				{"id": "work", "text": "Ask what keeps the road open despite the war.", "response": "Farah turns the letter toward you. 'Names. Bakers, drovers, widows, guards. A treaty survives when it remembers who needs the road tomorrow.'"},
				{"id": "boast", "text": "Offer your victories as proof that your word carries weight.", "response": "'A victory makes people listen,' Farah says. 'What you say once they are quiet will tell me rather more.'"},
				{"id": "help", "text": "Offer to carry a message without embellishing it.", "response": "Her expression brightens. 'A courier who does not improve the message may be the rarest ally in Kharzan.'"}
			],
			"intent_prompt": "As the audience ends, what do you want Farah to understand?",
			"intent_choices": [
				{"id": "know_better", "intent": "romantic", "text": "I would like to hear what you say when no court is listening.", "response": "Farah holds your gaze. 'Then return when I have no speech prepared. I warn you: I may be disappointingly direct.'"},
				{"id": "offer_help", "intent": "friendship", "text": "I would rather become a trusted friend than another obligation.", "response": "'That is a welcome distinction,' she says. 'You may find a place at my table without bringing a petition.'"},
				{"id": "another_time", "intent": "none", "text": "We can speak when the road brings me back.", "response": "'Then I hope it is a kinder road next time.'"}
			]},
		2: {"title": "The Address People Use",
			"text": "Farah shows you two maps of the same market quarter. One carries the official name; the other is marked Crooked Lantern in her own hand. 'Letters reach offices by the first name,' she says. 'People find one another by the second.'",
			"choices": [
				{"id": "villager", "text": "Walk the quarter and record the names residents actually use.", "response": "Farah returns with dust on her hem and six contradictory directions. 'Excellent. It is a completely unusable map and a perfect account of home.'"},
				{"id": "news", "text": "Bring news from merchants separated by the border closure.", "response": "She reads every name twice. 'This is why correspondence matters. Not for the seal—for the answer.'"},
				{"id": "verse", "text": "Ask which place-name she uses when writing to family.", "response": "'Crooked Lantern,' she admits. 'My aunt would reject any letter addressed to somewhere respectable.'"}
			]},
		3: {"title": "A Road Kept Open",
			"text": "Two allied houses have stopped sharing escorts after a public insult. Relief wagons wait behind their quarrel. Farah sets the reports aside. 'Pride can survive a delay. The grain cannot.'",
			"variants": [
				{"id": "fund_muster", "name": "Fund Neutral Escorts", "text": "Place silver in escrow for guards serving both houses.", "response": "Paid under a neutral seal, the escort rides without either house claiming submission."},
				{"id": "defend_district", "name": "Ride the Relief Road", "text": "Guard the first wagons through the disputed crossing.", "response": "The convoy arrives intact, giving both delegations a fact more useful than their grievance."},
				{"id": "correspondence", "name": "Carry Matched Letters", "text": "Deliver Farah's identical proposal to both households.", "response": "Neither side can pretend the other received better terms. The escorts return to the road."}
			]},
		4: {"title": "The Useful Answer",
			"text": "Farah's relatives demand a triumphal agreement that would humiliate the other house. She promised the merchants a workable peace. In council, every face turns toward you before she can answer for herself.",
			"choices": [
				{"id": "negotiate", "text": "Propose equal obligations and let both houses preserve dignity.", "response": "Farah builds on the compromise in her own words. The road opens under a compact neither side must disguise.", "memory": "Helped Farah negotiate a durable equal compact."},
				{"id": "support_edda", "text": "Support Farah's promised relief terms over her family's prestige.", "response": "The elders bristle, but Farah does not soften the promise she made. The merchants receive the protection they were offered.", "memory": "Stood with Farah when her promise challenged family prestige."},
				{"id": "break_promise", "text": "Endorse the family's harsher terms after promising Farah support.", "response": "Farah completes the meeting flawlessly. Only afterward does she say, 'I needed your honest refusal before the council, not your agreement before it.'"},
				{"id": "decline", "text": "Refuse to shape a diplomatic settlement you do not understand.", "response": "The council adjourns without resolution. Farah accepts your caution, though the wagons remain delayed."}
			],
			"repair": {"id": "repair_promise", "text": "Admit the breach and personally fund the relief convoy you endangered.", "response": "Farah accepts the restitution without pretending it erases the choice. 'Trust is not a speech,' she says. 'This is at least a useful sentence.'"}},
		5: {"title": "No Reply Required", "text": "The road is open again. Farah finds you without a letter in her hand.\n\n'I have spent years making every sentence carry someone else's need,' she says. 'I would like this one to belong to me. I am glad you came.'", "final_reward_key": "farid_ch5_final", "final_trust": 10}
	}
}

const KAEDE_STORY := {
	"title": "The Account We Choose",
	"chapters": {
		1: {"title": "An Unfinished Record",
			"text": "In Kitayama's archive, Kaede has placed two contradictory clan accounts side by side. 'Both are accurate about the banners,' she says. 'Neither mentions who opened the gate before the feud became a siege. Omissions are often where trouble waits.'",
			"choices": [
				{"id": "work", "text": "Ask how she separates error from deliberate omission.", "response": "'Patiently, and with less confidence than people expect,' Kaede says. 'Certainty is an attractive annotation. It is not always an honest one.'"},
				{"id": "boast", "text": "Offer a commander's account of how battles are decided.", "response": "Kaede reaches for a clean page. 'Good. Begin with where you stood. Every witness forgets that part first.'"},
				{"id": "help", "text": "Offer to find witnesses beyond the two clan halls.", "response": "'Speak to the ferrymen,' she says at once. 'They remember who crossed before anyone decided what the crossing meant.'"}
			],
			"intent_prompt": "Before you leave the archive, what do you ask of Kaede?",
			"intent_choices": [
				{"id": "know_better", "intent": "romantic", "text": "I would like to know what you choose when the record is only yours.", "response": "Kaede pauses longer than the question requires. 'I am not practiced at answering that. I would like another opportunity.'"},
				{"id": "offer_help", "intent": "friendship", "text": "Let me help as a friend, without claiming a place in the account.", "response": "'A friend still appears in the margins,' she says. 'But I accept the distinction.'"},
				{"id": "another_time", "intent": "none", "text": "I will leave the archive to its work.", "response": "'And I will try not to finish your conclusions for you.'"}
			]},
		2: {"title": "A Map of Useless Places",
			"text": "Kaede shows you a private map without roads or borders. It marks a dry stair, a wall warmed by afternoon sun, and a cat whose attendance is carefully labeled uncertain.",
			"choices": [
				{"id": "villager", "text": "Add a place where townsfolk rest when no official watches.", "response": "Kaede records the bench, then adds, 'Good in late light.' The opinion seems to surprise and please her."},
				{"id": "news", "text": "Ask who first taught her to draw private maps.", "response": "'No one. That was their appeal.' She shows you a childhood plan of three excellent hiding places and one unreliable cupboard."},
				{"id": "verse", "text": "Offer one ordinary place you would mark for yourself.", "response": "Kaede listens without correcting the distance. 'Then it belongs here. This map is allowed to prefer things.'"}
			]},
		3: {"title": "Witnesses at the Ford",
			"text": "The rival clans agree on one fact: neither trusts the other's copy of the old covenant. Kaede needs testimony and a joint defense before the next provocation hardens into violence.",
			"variants": [
				{"id": "fund_muster", "name": "Fund a Joint Watch", "text": "Equip a mixed patrol responsible to both villages.", "response": "The shared watch makes cooperation a daily practice before the council gives it a grander name."},
				{"id": "defend_district", "name": "Hold the Ford", "text": "Guard the disputed crossing against raiders while both clans confer.", "response": "Fighting beside one another gives the rivals a new event they cannot record separately."},
				{"id": "correspondence", "name": "Gather Independent Copies", "text": "Carry requests to temples, ferries and household archives.", "response": "Three incomplete copies overlap around the same promise. Kaede can finally show what none proves alone."}
			]},
		4: {"title": "The Line in Her Hand",
			"text": "The Kitayama council wants Kaede to certify the version that favors their own clan. She promised both villages an honest comparison. The official brush is placed before her.",
			"choices": [
				{"id": "negotiate", "text": "Recommend an amended covenant that states what the surviving records agree upon.", "response": "Kaede drafts a narrow promise both sides can actually keep, and labels every uncertainty rather than hiding it."},
				{"id": "support_edda", "text": "Defend Kaede's refusal to certify a convenient falsehood.", "response": "She signs her own finding. The council loses its easy victory; the villages keep an honest peace."},
				{"id": "break_promise", "text": "Ask Kaede to endorse Kitayama's version for the sake of swift unity.", "response": "Kaede sets the brush down. 'You asked me to make the record useful by making it false. I cannot call that unity.'"},
				{"id": "decline", "text": "Ask for more evidence before either version is accepted.", "response": "The decision waits. Kaede respects the caution, though she cannot promise the clans will remain patient."}
			],
			"repair": {"id": "repair_promise", "text": "Retract your pressure publicly and fund a neutral copying of every surviving record.", "response": "Kaede notes the retraction in the same hand as the original demand. 'A correction must remain visible,' she says. 'Now we can continue.'"}},
		5: {"title": "Room in the Margin", "text": "The new covenant is signed, with its uncertainties left visible. Kaede closes the official box and unrolls her private map.\n\n'This record does not require witnesses,' she says. 'I would still like you to be part of it.'", "final_reward_key": "kaede_ch5_final", "final_trust": 10}
	}
}


static func candidate_data(id: String) -> Dictionary:
	return CANDIDATES.get(id, {})


static func story_data(candidate_id: String) -> Dictionary:
	match candidate_id:
		EDDA: return EDDA_STORY
		FARAH: return FARAH_STORY
		KAEDE: return KAEDE_STORY
		_: return {}
