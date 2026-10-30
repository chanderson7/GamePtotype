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
	},
	"farid_supper_request": {
		"title": "Three Ways to Ask for Supper", "requires_any": [], "setting": "envoy_room",
		"opening": "Farah sits before a note whose first sentence occupies most of the page.\n\nFarah: If the household's present circumstances permit, and if the kitchen has not already committed its stores—\n\nYou: You're asking for soup.\n\nFarah lowers the page. Her dignity lasts for almost a breath.\n\nFarah: I had hoped not to sound demanding. When I was thirteen, I carried a message that said a visiting aunt wanted supper immediately. She had actually said she would eat whenever it was convenient. The cook fed her, then spent a year teaching me the difference.\n\nYou: A full year?\n\nFarah: She was thorough. By winter, I could request a cup of water in language suitable for ending a siege.\n\nShe points to three abandoned drafts. One apologizes to the lentils. Another assures the kitchen that refusing would not damage diplomatic relations.\n\nFarah: I know this is ridiculous. Knowing has not made the sentence shorter.",
		"choices": ["Read me the grandest version.", "Write: Is there any soup?", "I overthink small requests too."],
		"responses": [
			"Farah reads the longest draft with ceremonial gravity until she reaches a clause protecting the cook from future liability. She breaks first.\n\nFarah: I may preserve that line for an actual treaty. It would improve several of them.",
			"Farah writes the five words, then studies them as if they have arrived without credentials.\n\nFarah: Distressingly effective. It even leaves room for the answer. The cook will suspect someone else wrote it.",
			"Farah: Then you know how a harmless task can acquire witnesses, precedents, and an appeal process. I am relieved. I was afraid this was a private form of foolishness."
		],
		"closing": "She folds the shortest note before she can improve it. A servant passing the doorway accepts it without alarm.\n\nFarah: There. No border shifted. No aunt was offended. If soup arrives, I will try not to describe it as a successful negotiation.\n\nYou wait together. Farah moves the rejected drafts into a neat stack, then pulls the most elaborate one back out.\n\nFarah: This clause about lentils is genuinely excellent. Waste is still waste, even when it is funny.\n\nWhen the plain reply comes—yes, there is soup—she smiles at how little ceremony the answer required.",
		"summary": "Farah has turned a simple request for supper into diplomatic correspondence. She recalls the cook who taught her to soften messages, then lets you help her choose a plain sentence. The kitchen answers just as plainly. No supplies are bought; the soup and note remain part of an ordinary shared joke.",
		"memory": "Helped Farah ask for supper without drafting a treaty."
	},
	"farid_two_street_names": {
		"title": "The Street With Two Names", "requires_any": [], "setting": "qasr_hamra",
		"opening": "From the window, Farah points toward a lane hidden beyond the market roofs.\n\nFarah: Officially, South Market Street. At home, Crooked Lantern. Every letter from my mother used the second name, although no clerk recognized it.\n\nYou: Was the lantern crooked?\n\nFarah: The shopkeeper insisted the entire street was leaning. His lantern alone was honest about it.\n\nAs a child, Farah was sent to guide visitors who had followed the official signs into the wrong square. Her family argued over which name an outsider deserved to hear. Her uncle favored accuracy. Her mother favored arrival.\n\nFarah: I began writing directions in the margins of invitations. Turn where the spice seller sings badly. If you reach the blue well, you have believed the city surveyor.\n\nShe laughs.\n\nFarah: That may be why I care about correspondence. A letter should help one person find another. Everything more impressive came later.",
		"choices": ["Tell me about the shopkeeper.", "Which name do you use at home?", "I know a place with a private name."],
		"responses": [
			"Farah: He denied the lantern was crooked for thirty years, then sold little painted copies to travelers. Each copy leaned differently. He called that local accuracy.",
			"Farah: Crooked Lantern. South Market Street sounds like I am writing to request an audit. My aunt once returned a letter unopened because I used it. She said no niece of hers lived in an office.",
			"Farah listens for the shape of the name rather than asking whether it appears on a map.\n\nFarah: Then someone loved or disliked it enough to notice. Those are often the names that last."
		],
		"closing": "The lane remains out of sight, but Farah draws its turns on the dusty sill: left at the awning, right at the well, then toward the famously upright lantern.\n\nFarah: A proper envoy would verify these directions. A resident would tell you to follow the smell of bread.\n\nYou: Which are you today?\n\nShe considers, then wipes away the official route and leaves the shorter one.\n\nFarah: Today I would like you to arrive. Follow the bread.\n\nThe map is gone with a sweep of her sleeve, but the private name stays between you.",
		"summary": "Farah remembers a childhood street with an official name and the local name Crooked Lantern. Guiding lost visitors helped begin her love of correspondence: words mattered because they helped people find one another. You discuss the shopkeeper, family letters, or another private place-name without creating a map destination.",
		"memory": "Learned why Farah still calls South Market Street Crooked Lantern."
	},
	"farid_unsealed_letter": {
		"title": "The Letter Without a Seal", "requires_any": ["farid_supper_request", "farid_two_street_names"], "setting": "envoy_room",
		"opening": "An unsealed letter lies on Farah's table. Two pages discuss weather, safe roads, and everyone except the writer.\n\nFarah: My cousin asked whether I am happy. One question. I have written around it with considerable skill.\n\nYou: What did you want to say first?\n\nFarah: That depends which first you mean. The useful answer was that my work matters. The honest answer arrived before it, and I sent it away for lacking context.\n\nShe does not turn the page toward you.\n\nFarah: Envoys learn that words cannot be recalled once received. It is sensible training. It is less useful when a woman who changed your childhood bandages wants to know if you like your life.\n\nShe taps the blank space beneath the formal closing.\n\nFarah: I do. Mostly. There are parts I chose and parts I learned to call choices because they were mine to carry. I cannot fit that into a graceful sentence.",
		"choices": ["You don't have to read it to me.", "What would the small answer say?", "I find that question difficult too."],
		"responses": [
			"Farah's shoulders ease.\n\nFarah: Thank you. Privacy is not the same as loneliness, though people often offer company by taking it apart. You may stay while I write.",
			"Farah: It would say, 'Yes, and I am tired.' There. Seven words, none of them protected by a title. My cousin will understand both halves better than a court would.",
			"Farah: Then I will not ask you to answer in exchange. It is enough to know the question has weight in another hand. We can both be inarticulate with dignity."
		],
		"closing": "Farah draws a line through the account of the weather. Beneath it she writes one short sentence, shielding the page with her hand from habit rather than distrust.\n\nFarah: The first honest sentence is rather small. That may be why it frightened me. There was nowhere to hide the speaker.\n\nShe sands the ink but leaves the letter unsealed.\n\nFarah: I will read it tomorrow. If it still sounds like me, I will send it.\n\nYou talk about nothing urgent while the ink dries. For once, silence does not require her to supply a diplomatic bridge across it.",
		"summary": "A relative has asked Farah whether she is happy. Her draft answers with work, weather, and safe roads while avoiding the question. She writes one honest opening herself. You may ask, empathize, or protect her privacy; every response leaves the letter hers to send and creates no correspondence quest.",
		"memory": "Sat with Farah while she began an honest letter to her cousin."
	},
	"farid_wrong_courtesy": {
		"title": "The Wrong Courtesy", "requires_any": ["farid_unsealed_letter"], "setting": "envoy_room",
		"opening": "Farah is polishing a plain serving bowl, which seems beneath an envoy's attention until she explains why it makes her laugh.\n\nFarah: On my first independent visit, I brought my host an ornamental bowl in a box large enough for a saddle. Two servants carried it. The invitation had said informal supper.\n\nYou: What did they already own?\n\nFarah: Bowls. Several. Some of them useful.\n\nShe had prepared remarks about every carved symbol. Her host had prepared lentils and three questions about the road. They spent an hour admiring the gift because neither knew how to stop.\n\nFarah: At last she carried the plates away and asked whether I could dry them. I thought it was a test. It was, in a sense. She wanted to discover whether I could hold a cloth without explaining its lineage.\n\nThey spoke easily over the dishes. Farah remembers being relieved, embarrassed, and very careful not to polish the plates into diplomatic artifacts.",
		"choices": ["What became of the grand bowl?", "What did you talk about while drying?", "Your host found a kind exit."],
		"responses": [
			"Farah: She used it for onions. My uncle was appalled. I was secretly delighted. An object that expensive deserved useful work, even if the onions failed to admire it.",
			"Farah: A leaking roof, a nephew who refused sandals, and whether cardamom improves everything. She said no. I respected her courage, though she was plainly wrong.",
			"Farah: Yes. She did not mock the courtesy or submit to it forever. She simply handed me a towel. I have tried to remember that mercy can be practical."
		],
		"closing": "She puts the plain bowl back without making it shine.\n\nFarah: I still like ceremony. A beautiful welcome can tell someone they were expected. The mistake was believing the welcome mattered more than the guest.\n\nYou help carry two cups to the table. Farah begins to thank you in formal language, catches herself, and points instead.\n\nFarah: That one leaks. Take the other.\n\nYou: Distressingly effective.\n\nHer laugh arrives before any polished reply. The small task is completed without becoming a symbol, which makes it a pleasant change for both of you.",
		"summary": "Farah recalls arriving at an informal supper with an enormous ceremonial gift. Her host ended the awkward performance by asking her to dry dishes, and their first easy conversation followed. Farah still values ceremony, but she laughs at mistaking it for connection. The old gift remains only a story.",
		"memory": "Heard how washing dishes rescued Farah from the wrong courtesy."
	},
	"farid_own_answer": {
		"title": "My Own Answer", "requires_any": ["farid_wrong_courtesy"], "setting": "envoy_room",
		"opening": "Farah has opened a notebook along its spine. Thread, folded paper, and a blunt needle lie in careful disorder.\n\nFarah: Hold that edge, please. Firmly, but if either of us becomes heroic, the paper will tear.\n\nHer hands know the work. As a girl she spent a season with a bookbinder and once imagined staying. She also likes diplomacy; the old wish is not evidence of a stolen life.\n\nFarah: Whenever I mentioned the binding, I explained how it might serve the family correspondence. That was true. It was also camouflage. I liked making a small thing open properly. Apparently pleasure seemed an insufficient argument.\n\nShe pulls one stitch tight, checks it, and does not apologize for the uneven first attempt hidden beneath the new thread.\n\nFarah: A useful answer belongs to everyone it helps. This answer is mine: I enjoy this. It need not become a profession or a sacrifice to deserve the sentence.",
		"choices": ["Who taught you?", "What part do you enjoy most?", "You can value both kinds of work."],
		"responses": [
			"Farah: A binder named Samira who distrusted elegant hands. She made me sweep for three days before touching thread. Later she admitted the sweeping was necessary because I talked too much while nervous.",
			"Farah runs a thumb along the repaired fold.\n\nFarah: This. The moment the pages agree to turn together. Nothing applauds. Nothing signs. The book simply works better than it did.",
			"Farah: I know that when you say it. I am learning to know it before someone grants permission. Diplomacy is mine too; duty did not poison everything it touched."
		],
		"closing": "The final knot sits slightly off center. Farah considers correcting it, then closes the notebook. It opens flat.\n\nFarah: There. Evidence that I can stop when the thing works. Samira would be astonished.\n\nYou release the page. A faint indentation from your thumb remains near the margin.\n\nFarah: Leave it. A repaired book should not pretend nobody held it together.\n\nShe places the notebook beside her official dispatches, neither hidden beneath them nor displayed for praise. Before you go, she opens it once more simply because she likes the movement.",
		"summary": "Farah repairs a notebook and admits she once wanted to learn bookbinding. She still values diplomacy; the private craft does not expose a false life or demand a career change. You help hold the paper, ask about the work, or affirm both interests. The notebook remains an ordinary story prop.",
		"memory": "Helped Farah repair the notebook she keeps for herself."
	},
	"farid_no_reply_required": {
		"title": "No Reply Required", "requires_any": ["farid_own_answer"], "coda": true, "setting": "envoy_room",
		"opening": "Farah arrives without a document, seal, or carefully arranged reason.\n\nFarah: I saw something today that I wanted to tell you about. A dog was carrying a loaf longer than itself. The baker appeared to be losing the negotiation.\n\nYou: Did the dog have terms?\n\nFarah: Complete possession and a refusal to enter discussion. Brutal, but clear.\n\nShe sits before asking whether you have time, then notices what she has done.\n\nFarah: I usually bring news that requires an answer. Even my jokes arrive with a request attached: reassure someone, forgive a delay, admire the phrasing. This one has no function. I simply thought you would laugh.\n\nThe admission is quieter than the joke. She does not cover it with another story. Outside, someone calls the evening market closed and is ignored by at least half the street.\n\nFarah: There may be further unimportant news if you encourage me.",
		"choices": ["Tell me all of it.", "I saw something foolish too.", "Sit together without making a report."],
		"responses": [
			"Farah: The loaf survived. The baker recovered one end, which the dog treated as a separate loaf and graciously surrendered. I have rarely seen a settlement executed with such confidence.",
			"Farah receives your harmless observation with the attention she usually gives a border dispatch. Halfway through, you both recognize this and laugh.\n\nFarah: I am interested. I am merely trying not to look official about it.",
			"Farah settles into the quiet. Once, she opens her mouth to rescue the silence. Then she smiles and lets it remain exactly where it is."
		],
		"closing": "The room grows dim around the two of you. Nothing has been decided, delivered, or improved for distant parties.\n\nFarah: I used to believe closeness meant knowing the correct answer sooner than anyone else. This is easier. I can bring you a ridiculous dog and trust that the story is enough.\n\nShe glances toward the empty writing table.\n\nFarah: No reply required. Though I hope you will tell me if you ever see what became of the loaf.\n\nThe visit ends as ordinary news: memorable because she chose you as its first destination.",
		"summary": "Farah brings no petition, only a story about a dog stealing an impractically long loaf. She enjoys sharing something because it made her think of you. Romantic and friendship contexts both support this ordinary comfort. No reply, favor, message, or diplomatic action is created.",
		"memory": "Shared unimportant news with Farah because each of you wanted the other to hear it."
	},
	"kaede_useless_map": {
		"title": "A Map of Useless Places", "requires_any": [], "setting": "archive_room",
		"opening": "Kaede covers a small page when you approach, then uncovers it with visible annoyance at herself.\n\nKaede: It is a map. It will not help you travel.\n\nThere are no roads, borders, or distances. One mark records where afternoon light reaches a wall. Another notes a step that stays dry in rain. Beside the stairs is a compact ink shape.\n\nYou: What's this?\n\nKaede: A cat. Usually. I cannot guarantee the cat's attendance.\n\nAs a child, she mapped places where she could read undisturbed: behind a storehouse at noon, beneath a stair after lessons, beside an aunt who hummed and never asked what the book was about.\n\nKaede: Official maps explain how to reach an obligation. These explain why I might remain after arriving. I have not decided whether that makes them maps or illustrated excuses.\n\nShe straightens the page, animated now that there is a classification to dispute.",
		"choices": ["Show me the driest step.", "Do you draw these only for yourself?", "I would mark a place with a good view."],
		"responses": [
			"Kaede: It is dry unless the wind is east. I discovered the exception while protecting a book with my sleeve. The book survived. My notes became more precise.",
			"Kaede: Until now. That answer is technically no longer accurate.\n\nShe considers taking the page back, but leaves it between you.",
			"Kaede reaches for her brush.\n\nKaede: What makes it good? No—do not make that objective. Tell me why you would stay there."
		],
		"closing": "Kaede adds one small mark, then dates the corner.\n\nKaede: The cat may object to being represented without consent. I will amend the record if a complaint is submitted.\n\nYou: In writing?\n\nKaede: Paw marks would be admissible.\n\nHer smile appears quickly and is gone only because she bends over the page again. The map remains useless to an army and exact about the kind of afternoon she likes. When you leave, she does not cover it.\n\nThe uncertain cat keeps its place beside the stairs. Its schedule remains officially and pleasantly beyond the archivist's control.",
		"summary": "Kaede shows you a private map of places she likes: a dry stair, a patch of afternoon light, and a cat whose presence is not guaranteed. You ask about its details or add an ordinary preference. The map offers no travel intelligence, collectible, or strategic bonus.",
		"memory": "Kaede showed you her map of pleasant and strategically useless places."
	},
	"kaede_bad_mystery": {
		"title": "A Very Bad Mystery", "requires_any": [], "setting": "archive_room",
		"opening": "Kaede is reading a cheaply bound mystery with the concentration normally reserved for disputed covenants.\n\nKaede: The accusation is impossible. The seal is on the wrong side of the fold, and the witness described ink that had not yet been made.\n\nYou: Shall we stop reading?\n\nKaede: Certainly not. The gardener has just acquired a second disguise.\n\nShe has read the story before. A favorite childhood reader gave every suspect the same guilty whisper, including an elderly dog and one locked cabinet. Kaede and her cousins competed to produce theories unsupported by any evidence.\n\nKaede: I was excellent at being wrong. Deliberately wrong, I should clarify. Usually.\n\nShe turns the page and makes an offended sound at a clue she clearly enjoys.\n\nKaede: Real evidence deserves care. Fictional evidence has volunteered to be mistreated for our amusement. I see no ethical conflict.",
		"choices": ["The gardener's second disguise did it.", "Why read it again if it's so bad?", "Read me the next page."],
		"responses": [
			"Kaede: Too obvious. I accuse the cabinet. It has means, opportunity, and a documented history of being locked. Motive will emerge if the author has courage.",
			"Kaede: Because I know where it fails, so I can enjoy how confidently it approaches the failure. Also the dog is acquitted. I find that reassuring.",
			"Kaede gives the narrator an unnecessarily sinister voice, then stops to object to her own performance.\n\nKaede: No, that makes the actual culprit sound innocent. I must be less competent."
		],
		"closing": "The chapter ends by revealing a hidden tunnel that could not fit beneath the building described on page two. Kaede closes the book on one finger.\n\nKaede: Outrageous. We will continue tomorrow.\n\nYou: We?\n\nShe looks at the second cushion as though its presence constitutes prior agreement.\n\nKaede: You have accused a cabinet. You are now part of the inquiry. No expertise is required; in fact, it may be a disadvantage.\n\nShe leaves the book at the absurd clue, visibly pleased to have someone with whom to guess badly. The innocent dog, at least, can rest without suspicion tonight.",
		"summary": "Kaede complains about an impossible forged letter in a favorite bad mystery, then refuses to stop reading. She enjoys making deliberately weak theories in fiction while keeping real evidence serious. You accuse an implausible suspect, ask why she rereads it, or listen. No real clue or quest is involved.",
		"memory": "Joined Kaede in solving a very bad mystery as incorrectly as possible."
	},
	"kaede_margin_name": {
		"title": "A Name in the Margin", "requires_any": ["kaede_useless_map", "kaede_bad_mystery"], "setting": "archive_room",
		"opening": "A faded label has slipped from an old document box. The handwriting uses a name you do not recognize.\n\nKaede: My aunt wrote that. I was twelve and had just begun formal instruction. I demanded that everyone use my proper name.\n\nYou: Did they agree?\n\nKaede: For nearly an hour.\n\nThe nickname came from a childhood misunderstanding and became affectionate through repetition. Kaede had corrected her aunt in front of visiting scholars. Her aunt bowed gravely, used the proper name all afternoon, then labeled every sweet cake with the forbidden one.\n\nKaede: I was furious. I ate the cakes to destroy the evidence. This was not a strong archival principle.\n\nShe turns the label over. Her amusement softens.\n\nKaede: I thought affection made me look less serious. She knew I was serious. She also knew I was twelve. Both facts survived the afternoon.",
		"choices": ["What was your aunt like?", "You can keep the name private.", "I rejected a family name once too."],
		"responses": [
			"Kaede: Patient until patience became boring, then inventive. She corrected my citations and cheated at guessing games. I found this inconsistent. She considered it a complete personality.",
			"Kaede folds the label into her palm.\n\nKaede: Thank you. Curiosity can be respectful without being satisfied. I would like to remember that from both sides.",
			"Kaede listens without asking for the name.\n\nKaede: Then you know the strange moment when a familiar sound no longer fits, and the later moment when perhaps it does again."
		],
		"closing": "Kaede returns the label to the box rather than the official catalog.\n\nKaede: I may tell you another day. That is not a test. I dislike tests whose rules are concealed from the person taking them.\n\nYou: Then another day is enough.\n\nShe nods, relieved that the boundary has not turned the evening cold. Before closing the lid, she smiles at the old handwriting.\n\nKaede: She would be pleased that the label caused a discussion. She believed all properly stored objects should occasionally make trouble.\n\nThe private name remains hers; the story does not become less complete.",
		"summary": "Kaede finds a label bearing a childhood family nickname she once rejected. She remembers the aunt who teased and respected her in equal measure. You may ask about the relative, share a similar feeling, or leave the nickname private. Respecting the boundary completes the memory without revealing a secret.",
		"memory": "Spent an evening with Kaede and an old label whose private name remained her choice."
	},
	"kaede_missing_street": {
		"title": "The Missing Street", "requires_any": ["kaede_margin_name"], "setting": "archive_room",
		"opening": "Kaede has redrawn the same corner three times. On one page a bench stands beneath a tree. On another it faces the road. The newest sketch has no bench at all.\n\nKaede: It moved. Again.\n\nYou: Perhaps it prefers the shade.\n\nKaede: So do I. That is the troublesome part; I approve of the change.\n\nHer first map of home included a shortcut through a neighbor's gate. The route existed only when the neighbor remembered to leave it open, which Kaede's careful scale could not predict. She kept correcting the map until her mother wrote 'on Tuesdays, perhaps' beside the line.\n\nKaede: I considered that vandalism. It was also the most accurate annotation.\n\nThe present street keeps changing: a stall closes, a tree is pruned, the uncertain cat selects a different stair. Kaede has been treating each difference as a defect in the previous page rather than evidence of another day.",
		"choices": ["Date each version and keep them all.", "Tell me about the old shortcut.", "A changed place may deserve another drawing."],
		"responses": [
			"Kaede writes today's date beneath the missing bench.\n\nKaede: Then none of them must defeat the others. They can each be correct for an afternoon. That is an unexpectedly generous system.",
			"Kaede: It passed a kitchen window. On Tuesdays the neighbor baked pears and the shortcut became very slow. I omitted that because appetite was not part of the scale.",
			"Kaede: Another drawing rather than a correction. Yes. That permits me to like both. I am noticing how often preference complicates my filing system."
		],
		"closing": "She places the three maps side by side. The moving bench becomes a sequence rather than an error.\n\nKaede: Here it faced the sun. Here someone wanted to watch the road. Here it has gone somewhere outside my evidence.\n\nYou: Will you look for it?\n\nKaede: Tomorrow. Today I know where it was not.\n\nShe adds no speculative bench to the blank space. Instead she marks the patch of shade she likes and allows that fact to remain in the first person. The unfinished street looks more alive for refusing to hold still.",
		"summary": "Kaede cannot finish a private street map because the bench, stalls, and cat keep moving. She remembers a childhood shortcut that existed only when a neighbor's gate was open. You help her treat each drawing as a record of one afternoon instead of a failed final version. Campaign geometry does not change.",
		"memory": "Watched Kaede turn a changing street from an error into several true afternoons."
	},
	"kaede_kept_page": {
		"title": "The Page She Kept", "requires_any": ["kaede_missing_street"], "setting": "archive_room",
		"opening": "Kaede places two accounts of the same family gathering on the desk. The first is impeccable: arrivals, witnesses, meal, departure. The second begins with a sentence in a younger, less certain hand.\n\nKaede: My relatives met after a long quarrel. Everyone had come to hear an apology. My official summary says they ate fish.\n\nYou: Was the fish important?\n\nKaede: It was verifiable. I omitted the apology because I could not decide whether it had succeeded.\n\nHer teacher asked who the account was for. Kaede answered: anyone who needed the facts. The teacher gave the page back and asked what Kaede herself might need to remember.\n\nKaede: I wrote a second account. It says I was glad they stayed until evening. For years I thought that sentence was less true because it belonged only to me.\n\nShe has kept both pages, neither hidden nor filed as evidence in the clan dispute.",
		"choices": ["What else did the second account say?", "Your teacher asked a useful question.", "An account can have a purpose without containing everything."],
		"responses": [
			"Kaede: That my uncle's apology was clumsy, my grandmother accepted it anyway, and I wanted them to try again. The last part took longest to write. It could not be attributed to a witness.",
			"Kaede: Infuriatingly useful. I wanted a rule. She gave me another reader to consider, and that reader was myself. I could not cite her away.",
			"Kaede: Yes. The official page is not false. It is simply unable to carry what the other page was made for. Precision includes knowing the limits of the form."
		],
		"closing": "Kaede aligns the pages, then deliberately leaves the personal one on top.\n\nKaede: I still would not place this in a public archive. Feeling does not become evidence because it is sincere. But it does become part of a life. I was there. I was glad.\n\nShe signs the old page beneath the younger handwriting, not to certify it for anyone else but to claim the account as hers.\n\nKaede: That is enough authentication.\n\nThe two records return to the same box, serving different truths without being forced into one.",
		"summary": "Kaede shows you an official summary of a family reconciliation and the private page on which she admitted she was glad they stayed. Her teacher helped her see that records have different readers and purposes. The private account changes no clan claim and reveals no confidential archive material.",
		"memory": "Read the page where Kaede allowed her own experience into the record."
	},
	"kaede_room_on_map": {
		"title": "Room on the Map", "requires_any": ["kaede_kept_page"], "coda": true, "setting": "archive_room",
		"opening": "A fresh personal map lies between two cups. Kaede has drawn the room accurately except for one broad empty space.\n\nKaede: I left this unfinished on purpose. I checked twice.\n\nYou: What belongs there?\n\nKaede: Your choice, if you want one. A sunny place, a quiet corner, somewhere to watch people pass. This map records where we would remain, not what we own.\n\nShe offers the brush handle-first. The gesture is careful but not ceremonial.\n\nKaede: I used to believe including another person's preference would make the map less exact. That was convenient. It meant I never had to ask and never had to risk hearing that they would sit elsewhere.\n\nThe empty space is large enough for disagreement. She does not fill it while waiting. Outside the archive, footsteps cross the walkway and fade.\n\nKaede: You may also choose nothing today. An honest blank is still part of the page.",
		"choices": ["Mark the place beside the window.", "Choose the quiet corner near her desk.", "Leave room to watch people pass."],
		"responses": [
			"Kaede marks the window seat and adds the hour when sunlight reaches it.\n\nKaede: We may need to move in summer. I find I am comfortable allowing for that revision.",
			"Kaede draws two small cushions near the desk, then pretends to measure their distance.\n\nKaede: This is not necessary for scale. I wanted them to look as though conversation remained possible.",
			"Kaede places the mark near the open lattice.\n\nKaede: Good. A map should include somewhere the world can interrupt it. We need not identify everyone who walks by."
		],
		"closing": "Kaede adds her own preferred place after yours. The two marks do not claim the room or promise that either of you will always be there. They simply answer the question asked tonight.\n\nKaede: It is less balanced now.\n\nYou: Does that trouble you?\n\nShe studies the page, then smiles.\n\nKaede: I think I should like it. Balance was easier when nothing had been chosen. This is more useful to me.\n\nShe leaves another small blank at the edge and labels it only with tomorrow's date, room for the map to change without becoming wrong.",
		"summary": "Kaede invites you to add one ordinary preferred place to a new personal map. She adds her own choice beside it and leaves room for revision. In romance or friendship, the scene reflects chosen familiarity without assigning a home, claiming property, changing travel, or making a new commitment.",
		"memory": "Added an ordinary place beside Kaede's to a map that belongs to neither of you."
	}
}

