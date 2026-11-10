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
##
## Her voice: brisk, exact and bossy, because she is fond. Short orders (sit, eat, boots
## off), numbers for everything, "Captain". She shows care by counting people in and
## correcting their arithmetic, and says a feeling bluntly or not at all. Under it: the
## winter she was fourteen, Thornwall burned while the lord's riders were away, and her
## mother, the steward, brought forty-one villagers in and did not come in herself.
const EDDA_STORY := {
	"title": "A Place Beneath the Banner",
	"chapters": {
		1: {
			"title": "An Introduction",
			"face": "thoughtful",
			"lead": [{"text": """
In the hall of Ravensford a red-faced cousin is demanding silver for field horses. The woman at the ledger table lets him finish, writes down one number, and turns the book for him to read. He leaves without the silver.

Edda: Next. You're the sellsword. Don't stand on the rushes, they're fresh. How many are you, how many can still walk, and when did they last eat?
""", "options": [
				{"say": "Is this how Ravensford greets everyone?", "tone": "tease", "face": "amused", "reply": """
Edda: Only the ones who arrive armed. The others I ask about their feet.

Edda: I'm Edda. I keep this house's books, its stores and its temper. You'll deal with me whether you ask for the lord or not, so we may as well begin.
"""},
				{"say": "Ninety-odd. Most can walk. Yesterday.", "tone": "share", "reply": """
Edda: Yesterday.

She says it the way other people say 'plague', and has a boy sent to the kitchens before you can object.

Edda: I'm Edda. I keep this house's books and its stores. A company that tells me the truth about its bellies, I can work with.
"""},
			]}],
			"text": """
Edda: Now. I've forty hearths in Thornwall and thirty in Kettlebrook, a lord who counts horses, and raiders who count on that. What do you want with Ravensford, Captain?
""",
			"choices": [
				{"id": "work", "text": "What do you do here, when you're not frightening cousins?", "tag": "ask about her work", "face": "thoughtful",
					"response": """
Edda: I count. Grain in, grain out, who's hungry, who's lying about it.

Edda: Thornwall has burned twice in my lifetime. Both times the lord's riders were away winning something. So I count the villages too, every night, since nobody with a banner does.
"""},
				{"id": "boast", "text": "You'll have heard of my company. We don't lose.", "tag": "talk of your victories", "face": "amused",
					"response": """
Edda: I've heard. I've also heard what victories cost the farms they're won on.

Edda: Renown is good coin with lords, Captain. Spend it on them. Here you'll be judged by whether Kettlebrook still has a roof when you ride out.
"""},
				{"id": "help", "text": "If the household needs hands, mine are for hire. Or for free, depending.", "tag": "offer help", "face": "warm",
					"response": """
She puts her pen down. It is the first time she has.

Edda: 'Depending.' Good. A captain who leaves the price open has thought about what the work's worth.

Edda: I'll hold you to it when the winter stores need guarding. I hold people to things. Ask anyone.
"""}
			],
			"intent_prompt": "She has pushed the bread across the table and is waiting. What do you mean to be to her?",
			"intent_choices": [
				{"id": "know_better", "intent": "romantic", "text": "I'd like to know you. Not the ledgers. You.", "tag": "court her", "face": "warm",
					"response": """
For once she has no number ready.

Edda: Me. Nobody rides to Ravensford for me, Captain. They come for grain, or my signature, or my cousin's ear.

Edda: Come back, then, when the roads allow. Eat first. I'm told I'm better company to people who've eaten.
""",
					"memory": "The day I asked to know Edda better."},
				{"id": "offer_help", "intent": "friendship", "text": "I came to offer my sword to your villages. As a friend.", "tag": "as a friend", "face": "warm",
					"response": """
Edda: A friend. With a sword, who asks nothing.

She looks you over for the catch, finds none, and seems faintly annoyed about it.

Edda: Then there's a place at my table. Use it. I don't set places for show.
""",
					"memory": "The day I offered Edda my friendship."},
				{"id": "another_time", "intent": "none", "text": "We'll speak another time, steward.", "tag": "nothing decided yet", "face": "neutral",
					"response": """
Edda: We will. Take the bread; I'm not carrying it back. Fair roads, Captain.
""", "memory": "A first word with Edda, and nothing promised."}
			],
			"reward_key": "edda_ch1_intro",
			"trust_reward": 10,
			"standing_reward": 0
		},
		2: {
			"title": "Something of Your Own",
			"face": "thoughtful",
			"lead": [{"text": """
Edda is on the steps outside the hall with a bundle of parish records on her knee, the paper soft from too many hands. She has a pen behind her ear and has forgotten it.

Edda: Sit. Not there, that's the damp one. I'm copying out Thornwall. Births, weddings, who owed whom a pig. The hall burned with the first book in it, so this is the second, and half of it is what old women remembered.

Edda: When raiders fire a village the lords count the houses. Nobody counts the songs. Somebody ought to.
""", "options": [
				{"say": "Why you? You've a household to run.", "tone": "ask", "face": "concerned", "reply": """
Edda: Because I can write and they can't. And because I was there.

Edda: I was fourteen. I carried buckets. I remember what the smith's wife was singing to her youngest while the roof went, and I've never found anyone else who knew the rest of it.
"""},
				{"say": "You've a pen behind your ear.", "tone": "tease", "face": "amused", "reply": """
She finds it, looks at it as though it had enlisted without telling her, and puts it back.

Edda: It lives there. Don't distract me, I'm being grave.

Edda: I was fourteen when Thornwall burned. I carried buckets. I'd like something of that village to exist that isn't a list of what it lost.
"""},
			]}],
			"text": """
Edda: You've been up and down that border more than I have this year. Bring me something for the book, Captain. Anything true.
""",
			"choices": [
				{"id": "villager", "text": "Old Martha at Thornwall still remembers. I'll ride and write it down.", "tag": "ride to Thornwall for the elder's account", "face": "warm",
					"response": """
You come back with four pages in a soldier's handwriting. Edda reads them standing up.

Edda: The flood of forty years ago. The names of the oxen. She told you the names of the oxen.

Edda: She's never told me. I've asked for six years. You must have sat still a very long time.

She copies it into the book herself, slowly, and corrects your spelling without a word.
""",
					"memory": "The elder's account from Thornwall, written down before it was lost."},
				{"id": "news", "text": "The families from the ford. I have news of them.", "tag": "bring word of the border families", "face": "warm",
					"response": """
Edda: Say it quickly.

You: Safe. All of them, across the water and under a roof.

Her shoulders come down an inch. Her face takes a moment longer to be told.

Edda: Nineteen people. I've had them in the book in pencil since the thaw.

She inks them in, one name at a time, and you watch her count them twice.
""",
					"memory": "Word that the families from the ford were safe."},
				{"id": "verse", "text": "There's a verse they sing in the hills. I never understood the last line.", "tag": "share a verse of the hills", "face": "amused",
					"response": """
You say what you remember. She listens with her head on one side, and then, quietly and not at all well, sings the stanza that answers it.

Edda: That's the smith's wife's song. The last line's about bread rising. You'd have to have kept a house to hear it.

Edda: You listen between the drums, Captain. I didn't expect that of a sellsword. Write it in. Your hand, not mine; you found it.
""",
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
			"lead": [{"text": """
The hall is loud with a muster. Edda is not in it. She is in the still-room with the door shut and both hands flat on the table.

Edda: He's taking the riders. All of them, south, for the lord's quarrel. I asked him to leave me twenty for the villages. He told me to be reasonable.

Edda: I've been reasonable for twelve years, and Thornwall has burned twice.
""", "options": [
				{"say": "What happens to the villages?", "tone": "ask", "reply": """
Edda: What always happens. A horn, and nobody behind it. They'll hold a day because they're stubborn, and then they won't.

Edda: I can't order one rider in this house, Captain. I can only feed them.
"""},
				{"say": "You're shaking.", "tone": "comfort", "reply": """
Edda: I'm angry. It looks the same from outside.

She takes her hands off the table and looks at them as if they had spoken out of turn.

Edda: I carried buckets the last time. I won't stand in a yard and carry buckets again.
"""},
			]}],
			"text": """
Edda: I don't ask for things. I arrange them. So understand what it costs me to say this: I need help, and you're the only armed company within a week's ride that isn't his.
""",
			"variants": [
				{"id": "fund_muster", "name": "Sponsor Replacements", "text": "Then I'll pay for the muster.", "tag": "into the district's fund", "face": "warm",
					"response": """
You count the silver out on her still-room table. She counts it after you, which you are learning not to mind.

Edda: Forty spears, for a season. Local men, so they'll fight for their own thatch.

Edda: I'll see every one of them fed and shod, and I'll write your name in the book where the lord's ought to be. I don't do that lightly. I've never done it at all.
""",
					"memory": "The muster I paid for, standing watch over the villages."},
				{"id": "defend_district", "name": "Defend the Valley", "text": "We'll hold the valley ourselves.", "tag": "your company guards Ravensford's roads", "face": "warm",
					"promise": """
Edda: Then the valley roads are yours until the raiders are gone. Thornwall first. They always come for Thornwall first; it's nearest the ford.

Edda: And Captain. Come back with the number you ride out with. I'll be counting.
""",
					"response": """
Edda: They came for Thornwall, and you were in the road. The miller's boy ran the whole way here to tell me, and couldn't speak for laughing.

Edda: The village met your company with bread. They'll tell it at the hearth for forty years, and they'll get your name wrong.

Edda: I won't. I've been at the gate every dusk since you left, counting. Don't ever tell the household.
""",
					"memory": "The day the company held the valley."},
				{"id": "correspondence", "name": "Broker an Accord", "text": "Give me the letters. I ride tonight.", "tag": "carry word to the allied houses", "face": "amused",
					"promise": """
She has them written already. Of course she has. The wax is still soft.

Edda: Three houses, three letters, one reply from each. Don't let anyone talk you into carrying a fourth; they'll try.

Edda: And eat on the road. I've put something in your saddlebag. Don't look at me like that.
""",
					"response": """
Edda: Three pledges. Grain from one, spears from two, and nobody insulted. I'd have bet the ledgers against it.

Edda: I asked you to carry letters, and you carried them, and didn't improve them, and came back. You've no idea how rare that is.

Edda: The saddlebag came back empty. Good.
""",
					"memory": "The letters I carried, and the pledges that came back."}
			],
			"reward_key": "edda_ch3_shared",
			"trust_reward": 15,
			"standing_reward": 15
		},
		4: {
			"title": "Between Two Loyalties",
			"face": "concerned",
			"text": """
The council has been shouting for an hour. The lord wants every rider for the march south and the valley stripped of guards. Edda has asked, for the third time, for a garrison. She has not raised her voice once, which is how you know how angry she is.

Then the lord turns to you: the only soldier in the room that nobody here pays.

Edda: Say what you think, Captain. Not what he wants to hear. And not what I do. I'll know the difference.
""",
			"choices": [
				{"id": "negotiate", "text": "Keep a garrison here and send the rest. Neither of you gets everything.", "tag": "a compromise · Edda and the house both content", "face": "thoughtful",
					"trust": 15, "standing": 10,
					"response": """
The hall grumbles, and then, because it is a soldier saying it, listens. Thirty stay. The rest march.

Edda finds you afterwards in the passage.

Edda: Half of what I asked for. And all of what the valley needed. I checked the numbers while he was still shouting. You'd done them in your head, hadn't you.

Edda: Don't look pleased. I'm going to make you do my sums from now on.
""",
					"reward_key": "edda_ch4_negotiate", "memory": "The compromise I spoke for in the council."},
				{"id": "support_edda", "text": "The valley comes first. I stand with Edda.", "tag": "Edda's trust · the elders' displeasure", "face": "warm",
					"trust": 15, "standing": -10,
					"response": """
The elders scowl. The lord goes the colour of his own wine. Edda does not look at you at all, and stands an inch taller.

Afterwards, in the passage, she takes hold of your sleeve, and lets go of it again.

Edda: You've made enemies in that hall. Powerful, petty ones.

Edda: Nobody has ever done that for me. Stood up, in front of them. I've always had to be right quietly.

Edda: I'll make up the difference, Captain. In grain, in votes, in whatever it takes. I keep accounts.
""",
					"reward_key": "edda_ch4_support", "memory": "The day I stood with Edda against the hall."},
				{"id": "break_promise", "text": "The house head is right. We march.", "tag": "breaks your word to Edda · the house's favour", "face": "concerned",
					"trust": -10, "standing": 10, "strained": true, "strained_reason": "broken_promise",
					"response": """
The elders cheer. Edda does not argue. She closes the ledger, very gently, the way one shuts a door on a sleeping child, and walks out of the hall.

She does not look at you. You had given her your word.
""",
					"reward_key": "edda_ch4_breach", "memory": "The council where I broke my word to Edda."},
				{"id": "decline", "text": "I won't choose between you today.", "tag": "nothing decided", "tone": "plain", "face": "thoughtful",
					"trust": 0, "standing": 0,
					"response": """
You step back. The shouting takes up again without you. Edda's eyes stay on you a moment longer than the lord's do, and you cannot tell what she is adding up.
""",
					"reward_key": "", "memory": ""}
			],
			"repair": {"id": "repair_promise", "text": "I failed you in the hall. Let me make it right, at my own cost.", "tag": "mends it", "face": "thoughtful",
				"trust": 25, "standing": 0,
				"response": """
Edda hears you out without a word, and lets the silence run on afterwards. She has a gift for silences; she keeps them like accounts.

Edda: I wrote it down, you know. The day, and what you said. I meant to keep it against you.

Edda: Deeds, then. Not speeches. I'll trust you again, Captain. Slowly, and I'll be checking the sums.
""",
				"reward_key": "edda_ch4_repaired", "memory": "The debt I paid to mend my word to Edda."}
		},
		5: {
			"title": "What We Choose",
			"face": "warm",
			"text": """
Evening, and the courtyard under the banners is empty for once. Edda has no ledger with her. You have never seen her without one; it makes her look as though she has come out without a coat.

Edda: I've been trying to enter you in the books, Captain. I can't find the column. You're not a cost and you're not a store. You're not a debt, though heaven knows I owe you.

Edda: I don't like a thing I can't put a name to. So. What are we?
""",
			"final_choices": [
				{"id": "marry_public", "text": "Marry me. Before your house and everyone.", "tag": "before her house", "face": "warm",
					"response": """
Edda: Yes. Obviously, yes. Did you think I'd need to check something?

She is laughing, and wiping her eyes with the heel of her hand like someone annoyed to find them wet.

Edda: Give me a moment. I'm going to need a list.
"""},
				{"id": "marry_private", "text": "Let's make our vows quietly. Just us.", "tag": "tonight, by one candle · her house not asked", "face": "warm",
					"response": """
Edda: No cousins. No speeches, no seating, no aunt asking about the linen. Just you.

Edda: I could weep. I think I'm going to. Don't tell the household; they believe I can't.
"""},
				{"id": "friendship", "text": "Let's swear friendship, and stand by each other's houses.", "tag": "a pact between your houses", "face": "warm",
					"response": """
Edda: A pact. Your house and mine, in ink. Done. I'll have it written tonight, and I'll have it kept, and anyone who breaks it answers to my arithmetic.

She puts out her hand like a merchant. Then she does not let go of yours quite as quickly as a merchant would.
"""},
				{"id": "remain_close", "text": "Let's stay close, and let time decide.", "tag": "no promises yet", "face": "thoughtful",
					"response": """
Edda: Time's a poor steward. It loses things.

Edda: But all right. I'll keep the chair, and the place, and I'll go on counting you in. That much I can do without a name for it.
"""},
				{"id": "part_respectfully", "text": "I think our roads part here.", "tag": "for good", "face": "concerned",
					"response": """
Edda: Then go well, Captain.

She says it steadily. She has had practice at people riding out.

Edda: The book will say you were here. So will I.
"""}
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
		"text": """
Edda: Two chairs. Every supper for a month. Look at them.

Two of the household's captains each blame the other for an outpost lost on the border. Neither will sit at a table with the other, and the hall eats around the gap.

Edda: They'll listen to you. They've never listened to me; I'm the woman who counts their boots. They'll regret that at harvest, but I'd rather they simply sat down.
""",
		"choices": [
			{"id": "mediate", "text": "Sit them down together. I'll hear both accounts and draw the patrols up between them.", "tag": "a common table", "face": "warm",
				"response": """
It takes an evening. You hear each of them out alone, and then together, and then you draw the patrols so that neither can call the other's ground his own.

Edda: Two chairs, filled. Do you know how long I've—

Edda: I'm putting it in the ledger in red. So it stands out. So I can find it on bad days.
""",
				"reward_key": "edda_post_empty_chairs", "standing_gain": 5,
				"memory": "The night I brought the household's captains back to one table."},
			{"id": "sergeant", "text": "Put my sergeant between them for a season. He's outlasted worse.", "tag": "lend them your sergeant", "face": "amused",
				"response": """
Your sergeant rides their patrols for a month and tells each captain, in the same words, that he is exactly as useless as the other. They stop blaming each other. They start blaming him.

Edda: United against your sergeant. I'll take it. Send him a ham.
""",
				"reward_key": "edda_post_empty_chairs", "standing_gain": 5,
				"memory": "The month my sergeant rode the household's patrols."}
		]
	}
}

## Authored story chapters for Farah ("Words With Their Own Weight").
##
## Her voice: quick, playful and practised. She guesses about you aloud, tries names on you,
## answers a question with a better one, and flirts as a reflex because it is her trade.
## When she means a thing it comes out short, and startles her. Under it: she has been the
## family's smile since she was thirteen; the first truce she wrote alone held eleven days,
## and her brother Idris was on the road when it failed.
const FARAH_STORY := {
	"title": "Words With Their Own Weight",
	"chapters": {
		1: {"title": "A Carefully Plain Introduction", "face": "thoughtful",
			"lead": [{"text": """
A shaded audience room at Qasr Hamra, and a woman at a writing desk who does not get up. She has crossed out the opening of a letter three times and is smiling at the fourth.

Farah: Don't tell me. Let me guess. Sellsword; a good one, the boots are too well kept for a bad one. Here about the road. And somebody told you the envoy is a dragon.

Farah: I'm Farah. The dragon is my uncle. I'm the one they send out to smile.
""", "options": [
				{"say": "You guessed all that from boots?", "tone": "ask", "face": "amused", "reply": """
Farah: From boots, and from a letter that reached me two days before you did. I always cheat, Captain. It saves so much time.

Farah: You'll notice I told you so. That's the part people find confusing.
"""},
				{"say": "They said you were charming. They undersold it.", "tone": "tease", "face": "amused", "reply": """
Farah: Oh, very good. Quick, and almost sincere.

She makes a small mark at the corner of her page, as though scoring a point to you.

Farah: I should warn you that I do this for a living. You're flirting with a professional. You'll lose, and enjoy it.
"""},
			]}],
			"text": """
Farah: Now. Two armed borders, one road between them, and every greeting I write sounds like a promise to somebody. Why have you come to make my morning interesting?
""",
			"choices": [
				{"id": "work", "text": "What keeps the road open, with a war on either side of it?", "tag": "ask about the road", "face": "thoughtful",
					"response": """
Farah turns the letter so that you can read it. It is a list of names.

Farah: These. A baker, six drovers, a widow who sells rope, a boy who minds mules. Lords close roads. These are the people who need it open tomorrow.

Farah: I write to the lords. I write for them. It's a small trick, but it's my best one.
"""},
				{"id": "boast", "text": "My word carries weight. I've won enough to make sure of it.", "tag": "offer your victories as proof", "face": "amused",
					"response": """
Farah: I'm sure it does. A victory makes a room go quiet.

Farah: It's what you say once it's quiet that I'm curious about, Captain. Most people, I find, have prepared nothing.
"""},
				{"id": "help", "text": "If you need a message carried, I'll carry it. Word for word.", "tag": "offer to carry a message", "face": "warm",
					"response": """
The smile changes. It becomes, briefly, an expression instead of an instrument.

Farah: Word for word. You wouldn't improve it? Soften a line, add a compliment, leave out the part that will make someone shout?

Farah: A courier who doesn't edit. You may be the rarest creature in Kharzan. I'm tempted to have you stuffed.
"""}
			],
			"intent_prompt": "She has put down her pen and is waiting to see what you will ask for. Everyone asks her for something.",
			"intent_choices": [
				{"id": "know_better", "intent": "romantic", "text": "I'd like to hear what you say when no court is listening.", "tag": "court her", "face": "warm",
					"response": """
For the space of a breath she has nothing ready. You have the impression that does not happen often.

Farah: Careful, Captain. That isn't a thing people ask me. They ask what I can get them.

Farah: Come back when I've no speech prepared, then. I warn you: without one, I'm told I am alarmingly direct.
""",
					"memory": "The day I asked Farah what she says when no court is listening."},
				{"id": "offer_help", "intent": "friendship", "text": "I'd rather be a friend you can trust than another obligation.", "tag": "as a friend", "face": "warm",
					"response": """
Farah: A friend. With no petition up your sleeve.

She actually looks. You show her your empty hands, and she laughs out loud.

Farah: Then you've a place at my table, and I shan't ask what you want with it. That's the highest courtesy I own.
""",
					"memory": "The day I offered Farah my friendship."},
				{"id": "another_time", "intent": "none", "text": "We'll speak when the road brings me back.", "tag": "nothing decided yet", "face": "neutral",
					"response": """
Farah: Then I hope it's a kinder road next time. Go carefully, Captain. I've only just started guessing about you.
""", "memory": "A first audience with Farah, and nothing promised."}
			]},
		2: {"title": "The Address People Use", "face": "amused",
			"lead": [{"text": """
Farah has two maps of the same market quarter spread across the desk, one corner held down by a cup of something that has gone cold.

Farah: Look at these and tell me which is true. This is the surveyor's: South Market Street, measured to the pace. This one is mine. It says Crooked Lantern, and 'turn where the spice seller sings badly'.
""", "options": [
				{"say": "The second. I could find my way by it.", "tone": "share", "reply": """
Farah: Yes! Thank you. I have had this argument with four ministers.

Farah: Letters reach offices by the first name. People find one another by the second. I grew up on Crooked Lantern. I didn't know it had another name until a clerk corrected my own address.
"""},
				{"say": "Is the singing really that bad?", "tone": "tease", "reply": """
Farah: It's a civic landmark. Ships steer by it.

Farah: I grew up on that street. I didn't learn it had an official name until a clerk corrected my own address. I've held it against the surveyor ever since.
"""},
			]}],
			"text": """
Farah: I've lived in audience rooms since I was thirteen, Captain. I know every title in this city, and I've half forgotten what people call their own doors. Help me remember something.
""",
			"choices": [
				{"id": "villager", "text": "Show me the quarter. I'll write down what people actually call things.", "tag": "walk the quarter with her", "face": "amused",
					"response": """
She walks you through it at a pace no envoy should manage, greeting people by name and being corrected about their children. You write. By the end you have six contradictory sets of directions and dust to the knee.

Farah: Look at it. Completely unusable. It's the best account of home I've ever seen.

Farah: Nobody has walked me down that street in ten years, Captain. I've been carried through it in a chair.
""",
					"memory": "The map of the quarter, with the names people actually use."},
				{"id": "news", "text": "The merchants cut off by the closure. I've news of them.", "tag": "bring news from across the border", "face": "warm",
					"response": """
She reads every name twice, one finger moving under the line like a child's.

Farah: Alive. And the rope-seller's still cheating on the measure. Oh, that's wonderful.

Farah: This is what the letters are for. Not the seal. The answer. I'd forgotten how it felt to get one.
""",
					"memory": "News of the merchants across the closed border."},
				{"id": "verse", "text": "Which name do you use when you write home?", "tag": "ask about her letters home", "face": "amused",
					"response": """
Farah: Crooked Lantern. My mother sends back anything addressed to a respectable street. She says no daughter of hers lives in an office.

The laugh fades into something she doesn't dress up.

Farah: I do, though. Live in an office. You're the first person in a long while to ask where home was.
""",
					"memory": "The name she writes on letters home."}
			]},
		3: {"title": "A Road Kept Open", "face": "concerned",
			"lead": [{"text": """
Farah is not smiling. It takes you a moment to work out what is different about the room.

Farah: Two houses, one insult at a wedding, and now neither will lend the other an escort. There are forty relief wagons standing at the border with the grain going damp.

Farah: I've written to both. Beautiful letters. They each wrote back to say how beautiful.
""", "options": [
				{"say": "What was the insult?", "tone": "ask", "reply": """
Farah: Someone was seated below a salt-merchant. I wish I were joking.

Farah: People will starve over a chair, Captain. I've seen them do it for less.
"""},
				{"say": "You're frightened.", "tone": "comfort", "reply": """
Farah: I'm an envoy. I'm concerned, with a furrowed brow.

Farah: Yes. A truce of mine failed once, and the wagons on the road when it failed weren't empty. I don't intend to learn that twice.
"""},
			]}],
			"text": """
Farah: Pride will keep. Grain won't. I can't order a single spear, and I've run out of adjectives. What have you got?
""",
			"variants": [
				{"id": "fund_muster", "name": "Fund Neutral Escorts", "text": "I'll pay for guards who serve neither house.", "tag": "under a neutral seal", "face": "warm",
					"response": """
You pay, under a seal that belongs to nobody, and the wagons roll with neither house able to say the other bowed.

Farah: Do you know what you've bought? A silence both of them can live inside. I've been trying to write one for a month.

Farah: You did it with a purse. I'm trying not to be insulted.
""",
					"memory": "The neutral escort I paid for."},
				{"id": "defend_district", "name": "Ride the Relief Road", "text": "My company will take the first wagons through.", "tag": "guard the crossing yourself", "face": "amused",
					"promise": """
Farah: Then the wagons move when you do. I've told the drovers to look for your banner. I've also told them not to sing; they sing terribly, and you'd turn back.

Farah: Captain. Bring them in. And yourself with them; I've grown used to guessing about you.
""",
					"response": """
Farah: Forty wagons. I stood on the wall and counted like a merchant's wife.

Farah: Both delegations came down to the market to look at the grain, and stood next to each other without noticing. Nobody can argue with a loaf.

Farah: I prepared a speech of thanks. It was very fine. I find I'd rather just tell you that I was afraid, and now I'm not.
""",
					"memory": "The first wagons through the crossing."},
				{"id": "correspondence", "name": "Carry Matched Letters", "text": "Write it once. I'll carry the same words to both doors.", "tag": "deliver her proposal to both houses", "face": "thoughtful",
					"promise": """
She writes it once. She copies it once, and holds the two against the window to see that not a stroke differs.

Farah: Identical. If either house asks what the other was offered, hand them the other letter. Let them read it.

Farah: It's the plainest thing I've ever sealed. I feel slightly undressed.
""",
					"response": """
Farah: Neither could pretend the other got better terms, so neither could refuse without looking the smaller house. The escorts are back on the road.

Farah: I'm told it's an insult to tailor nothing. I've been tailoring since I was thirteen.

Farah: You carried them word for word, as you said you would that first day. I remember what people say to me, Captain. It's rarely an advantage. This time it was.
""",
					"memory": "The two identical letters I carried."}
			]},
		4: {"title": "The Useful Answer", "face": "concerned",
			"text": """
Her family's council, and her uncle in the high seat. They want a triumphal treaty: the other house on its knees, in writing. Farah promised the merchants a peace that would hold. She is standing, composed, her smile fixed on like a brooch.

Before she can speak, every face in the room turns to you.

Farah: The captain has the floor. I would have preferred to keep it, but it seems I'm furniture this morning.
""",
			"choices": [
				{"id": "negotiate", "text": "Equal obligations on both sides, and both houses keep their dignity.", "tag": "a compromise · Farah and her family both content", "face": "thoughtful",
					"response": """
You say it plainly, and stop. Into the gap Farah speaks: your bare terms in her words, each one turned so that her uncle can call it a victory. The council hears reason, and believes it thought of it.

Farah: You left me room to finish the sentence.

Farah: Do you know how rare that is? People hand me their conclusions and ask me to make them pretty. You handed me a beginning.
""",
					"memory": "The equal compact I proposed in council."},
				{"id": "support_edda", "text": "Farah promised the merchants relief. I'll hold the house to her word.", "tag": "Farah's trust · her family's displeasure", "face": "warm",
					"response": """
The elders bristle. Her uncle says something about sellswords and manners. Farah does not soften one syllable of what she promised, and for the first time in that room she is not smiling.

Afterwards, in the corridor, she leans on the wall as if it had been holding her up for years.

Farah: My family will forgive you eventually. They forgive anyone useful.

Farah: You took my word seriously. In front of them. Nobody does that, Captain. They take my phrasing seriously.
""",
					"memory": "The day I held her family to Farah's promise."},
				{"id": "break_promise", "text": "Her family's terms are stronger. Take the harsher ones.", "tag": "breaks your word to Farah · her family's favour", "face": "concerned",
					"response": """
Farah finishes the council without a flaw. She thanks you, by name, in front of them all. Her smile never moves.

Only afterwards, alone:

Farah: I needed your honest refusal before that council. Not your agreement in front of it.

Farah: I'm very good at being agreed with in public, Captain. I had thought you were for the other thing.
""",
					"memory": "The council where I broke my word to Farah."},
				{"id": "decline", "text": "I don't understand this settlement well enough to shape it.", "tag": "nothing decided", "tone": "plain", "face": "thoughtful",
					"response": """
The council adjourns with nothing decided. Farah inclines her head to you: no reproach, and no smile either.

Farah: Honest. Inconvenient, and honest. The wagons will wait a little longer. So, it seems, shall I.
""", "memory": ""}
			],
			"repair": {"id": "repair_promise", "text": "I broke my word in that council. The convoy I put at risk, I'll pay for.", "tag": "mends it", "face": "thoughtful",
				"response": """
Farah takes the restitution and counts it, which she has never done in front of you before.

Farah: I'm not going to say it's nothing. I say that for a living, and I'd like not to say it to you.

Farah: Trust isn't a speech, Captain. This is at least a useful sentence. Give me time to believe the rest of the paragraph.
""",
				"memory": "The convoy I paid for, to mend my word to Farah."}},
		5: {"title": "No Reply Required", "face": "warm",
			"text": """
The road is open. Farah finds you on the wall above it at dusk, and for once there is nothing in her hands: no letter, no cup, no fan.

Farah: I had a speech. Naturally. Three movements and a graceful exit. I threw it in the brazier on the way up.

Farah: Since I was thirteen, every sentence I've spoken has carried somebody else's need. This one is mine. I'm glad you came. Not for the road. I'd be glad if there were no road.

Farah: There. No exits. Your turn, Captain, and I've no idea what you'll say. It's horrible. I rather like it.
""",
			"final_choices": [
				{"id": "marry_public", "text": "Marry me. Before your house, in front of all of them.", "tag": "before her house", "face": "warm",
					"response": """
Farah: Yes. I had an answer prepared for this. Elegant. A little coy. It's gone. It's entirely gone.

She is laughing, and holding on to your coat with both hands.

Farah: In front of my uncle. Oh, his face. Yes. Yes.
"""},
				{"id": "marry_private", "text": "Let's make our vows quietly. No court.", "tag": "tonight, by one candle · her house not asked", "face": "warm",
					"response": """
Farah: No court. No speeches, no seals, nobody deciding what it means for the grain tariff.

Farah: Yes. Tonight, before I think of a clause.
"""},
				{"id": "friendship", "text": "Let's swear friendship between our houses.", "tag": "a pact between your houses", "face": "amused",
					"response": """
Farah: A pact between houses. Then I'll draft it badly, on purpose, with a blot, so that nobody ever mistakes it for a treaty. It isn't for them.

She offers you her hand, and not the way envoys do.
"""},
				{"id": "remain_close", "text": "Let's stay close, and see what the road brings.", "tag": "no promises yet", "face": "thoughtful",
					"response": """
Farah: The road has been kind to me lately. Against all precedent.

Farah: I'll allow it one more decision. Only one. Then I shall start drafting.
"""},
				{"id": "part_respectfully", "text": "I think this is where we part.", "tag": "for good", "face": "concerned",
					"response": """
Farah: Ah.

The smile comes back. You had not noticed, until now, that it had been gone for months.

Farah: Then fair roads, Captain. I meant it the first day, and I mean it now. I'll keep yours open.
"""}
			],
			"final_reward_key": "farid_ch5_final", "final_trust": 10}
	},
	"post_project": {
		"id": "blank_clause",
		"title": "The Blank Clause",
		"face": "thoughtful",
		"text": """
Farah: Come and look at this. It's the best thing I've ever not written.

The merchants want the compact renewed. Both houses want a clause naming the other as the cause of the closure. Where the clause would go, Farah has left a hand's breadth of empty parchment.

Farah: I could put something exquisite there. I'd rather they both agreed, in writing, to say nothing at all. I can't do it alone. They hear me coming.
""",
		"choices": [
			{"id": "mediate", "text": "Ride with me to both houses. We'll ask each for the same silence.", "tag": "ask both houses together", "face": "warm",
				"response": """
Two halls, two days, the same objection twice. You stand beside her and say nothing clever, which seems to unsettle both houses more than argument would. Each agrees to leave the space blank once it is sure the other will.

Farah: A treaty with a hole in it. It's the most honest thing I've ever sealed. I want it framed. I want it over the bed.
""",
				"reward_key": "farid_post_blank_clause", "standing_gain": 5,
				"memory": "The clause we persuaded both houses to leave blank."},
			{"id": "escort", "text": "My company takes the first guild caravan through, under both seals.", "tag": "escort the guild's caravan", "face": "amused",
				"response": """
The caravan goes through under two seals and one banner, which is yours. By the time either house thinks to argue precedence, the goods are sold and the drovers are drunk.

Farah: Nobody can quarrel over a market that's already open. I should have married a convoy years ago.

Farah: Don't look so smug. You're only slightly better than a convoy.
""",
				"reward_key": "farid_post_blank_clause", "standing_gain": 5,
				"memory": "The guild caravan that went through under both seals."}
		]
	}
}

## Authored story chapters for Kaede ("The Account We Choose").
##
## Her voice: level, literal and exact. She states observations and how sure she is of
## them, corrects before she comforts, and takes notes on you in front of you. She does
## not make jokes; she says true things that are funny, and notices afterwards. Under it:
## she was given to the archive at seven, a pledge-child, after the siege in which someone
## opened the lower gate. It was her father. No account names him.
const KAEDE_STORY := {
	"title": "The Account We Choose",
	"chapters": {
		1: {"title": "An Unfinished Record", "face": "thoughtful",
			"lead": [{"text": """
Kitayama's archive is cold and smells of cedar. The archivist does not look up. She has two scrolls open side by side and a brush stuck through her hair.

Kaede: You are standing in my light. Two steps left. Thank you.

Kaede: Mercenary captain. Arrived at the lower gate before noon, did not haggle over stabling, was polite to the porter. I have it written down. You may sit, if you touch nothing.
""", "options": [
				{"say": "You wrote down that I was polite?", "tone": "ask", "reply": """
Kaede: It was unusual. Unusual things are recorded.

Kaede: I am Kaede. I keep this archive. People believe that means I keep the past. It means I keep what somebody chose to write down, which is a different and smaller thing.
"""},
				{"say": "You've a brush in your hair.", "tone": "tease", "face": "amused", "reply": """
Kaede: I have three. I am aware of two.

She finds the third, inspects it, and returns it to her hair as the most efficient place for it.

Kaede: I am Kaede. I keep this archive. You are the first visitor this month to notice anything in it but the dust.
"""},
			]}],
			"text": """
Kaede: Look here. Two clans' accounts of the same siege. Both are exact about the banners. Neither says who opened the lower gate before the feud became a slaughter. Omissions are where trouble waits.

Kaede: State your business. Then I shall decide whether to record it.
""",
			"choices": [
				{"id": "work", "text": "How do you tell an error from a lie?", "tag": "ask about her work", "face": "thoughtful",
					"response": """
Kaede: Slowly. An error is careless everywhere. A lie is careful in exactly one place.

Kaede: And with less certainty than people want from me. Certainty is an attractive annotation, Captain. It is not always an honest one.
"""},
				{"id": "boast", "text": "I've decided a few battles. I can tell you how they're really won.", "tag": "offer a commander's account", "face": "amused",
					"response": """
Kaede takes a clean sheet at once. She does not appear to have noticed that you were boasting.

Kaede: Good. A primary source. Begin with where you stood, and what you could see from there. Every witness leaves that out, and it is the only part I can use.

Kaede: Slowly. I write faster than you remember.
"""},
				{"id": "help", "text": "There'll be witnesses outside the two halls. I can find them.", "tag": "offer to find witnesses", "face": "warm",
					"response": """
Kaede: You would do that. Without a fee.

She writes this down too.

Kaede: Begin with the ferrymen. They remember who crossed, before anyone had decided what the crossing meant.
"""}
			],
			"intent_prompt": "She has stopped writing, and is looking at you as she would at a document she has not yet classified. What do you ask of her?",
			"intent_choices": [
				{"id": "know_better", "intent": "romantic", "text": "I'd like to know what you choose when the record is only yours.", "tag": "court her", "face": "warm",
					"response": """
The brush stops. It stays stopped for longer than the question needs.

Kaede: I do not have an entry for that. I am asked what happened. I am never asked what I would choose.

Kaede: I am not practised at the answer. Come again. I should like a second attempt, with preparation.
""",
					"memory": "The day I asked Kaede what she chooses when the record is only hers."},
				{"id": "offer_help", "intent": "friendship", "text": "Let me help, as a friend. I don't need a place in the account.", "tag": "as a friend", "face": "warm",
					"response": """
Kaede: That is inaccurate. A friend appears in the margins whether they wish it or not.

Kaede: But I accept the distinction. I have not had cause to use that heading before. I shall rule a column.
""",
					"memory": "The day I offered Kaede my friendship."},
				{"id": "another_time", "intent": "none", "text": "I'll leave the archive to its work.", "tag": "nothing decided yet", "face": "neutral",
					"response": """
Kaede: Do. I shall try not to finish your conclusions for you while you are gone. It is a habit. People dislike it.
""", "memory": "A first word with Kaede, and nothing promised."}
			]},
		2: {"title": "A Map of Useless Places", "face": "amused",
			"lead": [{"text": """
Kaede puts her arm across a sheet as you come in. Then, with visible effort, she takes it away again.

Kaede: It is a map. It is not official. There are no roads on it.

There is a dry stair, a wall that the afternoon sun warms, and beside the stair a small ink shape labelled, in a very exact hand: cat (uncertain).
""", "options": [
				{"say": "Why 'uncertain'?", "tone": "ask", "reply": """
Kaede: The cat's attendance cannot be guaranteed. I record what I can stand behind.

Kaede: I have lived inside these walls since I was seven. These are the places in them I would choose. Nobody has seen this. I do not know why I have shown you.
"""},
				{"say": "It's a map of where you're happy.", "tone": "comfort", "face": "thoughtful", "reply": """
Kaede: That is not a cartographic category.

She looks at the page for some time.

Kaede: It is, however, accurate. I have lived inside these walls since I was seven. These are the places in them I chose. I had not put a word to it.
"""},
			]}],
			"text": """
Kaede: An official record may not prefer anything. This one is allowed to. I find I do not know how to add to it. It requires a preference, and I have very few.
""",
			"choices": [
				{"id": "villager", "text": "There's a bench by the lower gate where people sit when no one's watching. Put that on.", "tag": "add a place townsfolk rest", "face": "amused",
					"response": """
Kaede draws the bench. Then, after a pause, she writes beside it: good in late light.

She stares at what she has written.

Kaede: That is an opinion. I have entered an opinion. I am leaving it in.
""",
					"memory": "The bench I added to her map of useless places."},
				{"id": "news", "text": "Who taught you to draw maps like this?", "tag": "ask who taught her", "face": "warm",
					"response": """
Kaede: No one. That was the appeal. Everything else I know was taught to me, examined, and corrected.

She takes a creased sheet from the back of the box: a child's plan of three hiding places and one cupboard, marked unreliable.

Kaede: I was seven. The cupboard had a loose panel. The assessment stands.
""",
					"memory": "Her childhood map: three hiding places and one unreliable cupboard."},
				{"id": "verse", "text": "I'd mark the ford below Marchgate. The water's warm there in the evening.", "tag": "offer a place of your own", "face": "warm",
					"response": """
Kaede: I have never been to Marchgate. I have never been past the lower gate.

She draws it anyway, from your description, asking four exact questions about the bank. She does not correct your distances.

Kaede: Then it belongs here. Marked: reported, not observed. I should like, one day, to amend that.
""",
					"memory": "The place of mine she put on her map."}
			]},
		3: {"title": "Witnesses at the Ford", "face": "concerned",
			"lead": [{"text": """
Kaede is standing. You have not seen her stand at her own desk before.

Kaede: The clans agree on exactly one fact, which is that the other's copy of the covenant is forged. There have been stones thrown at the ford. Next it will not be stones.

Kaede: I can prove what the covenant says. I cannot prove it to people who are busy fighting. That is a defect in my method, and I have not been able to correct it.
""", "options": [
				{"say": "What's the covenant to you?", "tone": "ask", "reply": """
Kaede: It ended the siege. The siege in which someone opened the gate.

Kaede: That was my father. Both clans call him a traitor, for opposite reasons. The covenant is the only thing his death purchased. I should prefer that it not be wasted.
"""},
				{"say": "You're not as calm as you sound.", "tone": "comfort", "reply": """
Kaede: Correct. My hand is unsteady. I have spoiled two sheets.

Kaede: The covenant ended a siege. My father died in that siege. I was given to this archive afterwards, as a pledge that the record would be kept honestly. If the covenant fails, I am a pledge to nothing.
"""},
			]}],
			"text": """
Kaede: I need witnesses, or I need time, and I can obtain neither from this room. I am asking. I do not know the correct form for asking. This is it.
""",
			"variants": [
				{"id": "fund_muster", "name": "Fund a Joint Watch", "text": "I'll pay for a watch drawn from both villages.", "tag": "for a mixed patrol", "face": "amused",
					"response": """
A watch of both clans walks the ford, turn and turn about, on your silver.

Kaede: They have stopped arguing about the covenant. They are arguing about the rota. Who has the dawn watch; who brought no lantern.

Kaede: It is the same anger, put to something small. I did not know anger could be redirected. I have spent eleven years attempting to disprove it instead.
""",
					"memory": "The joint watch I paid for."},
				{"id": "defend_district", "name": "Hold the Ford", "text": "My company holds the ford while they talk.", "tag": "guard the crossing yourself", "face": "warm",
					"promise": """
Kaede: Then hold it until the witnesses have crossed and spoken. I shall record everything, including who arrives late.

Kaede: Captain. There is a discrepancy I wish to prevent. You leave with a number of soldiers. Return with the same number. I dislike corrections of that kind.
""",
					"response": """
Kaede: You held it. Both clans stood behind your line and were shot at by the same raiders.

Kaede: For the first time they have an event they cannot record separately. One account. I have written it; both have signed it; neither asked to see the other's copy.

Kaede: I also recorded that I watched the ford road each evening. It was not relevant. I have left it in.
""",
					"memory": "The day the company held the ford."},
				{"id": "correspondence", "name": "Gather Independent Copies", "text": "Temples, ferries, households. I'll bring you every copy there is.", "tag": "carry her requests for the other copies", "face": "amused",
					"promise": """
She hands you a list: every temple, ferry and household that might hold a copy, ranked by how much each will resent being asked.

Kaede: Begin with the ferrymen. They resent nothing. They simply charge.

Kaede: I cannot go myself. I have not been past the lower gate since I was seven. You will have to be my eyes, and you are careless about dates. Write them down.
""",
					"response": """
Kaede: Three copies. All incomplete, each damaged in a different place. Laid together, they overlap on the same promise.

Kaede: Three liars, agreeing by accident. It is the most beautiful thing I have ever catalogued.

Kaede: I could kiss the ferryman. That is a figure of speech. I have checked.
""",
					"memory": "The three copies I gathered, which agreed by accident."}
			]},
		4: {"title": "The Line in Her Hand", "face": "concerned",
			"text": """
The Kitayama council sits in a half-circle. They want Kaede to certify the copy that favours their own clan. She promised both villages an honest comparison. An elder lays the official brush on the table in front of her.

She does not pick it up. She looks at it as she would at a forgery.

Kaede: They are waiting for me to take it. So, I observe, are you. I should like to know which way you are hoping.
""",
			"choices": [
				{"id": "negotiate", "text": "Write a covenant that says only what the surviving records agree on.", "tag": "a compromise · Kaede and the council both content", "face": "thoughtful",
					"response": """
Kaede drafts it there, in front of them: a narrow promise both sides can keep, with every doubt labelled as a doubt and none of them hidden.

Kaede: It is a small document. Small documents survive. The grand ones are fought over.

Kaede: I had the evidence for that, and had never thought to use it. Thank you.
""",
					"memory": "The narrow covenant I argued for."},
				{"id": "support_edda", "text": "Kaede won't certify a lie, and she shouldn't have to.", "tag": "Kaede's trust · the council's displeasure", "face": "warm",
					"response": """
She signs her own finding, in her own name, and turns the sheet for the council to read. The clan loses its easy victory. The villages keep an honest peace.

Afterwards she is very quiet.

Kaede: You have made the record less convenient.

Kaede: My father made a siege less convenient, once. I have wondered all my life whether anyone stood beside him when he did it. Today someone stood beside me. I am recording that under my own name.
""",
					"memory": "The day I stood with Kaede against the council."},
				{"id": "break_promise", "text": "Sign their version. Unity now matters more than a dead clause.", "tag": "breaks your word to Kaede · the council's favour", "face": "concerned",
					"response": """
Kaede sets the brush down, parallel to the edge of the table, exactly.

Kaede: You have asked me to make the record useful by making it false.

Kaede: That is what was done to my father's name. I had not classified you among the people who do that. I shall have to correct the entry.
""",
					"memory": "The council where I broke my word to Kaede."},
				{"id": "decline", "text": "Neither version yet. We need more than two copies.", "tag": "nothing decided", "tone": "plain", "face": "thoughtful",
					"response": """
The council waits, displeased. Kaede inclines her head to you.

Kaede: Caution. It is defensible. I cannot promise the clans will be as patient as the evidence requires.
""", "memory": ""}
			],
			"repair": {"id": "repair_promise", "text": "I'll take back what I asked, in front of them, and pay for every record to be copied.", "tag": "mends it", "face": "thoughtful",
				"response": """
Kaede records your retraction herself, beneath the original demand, in the same hand and the same ink.

Kaede: A correction must remain visible. I do not scrape out.

Kaede: The entry now reads that you were wrong, and that you said so. That is a rarer document than you know. We may continue.
""",
				"memory": "The retraction I made before the council, to mend my word to Kaede."}},
		5: {"title": "Room in the Margin", "face": "warm",
			"text": """
The covenant is signed, its doubts left showing. Kaede closes the official box. Then she does something you have not seen her do: she pushes it aside, and unrolls her private map in the space where it was.

Kaede: I have reviewed my notes on you. There are a great many. They began as the record of a source.

Kaede: They are no longer objective. I have known for some time. I continued to keep them, which is itself evidence.

Kaede: This map does not require witnesses. I should still like you to be on it. I have not determined where. That is the question.
""",
			"final_choices": [
				{"id": "marry_public", "text": "Marry me. Let the whole archive witness it.", "tag": "before her house", "face": "warm",
					"response": """
Kaede: Yes.

Kaede: I am supposed to consider it. I have considered it. The consideration took no time; I find I had done it already, in the margins, over several months.

Kaede: I shall need to begin a page. A long one. Do not read it yet.
"""},
				{"id": "marry_private", "text": "Let's make our vows quietly. Just us, and no record.", "tag": "tonight, by one candle · her house not asked", "face": "warm",
					"response": """
Kaede: No record. I have never said that about anything. I have recorded what I ate on days when nothing else occurred.

Kaede: Yes. No record. I shall simply have to remember it. I find I am not worried.
"""},
				{"id": "friendship", "text": "Let's swear friendship between our houses.", "tag": "a pact between your houses", "face": "amused",
					"response": """
Kaede: Then I shall write it in the margin.

Kaede: You should understand what that means. The margin is where I put what the official text has no place for, and I refuse to lose.
"""},
				{"id": "remain_close", "text": "Let's stay close, and let time decide.", "tag": "no promises yet", "face": "thoughtful",
					"response": """
Kaede: Time is a careless archivist. It keeps nothing in order.

Kaede: I shall keep my own notes, then. They will continue not to be objective.
"""},
				{"id": "part_respectfully", "text": "I think our roads part here.", "tag": "for good", "face": "concerned",
					"response": """
Kaede: I see.

She rolls the map. Her hands are steady, which costs her something.

Kaede: Then I shall record it accurately. All of it. Including the good parts; I do not omit.
"""}
			],
			"final_reward_key": "kaede_ch5_final", "final_trust": 10}
	},
	"post_project": {
		"id": "third_copy",
		"title": "The Third Copy",
		"face": "concerned",
		"text": """
Kaede: I require a second opinion. Yours. It is not expert, but it is the one I trust.

A third clan has come to Kitayama with a copy of the covenant that names them too. It may be true. It may be a very good forgery, and the first two clans have already begun to sharpen things.

Kaede: I should like to be right about this before I am kind about it. Help me find out which I can afford to be.
""",
		"choices": [
			{"id": "mediate", "text": "Let's ask the ferrymen again. They remember who crossed.", "tag": "find the witnesses", "face": "thoughtful",
				"response": """
The oldest ferryman remembers three boats that night, not two, and the colour of the third one's sail. The copy is real. It has only been very badly kept.

Kaede: Three clans. I shall need a wider page.

Kaede: I am, I notice, pleased. A larger truth is more work, and I prefer it.
""",
				"reward_key": "kaede_post_third_copy", "standing_gain": 5,
				"memory": "The ferryman who remembered the third boat."},
			{"id": "stand", "text": "Tell them what you find. I'll stand beside you while you do.", "tag": "stand with her before the clans", "face": "warm",
				"response": """
She reads her finding aloud to three clans, with you at her shoulder. No one interrupts.

Kaede: They let me finish. That has never occurred.

Kaede: I have recorded it. I am considering having it framed.
""",
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
