## Authored candidates, story chapters, dialogue, prerequisites, choices, and reward keys
## for romance and alliance storylines. Pure authored content and definitions.
extends RefCounted

const Cultures = preload("res://scripts/data/cultures.gd")
const Relationships = preload("res://scripts/data/relationships.gd")

const EDDA := "edda"
const FARID := "farid"
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
	FARID: {
		"id": FARID,
		"content_id": FARID,
		"name": "Farid",
		"age": 31,
		"pronouns": "he/him",
		"role": "Envoy of Qasr Hamra",
		"culture": Cultures.KHARZANI,
		"initial_seat": "qasr_hamra",
		"aim": "Keep trade and correspondence open across hostile borders",
		"conflict": "Diplomatic compromise versus family prestige",
		"project": "Reconcile an allied dispute and arrange relief funding",
		"interests": ["cross-border trade", "treaties", "correspondence"],
		"boundaries": ["rejects needless bloodshed", "values discretion"],
		"blurb": "A cultured diplomat working to maintain merchant caravans and fragile pacts through turbulent border conflicts."
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


static func candidate_data(id: String) -> Dictionary:
	return CANDIDATES.get(id, {})


static func story_data(candidate_id: String) -> Dictionary:
	if candidate_id == EDDA:
		return EDDA_STORY
	return {}