static func ids_for(candidate_id: String) -> Array:
	var result: Array = []
	for scene_id in SCENES:
		if String(scene_id).begins_with(candidate_id + "_"):
			result.append(scene_id)
	return result

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
	elif scene_id == "farid_no_reply_required":
		if completed.has("farid_unsealed_letter"):
			result += "\n\nFarah: I sent the letter, by the way. The short answer survived the journey."
		if completed.has("farid_supper_request"):
			result += "\n\nA plain request for tea arrives; Farah accepts its five words without amendment."
		result += "\n\nFarah reaches for your hand." if context.get("romantic", false) else "\n\nFarah settles into the familiar ease of friendship."
	elif scene_id == "kaede_room_on_map":
		if completed.has("kaede_useless_map"):
			result += "\n\nKaede adds a tiny uncertain cat at the edge, preserving its right not to attend."
		if completed.has("kaede_bad_mystery"):
			result += "\n\nThe impossible mystery waits beside the map for another deliberately poor theory."
		result += "\n\nKaede lets her hand rest against yours beside the two marks." if context.get("romantic", false) else "\n\nKaede leaves both marks close, pleased by the company of a trusted friend."
	return result


## Presentation is versioned independently: authored choices/rewards retain content version 1.
const READER_VERSION := 1

static func beats(scene_id: String, node: int, choice: int, context: Dictionary) -> Array:
	var scene: Dictionary = SCENES.get(scene_id, {})
	if scene.is_empty():
		return []
	var passage: String = scene["opening"]
	if node == 1:
		if choice < 0 or choice >= scene["choices"].size():
			return []
		passage = "You: " + scene["choices"][choice] + "\n\n" + scene["responses"][choice] + "\n\n" + ending(scene_id, context, context.get("completed", []), context.get("choices", {}))
	var result: Array = []
	for paragraph in passage.split("\n\n", false):
		var speaker := "Narrator"
		var line: String = paragraph
		for name in ["Edda", "Farah", "Kaede", "You"]:
			if line.begins_with(name + ": "):
				speaker = name
				line = line.trim_prefix(name + ": ")
				break
		var expression := "neutral"
		if scene_id in ["edda_boots_by_door", "edda_ledger_blot"]:
			expression = "concerned" if node == 0 else "thoughtful"
		elif scene_id in ["edda_wrong_verse", "edda_morning_unclaimed"]:
			expression = "amused"
		elif scene_id == "edda_place_no_task":
			expression = "warm"
		elif scene_id == "edda_spare_spoon":
			expression = "thoughtful" if node == 0 else "amused"
			if node == 1 and result.size() >= 3:
				expression = "warm"
		elif scene_id in ["farid_supper_request", "farid_two_street_names", "farid_wrong_courtesy"]:
			expression = "amused" if node == 1 else "neutral"
		elif scene_id in ["farid_unsealed_letter", "farid_own_answer"]:
			expression = "concerned" if node == 0 else "thoughtful"
		elif scene_id == "farid_no_reply_required":
			expression = "warm"
		elif scene_id == "kaede_bad_mystery":
			expression = "amused"
		elif scene_id in ["kaede_margin_name", "kaede_kept_page"]:
			expression = "concerned" if node == 0 else "thoughtful"
		elif scene_id in ["kaede_useless_map", "kaede_missing_street"]:
			expression = "thoughtful" if node == 0 else "amused"
		elif scene_id == "kaede_room_on_map":
			expression = "warm"
		result.append({"speaker": speaker, "text": line, "expression": expression})
	return result


static func normalize_reader(scene_id: String, progress: Dictionary) -> void:
	var sequence := beats(scene_id, int(progress.get("node", 0)), int(progress.get("choice", -1)), progress.get("context", {}))
	var last := maxi(0, sequence.size() - 1)
	progress["beat"] = clampi(int(progress.get("beat", 0)), 0, last)
	progress["furthest_beat"] = clampi(int(progress.get("furthest_beat", progress["beat"])), progress["beat"], last)
	progress["reader_version"] = READER_VERSION
