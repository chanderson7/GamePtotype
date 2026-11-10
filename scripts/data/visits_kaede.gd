## Kaede's visits. (The format is described in personal_conversations.gd. The ids are save
## keys from the first version of each visit and no longer describe the scene.)
##
## Her voice: level, literal and exact. She states what she observes and how sure she is of
## it, corrects before she comforts, and takes notes on you in front of you. She does not
## make jokes; she says true things that are funny, and notices afterwards. No contractions.
##
## What is under it: at seven she was in the gatehouse of Kitayama during the siege. On the
## eleventh night her father, Ishida Ren, keeper of the lower gate, opened it to let the
## children out, and both clans loosed at the gate. He was carrying her. One clan's account
## calls the one who opened it a traitor, the other a coward; neither names him. She was
## given to the archive afterwards as a pledge-child, and has not passed the lower gate
## since. The visits go from interviewing you as a source, to the romances she hides under
## tide tables, to the name she wrote in a margin at nine, to the maps of places she has
## never seen, to her file on you, to the gate itself, to her own deposition.
##
## She asks you: what a siege is like for the small; what is not on the map; a preference
## you have never stated.
extends RefCounted

const SCENES := {
	"kaede_useless_map": {
		"title": "Primary Source", "rank": "C", "requires_any": [], "setting": "archive_room",
		"parts": [
			{"face": "thoughtful", "text": """
Kaede has a clean sheet, a fresh brush, and a list of questions. She has placed a stool for you at a measured distance from the desk.

Kaede: You command soldiers in battle. I have four hundred accounts of battles, and none by anyone who was at the front of one. You are a primary source. Sit.

Kaede: First question. How many people have you killed?
""", "options": [
				{"say": "That's your first question?", "tone": "tease", "face": "amused", "reply": """
Kaede: It is the one every account omits. I assumed it was therefore the important one.

Kaede: I see from your face that it is also impolite. I shall note that, and ask it last.
"""},
				{"say": "I stopped counting. On purpose.", "tone": "share", "mark": "kaede_honest_count", "reply": """
Kaede writes: source ceased counting, deliberately. Then she looks up.

Kaede: That is the first honest figure I have been given for a battle. It is not a number, and it is more exact than the numbers.
"""},
			]},
			{"face": "amused", "text": """
Kaede: Second. Before a charge. The chronicles say that commanders feel 'resolve'. Describe resolve.

You: Mostly I need to piss.

Kaede: That is not in any chronicle.

She writes it down, in full, in her best hand.
""", "options": [
				{"say": "You're really writing that?", "tone": "tease", "reply": """
Kaede: It is corroborated. A ferryman told me the same of floods. I had dismissed him. I owe him a correction.

Kaede: Do you know how rare it is for two sources to agree without a motive?
"""},
				{"say": "What do the chronicles say about fear?", "tone": "ask", "face": "thoughtful", "reply": """
Kaede: That the enemy felt it. Always the enemy. In four hundred accounts, not one victor was afraid.

Kaede: I have long suspected the accounts. I had no method of testing them. Now I have you.
"""},
			]},
			{"face": "thoughtful", "text": """
She has filled a page. She sets the brush down, squares it, and does something she has not done all afternoon: she hesitates.

Kaede: A last question. It is not for the record. I was in a siege, at seven. I remember almost nothing. A gate. Noise. Someone carrying me.

Kaede: You have been inside such things as an adult. What is it like, for the ones who are small?
""", "options": [
				{"say": "Loud. They don't understand it. They remember someone's arms.", "tone": "comfort", "mark": "kaede_told_siege",
					"memory": "Was interviewed by Kaede as a primary source, and told her what the small ones keep from a siege.", "reply": """
Kaede: Arms. Yes.

Kaede: That is consistent. I had thought it too slight a thing to be all I kept. You are saying it is what there is to keep.
"""},
				{"say": "Who carried you?", "tone": "ask", "reply": """
Kaede: I do not know who else was there. It is the first omission I ever noticed.

Kaede: I have spent twenty years in an archive looking for what nobody wrote down. That is not in my official statement of purpose. You may be the only person I have told.
"""},
				{"say": "Not for the record. Ask me as yourself.", "tone": "share", "reply": """
Kaede: I do not know the difference.

Kaede: I put the brush down before I asked. I did not notice that I had. Perhaps that is the difference.
"""},
			]},
		],
		"closing_face": "amused", "closing": """
She dates the sheet, signs it, and then, instead of filing it, sets it apart from the others.

Kaede: This is the most useful account in the building. It is also unpublishable. Nobody will believe the part about needing to piss.

Kaede: Come again. I have forty more questions. I have removed the impolite ones. There are now thirty-one.
""",
		"summary": "Kaede interviews you as a primary source on battles, since none of her four hundred chronicles was written by anyone at the front of one. Her questions are blunt and her note-taking exact. Then, off the record, she asks what a siege is like for a child: she was in one at seven, and remembers only a gate, noise, and being carried.",
		"memory": "Was interviewed by Kaede as a primary source, and made it into the record.",
	},
	"kaede_bad_mystery": {
		"title": "A Reference Work", "rank": "C", "requires_any": [], "setting": "archive_room",
		"parts": [
			{"face": "amused", "text": """
Kaede is reading a cheaply bound book with the concentration she gives to disputed covenants, and writing in its margins. When you come in she puts a tide table over it. The tide table is not large enough.

Kaede: It is a reference work.

You: It's called 'The Bandit Prince's Bride'.

Kaede: It refers to bandits.

[?kaede_honest_count] Kaede: You gave me an honest figure once. I shall give you one. I have read it nine times.
""", "options": [
				{"say": "What are you writing in it?", "tone": "ask", "reply": """
Kaede: Corrections. He scales a tower on a rope of bedsheets. I have calculated the load. He would fall forty feet.

Kaede: Also, the heroine faints eleven times, and no physician is consulted. I have recommended one.
"""},
				{"say": "Is it any good?", "tone": "tease", "reply": """
Kaede: It is dreadful. The geography is impossible, the seal is on the wrong side of the letter, and a horse changes colour in chapter four.

Kaede: I cannot stop reading it.
"""},
			]},
			{"face": "amused", "text": """
Kaede: A binder in the lower town sells them. I told him they were for a study of popular error. He wraps them in plain paper now, and winks. I do not know what the wink signifies.

Kaede: I do not understand the central matter. The prince says he would 'burn the world' for her. That is not a reasonable exchange. And yet I have read that page more often than the others.
""", "options": [
				{"say": "People say foolish things when they're in love.", "tone": "share", "reply": """
Kaede: So I have read. I had classified it as a convention of the form.

Kaede: You are a primary source on battles. Are you also one on this? You need not answer. I am noting that you have changed colour. Like the horse.
"""},
				{"say": "The wink means he knows why you buy them.", "tone": "tease", "mark": "kaede_wink", "reply": """
Kaede: He cannot. I gave a false purpose.

Kaede: The purpose was unconvincing. I see. I have been buying forbidden romances from a man who has known the entire time. I shall have to change binders. I shall not change binders.
"""},
			]},
			{"face": "thoughtful", "text": """
She takes the tide table off the book. It seems to cost her something, like declassifying a document.

Kaede: I was given to this archive at seven. Everything I was taught concerned what can be proven. Nobody mentioned this. I have had to study it from very poor sources.

Kaede: Read the page. Tell me whether it is as foolish as I think. I require a second opinion, and I can hardly ask the scribes.
""", "options": [
				{"say": "'I would burn the world for you, my desert rose!'", "tone": "tease", "mark": "kaede_read_aloud", "face": "amused",
					"memory": "Caught Kaede with 'The Bandit Prince's Bride', read it aloud in the voice, and made her laugh.", "reply": """
Kaede makes a sound you have not heard from her. It is, on inspection, a laugh, and she examines it with alarm.

Kaede: That was involuntary. Do it again. No. Do not. I have a reputation in this building.
"""},
				{"say": "It's foolish. That's why it works.", "tone": "share", "reply": """
Kaede: Explain.

You: Nobody wants a reasonable exchange.

Kaede: That contradicts every principle of this archive. I am going to think about it for several days. I resent that I shall enjoy doing so.
"""},
				{"say": "I think you like the prince.", "tone": "tease", "face": "amused", "reply": """
Kaede: I do not. He is a poor planner and a worse climber.

Kaede: I like that she corrects his map in chapter six. It is the only credible scene. I have marked it. Twice.
"""},
			]},
		],
		"closing_face": "amused", "closing": """
She puts the book in the drawer with her private maps, not with the tide tables.

Kaede: You will tell no one.

You: Who would I tell?

Kaede: That is a sound argument. Very well. There is a sequel. 'The Bandit Prince's Heir.' It is worse. I have not had anyone to say so to.
""",
		"summary": "You catch Kaede reading 'The Bandit Prince's Bride' under a tide table, and annotating its errors. She has read it nine times. Raised in an archive on what can be proven, she has been trying to study love from very poor sources, and asks you for a second opinion on one page.",
		"memory": "Caught Kaede with 'The Bandit Prince's Bride', and was asked for a second opinion.",
	},
	"kaede_margin_name": {
		"title": "A Name in the Margin", "rank": "B", "requires_any": ["kaede_useless_map", "kaede_bad_mystery"], "setting": "archive_room",
		"parts": [
			{"face": "concerned", "text": """
The official account of the siege of Kitayama lies open on the desk: forty leaves, three seals. In the margin of the ninth leaf, in a child's round hand, someone has written a name. Someone else has tried to scrape it out.

Kaede: I was nine. I was beaten for it. A margin is not for additions.

[?kaede_told_siege] Kaede: You told me what the small ones keep from a siege. Arms. These were the arms.
""", "options": [
				{"say": "Whose name?", "tone": "ask", "mark": "kaede_asked_name", "reply": """
Kaede: My father's. Ishida Ren. He kept the lower gate.

Kaede: You are the second person to ask. The first was the archivist who beat me. She asked in a different tone.
"""},
				{"say": "You needn't tell me.", "tone": "quiet", "mark": "kaede_left_name", "reply": """
Kaede: No. I need not. That is why I find I am going to.

Kaede: It is my father's. Ishida Ren. He kept the lower gate.
"""},
			]},
			{"face": "concerned", "text": """
Kaede: The account says: 'on the eleventh night the lower gate was opened from within, and the slaughter began.' It does not say by whom. One clan's copy says a traitor. The other's says a coward. Neither gives a name, because a name could be argued with.

Kaede: He opened it to let the children out. There were nineteen of us in the gatehouse. Both clans loosed at the gate at once. He was carrying me.
""", "options": [
				{"say": "He saved nineteen children.", "tone": "comfort", "reply": """
Kaede: Eighteen. And he began the slaughter. Both statements are accurate.

Kaede: That is what I cannot file. An archive wants one heading. I have had him under two for twenty years.
"""},
				{"say": "And nobody wrote that down.", "tone": "ask", "reply": """
Kaede: The children were seven. Nobody takes a statement from a child.

Kaede: I have the names of eighteen of them. It took eleven years. Not one was ever asked. I was the nineteenth, and I asked myself, at nine, in a margin.
"""},
			]},
			{"face": "thoughtful", "text": """
She touches the scraped place with one finger. The name is still legible under it, if you know to look.

Kaede: I became an archivist to put him in the record. Then I learned what a record is. If I write that he was a hero, I do what the clans do. I make the account convenient to me.

Kaede: So he is nowhere. I keep the most accurate archive in Ryumon, and my father is a scraped place in a margin.
""", "options": [
				{"say": "Then write only what you saw. You're a witness.", "tone": "help", "mark": "kaede_witness", "reply": """
Kaede: A witness aged seven.

Kaede: A primary source, with the limits stated. 'I was carried. The gate was open. I did not see who loosed.' That is not convenient to anyone. I could sign that.
"""},
				{"say": "A daughter looked for eleven years. That's a record too.", "tone": "comfort", "reply": """
Kaede: That is a sentiment.

Kaede: It is also a fact. Eleven years, eighteen names. It is documented; I documented it. I had not thought of the search as testimony.
"""},
				{"say": "He's somewhere. You said his name, and I heard it.", "tone": "heart", "when": "romantic", "face": "warm",
					"memory": "Saw the name Kaede wrote in a margin at nine, and heard her say it aloud to someone for the first time.", "reply": """
Kaede: Ishida Ren.

She says it again, to you, and then a third time, like someone testing a floor.

Kaede: It is different, said to a person. The margin did not answer. I had not understood what I was missing in a reader.
"""},
				{"say": "Tell me about him. I'll remember; that's an archive of a kind.", "tone": "warm", "when": "friend", "face": "warm", "reply": """
Kaede: You forget dates, and you fold corners.

Kaede: He whistled when he checked the bolts. He had a name for me that I have not heard since. You see: I am telling you. You are a poor archive, and I am using you anyway.
"""},
			]},
		],
		"closing_face": "thoughtful", "closing": """
She does not close the book. She leaves it open at the ninth leaf, with the lamp on it.

Kaede: I have never shown that margin to anyone. I should like it noted that the building is still standing.

Kaede: Come again. I may have further omissions.
""",
		"summary": "In the margin of the official account of the siege of Kitayama there is a name in a child's hand, half scraped out. Kaede wrote it at nine, and was beaten for it. It is her father's: Ishida Ren, who kept the lower gate and opened it to let nineteen children out, and whom both clans' accounts call a traitor without naming.",
		"memory": "Saw the name Kaede wrote in a margin at nine, and learned whose it was.",
	},
	"kaede_missing_street": {
		"title": "Reported, Not Observed", "rank": "B", "requires_any": ["kaede_margin_name"], "setting": "archive_room",
		"parts": [
			{"face": "thoughtful", "text": """
The desk is covered in maps. Not the archive's: Kaede's own, in her exact hand. The Glass Sea. The pass above Marchgate. A harbour, with every mooring drawn.

Kaede: I have never seen any of them. I have not been past the lower gate since I was seven. They are compiled from travellers. Each is marked: reported, not observed.

[?kaede_asked_name] Kaede: You asked me a direct question once, and I answered it. You may ask why.

[?kaede_left_name] Kaede: You did not ask, once. You will not ask why now, either. So I shall say.
""", "options": [
				{"say": "Why not go?", "tone": "ask", "reply": """
Kaede: A pledge-child does not leave. That was the term: I was given to the archive so that both clans would trust the record.

Kaede: The term lapsed when I came of age. Eleven years ago. I have examined the gate each morning since, and found no reason sufficient to walk through it.
"""},
				{"say": "They're beautiful.", "tone": "comfort", "reply": """
Kaede: They are accurate to the sources. The sources disagree; I have noted where.

Kaede: Beautiful is not a category I had applied. I shall consider it. I am free to leave, you understand. The pledge lapsed eleven years ago. I have simply not found a sufficient reason.
"""},
			]},
			{"face": "thoughtful", "text": """
Kaede: A ferryman told me the sea is the colour of slate. A pilgrim said jade. A child said it was the colour of the sea, and looked at me as though I were simple. I have recorded all three.

Kaede: You have been to these places. I should like a fourth source. Choose one, and tell me what is not on the map.
""", "options": [
				{"say": "The sea. It's never one colour. That's the point of it.", "tone": "share", "mark": "you_told_sea", "reply": """
Kaede: Then all three were right, and I was wrong to seek agreement.

She writes: colour, variable; the variation is the datum.

Kaede: I have been correcting my sources toward each other. I may have been erasing the sea.
"""},
				{"say": "A battlefield, the morning after. The birds come back first.", "tone": "share", "mark": "you_told_field", "reply": """
Kaede: Birds. No chronicle has birds. I have four hundred accounts that end at sunset. Nobody stays to write the morning.

Kaede: You stayed. Of course you did. You had to count.
"""},
				{"say": "The road at night, the company asleep. I'm the only one awake.", "tone": "share", "mark": "you_told_road", "reply": """
Kaede: You keep a watch that nobody ordered.

Kaede: I do the same, with the lamp. I had thought it was peculiar to archives. I shall mark it on both maps: one person awake.
"""},
			]},
			{"face": "concerned", "text": """
She looks at the lower gate, through the window. You have the sense she always knows where it is, the way one knows where a tooth is.

Kaede: I shall tell you the reason I have not found sufficient. It is not the pledge. If I walk through that gate, it is the gate. The one that was opened. I have not passed it since I was carried through.

Kaede: That is not rational. I have catalogued it as not rational. It has not helped.
""", "options": [
				{"say": "Then don't go through it alone.", "tone": "help", "reply": """
Kaede: That is not a method.

Kaede: It is, in fact, exactly a method. It is the one he used. I was carried. I had not considered that I might be accompanied.
"""},
				{"say": "Not rational doesn't mean not real.", "tone": "comfort", "reply": """
Kaede: That sentence would be struck from any finding of mine.

Kaede: I am going to keep it anyway. In the private box, where the things go that are true and cannot be proven.
"""},
				{"say": "When you're ready, I'll walk through it with you. However long.", "tone": "heart", "when": "romantic", "face": "warm",
					"memory": "Saw Kaede's maps of places she has never been, and promised to walk through the lower gate with her when she was ready.", "reply": """
Kaede: You are frequently away. Your waiting would be intermittent.

Kaede: I find that it would be sufficient. An intermittent source, consistently returning. I have relied on worse. I have never relied on better.
"""},
				{"say": "I'll walk you through it. Friends are allowed at gates.", "tone": "warm", "when": "friend", "face": "warm", "reply": """
Kaede: There is no rule concerning friends at gates.

Kaede: I have checked, just now, in my head. There is no rule. It appears to be permitted.
"""},
			]},
		],
		"closing_face": "thoughtful", "closing": """
She takes the harbour map and, beneath 'reported, not observed', leaves a blank line.

Kaede: For a later entry. I am not committing to one. I am leaving room, which I do not ordinarily do.

Kaede: Tell me another place before you go. I find I prefer them in your account.
""",
		"summary": "Kaede has drawn exact maps of the Glass Sea, the pass above Marchgate and a harbour, all from travellers' accounts: she has not been past the lower gate since she was seven. She asks you what is not on the map. And she tells you why she has never gone, though the pledge lapsed years ago: the gate she would have to walk through is the one her father opened.",
		"memory": "Saw Kaede's maps of places she has never been, and added what isn't on one.",
	},
	"kaede_kept_page": {
		"title": "Loss of Objectivity", "rank": "A", "requires_any": ["kaede_missing_street"], "setting": "archive_room",
		"parts": [
			{"face": "concerned", "text": """
Kaede has a ledger you have not seen before. It is thick. Your name is on the spine, in her hand, with a catalogue number.

Kaede: I must report an irregularity. I have kept a file on you since the first day. That is normal practice for a source. The file has become irregular.

[?kaede_wink] Kaede: Do not look like the binder. I know that expression now.
""", "options": [
				{"say": "Read me the first entry.", "tone": "ask", "reply": """
Kaede: 'Mercenary captain. Arrived before noon. Did not haggle. Was polite to the porter. Stands in the light.'

Kaede: That is a proper entry. Dated, impersonal, verifiable. I was satisfied with it.
"""},
				{"say": "Irregular how?", "tone": "ask", "reply": """
Kaede: I shall demonstrate. The first entry: 'Mercenary captain. Arrived before noon. Polite to the porter. Stands in the light.' Proper. Verifiable.

Kaede: They do not continue in that manner.
"""},
			]},
			{"face": "concerned", "text": """
She turns to a marker. Her voice does not change; she reads it as she would a grain tally.

Kaede: Four months later. 'Captain late. Roads reported clear. No cause for concern identified. Checked the lower gate three times. Spoiled a sheet.'

Kaede: And this. 'Captain laughed at the ferryman's story. Recording the laugh. Unable to describe it. Attempted four times; see struck lines.'
""", "options": [
				{"say": "You tried to describe my laugh four times?", "tone": "tease", "face": "amused", "reply": """
Kaede: The attempts were inadequate. I struck them. One compared it to a door opening. That is not a description; a door does not laugh.

Kaede: I have left the struck lines legible. I do not scrape out.
"""},
				{"say": "You checked the gate three times.", "tone": "comfort", "reply": """
Kaede: It is an observation post. It has a view of the road.

Kaede: I have never before required a view of the road. I am not being evasive. I am establishing the sequence. I am an archivist; the sequence is all I have.
"""},
			]},
			{"face": "concerned", "text": """
She closes the file and puts both hands on it.

Kaede: The finding is as follows. I have lost objectivity regarding the subject. The record is compromised. By the rules of this archive I should transfer the file to another keeper.

Kaede: I do not wish to transfer the file. I wish that entered also. I have never before wished anything about a file.
""", "options": [
				{"say": "Keep it. A record can be true and not objective.", "tone": "share", "face": "thoughtful", "reply": """
Kaede: That is heresy in this building.

Kaede: It is also what my father's margin is. True, and mine. I have defended that margin for twenty years, and failed to notice that I had already conceded the principle.
"""},
				{"say": "What would you write today?", "tone": "ask", "face": "thoughtful", "reply": """
Kaede: 'Subject present. Subject listened to the whole irregularity without leaving. Keeper relieved.'

Kaede: And the date. I always have the date. It is the one thing I am never uncertain about.
"""},
				{"say": "I've lost objectivity too. For months.", "tone": "heart", "when": "romantic", "face": "warm",
					"memory": "Heard Kaede report that her file on you had 'lost objectivity', and told her yours had too.", "reply": """
Kaede: Then the compromise is mutual. That alters the finding.

Kaede: Two biased sources, in agreement, with no motive to collude. Do you understand what that is? It is the strongest evidence there is. I have built covenants on less.

She has taken your hand, and appears to be the last to have noticed.
"""},
				{"say": "It's the file of a friend. Keep that heading.", "tone": "warm", "when": "friend", "face": "warm", "reply": """
Kaede: 'Friend.' I ruled that column the first day, and did not know what to enter in it.

Kaede: It appears I have been entering it ever since. Four hundred leaves. It is the fullest column I have.
"""},
			]},
		],
		"closing_face": "thoughtful", "closing": """
She does not return the file to the shelf. She puts it in the private box, with the maps and the bandit prince.

Kaede: Reclassified. Not a source file. I do not have a name for the new class.

Kaede: You may read it. Not today. I should have to leave the room, and I do not wish to leave the room.
""",
		"summary": "Kaede reports an irregularity: the file she has kept on you since the first day, as she would for any source, has stopped being objective. She reads you the entries to prove it. By the archive's rules she should hand the file to another keeper, and for the first time in her life she does not want to.",
		"memory": "Heard Kaede report that her file on you had 'lost objectivity', and that she meant to keep it.",
	},
	"kaede_room_on_map": {
		"title": "The Lower Gate", "rank": "A", "requires_any": ["kaede_kept_page"], "coda": true, "setting": "kitayama",
		"parts": [
			{"face": "warm", "text": """
Kaede is at the lower gate at dawn, in a travelling cloak that has never travelled. She has a satchel, a blank map, two brushes, and the expression of someone about to authenticate a doubtful document.

Kaede: I have determined that there is now a sufficient reason. I have it written down, in case I forget it at the threshold.

[?you_told_sea] Kaede: The sea. Colour variable. I intend to observe the variation.

[?you_told_field] Kaede: A morning, with birds. I have never been outdoors for one.

[?you_told_road] Kaede: A road, with one person awake on it. I should like to be the other.
""", "options": [
				{"say": "Take my arm.", "tone": "help", "reply": """
Kaede: That is not necessary for balance.

She takes it. Her grip would hold a rope bridge.

Kaede: It is necessary for a different purpose. I have not classified the purpose. Proceed.
"""},
				{"say": "We can stand here as long as you need.", "tone": "quiet", "reply": """
Kaede: I need eleven years. I have had them.

She steps up to the stone of the threshold and stops a hand's breadth short, breathing like someone reading a very bad page.
"""},
			]},
			{"face": "concerned", "text": """
The gate is only a gate: old timber, a new bar, a sentry yawning. Kaede looks at it as if it were forty leaves long.

Kaede: The bolts are on the left. He checked them each evening, and whistled. I had forgotten that the bolts were on the left.

Kaede: I was carried through here. I should like to walk through it awake. I find that my feet are not persuaded.
""", "options": [
				{"say": "Tell me what you see. Like a record.", "tone": "help", "face": "warm", "reply": """
Kaede: Timber, oak, three bars. A sentry, unshaven. Beyond: a road, descending. A field. Fog on it.

Kaede: A bird. On the fence. It is entirely unconcerned.

She is through the gate. She was describing, and did not notice the step.
"""},
				{"say": "Whistle. Like he did.", "tone": "comfort", "face": "amused", "reply": """
Kaede: I cannot whistle.

She purses her lips anyway. What comes out is thin, flat and entirely tuneless; and then she is laughing, and somewhere in the laugh she has crossed the threshold.

Kaede: That was inadequate. I am standing in the road.
"""},
			]},
			{"face": "warm", "text": """
She stands in the road outside Kitayama for the first time in twenty years, and turns all the way round, once, slowly, like a surveyor.

Kaede: It is larger than reported.

Kaede: The sources were all correct, and none of them was adequate. I shall have to redraw everything. Every map. It will take the rest of my life. I find I am pleased.
""", "options": [
				{"say": "Where first?", "tone": "ask", "reply": """
Kaede: The ford. It is the nearest thing I have only read about. Then, in order of distance, everything.

Kaede: I have a list. It is long. I have left a column for places you prefer.
"""},
				{"say": "How does it feel?", "tone": "ask", "reply": """
Kaede: Unverified. Loud. There is weather on my face.

Kaede: I should like it recorded that I did not know there was this much. And that I was not carried.
"""},
				{"say": "You're beautiful, standing in a road.", "tone": "heart", "when": "romantic",
					"memory": "Walked with Kaede through the lower gate, the first time in twenty years, and told her she was beautiful standing in a road.", "reply": """
Kaede: That is not relevant to the—

Kaede: I withdraw the objection. Enter it. Beautiful, standing in a road. Dated. I shall want it when I am back at the desk and doubt the whole morning.
"""},
				{"say": "First observation of the day: you did it.", "tone": "warm", "when": "friend", "reply": """
Kaede: Second. The first was the bird.

Kaede: But entered. 'Keeper passed the lower gate. Accompanied.' I have underlined 'accompanied'. I do not ordinarily underline.
"""},
			]},
		],
		"closing_face": "warm", "closing": """
She unrolls the blank map on a milestone and makes the first mark: the gate, seen from outside. Beneath it she writes, not 'reported', but 'observed'.

Then she looks back, once, at the gatehouse, and nods to it, the way one nods to a colleague; and walks on down the road ahead of you, already asking what the fog is called.
""",
		"summary": "At dawn Kaede stands at the lower gate with a satchel and a blank map. She has not passed it since she was carried through at seven, on the night her father opened it. With you beside her, she walks through it awake, and finds the world larger than reported.",
		"memory": "Walked with Kaede through the lower gate, the first time she had passed it in twenty years.",
	},
	"kaede_preference_stated": {
		"title": "A Preference, Stated", "rank": "S", "requires_any": ["kaede_room_on_map"], "coda": true, "setting": "archive_room",
		"parts": [
			{"face": "thoughtful", "text": """
Two columns, ruled on a sheet. One is headed 'Observed'. It is full to the foot. The other is headed 'Preferred'. It has one entry, struck through.

Kaede: I have been attempting an inventory of myself. The first column took an evening. The second has taken nine days.

[?kaede_read_aloud] Kaede: Do not read this one in the voice. It is not that sort of document.
""", "options": [
				{"say": "What did you strike out?", "tone": "ask", "reply": """
Kaede: 'Quiet.' It was true, and it was a hiding place. Most of what I call quiet is only that no one has asked me anything.

Kaede: I am trying to list what I should choose if someone did.
"""},
				{"say": "Nine days, for one column.", "tone": "tease", "face": "amused", "reply": """
Kaede: The first requires only eyes. The second requires a position. I have been trained for twenty years to hold none.

Kaede: I struck out 'quiet'. It was true, and it was a hiding place.
"""},
			]},
			{"face": "thoughtful", "text": """
Kaede: I require a model. You must hold one: a preference you have never stated, because no one asked, or because it seemed too slight to enter.
""", "options": [
				{"say": "I'd rather ride at the back of the column. It's quiet there.", "tone": "share", "mark": "you_pref_back", "reply": """
Kaede: A captain who prefers the rear, and rides at the front regardless.

Kaede: Then a preference may be held for years without being acted upon, and remain true. That is the piece I lacked. I had assumed an unused preference lapsed, like a pledge.
"""},
				{"say": "Rain on canvas. I'd take it over a fine day.", "tone": "share", "mark": "you_pref_rain", "reply": """
Kaede: Against all interest. Wet rope, slow roads, cold food. And preferred.

Kaede: Then a preference need not be defensible. I have been trying to defend mine before entering them. That is why the column is empty.
"""},
				{"say": "Plain bread, warm. Over any feast I've sat through.", "tone": "share", "mark": "you_pref_bread", "reply": """
Kaede: Stated without apology to the feast.

Kaede: You did not explain it. I should have appended three reasons and a precedent. It appears to stand without them.
"""},
			]},
			{"face": "warm", "text": """
She takes up the brush. She does not rule a line first, or try it on the blotter, or look at the door.

[?romantic] She writes one word in the second column, and turns the sheet toward you. It is your name.

[?friend] She writes in the second column: these afternoons. Then, after a moment, beneath it: continued.

Kaede: Stated. No precedent. No witness clause. My hand is not steady. I am recording that as a detail, and not as a doubt.
""", "options": [
				{"say": "Read it aloud. A preference should be heard.", "tone": "ask", "reply": """
Kaede reads it aloud. Her voice is level, exact, and rather louder than the room requires.

Kaede: It is the same in the air as on the page. I had feared a discrepancy.
"""},
				{"say": "The column looks better with something in it.", "tone": "tease", "face": "amused", "reply": """
Kaede: It looks unbalanced. One entry against forty.

Kaede: I have decided not to mind. The forty are what I saw. The one is what I meant.
"""},
				{"say": "Rule me a column. My entry is your name.", "tone": "heart", "when": "romantic",
					"memory": "Kaede wrote down a preference for the first time in her life: your name. You answered with hers.", "reply": """
Kaede rules a third column, heads it with your name, and waits with the brush. You say hers. She writes it.

Kaede: Reciprocal, and independently stated. That is as near to proof as this kind of record allows.

Kaede: I would burn the world for you. That is a quotation. I have decided it is not, after all, an unreasonable exchange.
"""},
				{"say": "Enter it twice. Once for me.", "tone": "warm", "when": "friend", "face": "amused", "reply": """
Kaede writes 'continued' again beneath the first, and initials it on your behalf with a crooked mark plainly meant for your hand.

Kaede: A forgery. In my own archive. You are a corrupting influence, and I have preferred it for some time.
"""},
			]},
		],
		"closing_face": "warm", "closing": """
She does not blot the entry. She lets it dry in the air, where anyone coming in would see it.

Kaede: I believed that to state a preference would make me a worse witness. It has not. I see the room exactly as before. I only know now where in it I should rather stand.

She pins the sheet above her desk, between a tide table and a list of disputed boundaries: one more thing that is the case.
""",
		"summary": "Kaede has been trying to write down her own preferences and has managed one entry in nine days, which she struck out. She asks you for a preference you have never stated, as a model. Then she writes hers, with no precedent and no witness clause.",
		"memory": "Kaede asked for a preference you had never stated, and then wrote down her own.",
	},
	"kaede_name_used": {
		"title": "The Name, Entered", "rank": "S", "requires_any": ["kaede_preference_stated"], "coda": true, "setting": "archive_room",
		"parts": [
			{"face": "warm", "text": """
The official account of the siege is open at the ninth leaf. Beside it is a new sheet, in Kaede's hand, under her own seal. She is sitting very straight.

Kaede: It is a deposition. Mine. 'I, the nineteenth child, aged seven, state as follows.' It will be bound into the account. The council has agreed. It did not wish to; I cited eleven precedents.

[?kaede_witness] Kaede: You said: write only what you saw. This is that. I have added nothing convenient.
""", "options": [
				{"say": "Read it to me.", "tone": "ask", "reply": """
Kaede: 'I was in the gatehouse. Ishida Ren, keeper of the lower gate, opened it. He was carrying me. I did not see who loosed. He did not put me down.'

Kaede: That is all. It took twenty years to be entitled to it.
"""},
				{"say": "His name's in it.", "tone": "comfort", "reply": """
Kaede: In the text. Not the margin. Ishida Ren, keeper of the lower gate. No one may scrape a deposition.

Kaede: The last line is 'he did not put me down'. I am told it is not strictly evidentiary. I declined to remove it.
"""},
			]},
			{"face": "warm", "text": """
[?kaede_asked_name] Kaede: You asked me once whose name was in the margin, and I told you his. There is another I did not tell you.

[?kaede_left_name] Kaede: You once told me I need not say a name. I said it. There is another; and again I need not, and again I find I shall.

[?!kaede_asked_name,!kaede_left_name] Kaede: There is a name that is not in the deposition. It is not evidence. It is only mine.

Kaede: He called me Suzume. Sparrow. I announced at four that I would keep the gate with him, and it came out as a chirp. No one has used it since the eleventh night. There was no one left who knew it.

Kaede: You may use it. Once, now. After that we shall see what the record supports.
""", "options": [
				{"say": "Suzume.", "tone": "quiet", "reply": """
Kaede closes her eyes for exactly the length of the word.

Kaede: Yes. That is how it sounded. Not the voice. The license.
"""},
				{"say": "Sparrow. Small, exact, and into everything.", "tone": "tease", "face": "amused", "reply": """
Kaede: He said: small, loud, and impossible to keep out of the grain.

Kaede: Yours is kinder. I shall keep both definitions, and cross-reference them.
"""},
				{"say": "Suzume. I'd like to be the one who says it.", "tone": "heart", "when": "romantic",
					"memory": "Kaede entered her father's name in the record, told you the one he called her, and gave you the keeping of it.", "reply": """
Kaede: Then say it when no one else is by, and not often, so that it does not wear smooth.

She puts her seal into your hand and closes your fingers on it: the archivist's seal, the one thing she has never set down.

Kaede: Custody shared. I have never done that with anything I could not replace.
"""},
				{"say": "Suzume. It's safe with me.", "tone": "warm", "when": "friend", "reply": """
Kaede: I know. I verified it, over several seasons, without informing you.

Kaede: Use it when I am being insufferable about a citation. He did. It was very effective.
"""},
			]},
		],
		"closing_face": "warm", "closing": """
Something moves on the stair. A compact grey cat arrives on the sill, sits, and regards the room as though it had convened the meeting.

[?kaede_wink] Kaede: The cat. In attendance. It has the binder's expression. I begin to think everyone in this town knew before I did.

[?!kaede_wink] Kaede: The cat. In attendance. I have never once been able to guarantee that. I am recording the date.

[?you_pref_back] Kaede: It has taken the place at the back, where it is quiet. I know someone with the same preference.

[?you_pref_rain] Kaede: It comes in ahead of rain. There will be rain on the roof tonight. You will like that; I have it written down.

[?you_pref_bread] Kaede: It wants the bread. Not the fish. I know someone with the same preference.

She sands the deposition and binds it in herself, at the ninth leaf: the first thing in that account that anyone has signed with their own name.
""",
		"summary": "Kaede has written her own deposition as a witness to the siege, aged seven, with the limits stated, and the council has agreed to bind it into the official account: her father's name is in the text at last. Then she tells you the name he called her, which nobody has used since that night, and lets you say it.",
		"memory": "Kaede entered her father's name in the record, and told you the one he called her.",
	},
}
