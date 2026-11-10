## Farah's visits: the envoy who can answer for everyone except herself. (The format is
## described in personal_conversations.gd. Her ids keep the candidate id, "farid".)
##
## Her running habit is the sentence that takes the scenic route: drafts, toasts and
## apologies, and now and then five plain words that land like a door shut. Her thread is
## her cousin's question, "Are you happy?" She asks you two things: a place you know by a
## name no map uses, and when you last said exactly what you meant.
extends RefCounted

const SCENES := {
	"farid_supper_request": {
		"title": "Three Ways to Ask for Supper", "rank": "C", "requires_any": [], "setting": "envoy_room",
		"parts": [
			{"face": "neutral", "text": """
Farah sits before a note whose first sentence occupies most of the page.

Farah: If the household's present circumstances permit, and if the kitchen has not already committed its stores—

You: You're asking for soup.

Farah lowers the page. Her dignity lasts for almost a breath.
""", "options": [
				{"say": "Read me the grandest version.", "tone": "ask", "face": "amused", "reply": """
Farah reads the longest draft with ceremonial gravity until she reaches a clause protecting the cook from future liability. She breaks first.

Farah: I may preserve that line for an actual treaty. It would improve several of them.
"""},
				{"say": "Give me the pen. I can make it worse.", "tone": "tease", "mark": "farah_outdrafted", "face": "amused", "reply": """
You add a preamble, two witnesses, and a clause on the disposition of leftover bread. Farah reads it with rising professional alarm.

Farah: 'In perpetuity.' You have requested soup in perpetuity. I have met ambassadors with less nerve.
"""},
			]},
			{"face": "amused", "text": """
Farah: I had hoped not to sound demanding. When I was thirteen, I carried a message that said a visiting aunt wanted supper immediately. She had actually said she would eat whenever it was convenient. The cook fed her, then spent a year teaching me the difference.

Farah: She was thorough. By winter, I could request a cup of water in language suitable for ending a siege.
""", "options": [
				{"say": "A full year? For one supper?", "tone": "tease", "reply": """
Farah: For one adverb. 'Immediately.' She made me carry it back to my aunt and apologize to it.

Farah: I have never used the word lightly since. You may have noticed I rarely use it at all.
"""},
				{"say": "Did you mind, being taught like that?", "tone": "ask", "face": "thoughtful", "reply": """
Farah: At thirteen, bitterly. I thought she was making me small.

Farah: She was making me careful, which is a different shape, though I admit they fit in the same cupboard.
"""},
			]},
			{"face": "amused", "text": """
She points to three abandoned drafts. One apologizes to the lentils. Another assures the kitchen that refusing would not damage diplomatic relations.

Farah: I know this is ridiculous. Knowing has not made the sentence shorter.
""", "options": [
				{"say": "Write: Is there any soup tonight?", "tone": "help", "reply": """
Farah writes the five words, then studies them as if they have arrived without credentials.

Farah: Distressingly effective. It even leaves room for the answer. The cook will suspect someone else wrote it.
"""},
				{"say": "I overthink small requests too.", "tone": "share", "reply": """
Farah: Then you know how a harmless task can acquire witnesses, precedents, and an appeal process. I am relieved. I was afraid this was a private form of foolishness.
"""},
				{"say": "Keep the lentil one. It's the best thing you've written.", "tone": "tease", "reply": """
Farah: It is, isn't it. 'With sincere regard for the lentils' patience.' I have signed border accords with less feeling.

Farah: I shall keep it. Not send it. There is a difference, and I am told it is the entire basis of my profession.
"""},
			]},
		],
		"closing_face": "amused", "closing": """
She folds the shortest note before she can improve it. A servant passing the doorway accepts it without alarm.

Farah: There. No border shifted. No aunt was offended. If soup arrives, I will try not to describe it as a successful negotiation.

You wait together. Farah moves the rejected drafts into a neat stack, then pulls the most elaborate one back out.

Farah: This clause about lentils is genuinely excellent. Waste is still waste, even when it is funny.

When the plain reply comes (yes, there is soup) she smiles at how little ceremony the answer required.
""",
		"summary": "Farah has turned a simple request for supper into diplomatic correspondence. She recalls the cook who spent a year teaching her to soften a message, then lets you help her send a plain sentence. The kitchen answers just as plainly. The soup and the note remain an ordinary shared joke.",
		"memory": "Helped Farah ask for supper without drafting a treaty.",
	},
	"farid_two_street_names": {
		"title": "The Street With Two Names", "rank": "C", "requires_any": [], "setting": "qasr_hamra",
		"parts": [
			{"face": "neutral", "text": """
From the window, Farah points toward a lane hidden beyond the market roofs.

Farah: Officially, South Market Street. At home, Crooked Lantern. Every letter from my mother used the second name, although no clerk recognized it.
""", "options": [
				{"say": "Let me guess. The lantern's crooked.", "tone": "tease", "face": "amused", "reply": """
Farah: The shopkeeper insisted the entire street was leaning. His lantern alone was honest about it.

Farah: He denied it for thirty years, then sold little painted copies to travelers. Each copy leaned differently. He called that local accuracy.
"""},
				{"say": "Which name do you use?", "tone": "ask", "face": "amused", "reply": """
Farah: Crooked Lantern. South Market Street sounds like I am writing to request an audit.

Farah: My aunt once returned a letter unopened because I used it. She said no niece of hers lived in an office.
"""},
			]},
			{"face": "amused", "text": """
As a child, Farah was sent to guide visitors who had followed the official signs into the wrong square. Her family argued over which name an outsider deserved to hear. Her uncle favored accuracy. Her mother favored arrival.

Farah: I began writing directions in the margins of invitations. Turn where the spice seller sings badly. If you reach the blue well, you have believed the city surveyor.

Farah: Now you. Everyone who travels has one: a place you know by a name no map would print. I should like to hear yours.
""", "options": [
				{"say": "The Leaning Bridge. It leans less than the name does.", "tone": "share", "mark": "you_name_bridge", "reply": """
Farah: So someone was frightened on it once, and the fear outlived the lean.

Farah: The Leaning Bridge. I shall use it. If a clerk queries me, I shall say the bridge was consulted.
"""},
				{"say": "Cold Kettle. A camp where nothing would boil.", "tone": "share", "mark": "you_name_kettle", "reply": """
Farah: Named in a temper, by people with wet feet. Those are the names that last.

Farah: Cold Kettle. I can hear the whole evening in it. Nobody slept, and somebody blamed the cook.
"""},
				{"say": "Widow's Elbow. A bend in a road. Nobody knows which widow.", "tone": "share", "mark": "you_name_elbow", "reply": """
Farah: Nobody knows, and so every village along it will have claimed her. I approve. A name should give people something to argue about.

Farah: Widow's Elbow. I shall be thinking about her all week.
"""},
			]},
			{"face": "amused", "text": """
Farah: That may be why I care about correspondence. A letter should help one person find another. Everything more impressive came later.

The lane remains out of sight, but Farah draws its turns on the dusty sill: left at the awning, right at the well, then toward the famously upright lantern.

Farah: A proper envoy would verify these directions. A resident would tell you to follow the smell of bread.
""", "options": [
				{"say": "Which are you today?", "tone": "ask", "reply": """
She considers, then wipes away the official route and leaves the shorter one.

Farah: Today I would like you to arrive. Follow the bread.
"""},
				{"say": "I'd follow the singing. Bad singing is easy to find.", "tone": "tease", "reply": """
Farah: He is retired now. His son sings worse, with more confidence. The street regards this as continuity.

Farah: You would arrive. That is the only test the directions were ever meant to pass.
"""},
				{"say": "Write them down for me. In a margin.", "tone": "share", "reply": """
Farah takes an old invitation from the sill and writes down its edge: left at the awning, right at the well, do not believe the surveyor.

Farah: There. It is not official. It will, however, work.
"""},
			]},
		],
		"closing_face": "amused", "closing": """
The map on the sill is gone with a sweep of her sleeve, but the private names stay between you.

Farah: Crooked Lantern, and yours beside it. Two names no clerk will ever file. I find I am pleased to hold both.
""",
		"summary": "Farah remembers a childhood street with an official name and a local one, Crooked Lantern. Guiding lost visitors began her love of correspondence: words mattered because they helped people find one another. She asks for a private place-name of yours, and keeps it.",
		"memory": "Learned why Farah still calls South Market Street Crooked Lantern, and gave her a name of your own.",
	},
	"farid_unsealed_letter": {
		"title": "The Letter Without a Seal", "rank": "B", "requires_any": ["farid_supper_request", "farid_two_street_names"], "setting": "envoy_room",
		"parts": [
			{"face": "concerned", "text": """
An unsealed letter lies on Farah's table. Two pages discuss weather, safe roads, and everyone except the writer.

Farah: My cousin asked whether I am happy. One question. I have written around it with considerable skill.

[?farah_outdrafted] Farah: Do not offer to improve it. I have seen what you do to soup.
""", "options": [
				{"say": "I'll sit over here, where I can't read it.", "tone": "quiet", "reply": """
Farah's shoulders ease.

Farah: Thank you. Privacy is not the same as loneliness, though people often offer company by taking it apart. You may stay while I write.
"""},
				{"say": "What did you want to say first?", "tone": "ask", "reply": """
Farah: That depends which first you mean. The useful answer was that my work matters. The honest answer arrived before it, and I sent it away for lacking context.
"""},
			]},
			{"face": "concerned", "text": """
Farah: Envoys learn that words cannot be recalled once received. It is sensible training. It is less useful when a woman who changed your childhood bandages wants to know if you like your life.

She taps the blank space beneath the formal closing.

Farah: I do. Mostly. There are parts I chose, and parts I learned to call choices because they were mine to carry.
""", "options": [
				{"say": "Tell me about a part you didn't choose.", "tone": "ask", "mark": "farah_asked_mostly", "reply": """
Farah: The leaving. I am good at arriving; I was raised for it. Nobody mentioned that every arrival is purchased with a departure somewhere else.

Farah: I have missed four weddings and a naming. I sent excellent letters. They were read aloud, I am told, and much admired.
"""},
				{"say": "Mostly is an honest word.", "tone": "comfort", "mark": "farah_let_mostly", "reply": """
Farah: It is. I keep trying to promote it to 'entirely', and it keeps declining the post.

Farah: You are the first person to let it stand. Everyone else wants to know what is wrong with the remainder, as though a remainder were a fault in the arithmetic.
"""},
			]},
			{"face": "thoughtful", "text": """
Farah draws a line through the account of the weather. Beneath it she writes one short sentence, shielding the page with her hand from habit rather than distrust.

Farah: The first honest sentence is rather small. That may be why it frightened me. There was nowhere to hide the speaker.
""", "options": [
				{"say": "What does the small sentence say?", "tone": "ask", "reply": """
Farah: It says, 'Yes, and I am tired.' There. Five words, none of them protected by a title.

Farah: My cousin will understand both halves better than a court would.
"""},
				{"say": "I find that question difficult too.", "tone": "share", "reply": """
Farah: Then I will not ask you to answer in exchange. It is enough to know the question has weight in another hand. We can both be inarticulate with dignity.
"""},
				{"say": "If she asks about me, what will you write?", "tone": "heart", "when": "romantic", "face": "warm",
					"memory": "Kept Farah company while she wrote one honest sentence to her cousin, and learned what she'd write of you.", "reply": """
Farah: That is a leading question, and I taught half this city how to ask them.

She does not look up from the page, but she has stopped pretending to read it.

Farah: I would write: there is someone who waits while the ink dries. She will know what that means. She changed my bandages.
"""},
				{"say": "Tell her you've a friend who'll vouch for 'mostly'.", "tone": "warm", "when": "friend", "face": "amused", "reply": """
Farah: A character witness. For an adverb.

Farah: I shall. She will want your name, your people, and whether you eat properly. I will answer one of the three.
"""},
			]},
		],
		"closing_face": "thoughtful", "closing": """
She sands the ink but leaves the letter unsealed.

Farah: I will read it tomorrow. If it still sounds like me, I will send it.

You talk about nothing urgent while the ink dries. For once, silence does not require her to supply a diplomatic bridge across it.
""",
		"summary": "A cousin has asked Farah whether she is happy. Her draft answers with work, weather and safe roads while avoiding the question. She admits she likes her life, mostly, and writes one honest sentence herself. The letter stays hers to send.",
		"memory": "Kept Farah company while she wrote one honest sentence to her cousin.",
	},
	"farid_wrong_courtesy": {
		"title": "The Wrong Courtesy", "rank": "B", "requires_any": ["farid_unsealed_letter"], "setting": "envoy_room",
		"parts": [
			{"face": "neutral", "text": """
Farah is polishing a plain serving bowl, which seems beneath an envoy's attention until she explains why it makes her laugh.

Farah: On my first independent visit, I brought my host a gift in a box large enough for a saddle. Two servants carried it. The invitation had said informal supper.

[?farah_asked_mostly] Farah: This is a happier story than the last, I promise. Nobody leaves in it.

[?farah_let_mostly] Farah: This part of my life I chose entirely. More fool me.
""", "options": [
				{"say": "Don't tell me. A horse. A stuffed one.", "tone": "tease", "face": "amused", "reply": """
Farah: A stuffed— no. Though I am grateful the idea did not occur to me at nineteen.

Farah: A bowl. Ornamental. Carved with the meeting of two rivers, neither of which my host had heard of.
"""},
				{"say": "What was in the box?", "tone": "ask", "face": "amused", "reply": """
Farah: A bowl. Ornamental. Carved with the meeting of two rivers, neither of which my host had heard of.

Farah: She already owned bowls. Several. Some of them useful.
"""},
			]},
			{"face": "amused", "text": """
She had prepared remarks about every carved symbol. Her host had prepared lentils and three questions about the road. They spent an hour admiring the gift because neither knew how to stop.

Farah: At last she carried the plates away and asked whether I could dry them. I thought it was a test. It was, in a sense. She wanted to discover whether I could hold a cloth without explaining its lineage.
""", "options": [
				{"say": "That's the best welcome there is.", "tone": "comfort", "reply": """
Farah: Yes. She did not mock the courtesy or submit to it forever. She simply handed me a towel. I have tried to remember that mercy can be practical.
"""},
				{"say": "Ceremony has its place, though.", "tone": "tease", "mark": "farah_defended_ceremony", "reply": """
Farah: It does. Thank you. People hear this story and conclude I ought to arrive everywhere with a dishcloth.

Farah: A beautiful welcome tells someone they were expected. The mistake was believing the welcome mattered more than the guest.
"""},
			]},
			{"face": "amused", "text": """
They spoke easily over the dishes. Farah remembers being relieved, embarrassed, and very careful not to polish the plates into diplomatic artifacts.

She puts the plain bowl back without making it shine.
""", "options": [
				{"say": "What became of the grand bowl?", "tone": "ask", "reply": """
Farah: She used it for onions. My uncle was appalled. I was secretly delighted. An object that expensive deserved useful work, even if the onions failed to admire it.
"""},
				{"say": "What did you talk about, drying?", "tone": "ask", "reply": """
Farah: A leaking roof, a nephew who refused sandals, and whether cardamom improves everything. She said no. I respected her courage, though she was plainly wrong.
"""},
				{"say": "I'd have liked to see you at nineteen, with that box.", "tone": "heart", "when": "romantic", "face": "warm", "reply": """
Farah: You would have been announced. At length. I had a speech for meeting strangers; it had three movements.

Farah: I am glad you met this one instead. She has fewer remarks prepared, and means more of them.
"""},
				{"say": "Next time bring me the dishcloth. Skip the box.", "tone": "warm", "when": "friend", "face": "warm", "reply": """
Farah: You shall have both. I am constitutionally unable to arrive empty-handed.

Farah: But the cloth first. I know now which one is the gift.
"""},
			]},
		],
		"closing_face": "amused", "closing": """
You help carry two cups to the table. Farah begins to thank you in formal language, catches herself, and points instead.

Farah: That one leaks. Take the other.

You: Distressingly effective.

Her laugh arrives before any polished reply. The small task is completed without becoming a symbol, which makes it a pleasant change for both of you.
""",
		"summary": "Farah recalls arriving at an informal supper with an enormous ceremonial gift. Her host ended the awkward performance by asking her to dry dishes, and their first easy conversation followed. Farah still values ceremony, but she laughs at having mistaken it for connection.",
		"memory": "Heard how washing dishes rescued Farah from the wrong courtesy.",
	},
	"farid_own_answer": {
		"title": "My Own Answer", "rank": "A", "requires_any": ["farid_wrong_courtesy"], "setting": "envoy_room",
		"parts": [
			{"face": "thoughtful", "text": """
Farah has opened a notebook along its spine. Thread, folded paper, and a blunt needle lie in careful disorder.

Farah: Hold that edge, please. Firmly, but if either of us becomes heroic, the paper will tear.
""", "options": [
				{"say": "Holding. Unheroically.", "tone": "help", "reply": """
Farah: Good. You have the hands of someone who has waited for bread to rise. That is the entire qualification.

Her own hands know the work. The needle goes through without her watching it.
"""},
				{"say": "Let me try a stitch.", "tone": "share", "mark": "you_tried_binding", "face": "amused", "reply": """
She passes you the needle the way one passes a full cup. Your stitch goes in crooked, comes out somewhere unexpected, and holds.

Farah: Dreadful. Leave it. My teacher said every book should contain one stitch its binder is ashamed of, so that it does not grow proud.
"""},
			]},
			{"face": "thoughtful", "text": """
As a girl she spent a season with a bookbinder named Samira, and once imagined staying. She also likes diplomacy; the old wish is not evidence of a stolen life.

Farah: Whenever I mentioned the binding, I explained how it might serve the family correspondence. That was true. It was also camouflage. I liked making a small thing open properly. Apparently pleasure seemed an insufficient argument.

[?farah_defended_ceremony] Farah: You will tell me ceremony has its place. This has none. That is what I like about it.
""", "options": [
				{"say": "Do you regret not staying?", "tone": "ask", "reply": """
Farah: On bad days at court, luxuriously. On good ones, not at all.

Farah: I have decided that a regret which only visits in bad weather is really a roof. One is glad to have it; one does not live there.
"""},
				{"say": "You could still do it. You're doing it now.", "tone": "comfort", "reply": """
Farah: I am mending one notebook on a table that belongs to a ministry.

Farah: But yes. I notice nobody has stopped me. I keep waiting for a cousin to come in and ask what it is for.
"""},
			]},
			{"face": "concerned", "text": """
She pulls one stitch tight, checks it, and does not apologize for the uneven first attempt hidden beneath the new thread.

Farah: There is something else, since we are being plain. Last spring I was offered an embassy. The great post, at a great court. I declined it in a letter so graceful that they thanked me.

Farah: I said the timing was wrong. The truth is that I did not want it, and I could not find a way to write that down that sounded like an envoy. I am still not sure I was right.
""", "options": [
				{"say": "What did you want instead?", "tone": "ask", "face": "thoughtful", "reply": """
Farah: This. A table. Roads I know by their unofficial names. Work small enough to see whether it helped.

Farah: It sounds like very little, said aloud. It did not feel like very little when I was choosing it.
"""},
				{"say": "You can value both kinds of work.", "tone": "comfort", "face": "thoughtful", "reply": """
Farah: I know that when you say it. I am learning to know it before someone grants permission. Diplomacy is mine too; duty did not poison everything it touched.
"""},
				{"say": "I'm glad you stayed. Selfishly.", "tone": "heart", "when": "romantic", "face": "warm",
					"memory": "Helped Farah repair the notebook she keeps for herself, and told her you were glad she stayed.", "reply": """
Farah: Selfishly. Good. I have had a year of people being glad for my career.

She ties off the thread with rather more care than the knot requires.

Farah: I stayed for several reasons. I will admit that one of them rides in at odd hours and holds paper badly.
"""},
				{"say": "For what it's worth, the roads here are better for it.", "tone": "warm", "when": "friend", "face": "warm", "reply": """
Farah: It is worth a good deal. Nobody tells an envoy that the place she declined to leave was improved by her staying.

Farah: I shall keep that sentence. I know exactly where; it opens flat now.
"""},
			]},
		],
		"closing_face": "thoughtful", "closing": """
The final knot sits slightly off center. Farah considers correcting it, then closes the notebook. It opens flat.

Farah: There. Evidence that I can stop when the thing works. Samira would be astonished.

[?you_tried_binding] Your crooked stitch shows at the head of the spine. She runs a thumb over it and leaves it where it is.

[?!you_tried_binding] You release the page. A faint indentation from your thumb remains near the margin.

Farah: Leave it. A repaired book should not pretend nobody held it together.

She places the notebook beside her official dispatches, neither hidden beneath them nor displayed for praise.
""",
		"summary": "Farah repairs a notebook and admits she once wanted to be a bookbinder. She still values diplomacy; the private craft does not expose a false life. Then she tells you plainly that she turned down a great embassy last spring because she did not want it, and is still not sure she was right.",
		"memory": "Helped Farah repair the notebook she keeps for herself.",
	},
	"farid_no_reply_required": {
		"title": "No Reply Required", "rank": "A", "requires_any": ["farid_own_answer"], "coda": true, "setting": "envoy_room",
		"parts": [
			{"face": "warm", "text": """
Farah arrives without a document, seal, or carefully arranged reason.

Farah: I saw something today that I wanted to tell you about. A dog was carrying a loaf longer than itself. The baker appeared to be losing the negotiation.
""", "options": [
				{"say": "Tell me all of it. Leave nothing out.", "tone": "ask", "face": "amused", "reply": """
Farah: The loaf survived. The baker recovered one end, which the dog treated as a separate loaf and graciously surrendered. I have rarely seen a settlement executed with such confidence.
"""},
				{"say": "The five-word version.", "tone": "tease", "face": "amused", "reply": """
Farah counts on her fingers.

Farah: Dog took bread. Baker lost. Four. I have a word in hand, and I am not going to spend it. You see how far I have come.
"""},
			]},
			{"face": "warm", "text": """
She sits before asking whether you have time, then notices what she has done.

Farah: I usually bring news that requires an answer. Even my jokes arrive with a request attached: reassure someone, forgive a delay, admire the phrasing. This one has no function. I simply thought you would laugh.

Farah: I sent the letter to my cousin, by the way. The short sentence survived the journey.
""", "options": [
				{"say": "I saw something foolish too.", "tone": "share", "face": "amused", "reply": """
Farah receives your harmless observation with the attention she usually gives a border dispatch. Halfway through, you both recognize this and laugh.

Farah: I am interested. I am merely trying not to look official about it.
"""},
				{"say": "And what did she say?", "tone": "ask", "reply": """
Farah: That she had waited eleven years for a letter with me in it. And that I should eat.

Farah: I have read it four times. It requires no reply, and I am going to reply anyway, which I gather is the point of family.
"""},
			]},
			{"face": "warm", "text": """
[?you_name_bridge] Farah: I crossed your Leaning Bridge last month, on the coast road. I told the escort its proper name. They have started using it. I am afraid you have altered a map.

[?you_name_kettle] Farah: We camped near your Cold Kettle last month, on the coast road. I told the escort its proper name. Nothing would boil. They were delighted.

[?you_name_elbow] Farah: I rode round your Widow's Elbow last month. I asked in three villages. Each one claims her, and each described a different woman. I have never been so pleased by a failed inquiry.

[?you_tried_binding] Farah: Your stitch is holding, incidentally. I check it. It has not grown any less crooked.

Outside, someone calls the evening market closed and is ignored by at least half the street.

Farah: There may be further unimportant news, if you encourage me.
""", "options": [
				{"say": "Go on. Every unimportant word.", "tone": "ask", "face": "amused", "reply": """
Farah: The well rope has been replaced with one of a slightly different color, and the street is divided. A boy sold me a pear that was a turnip. My uncle has written to complain about a cloud.

Farah: None of it requires anything of you. I cannot tell you how restful that is to say.
"""},
				{"say": "Or we sit, and nobody reports anything.", "tone": "quiet", "reply": """
Farah settles into the quiet. Once, she opens her mouth to rescue the silence. Then she smiles and lets it remain exactly where it is.
"""},
				{"say": "Come here. Tell me from closer.", "tone": "heart", "when": "romantic",
					"memory": "Heard Farah's unimportant news from close beside her, because each of you wanted the other to hear it.", "reply": """
Farah crosses the room in fewer steps than protocol would allow, sits where her shoulder rests against yours, and reaches for your hand.

Farah: From here the news is briefer. It is that I am glad to be here.
"""},
				{"say": "Encouraged. I've all evening.", "tone": "warm", "when": "friend", "reply": """
Farah settles into the familiar ease of friendship, one foot tucked under her, like someone who has stopped being received and started being at home.

Farah: Then I shall begin with the turnip.
"""},
			]},
		],
		"closing_face": "warm", "closing": """
The room grows dim around the two of you. Nothing has been decided, delivered, or improved for distant parties.

Farah: I used to believe closeness meant knowing the correct answer sooner than anyone else. This is easier. I can bring you a ridiculous dog and trust that the story is enough.

Farah: No reply required. Though I hope you will tell me if you ever see what became of the loaf.
""",
		"summary": "Farah brings no petition, only a story about a dog stealing an impractically long loaf. She enjoys telling you something simply because it made her think of you, and she has sent her cousin the short, honest letter. No reply, favor, message or diplomatic action is asked of you.",
		"memory": "Shared unimportant news with Farah because each of you wanted the other to hear it.",
	},
	"farid_said_plainly": {
		"title": "When You Last Said It Plainly", "rank": "S", "requires_any": ["farid_no_reply_required"], "coda": true, "setting": "envoy_room",
		"parts": [
			{"face": "thoughtful", "text": """
Farah has a blank sheet in front of her, and has had it for some time. The ink has skinned over in the well.

Farah: I have a question for you, and I have drafted it eleven ways. The eleventh was the longest. I am going to ask the first.

[?farah_outdrafted] Farah: Do not reach for the pen. I know your work.
""", "options": [
				{"say": "Ask the first one.", "tone": "quiet", "reply": """
Farah: Yes. Before I improve it.
"""},
				{"say": "Read me the eleventh. For the record.", "tone": "tease", "face": "amused", "reply": """
Farah: It begins 'Should the occasion ever have arisen in which', and it does not recover.

Farah: No. The first.
"""},
			]},
			{"face": "thoughtful", "text": """
Farah: When did you last say exactly what you meant? Not the useful thing. Not the kind one. The thing itself.
""", "options": [
				{"say": "Giving an order. It's the only time I'm certain.", "tone": "share", "mark": "you_plain_orders", "reply": """
Farah: So you are plain when lives depend on it, and careful the rest of the time.

Farah: I am the reverse. I can be exact about a border, and I cannot ask for soup. Between us we make one honest person.
"""},
				{"say": "At a graveside. Too late to be any use.", "tone": "share", "mark": "you_plain_grave", "face": "concerned", "reply": """
Farah does not reach for a graceful phrase. She lets the sentence stand in the room at its full size.

Farah: Then you know what it costs to keep the plain thing back until the occasion is safe. I have been keeping one back. I would rather not learn it your way.
"""},
				{"say": "Now, I think. Answering you.", "tone": "share", "mark": "you_plain_now", "face": "warm", "reply": """
Farah: That is either the truth or the best flattery I have ever been offered, and I have been flattered by professionals.

Farah: I think it is the truth. You have no gift for the other thing. It is one of the reasons I draft less when you are in the room.
"""},
			]},
			{"face": "warm", "text": """
She pushes the blank sheet away. Then, because she is who she is, she pulls it back and turns it face down, so that there is no page to write on at all.

Farah: I am going to try it. Five words. I counted them, and I am not going to tell you how many there were before I cut them down.

[?romantic] Farah: I love you. Stay close.

[?friend] Farah: I trust you. Completely. Always.

She stops. Nothing follows it. No clause, no courtesy, no route home.
""", "options": [
				{"say": "Say it again. Just as short.", "tone": "tease", "reply": """
Farah says it again. It comes out exactly the same length.

Farah: It holds. I half expected it to grow a preamble the moment I looked away.
"""},
				{"say": "How long was the first draft?", "tone": "ask", "face": "amused", "reply": """
Farah: Two pages. There was a paragraph on the weather the day we met. There was a subordinate clause about your horse.

Farah: Everything in it was true. None of it was this.
"""},
				{"say": "I love you. Five words was two too many.", "tone": "heart", "when": "romantic",
					"memory": "Farah asked when you last said exactly what you meant, then said five plain words. You answered in three.", "reply": """
Farah: Three. You have done it in three.

She laughs with her whole face, the laugh that arrives before any reply.

Farah: I shall never out-draft you after all. I find I do not mind. Say it again; I want to count.
"""},
				{"say": "And I you. No treaty needed.", "tone": "warm", "when": "friend", "reply": """
Farah: No treaty. No witnesses. Not even a seal.

Farah: It is the best-made agreement of my career, and there is nothing in the archive to show for it. Good.
"""},
			]},
		],
		"closing_face": "warm", "closing": """
The sheet stays face down. Farah puts the stopper back in the ink.

[?farah_defended_ceremony] Farah: You will tell me ceremony has its place. It does. Tonight it can wait in the corridor.

Farah: I spent a year learning to ask for water as though ending a siege. It has taken rather longer to learn the other thing.

She does not thank you for listening. She has, for once, said everything she meant to, and so she simply stays.
""",
		"summary": "Farah asks when you last said exactly what you meant, and you tell her. Then she tries it herself: five plain words, with no clause or courtesy after them, about what you are to her.",
		"memory": "Farah asked when you last said exactly what you meant, and then said five plain words of her own.",
	},
	"farid_short_answer": {
		"title": "The Short Answer", "rank": "S", "requires_any": ["farid_said_plainly"], "coda": true, "setting": "envoy_room",
		"parts": [
			{"face": "thoughtful", "text": """
A letter lies open on Farah's table in her cousin's hand, large and unhurried. Beside it is a reply. It is half a page. Farah keeps looking at how much paper is left over.

Farah: She has written again. The same question, which I take as either stubbornness or love. In my family they share a handwriting.

[?farah_asked_mostly] Farah: You asked me once about the part I didn't choose. I have put it in. One line. It turns out it only needed one.

[?farah_let_mostly] Farah: You let 'mostly' stand, once. I have looked at it again. It has been promoted. It did not apply for the post; I simply noticed one morning that it had happened.
""", "options": [
				{"say": "Read it to me.", "tone": "ask", "reply": """
Farah: Yes. That is why it is still unsealed. I wanted to hear whether it survives a second person.
"""},
				{"say": "Half a page? Are you well?", "tone": "tease", "face": "amused", "reply": """
Farah: I am in perfect health, and I resent the inquiry.

Farah: It is half a page because it is finished. I checked. I kept turning it over to see where the rest was.
"""},
			]},
			{"face": "warm", "text": """
She reads it aloud. It says that the roads are open. It says that she is tired, less than before. It says that she binds a book now and then, for no reason. It says: yes, I am happy; I did not expect to be asked twice, and I am glad you did.

[?romantic] It says: there is someone. You would like them. They hold paper badly.

[?friend] It says: I have a friend here who never needs the long version.

Farah: Does it sound like me?
""", "options": [
				{"say": "It sounds like you. The one who follows the bread.", "tone": "comfort", "reply": """
Farah: The resident, not the envoy. Good. That is who she wrote to.

Farah folds it once. She does not read it again.
"""},
				{"say": "It does. Add a line: that you've been eating properly.", "tone": "tease", "face": "amused", "reply": """
Farah: She will not believe it without a witness.

She writes it anyway, at the foot of the page, and then, in smaller letters: confirmed by a third party.

Farah: There. She will know I am happy if I am making jokes in the margin.
"""},
				{"say": "Add one line. Tell her my name.", "tone": "heart", "when": "romantic",
					"memory": "Heard Farah read her cousin the short answer, and saw her write your name into it.", "reply": """
Farah's pen stops above the page.

Farah: Your name. In my hand, to my family. You understand that in my house that is not a postscript. It is an announcement.

She writes it slowly, the way she signs treaties, and does not blot it.
"""},
				{"say": "Add one line. Tell her what you told me.", "tone": "warm", "when": "friend", "reply": """
Farah's pen stops above the page.

Farah: The five words. No. Those were yours. But I shall tell her that I said them, and that it did not take a treaty. She will read that part aloud to everyone.
"""},
			]},
		],
		"closing_face": "warm", "closing": """
She seals it herself, without a second draft, and sets it on the tray for the morning rider.

[?you_plain_orders] Farah: You said you are only plain when you give an order. Here is one from me, then: come back when the reply does. I shall want to read it to someone.

[?you_plain_grave] Farah: You said you were plain at a graveside, too late. This goes while she can still read it. I have you to thank for the hurry.

[?you_plain_now] Farah: You said you were plain when you answered me. I have been trying to deserve that. This letter is the nearest I have come.

Farah: 'Are you happy?' Eleven years to answer it, and it took half a page. I am told the best treaties are short. I never believed it until I signed one.
""",
		"summary": "Farah's cousin has asked again whether she is happy. This time the reply is half a page. Farah reads it aloud to you and asks whether it sounds like her; then she seals it without a second draft.",
		"memory": "Heard Farah read her cousin the short answer, and told her it sounded like her.",
	},
}
