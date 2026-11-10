## Farah's visits. (The format is described in personal_conversations.gd. Her ids keep the
## candidate id, "farid"; they are save keys from the first version of each visit and no
## longer describe the scene.)
##
## Her voice: quick, playful and practised. She guesses about you aloud, tries names on you,
## answers a question with a better one, and flirts as a reflex, because it is her trade.
## When she means a thing it comes out short, and startles her.
##
## What is under it: she was sent up the hill at thirteen to pour tea in rooms where she was
## furniture, and learned to read liars. At nineteen she wrote her first truce alone, for
## the Salt Road. It held eleven days. Her brother Idris, fifteen, was driving a mule on the
## road when it failed; she had told him it was safe. She has put three exits in every
## sentence since, and kept the roads open as a debt. The visits go from games, to the
## street she was born on, to Idris, to the envoy with her shoes off, to the embassy she
## does not want, to one sentence with no exits, to the Salt Road itself.
##
## She asks you: a place you know by a name no map prints; when you last said exactly what
## you meant.
extends RefCounted

const SCENES := {
	"farid_supper_request": {
		"title": "Two Truths", "rank": "C", "requires_any": [], "setting": "envoy_room",
		"parts": [
			{"face": "amused", "text": """
Farah has kept you waiting, and when she sweeps in she has changed for the occasion. You have the impression that you are the occasion.

Farah: My thunderous captain. No? Too much. I'm trying names on you; that one pinched. Sit. I've a game.

Farah: Three things about me. Two are true. Find the lie and I'll owe you a favour, which in this city is worth more than silver. One: I speak six languages. Two: I have never once lost my temper in a council. Three: I can't cook an egg.
""", "options": [
				{"say": "The temper. Nobody's that calm.", "tone": "share", "mark": "farah_guessed_temper", "reply": """
Farah: Oh, you're good.

Farah: I lost it once. I was nineteen. I threw an inkwell at a minister. I missed; I've regretted it ever since. The missing, I mean.
"""},
				{"say": "The languages. Six is showing off.", "tone": "tease", "reply": """
Farah: Seven, if you count the one I only swear in. I was being modest; it's a new experiment.

Farah: The lie is the temper. I lost it once, at nineteen, and threw an inkwell at a minister. I missed.
"""},
				{"say": "The egg. Anyone can cook an egg.", "tone": "tease", "reply": """
Farah: Anyone cannot. I have set fire to water. My cook has asked me, formally, in writing, to stay out.

Farah: The lie is the temper. I lost it once, at nineteen, and threw an inkwell at a minister. I missed.
"""},
			]},
			{"face": "amused", "text": """
Farah: Now you. Fair's fair. Three things, and I'll find the lie. I should tell you I do this for a living.

You tell her three things. She listens with her chin on her hand, entirely still, and you understand suddenly what it must be like to sit across a treaty table from her.

Farah: The second. You looked at my left ear. People do that when they're inventing; I've no idea why. It's a very ordinary ear.
""", "options": [
				{"say": "How did you learn that?", "tone": "ask", "face": "thoughtful", "reply": """
Farah: I was put in the room at thirteen. A girl pouring the tea is furniture, and people lie in front of furniture. I watched.

Farah: By sixteen I could tell my uncle which merchants would default. He was very proud. He bought me a better dress to pour in.
"""},
				{"say": "I'll keep my eyes off your ears.", "tone": "tease", "reply": """
Farah: Please don't. They'll feel neglected. Look wherever you like, Captain; I'll only read it.

Farah: I learned at thirteen, pouring tea in rooms where I was furniture. People lie in front of furniture.
"""},
			]},
			{"face": "thoughtful", "text": """
The game seems to be over. She has not quite stopped playing.

Farah: Here's a harder one, and no favour riding on it. Everyone who comes through that door wants something of the envoy. A road, a clause, an introduction. What do you want, Captain?
""", "options": [
				{"say": "Nothing. I liked the game.", "tone": "share", "mark": "farah_wanted_nothing",
					"memory": "Played two truths and a lie with Farah, and told her you wanted nothing from the envoy.", "reply": """
Farah: Nothing.

She waits for the rest of the sentence. It doesn't come.

Farah: Do you know, I've no reply to that. I've a reply to everything. I shall have to have one made.
"""},
				{"say": "To know whether you lied about the lie.", "tone": "tease", "face": "amused", "reply": """
Farah: Ah. You think I lied about the lie.

Farah: I might have. I'll tell you the tenth time you come. It gives you a reason, and me something to look forward to, and I've few enough of those that aren't in writing.
"""},
				{"say": "To see you when you're not performing.", "tone": "ask", "reply": """
The smile stays exactly where it is. It is the eyes that change.

Farah: That isn't on offer to visitors.

Farah: Ask me again some time. I didn't say never. I'm careful about never.
"""},
			]},
		],
		"closing_face": "amused", "closing": """
She walks you to the door herself, which you gather is not done.

[?farah_guessed_temper] Farah: You guessed right, so I owe you a favour. I pay my debts. Slowly, and with interest.

[?!farah_guessed_temper] Farah: You guessed wrong, so I owe you nothing. I'm going to owe you a favour anyway. I want to see what you'd ask for.

Farah: Come again. I've more names to try on you.
""",
		"summary": "Farah plays two truths and a lie with you, and then reads your own lie off your face: she learned it at thirteen, pouring tea in rooms where people forgot she was there. Then she asks what you want from the envoy, since everybody wants something.",
		"memory": "Played two truths and a lie with Farah, and was read like a letter.",
	},
	"farid_two_street_names": {
		"title": "Crooked Lantern", "rank": "C", "requires_any": [], "setting": "qasr_hamra",
		"parts": [
			{"face": "amused", "text": """
Farah is not in her audience room. She is in the street, with no servants, buying fried dough from a stall and being overcharged on purpose.

Farah: Captain! Don't bow. If you bow he'll know who I am and the price will double again. Here. Eat this. It's dreadful; you'll want another.

[?farah_wanted_nothing] Farah: You said you wanted nothing from the envoy. So I've brought you where there isn't one.
""", "options": [
				{"say": "Does your uncle know you're out here?", "tone": "tease", "reply": """
Farah: My uncle believes I'm composing a note of condolence. I composed it yesterday. I keep a drawer of them.

Farah: This is Crooked Lantern. The surveyor calls it South Market Street. I was born over the spice seller's. Don't tell the court; they think I was assembled in an anteroom.
"""},
				{"say": "Where are we?", "tone": "ask", "reply": """
Farah: Crooked Lantern. The surveyor calls it South Market Street, and nobody has forgiven him.

Farah: I was born over the spice seller's. He sings. You'll hear him in a moment, and wish you hadn't.
"""},
			]},
			{"face": "amused", "text": """
She walks you down it. Everyone knows her, and nobody calls her envoy. An old woman pinches her arm and tells her she is too thin, and that the captain is too armed.

Farah: At thirteen they sent me up the hill to pour tea, and I've been carried through this street in a chair ever since. I come down twice a year and pretend it's by accident.

Farah: Your turn. Everyone who travels has one: a place you know by a name no map would print.
""", "options": [
				{"say": "The Leaning Bridge. It leans less than the name does.", "tone": "share", "mark": "you_name_bridge", "reply": """
Farah: So somebody was frightened on it once, and the fright outlasted the lean. I love it.

Farah: I'm going to put it in a dispatch. The Leaning Bridge. If a clerk queries it I'll tell him the bridge was consulted.
"""},
				{"say": "Cold Kettle. A camp where nothing would boil.", "tone": "share", "mark": "you_name_kettle", "reply": """
Farah: Named in a temper, by people with wet feet. Those are the ones that last.

Farah: Cold Kettle. I can hear the whole evening. Nobody slept, and somebody blamed the cook.
"""},
				{"say": "Widow's Elbow. A bend in a road. Nobody knows which widow.", "tone": "share", "mark": "you_name_elbow", "reply": """
Farah: Nobody knows! Then every village on it will have claimed her.

Farah: I'm going to ask. The next time I'm on that road I shall ask in every one, and report.
"""},
			]},
			{"face": "thoughtful", "text": """
At the bottom of the lane the lantern itself hangs over a shut door, tilted, exactly as advertised.

Farah: That was ours. My mother still writes to me at this address. I've lived on the hill eighteen years; she will not put the palace on a letter.

Farah: I write back in my good hand, about the weather. I don't know when I stopped telling her anything. It was easier than explaining what I'd turned into.
""", "options": [
				{"say": "What did you turn into?", "tone": "ask", "reply": """
Farah: Something useful.

Farah: That isn't a complaint. Useful people eat. But my mother raised a girl who talked too much and laughed with her mouth open, and I'm not certain she'd know the woman who pours the tea.
"""},
				{"say": "You laughed with your mouth open, back there.", "tone": "comfort", "mark": "farah_seen_laughing", "face": "amused",
					"memory": "Walked Crooked Lantern with Farah, gave her a name of your own, and caught her laughing with her mouth open.", "reply": """
Farah: Did I?

Her hand goes to her mouth, a court habit. Then she takes it away again, deliberately.

Farah: So I did. Don't report it. I've a reputation for poise that took years to forge.
"""},
				{"say": "Write her a real one.", "tone": "help", "reply": """
Farah: Saying what? 'Dear Mother, I'm very good at my work, and I don't remember what I like'?

Farah: That is, I notice, a real one. Damn you, Captain. I'll think about it. Buy me another of those.
"""},
			]},
		],
		"closing_face": "amused", "closing": """
She eats the second one walking back up the hill, licking sugar off her thumb, and puts the envoy on again one piece at a time: the shoulders first, then the hands, the smile last.

Farah: Crooked Lantern, and yours beside it. Two names no clerk will file. I find I like holding both.
""",
		"summary": "Farah takes you to the street she was born on, which the surveyor calls South Market Street and everyone else calls Crooked Lantern. Nobody there calls her envoy. She asks you for a place-name of your own, and admits she no longer tells her mother anything real in her letters home.",
		"memory": "Walked Crooked Lantern with Farah, and gave her a name of your own.",
	},
	"farid_unsealed_letter": {
		"title": "Eleven Days", "rank": "B", "requires_any": ["farid_supper_request", "farid_two_street_names"], "setting": "envoy_room",
		"parts": [
			{"face": "concerned", "text": """
An unsealed letter lies on Farah's desk. She has turned her chair away from it. There is no smile at all this evening, and she has not put one on for you.

Farah: It's the day. I'm poor company on the day. You may go; I shan't be offended. I'm never offended, it's in my terms of service.

[?farah_seen_laughing] Farah: You've seen me laugh with my mouth open. I suppose you may as well see this.
""", "options": [
				{"say": "I'll stay. You needn't talk.", "tone": "quiet", "reply": """
Farah: Needn't I.

Her shoulders come down, slowly, like a tent being struck.

Farah: Nobody's said that to me since I was thirteen. I'm paid by the word, Captain. Sit where I can see you.
"""},
				{"say": "What day is it?", "tone": "ask", "reply": """
Farah: The day the Salt Road truce failed. Twelve years.

Farah: My truce. I was nineteen. It was the first thing they'd ever let me write alone.
"""},
			]},
			{"face": "concerned", "text": """
Farah: It was beautiful. I'd a clause for everything. The other envoy smiled at me the whole time, and I thought I was winning. I'd watched liars since I was thirteen and I didn't see it, because he was telling me I was clever.

Farah: It held eleven days. On the twelfth they closed the road with a caravan still on it. Forty wagons, and the boys who drove them.

Farah: My brother Idris was fifteen. He'd begged to go. I'd said yes. I'd said it was safe; I'd written the truce myself.
""", "options": [
				{"say": "That was their doing. Not yours.", "tone": "comfort", "reply": """
Farah: Yes. I know. I've been told so by experts.

Farah: It was their doing, and my signature. Both are true. I've had twelve years to make them cancel, and they won't.
"""},
				{"say": "Tell me about Idris.", "tone": "ask", "mark": "farah_asked_idris", "reply": """
Farah: He couldn't whistle. He tried constantly. He had a mule called Minister, because it wouldn't move without a bribe.

Something that is nearly a laugh gets out of her.

Farah: Nobody asks about him. They ask about the truce. Thank you.
"""},
			]},
			{"face": "thoughtful", "text": """
She turns the chair back toward the desk at last.

Farah: That's a letter to my mother. I write one on the day, every year. I've never sent one. They all say the same thing, in better and better prose.

Farah: This is why I keep the roads open, Captain. It isn't virtue. I owe the road a life, and I pay in instalments. And it's why there are three exits in every sentence I speak. The one time I said a plain thing, it was 'it's safe'.
""", "options": [
				{"say": "What does the letter say?", "tone": "ask", "reply": """
Farah: 'I'm sorry. It was my fault. I miss him.' Nine words. I've dressed them in three pages every year for twelve years.

Farah: Said aloud they're very small. I'd thought they'd be larger.
"""},
				{"say": "Send it.", "tone": "help", "reply": """
Farah: She'll know my hand's shaking. She knows my hand.

Farah: She'd rather that than the weather. I know she would. Don't push, Captain. You've moved it further tonight than I have in twelve years.
"""},
				{"say": "You've said a plain thing to me. Tonight. Nothing broke.", "tone": "heart", "when": "romantic", "face": "warm",
					"memory": "Stayed with Farah on the day the Salt Road truce failed, and she said a plain thing and nothing broke.", "reply": """
Farah: No.

She looks at you as if checking the walls.

Farah: Nothing broke. You're still sitting there. I'd like it noted that this is terrifying, and that I'm staying in the room.
"""},
				{"say": "A friend can hear the plain thing. No exits needed.", "tone": "warm", "when": "friend", "face": "warm", "reply": """
Farah: Can you? You're the first to offer.

Farah: Then here's one, as practice: I'm not all right today. There. I didn't die. Remarkable.
"""},
			]},
		],
		"closing_face": "thoughtful", "closing": """
She sands the ink. She does not seal it. But for the first time, you gather, she does not put it in the drawer with the other eleven.

Farah: I'll leave it on the desk. Tomorrow I'll see whether it still sounds like me.

You stay until the lamp wants trimming. She lets a silence stand without building anything across it.
""",
		"summary": "You find Farah on the anniversary of the Salt Road truce, the first she ever wrote alone. It held eleven days. Her brother Idris, fifteen, was on the road with a caravan when it failed, because she had told him it was safe. Every year she writes her mother a letter about it, and has never sent one.",
		"memory": "Stayed with Farah on the day the Salt Road truce failed, and heard about Idris.",
	},
	"farid_wrong_courtesy": {
		"title": "After the Banquet", "rank": "B", "requires_any": ["farid_unsealed_letter"], "setting": "envoy_room",
		"parts": [
			{"face": "neutral", "text": """
Past midnight. There has been a banquet for forty; you could hear her laugh from the courtyard all evening, bright as a struck glass. Now Farah is sitting on the floor of her own audience room with her shoes off and her back against the desk.

Farah: Don't. I know. An envoy doesn't sit on floors. An envoy has been charming for six hours and would like to be a sack of flour.

[?farah_asked_idris] Farah: You asked me about Idris. Nobody at that table has ever asked me a question they wanted the answer to.
""", "options": [
				{"say": "Is there room on that floor?", "tone": "share", "mark": "farah_floor", "face": "amused", "reply": """
You sit down against the desk beside her. She looks at you sidelong, as at an unexpected clause.

Farah: You'll crease. Oh, you don't care. How restful. I've spent the whole night with people who'd die before they creased.
"""},
				{"say": "You were magnificent in there.", "tone": "comfort", "reply": """
Farah: I was. I always am. I've a laugh for ministers and a laugh for their wives, and one for the man who thinks he's seducing me.

Farah: I counted tonight. Six hours, and I didn't say one thing I meant.
"""},
			]},
			{"face": "thoughtful", "text": """
Farah: Do you want to know the worst of it? I'm good at it. I like being good at it. I walk into a room and I can feel what everyone wants me to be, like heat, and I simply become it.

Farah: Then I come back here and take it off, and some nights I can't find what's under it. I look, and there's another smile.
""", "options": [
				{"say": "There's somebody under it. She's sitting on a floor.", "tone": "comfort", "face": "amused", "reply": """
Farah: She is, isn't she.

Farah: She's tired, and she'd like her feet rubbed, and she thinks the Minister of Tariffs has a face like a boiled shoe. There. That's her. She isn't very diplomatic.
"""},
				{"say": "Which one am I talking to now?", "tone": "ask", "reply": """
Farah: I don't know. That's the honest answer, and I haven't many.

Farah: Whichever she is, she hasn't prepared anything. So perhaps that's how you tell.
"""},
			]},
			{"face": "concerned", "text": """
She tips her head back against the desk and closes her eyes.

Farah: I'll be thirty-two in spring. An envoy's worth is that she's pleasant to look at and nobody minds her in the room. I've perhaps ten years of being furniture left. Then my uncle will find a niece.

Farah: And everyone who was so glad to see me will be exactly as glad to see her. I've watched it happen. I poured the tea for the last one.
""", "options": [
				{"say": "I don't come here for the envoy.", "tone": "share", "reply": """
Farah: No. You don't, do you. You've never once asked me for a road.

Farah: I keep waiting for the petition. It's been months. I'm beginning to suspect there isn't one, and I don't know what to do with a person like that.
"""},
				{"say": "Then what do you want, when it's over?", "tone": "ask", "reply": """
Farah: Nobody's asked.

Farah: A house on a crooked street. A door people knock on because they like me, and not because I can get them a clause. I'd be bad at it. I'd keep offering them concessions.
"""},
				{"say": "In ten years I'll still be glad to see you. Shoes off and all.", "tone": "heart", "when": "romantic", "face": "warm",
					"memory": "Found Farah on the floor after a banquet with the envoy taken off, and told her you'd still be glad to see her in ten years.", "reply": """
Farah: Don't say a thing like that to a woman on a floor. She's nowhere to fall.

She opens her eyes, and for once does not arrange her face first.

Farah: Say it again in ten years. I'll hold you to it; I draft a very binding clause.
"""},
				{"say": "You'll have one friend who doesn't want the niece.", "tone": "warm", "when": "friend", "face": "warm", "reply": """
Farah: Shall I. Truly.

Farah: Then I'm richer than my uncle, and he's no idea. Don't tell him. It'd be taxed.
"""},
			]},
		],
		"closing_face": "amused", "closing": """
[?farah_floor] You sit on the floor together until the lamp gutters. At some point her head is on your shoulder, and neither of you mentions it; it is not a diplomatic incident.

[?!farah_floor] You sit down on the floor after all. She makes room without opening her eyes.

Farah: Boiled shoe. I've wanted to say that for three years.

Farah: Go to bed, Captain. And thank you. That isn't the envoy talking; she'd have sent a card.
""",
		"summary": "After a banquet where she charmed forty guests for six hours, you find Farah on the floor of her audience room with her shoes off. She says she is so good at becoming what a room wants that some nights she can't find what is under it; and that in ten years her uncle will replace her with a niece, and nobody will mind.",
		"memory": "Found Farah on the floor after a banquet, with the envoy taken off.",
	},
	"farid_own_answer": {
		"title": "My Own Answer", "rank": "A", "requires_any": ["farid_wrong_courtesy"], "setting": "envoy_room",
		"parts": [
			{"face": "thoughtful", "text": """
Farah has a letter under her uncle's seal, and a notebook opened along its spine, with thread and a blunt needle. She is sewing the notebook. She is not looking at the letter.

Farah: Hold that edge. Firmly; but if either of us becomes heroic, the paper tears.

[?farah_floor] Farah: You sat on a floor for me. You can hold a page.
""", "options": [
				{"say": "What's in the letter?", "tone": "ask", "reply": """
Farah: An embassy. The great one, at the Shogun's court. My uncle has pulled strings for a year. It's the making of the family.

Farah: I'm to accept by the new moon. I've been mending this notebook for three days.
"""},
				{"say": "Let me try a stitch.", "tone": "share", "mark": "you_tried_binding", "face": "amused", "reply": """
She hands you the needle like a full cup. Your stitch goes in crooked, comes out somewhere unexpected, and holds.

Farah: Dreadful. Leave it. It's the only thing on this desk that isn't lying. That letter is an embassy. The great one. I'm to accept by the new moon.
"""},
			]},
			{"face": "thoughtful", "text": """
Farah: A binder taught me, one season, when I was fourteen and in disgrace for something. Samira. She didn't care who my uncle was. She made me sweep for three days before I touched thread.

Farah: I liked it more than anything I've done since. You make a small thing open properly, and nobody claps. It simply works. I never said so. Pleasure didn't seem an argument anyone would accept.
""", "options": [
				{"say": "And the embassy?", "tone": "ask", "reply": """
Farah: Silk, and a title, and every sentence weighed by a court that poisons the envoys it finds dull. I'd be superb.

Farah: I'd be the smile, Captain. For the rest of my life. With better lighting.
"""},
				{"say": "You don't want it.", "tone": "comfort", "reply": """
Farah: I haven't said that.

Farah: I've been unable to say that for three days. I've mended a notebook that wasn't broken. Draw your own conclusions; you clearly have.
"""},
			]},
			{"face": "concerned", "text": """
She pulls a stitch tight and stops, with the needle in the air.

Farah: If I refuse, the family loses the post. My uncle will say I've thrown away eighteen years of his patience. He'll be right. I am the most expensive thing they own.

Farah: I'm asking what you think. Not what's useful. I can get useful anywhere; I manufacture it.
""", "options": [
				{"say": "Refuse it. You've paid them enough.", "tone": "share", "mark": "farah_refuse", "reply": """
Farah: Like that. No clause, no soft landing.

She lets out a breath she seems to have been holding since she was thirteen.

Farah: I wanted to hear someone say it with no exits. I couldn't. It's a terrible sentence. I'm going to keep it.
"""},
				{"say": "What do you want? Say it plainly.", "tone": "ask", "reply": """
Farah: The road. This table. Work small enough to see whether it helped anyone.

Farah: And a notebook that opens flat. It's very little, said aloud. It didn't feel like little when I was choosing it.
"""},
				{"say": "Selfishly: stay. I'd miss you past bearing.", "tone": "heart", "when": "romantic", "face": "warm",
					"memory": "Held the page while Farah mended a notebook, and told her, selfishly, to stay.", "reply": """
Farah: Selfishly. Oh, good. I've had a year of people being glad for my career. Nobody's wanted me anywhere for the inconvenient reason.

She ties off the thread with a great deal more care than the knot needs.

Farah: I'll admit that one of my reasons rides in at odd hours and holds paper badly.
"""},
				{"say": "Whatever you choose, I'll still knock on the door.", "tone": "warm", "when": "friend", "face": "warm", "reply": """
Farah: The door of a disgraced ex-envoy on a crooked street?

Farah: You would. You'd bring fried dough. Captain, that's the first time the alternative has sounded like a life.
"""},
			]},
		],
		"closing_face": "thoughtful", "closing": """
The last knot sits slightly off centre. Farah looks at it, and closes the notebook. It opens flat.

[?you_tried_binding] Your crooked stitch shows at the head of the spine. She runs her thumb over it, and leaves it.

Farah: Samira said every book wants one stitch its binder's ashamed of. Keeps it from getting proud.

She picks up her uncle's letter at last, turns it over, and begins, on the back of it, in a perfectly plain hand, to write: no.
""",
		"summary": "Farah has been offered the great embassy at the Shogun's court, the making of her family, and has spent three days mending a notebook instead of answering. She learned bookbinding at fourteen and liked it better than anything since. She asks what you think: not what is useful, but what you think.",
		"memory": "Held the page while Farah mended a notebook, and watched her write 'no' to a great embassy.",
	},
	"farid_no_reply_required": {
		"title": "No Reply Required", "rank": "A", "requires_any": ["farid_own_answer"], "coda": true, "setting": "envoy_room",
		"parts": [
			{"face": "warm", "text": """
Farah arrives without a document, a servant, or a reason. You have never seen her without at least one of the three.

Farah: I saw a dog today carrying a loaf longer than itself. The baker was losing the negotiation. I thought: the captain should hear about this. So here I am. That's the whole of my business.
""", "options": [
				{"say": "Tell me all of it.", "tone": "ask", "face": "amused", "reply": """
Farah: The baker got hold of one end. The dog treated that as a separate loaf and graciously ceded it. I've rarely seen a settlement executed with such confidence. I took notes.
"""},
				{"say": "All this way for a dog?", "tone": "tease", "reply": """
Farah: For you. The dog was the pretext. I've decided to stop needing them. This is the last one, so I chose a good one.
"""},
			]},
			{"face": "warm", "text": """
She sits before she is asked, and notices, and laughs at herself with her mouth open.

Farah: Everything I bring anyone has a request tied to it. Even my jokes. Admire this; forgive that; remember me at the tariff hearing. This has nothing tied to it. I simply wanted you to laugh.

[?farah_refuse] Farah: You said 'refuse it', with no exits. I used your sentence on my uncle, word for word. He hasn't spoken to me since. It's the most restful month of my life.

Farah: I sent the letter to my mother, by the way. Nine words. She wrote back four: come down for supper.
""", "options": [
				{"say": "Did you go?", "tone": "ask", "reply": """
Farah: I went. She said I was too thin, and asked why I'd waited twelve years. I said I'd been composing.

Farah: We lit a lamp for Idris. I told her about his mule. She'd forgotten the mule. I gave her that back.
"""},
				{"say": "And the embassy?", "tone": "ask", "reply": """
Farah: Declined. I'm still the envoy of this road. I'm no longer the family's brooch.

Farah: I hadn't known those were different posts. Nobody tells you. You have to refuse one to find the other underneath.
"""},
			]},
			{"face": "warm", "text": """
[?you_name_bridge] Farah: I crossed your Leaning Bridge last month. I told the escort its proper name. They've started using it. I'm afraid you've altered a map.

[?you_name_kettle] Farah: We camped at your Cold Kettle last month. I told the escort its proper name. Nothing would boil. They were enchanted.

[?you_name_elbow] Farah: I rode round your Widow's Elbow last month, and asked in three villages. Each claims her; each described a different woman. I've never been so pleased by a failed inquiry.

[?farah_guessed_temper] Farah: I've lost my temper a second time, incidentally. At my uncle. I didn't miss.

Farah: There may be more unimportant news. If I'm encouraged.
""", "options": [
				{"say": "Encouraged. Every unimportant word.", "tone": "ask", "face": "amused", "reply": """
Farah: The well has a new rope, a slightly different colour, and the street's divided. A boy sold me a pear that was a turnip. My mother has written to complain about a cloud.

Farah: None of it needs anything from you. I can't tell you how restful that is to say.
"""},
				{"say": "Or we sit, and nobody reports.", "tone": "quiet", "reply": """
Farah settles into the quiet. Once she opens her mouth to rescue it. Then she smiles, a small unprofessional one, and lets it lie.
"""},
				{"say": "Come here. Tell me from closer.", "tone": "heart", "when": "romantic",
					"memory": "Heard Farah's unimportant news from close beside her, with nothing asked of you.", "reply": """
Farah crosses the room in fewer steps than protocol allows, sits where her shoulder fits against yours, and takes your hand as if she had drafted nothing else all week.

Farah: From here the news is shorter. I'm glad to be here. That's all of it.
"""},
				{"say": "I've all evening, and no tariff hearing.", "tone": "warm", "when": "friend", "reply": """
Farah tucks one foot under her, like someone who has stopped being received and started being at home.

Farah: Then I shall begin with the turnip.
"""},
			]},
		],
		"closing_face": "warm", "closing": """
The room goes dim round the two of you. Nothing has been decided, delivered, or improved for distant parties.

Farah: I thought being close to someone meant knowing the right answer first. This is easier. I can bring you a ridiculous dog, and that's enough.

Farah: No reply required. Though if you ever see what became of that loaf, I want a full report.
""",
		"summary": "Farah comes to you with no petition and no pretext, only a story about a dog stealing a loaf, because she wanted you to laugh. She has sent her mother the nine-word letter and gone down for supper, and she has refused the embassy. Nothing is asked of you.",
		"memory": "Heard Farah's unimportant news, because she wanted you to be the one who heard it.",
	},
	"farid_said_plainly": {
		"title": "No Exits", "rank": "S", "requires_any": ["farid_no_reply_required"], "coda": true, "setting": "envoy_room",
		"parts": [
			{"face": "thoughtful", "text": """
Farah has a blank sheet, and has had it for an hour. The ink has skinned over in the well.

Farah: I've a question for you. I've drafted it eleven ways. The eleventh ran to a page, and opened with a remark about the season.

[?farah_wanted_nothing] Farah: You told me, that first day, that you wanted nothing. I've been wanting to give you something ever since. It's this.
""", "options": [
				{"say": "Ask the first one.", "tone": "quiet", "reply": """
Farah: Yes. Before I improve it.
"""},
				{"say": "Read me the eleventh.", "tone": "tease", "face": "amused", "reply": """
Farah: 'Should the occasion ever have arisen, in a season so given to reflection—'

Farah: No. It doesn't recover. The first.
"""},
			]},
			{"face": "thoughtful", "text": """
Farah: When did you last say exactly what you meant? Not the useful thing. Not the kind one. The thing itself, with no way out of it.
""", "options": [
				{"say": "Giving an order. It's the only time I'm sure.", "tone": "share", "mark": "you_plain_orders", "reply": """
Farah: So you're plain when lives hang on it, and careful otherwise.

Farah: I'm the reverse. I can be exact about a border, and I can't ask for soup. Between us we make one honest person.
"""},
				{"say": "At a graveside. Too late to be of use.", "tone": "share", "mark": "you_plain_grave", "face": "concerned", "reply": """
Farah does not reach for a graceful phrase. She lets it stand in the room at its full size.

Farah: Then you know what it costs to keep the plain thing back until it's safe. I kept one back twelve years, and I've kept another since spring. I'd rather not learn the second your way.
"""},
				{"say": "Now, I think. Answering you.", "tone": "share", "mark": "you_plain_now", "face": "warm", "reply": """
Farah: That's either true or the best flattery I've ever had, and I've been flattered by professionals.

Farah: It's true. You've no gift for the other. It's why I draft less when you're in the room.
"""},
			]},
			{"face": "warm", "text": """
She pushes the blank sheet away. Then, being who she is, she pulls it back and turns it face down, so that there is no page to write on at all.

Farah: I said one plain sentence at nineteen, and it killed my brother. I've put three exits in every sentence since. I'm going to say one with none. Five words; I counted.

[?romantic] Farah: I love you. Stay close.

[?friend] Farah: I trust you. Completely. Always.

She stops. Nothing follows. No clause, no courtesy, no door.
""", "options": [
				{"say": "Say it again. Just as short.", "tone": "tease", "reply": """
Farah says it again. It comes out exactly the same length.

Farah: It holds. I half thought it'd grow a preamble the moment I looked away.
"""},
				{"say": "How long was the first draft?", "tone": "ask", "face": "amused", "reply": """
Farah: Two pages. A paragraph on the weather the day we met. A subordinate clause about your horse.

Farah: All of it true. None of it this.
"""},
				{"say": "I love you. Five words was two too many.", "tone": "heart", "when": "romantic",
					"memory": "Farah said five plain words with no exits. You answered in three.", "reply": """
Farah: Three. You did it in three.

She laughs with her mouth open, the laugh that gets out before any reply.

Farah: I'll never out-draft you. I find I don't mind. Say it again; I want to count.
"""},
				{"say": "And I you. No treaty needed.", "tone": "warm", "when": "friend", "reply": """
Farah: No treaty. No witnesses. Not even a seal.

Farah: It's the best agreement of my career, and there's nothing in the archive to show for it. Good.
"""},
			]},
		],
		"closing_face": "warm", "closing": """
The sheet stays face down. Farah stoppers the ink.

Farah: Nothing broke. I said it, and the walls are where they were.

She does not thank you for listening. She has, for once, said everything she meant, and so she simply stays.
""",
		"summary": "Farah asks when you last said exactly what you meant, with no way out of it. Then she does it herself, for the first time since she was nineteen: one sentence, five words, no exits, about what you are to her.",
		"memory": "Farah asked when you last said exactly what you meant, and then said five plain words of her own.",
	},
	"farid_short_answer": {
		"title": "The Salt Road", "rank": "S", "requires_any": ["farid_said_plainly"], "coda": true, "setting": "qasr_hamra",
		"parts": [
			{"face": "thoughtful", "text": """
The Salt Road, where it crosses the border, on a clear cold morning. There is a waystone here with forty names cut into it, and beside one of them someone has nailed a small brass mule.

Farah: I've never come. Twelve years. I've kept this road open from a desk, and I've sent wreaths, and I've never once stood on it.

Farah: I thought I needed a speech. I've brought you instead.
""", "options": [
				{"say": "Take your time. I'll hold the horses.", "tone": "quiet", "reply": """
Farah: Hold the horses. Yes. That's the most useful thing anyone's ever said to me at a memorial.

She walks to the stone alone, and stands with one glove off and her bare hand on his name.
"""},
				{"say": "The mule's a good touch.", "tone": "comfort", "face": "amused", "reply": """
Farah: My mother's. She had it made last month, after I told her. She'd forgotten Minister.

She laughs, and it breaks in the middle, and she lets it.

Farah: He'd have hated a solemn stone. He couldn't even whistle solemnly.
"""},
			]},
			{"face": "warm", "text": """
[?farah_asked_idris] Farah: You asked about him once, when everyone else asked about the truce. I've been able to say his name easily ever since. That's why you're here.

Farah: Idris. It's your sister. I'm late; I was drafting.

Farah: I'm sorry. It was my fault, and it was theirs, and I miss you. And I'm happy. I didn't think I'd be allowed both. I'm told I am.

She says it in a plain voice, to a stone. No court on earth has heard her use it.
""", "options": [
				{"say": "It sounded like you.", "tone": "comfort", "reply": """
Farah: The one from Crooked Lantern. Not the hill. Good. That's who he knew.

She puts her glove back on, and does not look as though she is putting anything else on with it.
"""},
				{"say": "Tell him about the road.", "tone": "ask", "reply": """
Farah: It's open, Idris. Eleven years out of twelve. Six hundred caravans. I counted every one in, like a miser.

Farah: None of them was yours. I know. I kept counting anyway. I think I can stop keeping score now, and simply keep the road.
"""},
				{"say": "Tell him about me.", "tone": "heart", "when": "romantic",
					"memory": "Stood on the Salt Road with Farah while she spoke to her brother's name, and was introduced.", "reply": """
Farah: Idris, this is the captain. Holds paper badly. Reads me better than I'd like. I'm keeping them.

She takes your hand, in front of forty names, without a word of preamble.

Farah: He'd have asked whether you can whistle. Can you? Never mind. Tell me at home.
"""},
				{"say": "Tell him you've a friend on the road now.", "tone": "warm", "when": "friend", "reply": """
Farah: Idris, I've a friend. An armed one. They want nothing from me, and I've checked repeatedly.

Farah: He'd be astonished. He always said I collected people the way other girls collected ribbons, and never kept one.
"""},
			]},
		],
		"closing_face": "warm", "closing": """
[?you_plain_orders] Farah: You're only plain when you give an order, you said. Here's one from me, then: come home with me. That's the plainest I've got.

[?you_plain_grave] Farah: You said you were plain at a graveside, too late. I've been plain at one today, and it wasn't too late. I've you to thank for the hurry.

[?you_plain_now] Farah: You said you were plain when you answered me. I've been trying to deserve that. This, just now, is the nearest I've come.

A caravan comes up the road as you leave: twenty wagons, and a boy on the lead mule trying, without success, to whistle.

Farah watches it all the way past. Then she turns her horse toward home, and does not once look back to see whether the road stays open behind her.
""",
		"summary": "Farah has kept the Salt Road open from a desk for twelve years and never stood on it. She takes you to the waystone where the caravan's names are cut, her brother's among them, and says to him plainly what she has dressed in three pages every year: that she is sorry, that she misses him, and that she is happy.",
		"memory": "Stood on the Salt Road with Farah while she spoke to her brother's name.",
	},
}
