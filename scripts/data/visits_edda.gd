## Edda's visits: the steward who sets a place for everyone but herself. (The format is
## described in personal_conversations.gd.)
##
## Her running habit is counting: spoons, boots, verses, heads at a table, and never
## herself. Her thread is the aunt who visited the outlying houses and came home late.
## She asks you two things: what you'd do with a free morning, and who set a place for you.
extends RefCounted

const SCENES := {
	"edda_spare_spoon": {
		"title": "The Spare Spoon", "rank": "C", "requires_any": [],
		"parts": [
			{"face": "thoughtful", "text": """
Edda stands beside a small table, moving spoons from one place to another.

Edda: Seven spoons. Six guests. That ought to be enough. Unless someone has brought a cousin. Someone generally brings a cousin.

She counts again, silently, then looks at you.

Edda: You needn't stand as though this is an inspection.
""", "options": [
				{"say": "Give me half. I'll count from the other end.", "tone": "help", "mark": "edda_counted", "reply": """
Edda hands you four spoons, considers, and takes one back.

Edda: Three. I have seen how soldiers count rations. Lay them a hand's width from the edge. No, your hand. Mine has opinions.
"""},
				{"say": "Isn't it one? An inspection?", "tone": "tease", "reply": """
Edda: If it were, you would have failed it at the door. Your boots have brought half the road in with them.

She pushes a stack of spoons toward you anyway.

Edda: Hold these. Now you are furniture, and furniture is never inspected.
"""},
			]},
			{"face": "amused", "text": """
Edda: I was remembering supper at home. My mother would announce the exact number expected, and my uncle would set another bowl out without answering her. They did this every evening for years.

Edda: Our neighbor claimed she only came to return things. A cup, a scarf, a pan she had borrowed before I was born. Somehow she always returned them just as the soup arrived.
""", "options": [
				{"say": "And nobody ever said a word about it?", "tone": "ask", "reply": """
Edda: Not one. My mother counted. My uncle set the bowl. The neighbor returned a pan. It was the most reliable treaty I have ever witnessed, and nobody signed anything.
"""},
				{"say": "I'd have borrowed a pan myself.", "tone": "tease", "reply": """
Edda: You would have been found out inside a week. She had forty years of practice and a very honest face.

Edda: She would have liked you, though. She approved of anyone who arrived hungry.
"""},
			]},
			{"face": "thoughtful", "text": """
Edda turns a spoon over. Its handle has been worn almost smooth.

Edda: I thought the extra place was for her. Later I realized nobody ever decided who it belonged to. That was rather the point.

She sets it down at the end of the row and counts the places once more. Six. She frowns at the seventh spoon as though it had miscounted itself.
""", "options": [
				{"say": "Who usually arrived late?", "tone": "ask", "face": "amused", "reply": """
Edda: The neighbor could be relied upon. My cousin was less predictable. Once he arrived with a dog and argued that nobody had specifically excluded dogs. My mother gave it his chair. He ate standing up, very politely.
"""},
				{"say": "You haven't counted yourself.", "tone": "comfort", "mark": "edda_noticed_place",
					"memory": "Noticed that Edda had counted every place at the table but her own, and laid a spoon there.", "reply": """
Edda looks down at the empty end of the table.

Edda: It is too early in the evening for you to be this observant. Yes. I have counted everyone except myself. Again. Please don't give the household a new saying about it.
"""},
				{"say": "I can sit wherever is free.", "tone": "share", "face": "amused", "reply": """
Edda: A dangerous offer. At home that meant beside my uncle, who believed every meal needed a detailed account of the weather. He could make three minutes of rain last until pudding. I was very fond of him.
"""},
			]},
		],
		"closing_face": "warm", "closing": """
She opens a drawer, catches it against her knee, and lifts it carefully.

Edda: It sticks. You have to lift it a little.

You take the seventh spoon and lay it at her place. She leaves it there. For a moment neither of you rearranges anything.

Edda: There. Now there is enough room. I suppose I can stop counting.

She sits down, looking pleased by the small untidiness of an extra setting.
""",
		"summary": "Edda is counting spoons for supper and remembers the extra place her family always set for whoever turned up. Counting everyone else's, she forgets her own. You lay a spoon at her place, and she sits down. The sticking drawer and the unclaimed seat become small shared memories.",
		"memory": "Counted spoons with Edda, and laid one at her place.",
	},
	"edda_wrong_verse": {
		"title": "The Wrong Last Verse", "rank": "C", "requires_any": [],
		"parts": [
			{"face": "amused", "text": """
By a window, Edda is tapping a rhythm on the sill. She stops when she notices you, then deliberately starts again.

Edda: I am trying to remember a song. Before you ask, it has no historical importance whatsoever. There is a miller, a sack of flour, and an argument about a donkey.

[?edda_counted] Edda: Four verses. I have counted. You may check my work; you have experience.
""", "options": [
				{"say": "Does it go like this?", "tone": "tease", "reply": """
You hum something. It is not a tune. Edda listens to all of it, which is generous.

Edda: No. It has never gone like that. Nothing has. Though I admit the donkey would have preferred your version.
"""},
				{"say": "Which part have you forgotten?", "tone": "ask", "reply": """
Edda: The ending. Thank you for assuming I had mislaid only one part. It is generous and, today, correct.
"""},
			]},
			{"face": "amused", "text": """
Edda: I remember two endings, and one of them cannot possibly fit the tune. My aunt insisted that the miller learned patience. My cousin insisted that he fell headfirst into his own flour bin.

You: Which did you sing?

Edda: Indoors? Patience. I was a sensible child.
""", "options": [
				{"say": "Sing me the flour bin.", "tone": "ask", "reply": """
Edda: The donkey refuses to recognize him until he sneezes. That is the entire joke. My cousin needed four extra lines to explain it, which he sang increasingly quickly. It was dreadful. I still laughed every time.
"""},
				{"say": "Patience is the better ending.", "tone": "tease", "mark": "edda_argued_verse", "reply": """
Edda: You are siding with my aunt. Nobody has sided with my aunt about that song in twenty years.

She looks delighted, and tries to hide it by examining the sill.

Edda: You are wrong, of course. But it is a pleasure to have an opponent.
"""},
			]},
			{"face": "thoughtful", "text": """
She draws an invisible line across the window's dusty ledge.

Edda: I used to write songs in a little book. I always chose the respectable version. Anyone reading it would think we were a household of remarkably solemn children. That book is a terrible witness.
""", "options": [
				{"say": "Who invented the other version?", "tone": "ask", "face": "amused", "reply": """
Edda: My cousin claimed credit. So did three children from the next street. I suspect it belonged to everyone and none of them. He considered this an outrageous accusation. He was eight; he took authorship very seriously.
"""},
				{"say": "I forget lyrics too.", "tone": "share", "face": "amused", "reply": """
Edda: Then we could form a very unreliable choir. No performances, naturally. We would meet, disagree about the second verse, and go home. It sounds like an excellent institution. I would happily keep no records of it.
"""},
				{"say": "What else did the book leave out?", "tone": "ask", "face": "amused", "reply": """
Edda: A rhyme about my uncle's hat that would have ended my career before it began. A counting game whose forfeit was kissing the pump handle. Everything worth remembering, in short.

Edda: I kept excellent records of all the wrong things.
"""},
			]},
		],
		"closing_face": "amused", "closing": """
She tries the rhythm again, silently fitting the impossible ending into it. Her expression becomes so concentrated that you both laugh.

Edda: There. That is why I stopped writing it down. Some things are better when someone is getting them slightly wrong beside you.

The tapping fades. She leaves the dust on the sill undisturbed.

Edda: If you ever find that book, promise me nothing. Just remember that its author knew considerably more foolish songs than she admitted.
""",
		"summary": "Edda remembers two endings to a childhood song: her aunt's respectable lesson and her cousin's absurd flour-bin mishap. She admits that her careful childhood songbook left out the version she liked best. You share a laugh about unreliable lyrics, without performing a song or passing a test.",
		"memory": "Learned why Edda's childhood songbook left out the funniest ending.",
	},
	"edda_boots_by_door": {
		"title": "Boots by the Door", "rank": "B", "requires_any": ["edda_spare_spoon", "edda_wrong_verse"],
		"parts": [
			{"face": "concerned", "text": """
Edda pauses under a sheltered doorway. Beyond it, water drips steadily from a crooked gutter.

Edda: Our old roof made exactly that noise. I used to put a bowl underneath and pretend it was keeping time.

She glances at the boots beside the entrance. One pair has fallen over in the wet.

[?edda_counted] Edda: Seven pairs. I counted before I could stop myself. You have seen me do it.
""", "options": [
				{"say": "I'll bring them in out of the rain.", "tone": "help", "reply": """
You stand the fallen pair under the eave and, without thinking, set the rest beside them, largest to smallest.

Edda: You have done that before. Or you were once a child waiting for someone. It is the same training.
"""},
				{"say": "Stand here a minute. I like the noise.", "tone": "quiet", "reply": """
She had been about to go in. She stays instead, her shoulder almost against the doorframe.

Edda: Most people apologize for a gutter. You are an unusual guest.
"""},
			]},
			{"face": "thoughtful", "text": """
Edda: My aunt visited the outlying houses. I imagined she was discussing great matters. Boundaries, harvests, things with seals attached. Mostly she listened to people explain which door wouldn't shut and whose roof still leaked. She remembered all of it.

Edda: Before I was old enough to go with her, I waited. I lined up everyone's muddy boots by size. I believed that if the hall looked ready, she would come home sooner. Children make very odd bargains with furniture.

She smiles, then lets the smile go.

Edda: Once she missed a little celebration I had spent all afternoon preparing. I understood why she was late. I was still furious. Those two things occupied the same small child quite comfortably.
""", "options": [
				{"say": "You were right to be furious.", "tone": "comfort", "mark": "edda_aunt_right", "reply": """
Edda: I have waited a long time for someone to say so without adding 'but'.

She waits. You don't add it.

Edda: Thank you. I shall be insufferable about it for an hour.
"""},
				{"say": "I think she knew what it cost you.", "tone": "comfort", "mark": "edda_aunt_knew", "reply": """
Edda: She did. She brought me back a ribbon from the far farm, which is not what a person brings unless she has been thinking about someone the whole road home.

Edda: I wore it. Furiously.
"""},
			]},
			{"face": "concerned", "text": """
Edda: I should tell you the rest, since you are being fair to both of us. This spring I had a supper planned for the kitchen girls. Nothing grand. Then a roof went at one of the outlying farms, and I rode out.

Edda: I came back after the candles. They had kept me a plate. Nobody was furious. That was considerably worse.
""", "options": [
				{"say": "What do you remember most, from the first one?", "tone": "ask", "face": "thoughtful", "reply": """
Edda: The candles bending. I had set them too near the hearth. And how pleased she looked when she finally saw everything. That made it harder to be angry, which made me angrier. Memory is not a particularly orderly cupboard.
"""},
				{"say": "Did you and she ever talk about it?", "tone": "ask", "face": "thoughtful", "reply": """
Edda: Badly, at first. I accused her of preferring broken roofs to me. She explained the roofs. Neither of us had answered the other. Later we did better. Not perfectly, but better. I am glad we had later.
"""},
				{"say": "Next time, tell me. I'll ride out to the roof.", "tone": "heart", "when": "romantic", "face": "warm",
					"memory": "Listened to Edda's memories of waiting by the door, and offered to ride out to the next roof in her place.", "reply": """
Edda: You would, too. You would stand in someone's kitchen holding a ladder and getting the children's names wrong.

She has stepped nearer without quite deciding to.

Edda: Then I should have no excuse left, and should have to sit down at my own supper. It is a serious offer. I am giving it serious thought.
"""},
				{"say": "Next time, send word. I can hold a ladder.", "tone": "warm", "when": "friend", "face": "warm",
					"memory": "Listened to Edda's memories of waiting by the door, and offered to hold the ladder next time.", "reply": """
Edda: Badly, I expect. But you would hold it.

Edda: I am not used to having someone to send word to. I shall have to remember that I do.
"""},
			]},
		],
		"closing_face": "thoughtful", "closing": """
A drop lands in the bowl someone has placed beneath the gutter. Edda listens until the next one falls.

Edda: I keep her habit of remembering the roofs. I hope I also remember the person waiting by the door.

After a while she straightens a boot with her foot, notices herself doing it, and leaves its neighbor crooked.

Edda: Come inside. We needn't spend the whole visit in the doorway.
""",
		"summary": "Rain recalls Edda's childhood waits for an aunt who visited struggling households. Edda admired that care and resented the missed celebration; both feelings remain. This spring she missed a supper of her own for a farm roof. You listen without judging her family, and she reflects on remembering the people who wait as well as those who need help.",
		"memory": "Listened to Edda's memories of waiting beside the boots by the door.",
	},
	"edda_morning_unclaimed": {
		"title": "A Morning Unclaimed", "rank": "B", "requires_any": ["edda_boots_by_door"],
		"parts": [
			{"face": "amused", "text": """
A quiet bench has room for two. Edda sits at one end, hands folded as though she is waiting for the purpose of the bench to be explained.

[?edda_aunt_right] Edda: You told me I was right to be furious, in the doorway. I have been pleasant to everyone since. It can't last.

[?edda_aunt_knew] Edda: I found the ribbon, after we talked in the doorway. It was in with the good thread. I have not decided what to do with it.

You: A morning with nothing that needs doing. What would you choose?

Edda: I would mend— oh. You mean it. Nothing? Not even a letter?
""", "options": [
				{"say": "Nothing. I'll confiscate the pen.", "tone": "tease", "reply": """
Edda: You will find three more. I keep them the way other people keep grudges.

She considers the question with suspicious seriousness.
"""},
				{"say": "One errand. A small one. Then nothing.", "tone": "share", "reply": """
Edda: Don't negotiate with me. I shall take the errand and build a morning's work on it.

Edda: No. Nothing. I can do nothing. I have seen it done.
"""},
			]},
			{"face": "amused", "text": """
Edda: The river, perhaps. My younger cousin and I used to skip stones. She had no technique whatsoever and regularly beat me. I found that deeply unreasonable.

You: Did you tell her?

Edda: At length. She asked whether I wanted to make a complaint to the river. I had walked directly into that one.
""", "options": [
				{"say": "Tell me your technique.", "tone": "ask", "reply": """
Edda: Flat, but not too thin. Round, unless a better stone happens to be oval. You see how rigorous this is. Then a low throw and complete confidence that your cousin is standing in the better spot. That last part is essential.
"""},
				{"say": "Even leisure is a contest?", "tone": "tease", "reply": """
Edda: Only when I am losing. When I win, it becomes a pleasant family tradition. I can hear how that sounds. You needn't look so delighted. My cousin would have liked you immediately, which is a mildly alarming thought.
"""},
			]},
			{"face": "thoughtful", "text": """
Edda picks up a fallen leaf and turns it between her fingers.

Edda: I haven't thought about that in years. I remember where the bank was softest, though. And the exact face she made when her stone went farther. Some records apparently keep themselves.

Edda: Now you. The same question, and you may not answer 'drill'. A morning with nothing that needs doing.
""", "options": [
				{"say": "The river. I'd like to lose to your cousin.", "tone": "share", "mark": "edda_morning_river", "face": "amused", "reply": """
Edda: Everyone does. It is very good for the character, and she will tell you so.

Edda: I shall write to her. Not to arrange it. Only so that she can begin being unbearable in advance.
"""},
				{"say": "Sleep. Until the camp gives up on me.", "tone": "share", "mark": "edda_morning_sleep", "face": "amused", "reply": """
Edda: How long does that take? No, don't tell me, I shall start planning around it.

Edda: I have never once slept past the bread. I am told it is pleasant. Report back.
"""},
				{"say": "A market, and no list.", "tone": "share", "when": "friend", "mark": "edda_morning_market", "face": "amused", "reply": """
Edda: No list. You say it so calmly.

Edda: I should like to watch that. From a distance, at first. I would bring a list in case of emergency, and not look at it.
"""},
				{"say": "This one. A bench, and you with nothing to do.", "tone": "heart", "when": "romantic", "mark": "edda_morning_bench", "face": "warm", "reply": """
Edda: That is not an answer. That is flattery sitting where an answer should be.

She does not look displeased. Her hands, at least, have come unfolded.

Edda: It is a good bench. I shall allow it.
"""},
			]},
		],
		"closing_face": "amused", "closing": """
She lets the leaf fall. There is no river here to settle the old contest, and neither of you gets up to find one.

Edda: I think I would enjoy choosing the stones again. Even if I lost. Please don't send that admission to my cousin.

You sit a little longer.

Edda: That was a surprisingly difficult question. Ask me another ordinary one sometime. I seem to have neglected them.
""",
		"summary": "Asked how she would spend a free morning, Edda first lists work, then remembers skipping stones with a cousin who always beat her. She asks you the same question, and you tell her what your own morning would be. The talk makes room for an ordinary pleasure; it creates no appointment or obligation.",
		"memory": "Imagined an unclaimed morning with Edda, and told her what yours would be.",
	},
	"edda_ledger_blot": {
		"title": "The Blot in the Ledger", "rank": "A", "requires_any": ["edda_morning_unclaimed"],
		"parts": [
			{"face": "concerned", "text": """
Edda has a loose page on the desk. A thick correction crosses one line, and a blot obscures part of the margin. She has turned it face down twice since you came in.

Edda: It is nothing. It is a page. I keep it for reasons that sounded better this morning.
""", "options": [
				{"say": "May I see it?", "tone": "ask", "reply": """
She turns it over and slides it across, one finger still on the corner.

Edda: My first year keeping accounts. That is my handwriting, before I learned that making a number beautiful does not make it correct.
"""},
				{"say": "Show me when you're ready. Or not at all.", "tone": "quiet", "reply": """
She looks at the page, then at you, and turns it over herself.

Edda: That is an irritatingly effective thing to say to me. My first year keeping accounts. That is my handwriting, before I learned that making a number beautiful does not make it correct.
"""},
			]},
			{"face": "concerned", "text": """
Edda: I entered a payment under the wrong name. A family was asked for the same levy twice. We corrected it before anything was collected, but they still had to come and explain themselves. Then I had to go and explain myself.

Edda: At their kitchen table. There was a small boy watching me as though I might perform another mistake for his entertainment. His mother made him stop staring. He stared from behind his cup instead.
""", "options": [
				{"say": "I'd have been as frightened as you were.", "tone": "share", "reply": """
Edda: That moment before you knock is awful, isn't it? You imagine every possible speech except the one you actually give.

Edda: I won't ask you to trade a confession for mine. It helps simply to know you recognize the doorstep.
"""},
				{"say": "What did they say to you?", "tone": "ask", "reply": """
Edda: They wanted to know it wouldn't happen again. I wanted to promise that. Instead I explained how we would check the entries. It was a smaller answer and a more useful one.

Edda: Then the boy asked whether I could draw a horse.
"""},
			]},
			{"face": "concerned", "text": """
Edda: My supervisor would not let me copy the page clean. He said a correction should be visible to the next person checking the book. I thought he was keeping evidence against me. That tells you something about being young.

She squares the page against the desk's edge, which it does not need.

Edda: I made another one. This month. A tally of seed grain, carried over wrong. I found it myself, at night, and I have not yet shown anyone. You are the first.
""", "options": [
				{"say": "Why keep the old page at all?", "tone": "ask", "face": "thoughtful", "reply": """
Edda: At first, to punish myself efficiently. I could feel dreadful without leaving my desk.

Edda: Now it reminds me that fixing something leaves a mark, and the mark belongs in the record. I do occasionally need reminding of the difference.
"""},
				{"say": "Then show me the new one. We'll read it together.", "tone": "help", "face": "thoughtful",
					"memory": "Saw the corrected ledger page Edda keeps, and read the new correction with her before anyone else had.", "reply": """
Edda takes a second sheet from under the blotter. The correction on it is small and very straight.

Edda: There. Carried over as forty; it was fourteen. Nobody has gone hungry over it, and nobody will. It is better, read aloud. It sounds like a number again and not a verdict.
"""},
				{"say": "You found it at night and came to work in the morning. I like that about you.", "tone": "heart", "when": "romantic", "face": "warm", "reply": """
Edda: You like that I lose sleep over seed grain.

Edda: No. I heard it. I am only going to stand here a moment and hear it again.
"""},
				{"say": "Whoever checks that book after you is lucky.", "tone": "warm", "when": "friend", "face": "warm", "reply": """
Edda: They will not think so. They will think: here is a woman who could not carry a four.

Edda: But they will be able to see it. Yes. That is rather the point. Thank you.
"""},
			]},
		],
		"closing_face": "thoughtful", "closing": """
She slides the old page back into its folder. One corner remains uneven. Her hand moves to straighten it, then stops.

Edda: That first family forgave me before I did. It was inconvenient. I had prepared a very thorough case against myself.

You: And the horse?

Edda: Terrible. He said so immediately. A useful second opinion.

[?edda_counted] Edda: You count well, for a soldier. I may let you check the next page.

She closes the folder with the crooked corner still showing, and lays the new correction on top of tomorrow's work, where the clerk will see it first.
""",
		"summary": "Edda shows you a corrected page from her first year as a clerk: an entry error briefly had a family asked for a levy twice, and she apologized at their kitchen table. She keeps the correction visible on purpose. Then she tells you about a new mistake she found this month and has shown no one else.",
		"memory": "Saw the corrected ledger page Edda keeps, and the new correction she had shown no one else.",
	},
	"edda_place_no_task": {
		"title": "A Place With No Task", "rank": "A", "requires_any": ["edda_ledger_blot"], "coda": true,
		"parts": [
			{"face": "warm", "text": """
There are two places at a small table. Edda has already drawn back both chairs. A folded cloth sits slightly crooked between them.

Edda: I have no letters for you. No requests, either. I checked, in case habit had hidden one up my sleeve.

[?edda_spare_spoon] Edda: I put my own spoon out first this time. And you already know how to open the drawer.
""", "options": [
				{"say": "Then I'll sit before you find one.", "tone": "tease", "reply": """
You take the nearer chair. Edda stays standing a moment longer, as if the room might still produce a task.

Edda: Very well. A remarkable administrative achievement: I have been outmanoeuvred into my own chair.
"""},
				{"say": "After you. It's your table.", "tone": "quiet", "reply": """
She begins to ask whether you need anything, stops halfway through the question, and sits down instead.

Edda: There. A remarkable administrative achievement. I have managed to occupy my own chair.
"""},
			]},
			{"face": "warm", "text": """
For a moment she watches the doorway. Then she turns back to you.

Edda: I used to think a visit needed a reason I could explain afterward. A problem solved, a message delivered. Now I am trying to let the afternoon speak for itself. It has made no requests for better management.

[?edda_argued_verse] Edda: You still owe the miller an apology, by the way. I have not forgotten whose side you took.

[?edda_wrong_verse,!edda_argued_verse] She taps a familiar, slightly impossible rhythm on the table: the miller's unfortunate ending.
""", "options": [
				{"say": "You left the cloth crooked.", "tone": "tease", "reply": """
Edda glances at the cloth, then back at you.

Edda: I did. I considered straightening it, but I was already sitting comfortably. A difficult decision. I expect the table will survive the consequences.
"""},
				{"say": "How was your day?", "tone": "ask", "reply": """
Edda: Ordinary. Someone told a story badly, and I laughed anyway. I found something I thought I had lost. Nothing that belongs in a report.

Edda: Thank you for asking a question with room for such an unimportant answer. I liked my day.
"""},
			]},
			{"face": "warm", "text": """
[?edda_morning_river] Edda: My cousin has written back, incidentally. She says she will go easy on you at the river. She will not.

[?edda_morning_sleep] Edda: I slept past the bread on Tuesday. On purpose. I lay there the entire time composing a list of what I was not doing, but I am told that counts.

[?edda_morning_market] Edda: I went to the market without a list. I came back with a list. Someone was selling paper.

[?edda_morning_bench] Edda: I have been back to that bench. It is a perfectly ordinary bench when you are not on it. I checked.

Somewhere beyond the room, a door closes and someone laughs. Neither of you has to explain the sound or turn it into a subject.

Edda: Stay a little, if you like. I haven't anything else to offer you.
""", "options": [
				{"say": "This is enough.", "tone": "quiet", "reply": """
She smiles, accepting the answer without searching for something to add.

Edda: Then I shall stop looking for more. That is harder than it sounds, and I am doing it anyway.
"""},
				{"say": "Then tell me nothing important.", "tone": "ask", "reply": """
Edda: The pump handle froze and the cook has named it. The cat has taken the good windowsill. I found a glove I have blamed on a cousin since autumn.

Edda: Not one line of it belongs in a report. I shall want yours afterward, in the same detail.
"""},
				{"say": "Give me your hand, then. That's something.", "tone": "heart", "when": "romantic",
					"memory": "Shared a quiet visit with Edda, with no task to justify it, and her hand in yours.", "reply": """
You offer your hand across the table. She takes it, gently, and does not let go to straighten the cloth.

Edda: I had not counted that. I shall have to revise the inventory.
"""},
				{"say": "Your company's the offer. I'll take it.", "tone": "warm", "when": "friend", "reply": """
Edda leans back in her chair, at ease in the familiar company of a friend.

Edda: Then we are both well supplied.
"""},
			]},
		],
		"closing_face": "warm", "closing": """
She rests her hands on the table. The cloth remains crooked. Nothing has been promised or assigned, and the visit has not become less worthwhile for it.

Edda: Two places. I counted them twice, from habit, and both times I was one of them.

Outside, the afternoon goes on without being managed.
""",
		"summary": "Edda has set two places, including her own. With no letters or requests to deliver, she enjoys your company for its own sake. A harmless crooked cloth stays crooked. You share an ordinary, comfortable visit that reflects the relationship you already chose together, without making a new promise.",
		"memory": "Shared a quiet visit with Edda, with no task to justify being together.",
	},
	"edda_who_set_your_place": {
		"title": "Who Set Your Place", "rank": "S", "requires_any": ["edda_place_no_task"], "coda": true,
		"parts": [
			{"face": "thoughtful", "text": """
Edda is laying a table, and for once she is doing it slowly. Two bowls. Two cups. She has a spoon in each hand and has not put either down.

Edda: I have been meaning to ask you something, and I have been laying this table for a quarter of an hour so as not to.

[?edda_noticed_place] Edda: You noticed, that first evening, that I had counted everyone but myself. I have been turning it over ever since. It occurred to me that I never asked who counted you.

[?!edda_noticed_place] Edda: I have told you about my uncle's extra bowl a dozen times. It occurred to me that I never asked who set a place for you.
""", "options": [
				{"say": "Ask. I've nowhere to be.", "tone": "quiet", "reply": """
Edda: You always say that, and then a rider comes.

She puts one spoon down, which leaves her a hand free and nothing to do with it.
"""},
				{"say": "Put the spoons down first.", "tone": "tease", "reply": """
Edda: I am perfectly capable of asking a question while holding—

She looks at her hands, and puts the spoons down.

Edda: That was unfair. Accurate, and unfair.
"""},
			]},
			{"face": "thoughtful", "text": """
Edda: When you were small. Before the company, before anyone called you captain. Who set a place for you?
""", "options": [
				{"say": "Someone at home. Every night, early.", "tone": "share", "mark": "you_place_home", "face": "warm", "reply": """
She nods slowly, as if a column has finally come out even.

Edda: Early. So you were expected. It shows, you know. You sit down at a table as though it had been waiting for you. I used to think that was a soldier's confidence.
"""},
				{"say": "A stranger, once, on the road. I never forgot it.", "tone": "share", "mark": "you_place_stranger", "face": "warm", "reply": """
Edda: One bowl, from someone who owed you nothing.

Edda: I know that bowl. My uncle set it out every night for twenty years, and I never once met the person who needed it the way you did. I shall tell him it was used.
"""},
				{"say": "No one. I learned to set my own.", "tone": "share", "mark": "you_place_none", "face": "concerned", "reply": """
Edda does not say she is sorry. She looks at the table she has been laying for a quarter of an hour.

Edda: Then you have been doing my work your whole life, and nobody thanked you for it either. That is going to stop. I am very good at stopping things.
"""},
			]},
			{"face": "warm", "text": """
She takes up the second bowl again and sets it down, not opposite her own but beside it. She squares it. She un-squares it.

Edda: This is yours. Not the guest's place. Not whoever comes. I have written it in the household book, in ink, between the linen and the lamp oil, and the clerk has been told not to query it.

She steps back and counts the table aloud.

Edda: One. Two.
""", "options": [
				{"say": "You counted yourself first.", "tone": "tease", "reply": """
Edda: I did. I have been practising when you are not here.

Edda: It is easier with two. With one, I kept losing my place.
"""},
				{"say": "Then I'll be home for supper.", "tone": "share", "reply": """
Edda: Don't promise the hour. I know what roads are.

Edda: Promise the place. I shall keep it whether you are in it or not. That is what it is for.
"""},
				{"say": "Two. I like how that sounds when you say it.", "tone": "heart", "when": "romantic",
					"memory": "Edda asked who set a place for you, then set one beside her own, in ink, and counted to two.", "reply": """
Edda: Two.

She says it again, more quietly, to see whether it holds. It does.

Edda: I have counted a great many things in this house. I think that is the first number I have wanted to keep.
"""},
				{"say": "Two. Your uncle would approve.", "tone": "warm", "when": "friend", "reply": """
Edda: He would set a third, on principle.

Edda: But yes. He would look at this table and say nothing at all, which from him was applause.
"""},
			]},
		],
		"closing_face": "warm", "closing": """
You sit. The drawer sticks when she goes for the ladle; you lift it a little without being asked, and she lets you.

Edda: Seven spoons, the first evening. I remember being so sure the trouble was the number.

She sits down beside you, in the place she counted first.
""",
		"summary": "Edda asks who set a place for you when you were small, and you tell her. Then she sets a place at her own table that is yours and no guest's, writes it into the household book, and counts the table aloud: herself first, then you.",
		"memory": "Edda asked who set a place for you, and then set one beside her own, in ink.",
	},
	"edda_home_on_time": {
		"title": "Home on Time", "rank": "S", "requires_any": ["edda_who_set_your_place"], "coda": true,
		"parts": [
			{"face": "concerned", "text": """
The hall smells of bread. Trestles are up, the good cloth is out, and Edda is standing in the middle of it all with her riding cloak already over one arm.

Edda: The Hollin farm has lost half its barn roof. The boy came an hour ago. The feast is at dusk. If I ride now I can see the damage and be back before the second course.

She is not looking at you. She is looking at the door, which is where her aunt always was.
""", "options": [
				{"say": "Your aunt would have gone.", "tone": "ask", "reply": """
Edda: Yes.

Edda: And been back for the second course, and missed the first, and been forgiven by everyone at the table except one.
"""},
				{"say": "I'll hold your cloak. Either way.", "tone": "quiet", "reply": """
You take the cloak from her arm and fold it, badly. She watches you do it.

Edda: You are not going to tell me what to do. You never do. It is extremely inconvenient.
"""},
			]},
			{"face": "thoughtful", "text": """
[?edda_aunt_right] Edda: You told me once I was right to be furious. I have been wondering whether I am about to earn it from someone else.

[?edda_aunt_knew] Edda: You said she knew what it cost. She did. So do I. That has never yet been enough to stop a person.

[?!edda_aunt_right,!edda_aunt_knew] Edda: I used to line up the boots so she would come home sooner. Somebody in that kitchen is doing the same with the cups. I can see it from here.

Edda: The roof is real. But the girls have been at this since before light, and three of them have asked the cook whether I am coming.

She calls the stable boy and gives him the errand without herself in it: the carpenter, two men, a tarpaulin tonight, and the steward at first light with the tally book.

Edda: There. A roof can be looked at in the morning. A first course cannot.
""", "options": [
				{"say": "How does it feel?", "tone": "ask", "reply": """
Edda: Like leaving a column unadded. I keep reaching for it.

Edda: Ask me again after the soup. I suspect it is going to feel like supper.
"""},
				{"say": "I'll ride out with you at first light.", "tone": "help", "reply": """
Edda: You will be useless on a roof.

Edda: Come anyway. You can hold the tally book and tell the Hollins I was late on purpose. They should hear that it can be done.
"""},
				{"say": "Stay. And I'll stay too, if I'm asked.", "tone": "heart", "when": "romantic",
					"memory": "Stayed beside Edda at the feast she nearly rode away from, and was counted.", "reply": """
Edda: You are asked. You were asked when I wrote you into the household book.

She puts her arm through yours, in front of the whole kitchen, as though it were simply where an arm goes.

Edda: Come and be counted.
"""},
				{"say": "Then put me to work. What needs carrying?", "tone": "warm", "when": "friend", "reply": """
Edda: The bread. All of it. You may not eat any on the way; I shall know.

Edda: And sit by me when it is done. I want one person at that table who knows what I nearly did.
"""},
			]},
		],
		"closing_face": "warm", "closing": """
The hall fills. Somebody has brought a cousin; somebody generally does. Edda counts heads from the doorway, once, and comes out even.

[?you_place_home] Edda: Early. You said they set yours early. I begin to see why.

[?you_place_stranger] Edda: There is a spare bowl at the end, for whoever is on the road tonight. You know why.

[?you_place_none] Edda: Yours is the one by mine. Nobody set it but me. I wanted you to know whose hand.

She is in her chair before the first course is carried in. The door stays shut behind her, and she does not once turn to look at it.
""",
		"summary": "On the evening of a feast Edda has arranged for the household, word comes of a barn roof down at an outlying farm. She has her cloak on her arm, as her aunt always did. This time she sends the carpenter, keeps the roof for the morning, and is in her chair before the first course.",
		"memory": "Stayed with Edda for the feast she nearly rode away from.",
	},
}
