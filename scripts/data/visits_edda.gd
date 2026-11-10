## Edda's visits. (The format is described in personal_conversations.gd. The ids are save
## keys from the first version of each visit and no longer describe the scene.)
##
## Her voice: brisk, exact and bossy, because she is fond. Orders (sit, eat, boots off),
## numbers for everything, "Captain". She shows care by feeding people, counting them in
## and correcting their sums; a feeling is said bluntly or not at all.
##
## What is under it: the winter she was fourteen, the lord took the riders south and raiders
## fired Thornwall. Her mother, steward before her, made four journeys with a cart and
## brought in forty-one people; Edda stood at the hall door cutting a notch for each, and
## waited until light for the forty-second. She has counted the household in every night
## since. The visits go from being inspected and fed, to why she counts, to the page she has
## begun for your company's dead, to the forty-second notch.
##
## She asks you: why you took up the sword; how you carry your dead; who counted you in.
extends RefCounted

const SCENES := {
	"edda_spare_spoon": {
		"title": "The Spare Place", "rank": "C", "requires_any": [],
		"parts": [
			{"face": "thoughtful", "text": """
You are barely through the door of the common room when Edda looks you over, top to bottom, like a delivery.

Edda: Stop there. Mud to the knee, a strap gone on that pauldron, and you've lost flesh since the thaw. When did you last sit at a table? A table, Captain. Not a saddle. Not a log.
""", "options": [
				{"say": "I can't remember.", "tone": "share", "mark": "edda_fed", "reply": """
Edda: I can. It was here, eleven days ago, and you left half the bread.

She has a bowl in front of you before you have finished sitting down.

Edda: Eat. I'll be watching, so don't push it about.
"""},
				{"say": "Is this an inspection, steward?", "tone": "tease", "face": "amused", "reply": """
Edda: Yes. You're failing it.

She puts a bowl in front of you regardless, and stands over it with her arms folded.

Edda: You can be witty when that's empty.
"""},
			]},
			{"face": "amused", "text": """
There are seven places laid at the long table, and six stools.

You: Who's the seventh for?

Edda: Whoever comes. A drover, a tinker, a cousin; somebody always brings a cousin. It was my mother's rule. A steward lays one more place than she has people, every night, and never asks who it's for.
""", "options": [
				{"say": "And tonight it's for me.", "tone": "tease", "reply": """
Edda: Tonight you happened to it. Don't get ideas; last week it was a man selling eels.

Edda: He had better manners. He finished his bread.
"""},
				{"say": "Has it ever stood empty?", "tone": "ask", "face": "thoughtful", "reply": """
Edda: Most nights. That isn't the point.

Edda: The point is that nobody who comes to this door finds I hadn't thought of them. I can't stop the raids, Captain. I can lay a spoon.
"""},
			]},
			{"face": "thoughtful", "text": """
She watches you eat with the frank satisfaction of someone watching a roof being mended.

Edda: You feed ninety soldiers, I'm told. Who feeds you? Don't say 'the cook'. I've met army cooks.
""", "options": [
				{"say": "Nobody. I see to the company first.", "tone": "share", "mark": "edda_last_fed", "reply": """
Edda: Of course you do. I do the same; I ate standing up for six years.

Edda: It's a stupid habit, and I'm going to break you of it before I break myself. Sit down properly. That's an order from the household.
"""},
				{"say": "You, apparently.", "tone": "tease", "face": "amused", "reply": """
Edda: Apparently. I don't recall agreeing to it.

Edda: I'll put you in the kitchen book. It isn't a favour. I simply can't abide an uncounted mouth.
"""},
				{"say": "You haven't eaten either.", "tone": "comfort", "mark": "edda_noticed_place",
					"memory": "Was inspected and fed by Edda, and noticed she had laid no place for herself.", "reply": """
She looks at the table. Seven places. She has laid none of them for herself.

Edda: No.

Edda: It's too early in our acquaintance for you to be this observant. Move over.
"""},
			]},
		],
		"closing_face": "warm", "closing": """
She sits. It is, you gather from the kitchen boy's face, an event.

Edda: The drawer sticks. For the spoons. You lift it a little.

You lift it a little. She takes the spoon you hand her, and for a while the steward of Ravensford eats her own soup at her own table, like a guest.

Edda: Come when you're hungry, Captain. Not when you need grain. I can tell the difference, and I'd rather the first.
""",
		"summary": "Edda inspects you at the door, finds you underfed, and puts a bowl in front of you at the spare place her mother taught her always to lay. She asks who feeds the captain. By the end she has sat down at her own table, which the household does not often see.",
		"memory": "Was inspected, fed, and given the spare place at Edda's table.",
	},
	"edda_wrong_verse": {
		"title": "The Company's Accounts", "rank": "C", "requires_any": [],
		"parts": [
			{"face": "amused", "text": """
Edda has your company's pay ledger. You did not give it to her.

Edda: Your quartermaster left it on my bench. I'm not saying he should be flogged. I'm saying I read it, because it was there, and I've some questions.

[?edda_fed] Edda: You've eaten today. I can tell. Good. You'll want your strength.
""", "options": [
				{"say": "You read my books?", "tone": "tease", "reply": """
Edda: I corrected your books. There's a difference, and the difference is eleven silver a month.

Edda: Your sutler charges you for forty sacks and delivers thirty-six. He's done it since autumn. He rounds his fours to look like nines; it's almost artistic.
"""},
				{"say": "How bad is it?", "tone": "ask", "reply": """
Edda: You're not a fool with money. You're only too busy to look. That's worse; fools get lucky.

Edda: Your sutler charges you for forty sacks and delivers thirty-six. Since autumn. He rounds his fours to look like nines; it's almost artistic.
"""},
			]},
			{"face": "thoughtful", "text": """
She turns the ledger round. The margins are full of her small upright figures, and here and there a single word: no.

Edda: And this. You pay every soldier before yourself, and in the lean months you don't pay yourself at all. Three times last winter. Don't tell me it's noble. It's bad accounting. A captain in debt makes desperate bargains.
""", "options": [
				{"say": "They've earned it. I can wait.", "tone": "share", "reply": """
Edda: I know they have. I'm not telling you to short them.

Edda: I did the same with this house for six years, and one winter I'd nothing left to bargain with when it mattered. Pay yourself a wage, Captain. A small one. In the book, where you can't argue with it.
"""},
				{"say": "You hum when you add.", "tone": "tease", "face": "amused", "reply": """
She stops. She had not known.

Edda: It's the miller's song. My mother sang it over the accounts. The miller falls in his own flour bin at the end; she said it was a warning to people who don't check their sums.

Edda: Stop changing the subject.
"""},
			]},
			{"face": "thoughtful", "text": """
Edda: I shouldn't have opened it. I know that. I see a thing going wrong and my hands are in it before I've asked.

Edda: It's the only way I know of being fond of anyone. I fix their arithmetic. You may tell me to mind my own house.
""", "options": [
				{"say": "Keep the book. Check it every month.", "tone": "share", "mark": "edda_keeps_books", "face": "warm",
					"memory": "Let Edda keep the company's accounts, since she had corrected them anyway.", "reply": """
Edda: Every month.

She has gone slightly pink, which on her is like another woman bursting into song.

Edda: I'll want it by the first. Not the third. I know soldiers.
"""},
				{"say": "Mind your own house, steward.", "tone": "tease", "face": "amused", "reply": """
Edda: I'm trying. You keep walking into it.

She closes the ledger and holds it out. She does not quite let go until you pull.

Edda: The sutler, though. Deal with the sutler. I shan't sleep.
"""},
				{"say": "Nobody's looked after my sums before.", "tone": "comfort", "face": "warm", "reply": """
Edda: No. I could see that. They've the look of sums done by firelight with one glove on.

Edda: Well. Somebody has now. I'd get used to it. I don't stop.
"""},
			]},
		],
		"closing_face": "amused", "closing": """
She walks you to the door with the ledger under her own arm, apparently by accident.

Edda: Thirty-six sacks. I want to be there when you tell him.

You: You want to watch.

Edda: I want to count the sacks afterwards. But yes. I should also like to watch.
""",
		"summary": "Edda has read your company's pay ledger without being asked, and corrected it. Your sutler has been cheating you since autumn, and you have been going without pay so your soldiers needn't. She admits that fixing people's arithmetic is the only way she knows of being fond of them.",
		"memory": "Found Edda had corrected the company's accounts uninvited, and was right.",
	},
	"edda_boots_by_door": {
		"title": "Forty-One", "rank": "B", "requires_any": ["edda_spare_spoon", "edda_wrong_verse"], "setting": "ravensford",
		"parts": [
			{"face": "concerned", "text": """
Dusk, and Edda is in the hall doorway looking down the valley road. The household's boots are lined up beside her, largest to smallest. You have the feeling she has been there some time.

Edda: Thirty-eight out this morning. Thirty-eight back. I can go in now.

[?edda_noticed_place] Edda: Don't say it. I know I haven't counted myself. I'm standing here; I know where I am.
""", "options": [
				{"say": "You count them in every night?", "tone": "ask", "reply": """
Edda: Every night. Carters, herd boys, the girl who takes the eggs to Kettlebrook. I don't sit down until the number's right.
"""},
				{"say": "Stand here a while. I'll count with you.", "tone": "comfort", "mark": "edda_counted", "reply": """
Edda: There's nobody left to count.

She stays in the doorway all the same, and makes room in it.

Edda: Thirty-eight. And one sellsword, extra. Thirty-nine.
"""},
			]},
			{"face": "concerned", "text": """
Edda: My mother was steward before me. The winter I was fourteen the lord took the riders south, and raiders came over the ford and fired Thornwall.

Edda: She took a cart and went out to bring the village in. Four journeys, through the smoke. She brought in forty-one people.

Edda: I was at this door with a tally stick, cutting a notch for each. I got to forty-one and waited for forty-two. I waited until it was light.
""", "options": [
				{"say": "She was the forty-second.", "tone": "comfort", "reply": """
Edda: She went back for the miller's youngest. The roof came down on them both.

Edda: Forty-one notches. I've still got the stick. I can't throw away a thing that's been counted.
"""},
				{"say": "You were a child with a stick.", "tone": "comfort", "reply": """
Edda: I was the steward's daughter, with a job. I was to count them in.

Edda: I counted right, Captain. That's what I can't get past. I counted exactly right, and it came out one short.
"""},
			]},
			{"face": "thoughtful", "text": """
The last of the light goes off the road. She does not move from the door.

Edda: I took the books at sixteen. I've counted this household in every night for twelve years, and I've not been one short since.

Edda: And now I catch myself listening for your company on the road. Ninety soldiers I don't feed and can't order. I didn't ask to start counting you.
""", "options": [
				{"say": "Count us. I'd like to be expected somewhere.", "tone": "share", "reply": """
Edda: Don't say that lightly. I'll hold you to the number.

Edda: Ninety-odd, then. Find out the odd. I can't work with 'odd'.
"""},
				{"say": "I can't promise you the number, Edda.", "tone": "share", "mark": "edda_no_promise", "reply": """
Edda: No. I know. You're a soldier. I'm not a fool.

Edda: Thank you for not lying. Everyone who rides out of this yard tells me they'll be back for supper. My mother said it.
"""},
				{"say": "Then count me. I'll come back to be counted.", "tone": "heart", "when": "romantic", "face": "warm",
					"memory": "Stood at the door while Edda counted the household in, and told her to count you too.", "reply": """
Edda: You can't know that. Say it again anyway.

You say it again. She puts her hand flat against your chest for a moment, like someone checking that a tally mark is really there.
"""},
				{"say": "A friend at the door is worth counting for.", "tone": "warm", "when": "friend", "face": "warm", "reply": """
Edda: It is. I hadn't had one to count before.

Edda: Go in, then, so I can stop. You're letting the cold into my arithmetic.
"""},
			]},
		],
		"closing_face": "thoughtful", "closing": """
She straightens one boot with her foot. She notices herself doing it, and leaves its neighbour crooked, on purpose, as if to see whether the hall will fall down.

Edda: I've never told that properly. People here know it; they were there. Nobody's ever needed it explained.

Edda: Come in. I'm not going to stand in a doorway all night like a ghost. It's bad for the rushes.
""",
		"summary": "At dusk Edda counts the household in from the hall door, as she has every night for twelve years. She tells you why: the winter Thornwall burned, her mother brought forty-one villagers in through the smoke, and Edda, fourteen, counted them with a tally stick and waited all night for the forty-second. She has begun, against her will, to listen for your company too.",
		"memory": "Stood at the door while Edda counted the household in, and learned who the forty-second was.",
	},
	"edda_morning_unclaimed": {
		"title": "An Hour Unclaimed", "rank": "B", "requires_any": ["edda_boots_by_door"],
		"parts": [
			{"face": "amused", "text": """
You have taken the pen out of Edda's hand. She is looking at her empty fingers as though you had removed one of them.

You: One hour. Nothing that needs doing.

Edda: There is always something that needs doing. That's what a household is.

[?edda_keeps_books] Edda: I've your accounts to check, for one. It's nearly the first.

[?edda_last_fed] Edda: You see to your company before yourself; you told me so. I don't see why I'm the one being lectured.
""", "options": [
				{"say": "It'll still need doing in an hour.", "tone": "tease", "reply": """
Edda: That's the most irresponsible sentence I've ever heard.

She sits down on the bench anyway, bolt upright, like someone waiting to be told what the bench is for.
"""},
				{"say": "When did you last do nothing?", "tone": "ask", "reply": """
Edda: I was ill, the winter before last. Two days. I reorganised the linen from my bed.

She sits down on the bench, bolt upright, like someone waiting to be told what the bench is for.
"""},
			]},
			{"face": "thoughtful", "text": """
For a while she simply sits. It appears to be difficult.

Edda: I was going to be a weaver. Before. My aunt at Kettlebrook had a loom the size of a barn door, and I'd a pattern half set up on it: herons, in the reeds. Blue on grey.

Edda: Then Thornwall burned, and I was the steward's daughter with no steward. Nobody asked me. I didn't ask either; there were forty-one people in the hall wanting breakfast.
""", "options": [
				{"say": "Is the loom still there?", "tone": "ask", "reply": """
Edda: With the herons still on it, half done. My aunt won't cut them off. She says they're waiting for me, which is a wicked thing to say to a busy woman.

Edda: I've not been up there in four years. I'd only see the mistakes.
"""},
				{"say": "Do you regret it?", "tone": "ask", "reply": """
Edda: No. I'm good at this. I'd have been a middling weaver, and I'm a very fine steward.

Edda: I just never chose it. That's a different sum from regret. It doesn't come out to anything. It only sits there.
"""},
			]},
			{"face": "thoughtful", "text": """
Edda: Now you. And don't tell me you were born with a sword in your hand; I've met your sergeant, and he says you couldn't hold one straight at twenty.

Edda: Why this? Why a company? You could have been anything that pays worse and kills you slower.
""", "options": [
				{"say": "Someone had to keep them alive. It turned out to be me.", "tone": "share", "mark": "you_why_keep", "reply": """
Edda: So you're a steward. With a sword instead of a ledger.

Edda: I thought so. You count them in as well, don't you. You just haven't a door to do it at.
"""},
				{"say": "Coin. I was hungry, and I was good at it.", "tone": "share", "mark": "you_why_coin", "reply": """
Edda: Honest. I like that better than a calling. A calling doesn't check its sums.

Edda: Hunger's a reason. I've watched it make worse people than you. It made you careful; I've seen your books.
"""},
				{"say": "I'd nowhere else. The company's the only house I've had.", "tone": "share", "when": "friend", "mark": "you_why_house", "reply": """
Edda: A house that moves.

She is quiet a moment, doing some arithmetic that isn't about silver.

Edda: Then you've never had a door, Captain. Somebody ought to see to that.
"""},
				{"say": "I'd nowhere else. Until lately.", "tone": "heart", "when": "romantic", "mark": "you_why_house", "face": "warm",
					"memory": "Took Edda's pen away for an hour, heard about the herons, and told her you'd had nowhere else until lately.", "reply": """
Edda: Until lately.

She looks at you, then at the bench, then at the door of her own hall, in that order.

Edda: I see. I'm not going to answer that sitting down doing nothing; I'd say something I haven't checked. Give me until the hour's up.
"""},
			]},
		],
		"closing_face": "amused", "closing": """
The hour is not up. She has, however, stopped looking at the door.

Edda: I might ride up to Kettlebrook. Before the snow. Only to see whether the moths have got at it.

You: The herons.

Edda: The loom. The herons are my aunt's business. Don't smirk, Captain. And give me back my pen.
""",
		"summary": "You take Edda's pen away for an hour. With nothing to do, she tells you she was going to be a weaver before Thornwall burned and made her steward at sixteen; a half-finished pattern of herons still waits on her aunt's loom. Then she asks why you took up the sword, and you tell her.",
		"memory": "Took Edda's pen away for an hour, and heard about the herons.",
	},
	"edda_ledger_blot": {
		"title": "The Names", "rank": "A", "requires_any": ["edda_morning_unclaimed"],
		"parts": [
			{"face": "concerned", "text": """
There is a second book under Edda's ledger: narrow, black, and much older. She closes it when you come in. Then, deliberately, she opens it again.

Edda: You may as well see. It's the valley's dead. My mother began it. Name, year, and how. I've kept it up.

[?edda_counted] Edda: You stood at the door and counted with me once. This is the other half of that.
""", "options": [
				{"say": "May I read it?", "tone": "ask", "reply": """
She turns it toward you. Forty years of names in two hands; and near the end, in fresh ink, a page headed with the name of your company.

Edda: I began that page in spring. I'd no right. They're not mine to keep.
"""},
				{"say": "Why show me?", "tone": "ask", "reply": """
Edda: Because there's a page in it I'd no right to begin.

She turns it. Near the end, in fresh ink, a page is headed with the name of your company.

Edda: Spring. The first you lost after you started coming here. I asked your sergeant the name.
"""},
			]},
			{"face": "concerned", "text": """
Edda: I asked him for all of them, after that. Where they came from. Who's to be told. He thought I was mad. He told me anyway.

Edda: You don't keep a book. I looked, when I had your accounts. Wages and rations to the last crust, and nowhere at all that says who's gone. How do you carry them, Captain?
""", "options": [
				{"say": "I know every name. I say them, some nights.", "tone": "share", "mark": "you_carry_names", "reply": """
Edda: Aloud?

Edda: Good. I'd thought you might be one of the ones who drinks instead. A name said aloud is still on somebody's account.
"""},
				{"say": "I don't. I can't count them and still give orders.", "tone": "share", "mark": "you_carry_none", "reply": """
Edda: No. I can see that you can't.

Edda: Then let me. I don't have to give the orders; I only have to hold the pen. It's a fair division. It's how my mother and the old captain did it.
"""},
				{"say": "I write to their families. Badly.", "tone": "share", "mark": "you_carry_letters", "reply": """
Edda: I've seen your handwriting. I believe you.

Edda: Bring me the next one before you send it. I'll not change a word. I'll only make sure a mother can read it.
"""},
			]},
			{"face": "concerned", "text": """
She runs a finger down the new page, not touching the ink.

Edda: I swore I'd never be fond of a soldier. I've buried too many names I'd only just learned to spell.

[?edda_no_promise] Edda: You wouldn't promise me the number, at the door. I've thought the better of you since, and slept the worse.

Edda: And here's a whole page of yours in my own hand, and I listen for your horses like a girl. I'm angry about it. I want you to know that I'm angry.
""", "options": [
				{"say": "Be angry. I'd rather that than be left out of the book.", "tone": "share", "reply": """
Edda: You're not in the book. That's the whole—

She stops, and shuts her eyes.

Edda: You're not in the book, Captain. See that it stays so. It's the only thing I'm asking, and I know you can't promise it.
"""},
				{"say": "I'm sorry I made you count us.", "tone": "comfort", "reply": """
Edda: Don't be sorry. I'd started before you asked.

Edda: I'd only like it noted that I didn't go looking for this. It rode into my yard and ate my bread.
"""},
				{"say": "I listen for this door, too. On the road.", "tone": "heart", "when": "romantic", "face": "warm",
					"memory": "Read the book of the valley's dead, found a page begun for the company, and told Edda you listen for her door.", "reply": """
Edda: Do you.

She closes the black book and puts both hands on it, to keep them still.

Edda: Then we're both fools, and there are two of us, which is at least a number I can work with.
"""},
				{"say": "A friend who keeps my dead. That's more than most captains get.", "tone": "warm", "when": "friend", "face": "warm", "reply": """
Edda: It is. I'd not thought of it as a gift.

Edda: I'd thought of it as trespass. I'll go on, then. With leave.
"""},
			]},
		],
		"closing_face": "thoughtful", "closing": """
[?you_carry_names] Edda: Say them here, next time. Not to a fire. I'll write while you say.

[?you_carry_none] Edda: You give the orders. I'll hold the pen. Send your sergeant to me after; you needn't come yourself.

[?you_carry_letters] Edda: The letters, mind. Before you send them. I mean it.

She puts the black book back under the ledger, where it has always lived: the dead beneath the accounts, holding them up.

Edda: There. Now you know where everything in this house is kept.
""",
		"summary": "Under her ledger Edda keeps a black book of the valley's dead, begun by her mother. She has started a page in it for your company's fallen, with names she got from your sergeant. She asks how you carry them, and admits, angrily, that she swore never to be fond of a soldier and now listens for your horses.",
		"memory": "Read the book of the valley's dead, and found Edda had begun a page for the company.",
	},
	"edda_place_no_task": {
		"title": "A Place With No Task", "rank": "A", "requires_any": ["edda_ledger_blot"], "coda": true,
		"parts": [
			{"face": "warm", "text": """
Two places at the small table. Edda has laid her own first; you can tell, because hers is the one that is perfectly square.

Edda: I've no letters for you. No petitions, no accounts, nothing wants signing. I checked. I'm at a complete loss.

[?edda_fed] Edda: And you've eaten, and I've eaten. I don't know what's left to do to a person.
""", "options": [
				{"say": "Sit down, Edda.", "tone": "quiet", "reply": """
She sits. It takes her three tries to stop looking at the door.

Edda: There. I've occupied my own chair. Write it in the book.
"""},
				{"say": "We could do nothing. You've practised.", "tone": "tease", "face": "amused", "reply": """
Edda: One hour, once, and I thought about linen for most of it.

She sits, though, and makes a visible effort not to straighten the cloth.
"""},
			]},
			{"face": "warm", "text": """
Edda: I've been thinking about why I count.

Edda: I thought it was care. It is care. But if I'm counting, I'm at the door, and if I'm at the door, I'm not at the table. I've spent twelve years laying a place for everyone in this valley so that I'd never have to sit in one.
""", "options": [
				{"say": "And now?", "tone": "ask", "reply": """
Edda: Now there's somebody across the table who'd notice if I got up. It's very inconvenient.

Edda: I find I don't want to get up.
"""},
				{"say": "That's the bravest sum you've done.", "tone": "comfort", "reply": """
Edda: It's the first I've done about myself. I'm not sure I carried everything.

Edda: Check it for me. No, don't. Just stay there while it sits.
"""},
			]},
			{"face": "warm", "text": """
[?you_why_keep] Edda: You said you took the company because someone had to keep them alive. I took the house the same way. I think we're allowed one hour a day when it isn't our turn.

[?you_why_coin] Edda: You said you took the sword because you were hungry. You're not hungry now; I've seen to it. So what do you want, when you're not?

[?you_why_house] Edda: You said the company was the only house you'd had. This is one, Captain. It's got a door and everything. I counted.

Outside, the yard goes about its evening without her.

Edda: I haven't anything to give you. It's the first time since I was sixteen I've sat with someone and had nothing in my hands.
""", "options": [
				{"say": "This is enough.", "tone": "quiet", "reply": """
Edda: Is it.

She tests the sentence the way she'd test a floorboard, and finds that it holds.

Edda: Then I'll stop looking for more. That's harder than it sounds, and I'm doing it.
"""},
				{"say": "Tell me something that isn't about the household.", "tone": "ask", "reply": """
Edda: The herons. I rode up. The moths hadn't got at them.

Edda: I did a hand's breadth. Blue on grey. It's crooked. I'm leaving it crooked.
"""},
				{"say": "Give me your hands, then. They're not empty now.", "tone": "heart", "when": "romantic",
					"memory": "Sat with Edda with no task between you, and her hands in yours.", "reply": """
You hold out yours. She puts hers in them: ink on the right forefinger, a burn from the bread oven, all of it.

Edda: I hadn't counted that. I'll have to revise the inventory.
"""},
				{"say": "You're the offer. I'll take it.", "tone": "warm", "when": "friend", "reply": """
Edda: A poor bargain. I come with forty hearths and a temper.

Edda: But done. I don't go back on a count.
"""},
			]},
		],
		"closing_face": "warm", "closing": """
She does not get up. When the kitchen boy comes to ask about the morning's bread she tells him, without turning her head, to ask her in the morning.

He looks at you as though you had worked a miracle.

Edda: Two places. I counted them twice, from habit. Both times, I was one of them.
""",
		"summary": "Edda has set two places and has nothing to hand you: no letters, no accounts. She tells you what she has worked out about her counting: that a woman who is always at the door never has to sit at the table. Tonight she sits, and stays sitting.",
		"memory": "Sat with Edda with no task to justify it, and she stayed in her chair.",
	},
	"edda_who_set_your_place": {
		"title": "The Forty-Second", "rank": "S", "requires_any": ["edda_place_no_task"], "coda": true, "setting": "ravensford",
		"parts": [
			{"face": "thoughtful", "text": """
She has brought you up to Thornwall. The village is rebuilt; the new hall still smells of cut pine. Behind it, on the slope, there is a cairn, and Edda has stopped a little way short of it with her hands wrapped in her shawl.

Edda: I come up on the day. I tell her the numbers. Hearths, harvest, how many born. She liked a full account.

[?you_carry_names] Edda: You say your dead aloud, some nights; you told me. So do I, up here. It's the same habit.

[?you_why_house] Edda: You said you'd never had a house with a door. She kept this valley's. I'd like her to see who's come through it.

Edda: I've never brought anyone. I'm not sure of the form.
""", "options": [
				{"say": "Tell her the numbers. I'll wait.", "tone": "quiet", "reply": """
Edda: You'll stand here. Not back there. Here.

She tells the cairn: forty-four hearths now, a good barley year, nine born and all living. Her voice is perfectly steady, like a clerk's.
"""},
				{"say": "Introduce me.", "tone": "share", "reply": """
Edda: She'd want your muster roll, and whether you pay on time.

She tells the cairn anyway: forty-four hearths, a good barley year, nine born. And then, in the same clerk's voice: and this is the captain.
"""},
			]},
			{"face": "thoughtful", "text": """
Edda: I've been angry at her for fourteen years. For going back. She'd done it; she had forty-one. She could have stayed at the door with me.

Edda: I understand it now, and I'm still angry. I've had to learn that both will fit.

Edda: Captain. When you were small. Before the company. Was there someone who counted you in?
""", "options": [
				{"say": "Someone at home. They'd stand in the lane till they saw me.", "tone": "share", "mark": "you_place_home", "face": "warm", "reply": """
Edda: Then you know what it is to be looked for. I thought you might. You've the look of someone who was.

Edda: I'd like to have met them. I'd have compared notes.
"""},
				{"say": "Nobody. I came and went, and no one marked it.", "tone": "share", "mark": "you_place_none", "face": "concerned", "reply": """
Edda does not say she is sorry. She looks at the cairn, and then at you, as if adding a figure to a column.

Edda: Then it's been owed you a long time. I collect debts, Captain. I'm known for it.
"""},
				{"say": "An old sergeant. He counted the whole company every dusk.", "tone": "share", "mark": "you_place_sergeant", "face": "warm", "reply": """
Edda: Somebody who counts at dusk. I'd have liked him.

Edda: Is he in my book? No. Don't tell me now. Tell me at home, and I'll write it properly.
"""},
			]},
			{"face": "warm", "text": """
She takes something from her shawl: a hazel stick, grey with age, notched all down one side. Forty-one notches. She has her knife in her other hand.

Edda: I've carried this since I was fourteen, waiting for the next one. I always thought the forty-second notch was hers. It isn't. She's not coming in. I've known that a long time; I only never said it up here.

She cuts a notch. It is clean, and new, and white against the old wood.

Edda: That's you. Forty-two. Come in.
""", "options": [
				{"say": "I'm in.", "tone": "quiet", "reply": """
She runs her thumb over the new notch, once.

Edda: It came out right. First time in fourteen years the count's come out right.
"""},
				{"say": "What happens to the stick now?", "tone": "ask", "reply": """
Edda: It goes over the hall door, where I can see it when I'm counting.

Edda: I shan't cut another. Forty-two's the number. I'm done waiting on that road.
"""},
				{"say": "Forty-two. And I'm not going back out without you.", "tone": "heart", "when": "romantic",
					"memory": "At Thornwall, Edda cut the forty-second notch in her mother's tally stick, and put the stick in your hand.", "reply": """
Edda: You will. You're a soldier. You'll ride out a hundred times.

Edda: But you'll be counted, every time, by someone who can't sit down till you're in. That's what I've got to give. It's all of it.

She puts the stick into your hand, and closes her own hand over yours, and the cairn can make of that what it likes.
"""},
				{"say": "Forty-two. She'd approve the arithmetic.", "tone": "warm", "when": "friend", "reply": """
Edda: She'd check it. Twice. Then she'd ask what you eat.

Edda: Yes. She'd approve. I can hear her doing it.
"""},
			]},
		],
		"closing_face": "warm", "closing": """
You walk down through Thornwall together. A woman at a door calls out to ask whether the steward will take bread, and Edda, to the visible astonishment of the whole street, says yes and sits down on the step.

Edda: Don't look at me like that. I'm allowed to be a guest. I've seen it done.
""",
		"summary": "Edda takes you to her mother's cairn above Thornwall, where she reports the valley's numbers every year. She asks who counted you in when you were small. Then she takes out the tally stick she has carried since she was fourteen, with its forty-one notches, and cuts the forty-second: you.",
		"memory": "At Thornwall, Edda cut the forty-second notch in her mother's tally stick, and it was you.",
	},
	"edda_home_on_time": {
		"title": "Home on Time", "rank": "S", "requires_any": ["edda_who_set_your_place"], "coda": true,
		"parts": [
			{"face": "concerned", "text": """
The hall smells of bread. Trestles are up, the good cloth is out, and the whole household is expected at dusk. Edda is standing in the middle of it with her riding cloak over her arm.

Edda: The Hollin farm's lost half its barn roof. The boy came an hour ago. If I ride now I can see it and be back by the second course.

She is looking at the door. Over it hangs a hazel stick with forty-two notches.
""", "options": [
				{"say": "Your mother would have ridden.", "tone": "ask", "reply": """
Edda: She would. She'd have been right to, most nights.

Edda: She'd have been back for the second course, and missed the first, and been forgiven by everyone at the table but one.
"""},
				{"say": "I'll hold your cloak. Whichever you choose.", "tone": "quiet", "reply": """
You take it from her arm and fold it, badly. She watches you do it.

Edda: You're not going to tell me. You never do. It's the most irritating thing about you.
"""},
			]},
			{"face": "thoughtful", "text": """
[?you_carry_none] Edda: You told me you can't count your dead and still give orders. I'm the other way about. I count so hard I never give myself one. Here's one.

Edda: The roof's real. The barn won't mend for my eating supper. But the kitchen girls have been at this since before light, and three of them have asked the cook whether I'm coming.

She calls the stable boy. The carpenter, two men, a cart and a tarpaulin tonight; the steward at first light, with the tally book.

Edda: There. A roof can be looked at in the morning. A first course can't.
""", "options": [
				{"say": "How does it feel?", "tone": "ask", "reply": """
Edda: Like a column left unadded. My hands keep going to it.

Edda: Ask me after the soup. I've a suspicion it's going to feel like supper.
"""},
				{"say": "I'll ride out with you at first light.", "tone": "help", "reply": """
Edda: You'll be useless on a roof.

Edda: Come anyway. Hold the book, and tell the Hollins I was late on purpose. They ought to hear that it can be done.
"""},
				{"say": "Stay. And I'll stay, if I'm asked.", "tone": "heart", "when": "romantic",
					"memory": "Stayed beside Edda at the feast she nearly rode away from, and was counted.", "reply": """
Edda: You're asked. You were asked the day I cut the notch.

She puts her arm through yours in front of the entire kitchen, as if that were simply where an arm goes.

Edda: Come and be counted.
"""},
				{"say": "Then give me something to carry.", "tone": "warm", "when": "friend", "reply": """
Edda: The bread. All of it. You'll not eat any on the way; I'll know.

Edda: And sit by me. I want one person at that table who knows what I nearly did.
"""},
			]},
		],
		"closing_face": "warm", "closing": """
The hall fills. Somebody has brought a cousin; somebody always does. Edda counts heads from the doorway, once, and it comes out even.

[?you_place_home] Edda: Someone stood in a lane for you, you said. I'm standing in a door. It's the same office.

[?you_place_none] Edda: Nobody marked you in, you said. Mark this: I did. Tonight and after.

[?you_place_sergeant] Edda: Your old sergeant counted at dusk, you said. I've put him in the black book, on the first page of yours, where a founder goes.

She is in her own chair before the first course comes in. The door stays shut behind her, and she does not once turn to look at it.
""",
		"summary": "On the evening of a feast for the whole household, word comes of a barn roof down at an outlying farm. Edda has her cloak on her arm, as her mother would have. This time she sends the carpenter, keeps the roof for the morning, and is in her chair before the first course.",
		"memory": "Stayed with Edda for the feast she nearly rode away from.",
	},
}
