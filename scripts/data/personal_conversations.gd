## Original, optional backstory. Choices are expressive, never scored differently.
extends RefCounted

const VERSION := 1
const SCENES := {
	"edda_spare_spoon": {
		"title": "The Spare Spoon", "requires_any": [],
		"opening": "Edda stands beside a small table, moving spoons from one place to another.\n\nEdda: Seven spoons. Six guests. That ought to be enough. Unless someone has brought a cousin. Someone generally brings a cousin.\n\nShe counts again, silently, then looks at you.\n\nEdda: You needn't stand as though this is an inspection. I was remembering supper at home. My mother would announce the exact number expected, and my uncle would set another bowl out without answering her. They did this every evening for years.\n\nYou: Was someone always late?\n\nEdda: Our neighbor, usually. She claimed she only came to return things. A cup, a scarf, a pan she had borrowed before I was born. Somehow she always returned them just as the soup arrived.\n\nEdda turns a spoon over. Its handle has been worn almost smooth.\n\nEdda: I thought the extra place was for her. Later I realized nobody ever decided who it belonged to. That was rather the point.",
		"choices": ["Who usually arrived late?", "You missed your own place.", "I can sit wherever is free."],
		"responses": [
			"Edda: The neighbor could be relied upon. My cousin was less predictable. Once he arrived with a dog and argued that nobody had specifically excluded dogs. My mother gave it his chair. He ate standing up, very politely.",
			"Edda looks down at the empty end of the table.\n\nEdda: It is too early in the evening for you to be this observant. Yes. I have counted everyone except myself. Again. Please don't give the household a new saying about it.",
			"Edda: A dangerous offer. At home that meant beside my uncle, who believed every meal needed a detailed account of the weather. He could make three minutes of rain last until pudding. I was very fond of him."
		],
		"closing": "She opens a drawer, catches it against her knee, and lifts it carefully.\n\nEdda: It sticks. You have to lift it a little.\n\nYou take another spoon and lay it at her place. She leaves it there. For a moment neither of you rearranges anything.\n\nEdda: There. Now there is enough room. I suppose I can stop counting.\n\nShe sits down, looking pleased by the small untidiness of an extra setting.",
		"summary": "Edda recalls the extra place her family always set for an unexpected visitor. While counting everyone else's spoons, she forgets her own. You help set a place for her, and she sits down. The sticking drawer and the unclaimed seat become small shared memories.",
		"memory": "Shared the story of Edda's spare spoon and made room for her at the table."
	},
	"edda_wrong_verse": {
		"title": "The Wrong Last Verse", "requires_any": [],
		"opening": "By a window, Edda is tapping a rhythm on the sill. She stops when she notices you, then deliberately starts again.\n\nEdda: I am trying to remember a song. Before you ask, it has no historical importance whatsoever. There is a miller, a sack of flour, and an argument about a donkey.\n\nYou: Which part have you forgotten?\n\nEdda: The ending. Or rather, I remember two endings, and one of them cannot possibly fit the tune. My aunt insisted that the miller learned patience. My cousin insisted that he fell headfirst into his own flour bin.\n\nYou: Which did you sing?\n\nEdda: Indoors? Patience. I was a sensible child.\n\nShe draws an invisible line across the window's dusty ledge.\n\nEdda: I used to write songs in a little book. I always chose the respectable version. Anyone reading it would think we were a household of remarkably solemn children. That book is a terrible witness.",
		"choices": ["Tell me the ridiculous ending.", "Who invented that version?", "I forget lyrics too."],
		"responses": [
			"Edda: The donkey refuses to recognize him until he sneezes. That is the entire joke. My cousin needed four extra lines to explain it, which he sang increasingly quickly. It was dreadful. I still laughed every time.",
			"Edda: My cousin claimed credit. So did three children from the next street. I suspect it belonged to everyone and none of them. He considered this an outrageous accusation. He was eight; he took authorship very seriously.",
			"Edda: Then we could form a very unreliable choir. No performances, naturally. We would meet, disagree about the second verse, and go home. It sounds like an excellent institution. I would happily keep no records of it."
		],
		"closing": "She tries the rhythm again, silently fitting the impossible ending into it. Her expression becomes so concentrated that you both laugh.\n\nEdda: There. That is why I stopped writing it down. Some things are better when someone is getting them slightly wrong beside you.\n\nThe tapping fades. She leaves the dust on the sill undisturbed.\n\nEdda: If you ever find that book, promise me nothing. Just remember that its author knew considerably more foolish songs than she admitted.",
		"summary": "Edda remembers two endings to a childhood song: her aunt's respectable lesson and her cousin's absurd flour-bin mishap. She admits that her careful childhood songbook omitted the version she liked best. You share a laugh about unreliable lyrics, without performing a song or passing a test.",
		"memory": "Learned why Edda's childhood songbook left out the funniest ending."
	},
	"edda_boots_by_door": {
		"title": "Boots by the Door", "requires_any": ["edda_spare_spoon", "edda_wrong_verse"],
		"opening": "Edda pauses under a sheltered doorway. Beyond it, water drips steadily from a crooked gutter.\n\nEdda: Our old roof made exactly that noise. I used to put a bowl underneath and pretend it was keeping time.\n\nShe glances at the boots beside the entrance.\n\nEdda: My aunt visited the outlying houses. I imagined she was discussing great matters. Boundaries, harvests, things with seals attached. Mostly she listened to people explain which door wouldn't shut and whose roof still leaked. She remembered all of it.\n\nYou: Did you go with her?\n\nEdda: When I was older. Before that, I waited. I lined up everyone's muddy boots by size. I believed that if the hall looked ready, she would come home sooner. Children make very odd bargains with furniture.\n\nShe smiles, then lets the smile go.\n\nEdda: Once she missed a little celebration I had spent all afternoon preparing. I understood why she was late. I was still furious. Those two things occupied the same small child quite comfortably.",
		"choices": ["What do you remember most?", "That sounds lonely.", "Did you ever talk about it?"],
		"responses": [
			"Edda: The candles bending. I had set them too near the hearth. And how pleased she looked when she finally saw everything. That made it harder to be angry, which made me angrier. Memory is not a particularly orderly cupboard.",
			"Edda: Sometimes. There were other people in the house, but they weren't the person I was waiting for. I don't need you to decide she was unkind. She wasn't. I simply wish she had come home earlier that evening.",
			"Edda: Badly, at first. I accused her of preferring broken roofs to me. She explained the roofs. Neither of us had answered the other. Later we did better. Not perfectly, but better. I am glad we had later."
		],
		"closing": "A drop lands in the bowl someone has placed beneath the gutter. Edda listens until the next one falls.\n\nEdda: I keep her habit of remembering the roofs. I hope I also remember the person waiting by the door.\n\nYou stay beside her without trying to settle the old argument. After a while she straightens a boot with her foot, notices herself doing it, and leaves its neighbor crooked.\n\nEdda: Come inside. We needn't spend the whole visit in the doorway.",
		"summary": "Rain recalls Edda's childhood waits for an aunt who visited struggling households. Edda admired that care and resented the missed celebrations. Both feelings remain part of the memory. You listen without judging her family, and she reflects on remembering the people who wait as well as those who need help.",
		"memory": "Listened to Edda's memories of waiting beside the boots by the door."
	},
	"edda_morning_unclaimed": {
		"title": "A Morning Unclaimed", "requires_any": ["edda_boots_by_door"],
		"opening": "A quiet bench has room for two. Edda sits at one end, hands folded as though she is waiting for the purpose of the bench to be explained.\n\nYou: A morning with nothing that needs doing. What would you choose?\n\nEdda: I would mend—oh. You mean it. Nothing? Not even a letter?\n\nYou: Nothing that needs doing.\n\nShe considers this with suspicious seriousness.\n\nEdda: The river, perhaps. My younger cousin and I used to skip stones. She had no technique whatsoever and regularly beat me. I found that deeply unreasonable.\n\nYou: Did you tell her?\n\nEdda: At length. She asked whether I wanted to make a complaint to the river. I had walked directly into that one.\n\nEdda picks up a fallen leaf and turns it between her fingers.\n\nEdda: I haven't thought about that in years. I remember where the bank was softest, though. And the exact face she made when her stone went farther. Some records apparently keep themselves.",
		"choices": ["Tell me your technique.", "I like a quiet walk.", "Even leisure is a contest?"],
		"responses": [
			"Edda: Flat, but not too thin. Round, unless a better stone happens to be oval. You see how rigorous this is. Then a low throw and complete confidence that your cousin is standing in the better spot. That last part is essential.",
			"Edda: Without somewhere you must arrive? I like that. My walks tend to collect errands on the way. Perhaps yours could remain a walk. I shall try to remember that a destination is not a requirement. Neither, apparently, is a basket.",
			"Edda: Only when I am losing. When I win, it becomes a pleasant family tradition. I can hear how that sounds. You needn't look so delighted. My cousin would have liked you immediately, which is a mildly alarming thought."
		],
		"closing": "She lets the leaf fall. There is no river here to settle the old contest, and neither of you gets up to find one.\n\nEdda: I think I would enjoy choosing the stones again. Even if I lost. Please don't send that admission to my cousin.\n\nYou sit a little longer. Her hands are no longer folded.\n\nEdda: That was a surprisingly difficult question. Ask me another ordinary one sometime. I seem to have neglected them.",
		"summary": "Asked how she would spend a free morning, Edda initially lists work before remembering competitive childhood stone-skipping. She laughs about her elaborate technique and her cousin's effortless victories. Your conversation makes space for an ordinary pleasure; it creates no appointment, minigame, or obligation to visit the river.",
		"memory": "Imagined an unclaimed morning with Edda, remembering her stone-skipping rivalry."
	},
	"edda_ledger_blot": {
		"title": "The Blot in the Ledger", "requires_any": ["edda_morning_unclaimed"],
		"opening": "Edda has a loose page on the desk. A thick correction crosses one line, and a blot obscures part of the margin.\n\nEdda: My first year keeping accounts. That is my handwriting, before I learned that making a number beautiful does not make it correct.\n\nYou: What happened?\n\nEdda: I entered a payment under the wrong name. A family was asked for the same levy twice. We corrected it before anything was collected, but they still had to come and explain themselves. Then I had to go and explain myself.\n\nShe holds the page by its undamaged edge.\n\nEdda: At their kitchen table. There was a small boy watching me as though I might perform another mistake for his entertainment. His mother made him stop staring. He stared from behind his cup instead.\n\nYou: You kept the page?\n\nEdda: My supervisor would not let me copy it clean. He said a correction should be visible to the next person checking the book. I thought he was keeping evidence against me. That tells you something about being young.",
		"choices": ["What did the family say?", "Why keep it now?", "I've had to own a mistake too."],
		"responses": [
			"Edda: They wanted to know it wouldn't happen again. I wanted to promise that. Instead I explained how we would check the entries. It was a smaller answer and a more useful one. Then the boy asked whether I could draw a horse.",
			"Edda: At first, to punish myself efficiently. I could feel dreadful without leaving my desk. Now it reminds me that fixing something leaves a mark, and the mark belongs in the record. I do occasionally need reminding of the difference.",
			"Edda: That moment before you knock is awful, isn't it? You imagine every possible speech except the one you actually give. I won't ask you to trade a confession for mine. It helps simply to know you recognize the doorstep."
		],
		"closing": "She slides the page back into its folder. One corner remains uneven. Her hand moves to straighten it, then stops.\n\nEdda: They forgave me before I did. That was inconvenient. I had prepared a very thorough case against myself.\n\nYou: And the horse?\n\nEdda: Terrible. He said so immediately. A useful second opinion.\n\nShe closes the folder with the crooked corner still showing, and turns away from the desk to face you.",
		"summary": "Edda shows you a corrected page from her first year as a clerk. An entry error briefly caused a family to be asked for a levy twice; it was resolved long ago. She recalls apologizing at their table and explains why she now values keeping the correction visible.",
		"memory": "Saw the corrected ledger page Edda keeps as a reminder that mistakes can be repaired."
	},
	"edda_place_no_task": {
		"title": "A Place With No Task", "requires_any": ["edda_ledger_blot"], "coda": true,
		"opening": "There are two places at a small table. Edda has already drawn back both chairs. A folded cloth sits slightly crooked between them. The room is quiet enough to hear voices from the street.\n\nEdda: I have no letters for you. No requests, either. I checked, in case habit had hidden one up my sleeve.\n\nYou: Then I picked a good visit.\n\nEdda: I was hoping you might think so.\n\nShe begins to ask whether you need anything, stops halfway through the question, and sits down instead.\n\nEdda: There. A remarkable administrative achievement. I have managed to occupy my own chair.\n\nFor a moment she watches the doorway. Then she turns back to you.\n\nEdda: I used to think a visit needed a reason I could explain afterward. A problem solved, a message delivered. Otherwise I worried I had taken up someone's afternoon.\n\nYou: And now?\n\nEdda: Now I am trying to let the afternoon speak for itself. It seems quite content so far. It has made no requests for better management.",
		"choices": ["You left the cloth crooked.", "How was your day?", "Sit quietly together."],
		"responses": [
			"Edda glances at the cloth, then back at you.\n\nEdda: I did. I considered straightening it, but I was already sitting comfortably. A difficult decision. I expect the table will survive the consequences. We can review the matter when we stand up.",
			"Edda: Ordinary. Someone told a story badly, and I laughed anyway. I found something I thought I had lost. Nothing that belongs in a report. Thank you for asking a question with room for such an unimportant answer. I liked my day.",
			"At first Edda looks ready to fill the silence. Then she settles back. Somewhere beyond the room, a door closes and someone laughs. Neither of you has to explain the sound or turn it into a subject. The quiet holds comfortably."
		],
		"closing": "She rests her hands on the table. The cloth remains crooked. Nothing has been promised or assigned, and the visit has not become less worthwhile for it.\n\nEdda: Stay a little, if you like. I haven't anything else to offer you.\n\nYou: This is enough.\n\nShe smiles, accepting the answer without searching for something to add.",
		"summary": "Edda has set two places, including her own. With no letters or requests to deliver, she enjoys your company for its own sake. A harmless crooked cloth stays crooked. You share an ordinary, comfortable visit that reflects the relationship you already chose together, without making a new promise.",
		"memory": "Shared a quiet visit with Edda, with no task to justify being together."
	}
}

static func ids_for(candidate_id: String) -> Array:
	return SCENES.keys() if candidate_id == "edda" else []

static func ending(scene_id: String, context: Dictionary, completed: Array, choices: Dictionary) -> String:
	var result: String = SCENES[scene_id]["closing"]
	if scene_id == "edda_place_no_task":
		if completed.has("edda_spare_spoon"):
			result += "\n\nEdda: I put my spoon out first this time. And you already know how to open the drawer."
		if completed.has("edda_wrong_verse"):
			result += "\n\nShe taps a familiar, slightly impossible rhythm: the miller's unfortunate ending."
		if int(choices.get("edda_morning_unclaimed", -1)) == 1:
			result += "\n\nEdda: A visit without an errand. Like that quiet walk you mentioned."
		if context.get("romantic", false):
			result += "\n\nYou offer your hand across the table. She takes it, gently, and stays beside you."
		else:
			result += "\n\nEdda leans back in her chair, at ease in the familiar company of a friend."
	return result
