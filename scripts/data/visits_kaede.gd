## Kaede's visits: the archivist who records everything except her own preferences. (The
## format is described in personal_conversations.gd.)
##
## Her running habits are the cat on her private map, whose attendance is never guaranteed,
## and her deliberately terrible theories about a very bad mystery. Her thread is the
## childhood name she forbade, and the aunt who gave it. She asks you three things: a place
## of no use to anyone, a place that changes each time, and a preference never said aloud.
extends RefCounted

const SCENES := {
	"kaede_useless_map": {
		"title": "A Map of Useless Places", "rank": "C", "requires_any": [], "setting": "archive_room",
		"parts": [
			{"face": "thoughtful", "text": """
Kaede covers a small page when you approach, then uncovers it with visible annoyance at herself.

Kaede: It is a map. It will not help you travel.

There are no roads, borders, or distances. One mark records where afternoon light reaches a wall. Another notes a step that stays dry in rain. Beside the stairs is a compact ink shape.
""", "options": [
				{"say": "What's this one, by the stairs?", "tone": "ask", "face": "amused", "reply": """
Kaede: A cat. Usually. I cannot guarantee the cat's attendance.
"""},
				{"say": "That stair has nine steps. You've drawn eight.", "tone": "tease", "mark": "kaede_corrected", "face": "amused", "reply": """
Kaede counts the drawn steps. Then she goes to the door, counts the real ones, and comes back with color in her face.

Kaede: Nine. You are right. That is the first correction anyone has made to this map, and it is a good one. I am annoyed at how pleased I am.
"""},
			]},
			{"face": "amused", "text": """
As a child, she mapped places where she could read undisturbed: behind a storehouse at noon, beneath a stair after lessons, beside an aunt who hummed and never asked what the book was about.

Kaede: Official maps explain how to reach an obligation. These explain why I might remain after arriving. I have not decided whether that makes them maps or illustrated excuses.
""", "options": [
				{"say": "No strategic value at all. I like that.", "tone": "comfort", "reply": """
Kaede: None. I verified it. An army could take every position on this page and gain one dry step.

Kaede: You are the first person to say so as a compliment.
"""},
				{"say": "Do you draw these only for yourself?", "tone": "ask", "reply": """
Kaede: Until now. That answer is technically no longer accurate.

She considers taking the page back, but leaves it between you.
"""},
			]},
			{"face": "amused", "text": """
She straightens the page, animated now that there is a classification to dispute.

Kaede: You have looked at it long enough to have formed an opinion. That is how it starts. Name one. A place of no use to anyone, where you would stay anyway.
""", "options": [
				{"say": "A wall that keeps the sun's warmth after dusk.", "tone": "share", "mark": "you_spot_wall", "reply": """
Kaede reaches for her brush.

Kaede: South-facing, then, and stone. How long does it hold? No. Do not make that objective. Tell me another day how long you stayed.
"""},
				{"say": "A gate to lean on, with a road to watch.", "tone": "share", "mark": "you_spot_gate", "reply": """
Kaede: A gate that is not being used as a gate. Good. That is exactly the category.

She draws it small, slightly open, and declines to say where the road goes.
"""},
				{"say": "The step outside a cook tent, before anyone's up.", "tone": "share", "mark": "you_spot_step", "reply": """
Kaede: A step again. We have a shared weakness.

Kaede: I shall mark it 'early'. The hour is part of the place; I learned that from the cat.
"""},
			]},
		],
		"closing_face": "amused", "closing": """
Kaede adds one small mark, then dates the corner.

Kaede: The cat may object to being represented without consent. I will amend the record if a complaint is submitted.

You: In writing?

Kaede: Paw marks would be admissible.

Her smile appears quickly and is gone only because she bends over the page again. When you leave, she does not cover it.
""",
		"summary": "Kaede shows you a private map of places she likes: a dry stair, a patch of afternoon light, and a cat whose presence is not guaranteed. She asks you for a useless place of your own and adds it. The map offers no travel intelligence or strategic bonus.",
		"memory": "Kaede showed you her map of pleasant and useless places, and you added one.",
	},
	"kaede_bad_mystery": {
		"title": "A Very Bad Mystery", "rank": "C", "requires_any": [], "setting": "archive_room",
		"parts": [
			{"face": "amused", "text": """
Kaede is reading a cheaply bound mystery with the concentration normally reserved for disputed covenants.

Kaede: The accusation is impossible. The seal is on the wrong side of the fold, and the witness described ink that had not yet been made.

[?kaede_corrected] Kaede: You may correct the author as freely as you corrected my stairs. He needs it more.

You: Shall we stop reading?

Kaede: Certainly not. The gardener has just acquired a second disguise.
""", "options": [
				{"say": "The gardener did it. In the second disguise.", "tone": "tease", "reply": """
Kaede: Too obvious. I accuse the cabinet. It has means, opportunity, and a documented history of being locked. Motive will emerge if the author has courage.
"""},
				{"say": "It was the cat. It's always the cat.", "tone": "tease", "mark": "kaede_accused_cat", "reply": """
Kaede: There is no cat in this book.

Kaede: Which is precisely what a competent cat would arrange. Entered. I shall need a motive by the end of the chapter, and it cannot be 'spite', which is assumed.
"""},
			]},
			{"face": "amused", "text": """
She has read the story before. A favorite childhood reader gave every suspect the same guilty whisper, including an elderly dog and one locked cabinet. Kaede and her cousins competed to produce theories unsupported by any evidence.

Kaede: I was excellent at being wrong. Deliberately wrong, I should clarify. Usually.
""", "options": [
				{"say": "Why read it again, if it's so bad?", "tone": "ask", "reply": """
Kaede: Because I know where it fails, so I can enjoy how confidently it approaches the failure. Also the dog is acquitted. I find that reassuring.
"""},
				{"say": "I've a worse book than that in my saddlebag.", "tone": "share", "reply": """
Kaede: Worse. You are certain.

Kaede: I shall want to see it. Not to borrow. To verify. A claim of that size requires an inspection of the binding at the very least.
"""},
			]},
			{"face": "amused", "text": """
She turns the page and makes an offended sound at a clue she clearly enjoys.

Kaede: Real evidence deserves care. Fictional evidence has volunteered to be mistreated for our amusement. I see no ethical conflict.
""", "options": [
				{"say": "Read me the next page.", "tone": "ask", "reply": """
Kaede gives the narrator an unnecessarily sinister voice, then stops to object to her own performance.

Kaede: No, that makes the actual culprit sound innocent. I must be less competent.
"""},
				{"say": "Does anyone know you read these?", "tone": "ask", "reply": """
Kaede: The binder who sells them, who has been sworn to nothing and will tell anyone who asks.

Kaede: And now you. I find I mind that less than I had planned to.
"""},
				{"say": "Deliberately wrong. Teach me.", "tone": "tease", "reply": """
Kaede: First, identify what the evidence supports. Then walk briskly in the other direction.

Kaede: The art is in the confidence. You must accuse the cabinet as though you had seen it holding the knife.
"""},
			]},
		],
		"closing_face": "amused", "closing": """
The chapter ends by revealing a hidden tunnel that could not fit beneath the building described on page two. Kaede closes the book on one finger.

Kaede: Outrageous. We will continue tomorrow.

You: We?

[?kaede_accused_cat] Kaede: You have accused a cat that does not appear in the text. You are now part of the inquiry. No expertise is required; in fact, it may be a disadvantage.

[?!kaede_accused_cat] Kaede: You have accused a man on the evidence. That will have to be trained out of you. You are now part of the inquiry.

She leaves the book at the absurd clue, visibly pleased to have someone with whom to guess badly.
""",
		"summary": "Kaede complains about an impossible forged letter in a favorite bad mystery, then refuses to stop reading. She enjoys making deliberately weak theories about fiction while keeping real evidence serious. You accuse an implausible suspect and are enrolled in the inquiry. No real clue or quest is involved.",
		"memory": "Joined Kaede in solving a very bad mystery as incorrectly as possible.",
	},
	"kaede_margin_name": {
		"title": "A Name in the Margin", "rank": "B", "requires_any": ["kaede_useless_map", "kaede_bad_mystery"], "setting": "archive_room",
		"parts": [
			{"face": "concerned", "text": """
A faded label has slipped from an old document box. The handwriting uses a name you do not recognize.

Kaede: My aunt wrote that. I was twelve and had just begun formal instruction. I demanded that everyone use my proper name.

You: Did they agree?

Kaede: For nearly an hour.
""", "options": [
				{"say": "What was the name?", "tone": "ask", "mark": "kaede_asked_name", "reply": """
Kaede closes her hand over the label. Not quickly; she is not hiding it. She is deciding.

Kaede: Not today. I should like it noted that you asked, and that I am glad you did. Those are separate entries.
"""},
				{"say": "You needn't tell me what it says.", "tone": "quiet", "mark": "kaede_left_name", "reply": """
Kaede folds the label into her palm.

Kaede: Thank you. Curiosity can be respectful without being satisfied. I would like to remember that from both sides.
"""},
			]},
			{"face": "amused", "text": """
The nickname came from a childhood misunderstanding and became affectionate through repetition. Kaede had corrected her aunt in front of visiting scholars. Her aunt bowed gravely, used the proper name all afternoon, then labeled every sweet cake with the forbidden one.

Kaede: I was furious. I ate the cakes to destroy the evidence. This was not a strong archival principle.
""", "options": [
				{"say": "What was your aunt like?", "tone": "ask", "reply": """
Kaede: Patient until patience became boring, then inventive. She corrected my citations and cheated at guessing games. I found this inconsistent. She considered it a complete personality.
"""},
				{"say": "I was called something, once. I stopped answering to it.", "tone": "share", "face": "thoughtful", "reply": """
Kaede listens without asking for the name.

Kaede: Then you know the strange moment when a familiar sound no longer fits, and the later moment when perhaps it does again.
"""},
			]},
			{"face": "thoughtful", "text": """
She turns the label over. Her amusement softens.

Kaede: I thought affection made me look less serious. She knew I was serious. She also knew I was twelve. Both facts survived the afternoon.

Kaede: She died the winter before last. Nobody has used the name since. I notice the silence where it was, which is not something I expected to be able to catalog.
""", "options": [
				{"say": "Do you miss hearing it?", "tone": "ask", "reply": """
Kaede: I miss being someone it could be said to. That is not the same, and I have not found the right heading for it.

Kaede: The name itself is only a sound. It was the license to use it that was rare.
"""},
				{"say": "She'd be glad it started a conversation.", "tone": "comfort", "face": "amused", "reply": """
Kaede: She would be pleased that the label caused a discussion. She believed all properly stored objects should occasionally make trouble.
"""},
				{"say": "When you want it said again, I'd be honored.", "tone": "heart", "when": "romantic", "face": "warm",
					"memory": "Spent an evening with Kaede and an old label, and offered to be the one who says her private name, when she chooses.", "reply": """
Kaede is very still, in the way she is when a document turns out to be older than its catalog entry.

Kaede: That is a significant offer. I am not declining it. I am filing it where I can find it.
"""},
				{"say": "If you ever want it heard, I'm a safe archive.", "tone": "warm", "when": "friend", "face": "amused", "reply": """
Kaede: You are a terrible archive. You forget dates and you fold corners.

Kaede: You are, however, safe. I have noted the distinction.
"""},
			]},
		],
		"closing_face": "thoughtful", "closing": """
Kaede returns the label to the box rather than the official catalog.

[?kaede_bad_mystery] Kaede: If this were our mystery, the label would be a clue and my aunt would be the cabinet. I am glad it is not our mystery.

Kaede: I may tell you another day. That is not a test. I dislike tests whose rules are concealed from the person taking them.

You: Then another day is enough.

She nods, relieved that the boundary has not turned the evening cold.
""",
		"summary": "Kaede finds a label bearing a childhood nickname she once forbade. She remembers the aunt who teased and respected her in equal measure, and who died the winter before last. The name stays private for now; respecting that completes the memory.",
		"memory": "Spent an evening with Kaede and an old label whose private name remained her choice.",
	},
	"kaede_missing_street": {
		"title": "The Missing Street", "rank": "B", "requires_any": ["kaede_margin_name"], "setting": "archive_room",
		"parts": [
			{"face": "thoughtful", "text": """
Kaede has redrawn the same corner three times. On one page a bench stands beneath a tree. On another it faces the road. The newest sketch has no bench at all.

Kaede: It moved. Again.

[?kaede_asked_name] Kaede: Before you ask: no, the bench does not have a private name. I saw your face. You were going to ask.

[?kaede_left_name] Kaede: You are allowed to ask about this one. It is only a bench.
""", "options": [
				{"say": "Give me the cord. We'll measure it properly.", "tone": "help", "reply": """
You hold one end of a knotted cord against the wall while she paces out the corner in ink. The numbers agree with all three drawings and explain none of them.

Kaede: The measurements are sound. The street is simply not cooperating with them.
"""},
				{"say": "Perhaps it prefers the shade.", "tone": "tease", "face": "amused", "reply": """
Kaede: So do I. That is the troublesome part; I approve of the change.
"""},
			]},
			{"face": "amused", "text": """
Her first map of home included a shortcut through a neighbor's gate. The route existed only when the neighbor remembered to leave it open, which Kaede's careful scale could not predict. She kept correcting the map until her mother wrote 'on Tuesdays, perhaps' beside the line.

Kaede: I considered that vandalism. It was also the most accurate annotation.

Kaede: You travel more than I do. There must be a place that is different each time you return to it. I should like a second example before I draw a conclusion.
""", "options": [
				{"say": "A ford I use. Never the same river twice.", "tone": "share", "mark": "you_change_ford", "face": "thoughtful", "reply": """
Kaede: Then every crossing is a first crossing, and the map is a record of one afternoon's luck.

Kaede: How do you find it again? No. I see. You do not find it; you find where it was, and ask the water.
"""},
				{"say": "Our camp. Same tents, new ground every night.", "tone": "share", "mark": "you_change_camp", "face": "thoughtful", "reply": """
Kaede: A place that keeps its plan and changes its location. I have only ever studied the reverse.

Kaede: Then you can walk to your own tent in the dark anywhere in the world. That is either a map or its opposite. I shall need to think.
"""},
				{"say": "The village I'm from. Smaller each time.", "tone": "share", "mark": "you_change_home", "face": "thoughtful", "reply": """
She does not correct you, though both of you know the measurements have not changed.

Kaede: Then the surveyor is the variable. I had not allowed for that. I am going to have to, I think, in several places.
"""},
			]},
			{"face": "thoughtful", "text": """
The present street keeps changing: a stall closes, a tree is pruned, the uncertain cat selects a different stair. Kaede has been treating each difference as a defect in the previous page rather than evidence of another day.

She lays the three maps side by side.
""", "options": [
				{"say": "Date each version and keep them all.", "tone": "help", "reply": """
Kaede writes today's date beneath the missing bench.

Kaede: Then none of them must defeat the others. They can each be correct for an afternoon. That is an unexpectedly generous system.
"""},
				{"say": "Tell me about the old shortcut.", "tone": "ask", "face": "amused", "reply": """
Kaede: It passed a kitchen window. On Tuesdays the neighbor baked pears, and the shortcut became very slow. I omitted that because appetite was not part of the scale.
"""},
				{"say": "Draw today's with us on the bench. Wherever it is.", "tone": "heart", "when": "romantic", "face": "warm",
					"memory": "Watched Kaede turn a changing street into several true afternoons, and drawn into one of them beside her.", "reply": """
Kaede: The bench is not in evidence today.

She draws it anyway, where the shade is, with two small marks on it that are not to scale and not labeled.

Kaede: A conjecture. I shall date it. I should like it to have been true on at least one afternoon.
"""},
				{"say": "Draw today's and I'll witness it.", "tone": "warm", "when": "friend", "face": "amused", "reply": """
Kaede: A witnessed map of nothing in particular. Yes.

She draws the corner as it stands, hands you the brush, and shows you where a witness signs. Your mark is crooked. She dates it without comment, which is a kindness.
"""},
			]},
		],
		"closing_face": "thoughtful", "closing": """
The moving bench becomes a sequence rather than an error.

Kaede: Here it faced the sun. Here someone wanted to watch the road. Here it has gone somewhere outside my evidence.

You: Will you look for it?

Kaede: Tomorrow. Today I know where it was not.

She marks the patch of shade she likes, and allows that fact to remain in the first person.
""",
		"summary": "Kaede cannot finish a private street map because the bench, the stalls and the cat keep moving. She remembers a childhood shortcut that existed only when a neighbor's gate was open, and asks you for a place that changes each time you return. Each drawing becomes a record of one afternoon instead of a failed final version.",
		"memory": "Watched Kaede turn a changing street from an error into several true afternoons.",
	},
	"kaede_kept_page": {
		"title": "The Page She Kept", "rank": "A", "requires_any": ["kaede_missing_street"], "setting": "archive_room",
		"parts": [
			{"face": "concerned", "text": """
Kaede places two accounts of the same family gathering on the desk. The first is impeccable: arrivals, witnesses, meal, departure. The second begins with a sentence in a younger, less certain hand.

Kaede: My relatives met after a long quarrel. Everyone had come to hear an apology. My official summary says they ate fish.

[?you_change_home] Kaede: You told me your village is smaller each time. I have been thinking about surveyors since. This is about one.
""", "options": [
				{"say": "May I read the other one?", "tone": "ask", "mark": "kaede_asked_page", "reply": """
Kaede: You may read the first line. I am supervising.

It says: I was glad they stayed until evening. The hand is round, and presses too hard.
"""},
				{"say": "I won't read it. Tell me what you'd like me to know.", "tone": "quiet", "mark": "kaede_page_closed", "reply": """
Kaede: That is the correct procedure, and almost nobody follows it.

Kaede: It says I was glad they stayed until evening. I can say it aloud now. It took some years.
"""},
			]},
			{"face": "thoughtful", "text": """
You: Was the fish important?

Kaede: It was verifiable. I omitted the apology because I could not decide whether it had succeeded.

Her teacher asked who the account was for. Kaede answered: anyone who needed the facts. The teacher gave the page back and asked what Kaede herself might need to remember.
""", "options": [
				{"say": "Your teacher asked a useful question.", "tone": "comfort", "reply": """
Kaede: Infuriatingly useful. I wanted a rule. She gave me another reader to consider, and that reader was myself. I could not cite her away.
"""},
				{"say": "What else did the second account say?", "tone": "ask", "reply": """
Kaede: That my uncle's apology was clumsy, my grandmother accepted it anyway, and I wanted them to try again. The last part took longest to write. It could not be attributed to a witness.
"""},
			]},
			{"face": "concerned", "text": """
Kaede: For years I thought that sentence was less true because it belonged only to me.

She takes a third sheet from under the other two. It is recent; the ink is this season's.

Kaede: This is the archive's visitor record. Every caller, the hour, the business. Your name is in it eleven times, and under 'business' I have written the truth, which is 'none'. I do not know which kind of page that makes it.
""", "options": [
				{"say": "A record can have a purpose without holding everything.", "tone": "comfort", "face": "thoughtful", "reply": """
Kaede: Yes. The official page is not false. It is simply unable to carry what the other page was made for. Precision includes knowing the limits of the form.
"""},
				{"say": "Leave 'none' in the official one. It's accurate.", "tone": "tease", "face": "amused", "reply": """
Kaede: It is accurate. It will also be read by the next archivist, who will conclude that someone visited this room eleven times for no reason.

Kaede: Which is exactly what occurred. Very well. Let her wonder. A record should occasionally make trouble.
"""},
				{"say": "Keep a private page too. Write why you were glad.", "tone": "heart", "when": "romantic", "face": "warm",
					"memory": "Read the page where Kaede let her own experience into the record, and the new one she wrote about you.", "reply": """
Kaede draws a clean sheet toward her and writes for some time, shielding nothing. Then she turns it for you to read. It says: glad, each time; more than the time before; the trend is consistent.

Kaede: I have signed it. That is enough authentication.
"""},
				{"say": "Put 'friendship'. It's a kind of business.", "tone": "warm", "when": "friend", "face": "warm", "reply": """
Kaede: It is not a recognized category.

She writes it anyway, in the margin, in the small upright hand she uses for corrections she is sure of.

Kaede: It is now. I am the archivist. I recognize it.
"""},
			]},
		],
		"closing_face": "thoughtful", "closing": """
Kaede aligns the pages, then deliberately leaves the personal one on top.

Kaede: I still would not place this in a public archive. Feeling does not become evidence because it is sincere. But it does become part of a life. I was there. I was glad.

She signs the old page beneath the younger handwriting, not to certify it for anyone else but to claim the account as hers.

The records return to the same box, serving different truths without being forced into one.
""",
		"summary": "Kaede shows you an official summary of a family reconciliation and the private page on which she admitted she was glad they stayed. Her teacher helped her see that records have different readers. Then she shows you the archive's visitor record, where your name appears eleven times with no business given.",
		"memory": "Read the page where Kaede allowed her own experience into the record.",
	},
	"kaede_room_on_map": {
		"title": "Room on the Map", "rank": "A", "requires_any": ["kaede_kept_page"], "coda": true, "setting": "archive_room",
		"parts": [
			{"face": "warm", "text": """
A fresh personal map lies between two cups. Kaede has drawn the room accurately except for one broad empty space.

Kaede: I left this unfinished on purpose. I checked twice.

[?you_spot_wall] Kaede: Your warm wall is on the old map. This is a different question: not where you would stay alone.

[?you_spot_gate] Kaede: Your gate is on the old map, still slightly open. This is a different question: not where you would stay alone.

[?you_spot_step] Kaede: Your early step is on the old map. This is a different question: not where you would stay alone.
""", "options": [
				{"say": "What belongs there?", "tone": "ask", "reply": """
Kaede: Your choice, if you want one. A sunny place, a quiet corner, somewhere to watch people pass. This map records where we would remain, not what we own.
"""},
				{"say": "You've left the cat off.", "tone": "tease", "face": "amused", "reply": """
Kaede: The cat is on the back. It declined to be on the front.

Kaede: The blank is for you. A sunny place, a quiet corner, somewhere to watch people pass. This map records where we would remain, not what we own.
"""},
			]},
			{"face": "warm", "text": """
She offers the brush handle-first. The gesture is careful but not ceremonial.

Kaede: I used to believe including another person's preference would make the map less exact. That was convenient. It meant I never had to ask, and never had to risk hearing that they would sit elsewhere.

[?kaede_bad_mystery] The impossible mystery waits beside the map, a ribbon at the hidden tunnel, for another deliberately poor theory.

Kaede: You may also choose nothing today. An honest blank is still part of the page.
""", "options": [
				{"say": "Mark the place beside the window.", "tone": "share", "reply": """
Kaede marks the window seat and adds the hour when sunlight reaches it.

Kaede: We may need to move in summer. I find I am comfortable allowing for that revision.
"""},
				{"say": "The quiet corner near your desk.", "tone": "share", "reply": """
Kaede draws two small cushions near the desk, then pretends to measure their distance.

Kaede: This is not necessary for scale. I wanted them to look as though conversation remained possible.
"""},
				{"say": "Leave room to watch people pass.", "tone": "share", "reply": """
Kaede places the mark near the open lattice.

Kaede: Good. A map should include somewhere the world can interrupt it. We need not identify everyone who walks by.
"""},
			]},
			{"face": "warm", "text": """
Kaede adds her own preferred place after yours. The two marks do not claim the room or promise that either of you will always be there. They simply answer the question asked tonight.

[?you_change_ford] Kaede: Like your ford. Correct for this crossing.

[?you_change_camp] Kaede: Like your camp. The plan holds; the ground may change.

[?you_change_home] Kaede: And if it looks smaller next time, we shall know which of us to measure.

Kaede: It is less balanced now.
""", "options": [
				{"say": "Does that trouble you?", "tone": "ask", "reply": """
She studies the page, then smiles.

Kaede: I think I should like it. Balance was easier when nothing had been chosen. This is more useful to me.
"""},
				{"say": "Unbalanced suits a map of preferences.", "tone": "tease", "face": "amused", "reply": """
Kaede: A preference is by definition a departure from even weight. Yes.

Kaede: I am going to stop apologizing to the page. It has never once complained.
"""},
				{"say": "Draw them closer. I'd sit nearer than that.", "tone": "heart", "when": "romantic",
					"memory": "Added a place beside Kaede's on a map that belongs to neither of you, and asked her to draw them closer.", "reply": """
Kaede lets her hand rest against yours beside the two marks, then moves her own mark the width of a brush hair.

Kaede: Corrected. The earlier distance was an error of caution. I shall note the revision, and not the reason.
"""},
				{"say": "Good. It looks like two people now.", "tone": "warm", "when": "friend", "reply": """
Kaede leaves both marks close, pleased by the company of a trusted friend.

Kaede: It does. Before, it looked like a room. I had not seen the difference until there was one.
"""},
			]},
		],
		"closing_face": "warm", "closing": """
[?kaede_useless_map] Kaede adds a tiny uncertain cat at the edge, preserving its right not to attend.

She leaves another small blank at the edge and labels it only with tomorrow's date: room for the map to change without becoming wrong.
""",
		"summary": "Kaede invites you to add one ordinary preferred place to a new personal map, and adds her own beside it, leaving room for revision. In romance or friendship, the scene reflects chosen familiarity without assigning a home, claiming property or making a new commitment.",
		"memory": "Added an ordinary place beside Kaede's to a map that belongs to neither of you.",
	},
	"kaede_preference_stated": {
		"title": "A Preference, Stated", "rank": "S", "requires_any": ["kaede_room_on_map"], "coda": true, "setting": "archive_room",
		"parts": [
			{"face": "thoughtful", "text": """
Kaede has two columns ruled on a sheet. One is headed 'Observed'. It is full. The other is headed 'Preferred', and it has one entry, crossed out.

Kaede: I have been attempting an inventory. The first column took an evening. The second has taken nine days.

[?kaede_asked_page] Kaede: You asked to read my private page once. This is the same page, grown up. You may look.

[?kaede_page_closed] Kaede: You once declined to read my private page until I asked. I am asking. Look.
""", "options": [
				{"say": "What did you cross out?", "tone": "ask", "reply": """
Kaede: 'Quiet.' It was true, and it was a hiding place. Half of what I call quiet is only nobody asking me anything.

Kaede: I am trying to list what I would choose if someone did ask.
"""},
				{"say": "Nine days. For one column.", "tone": "tease", "face": "amused", "reply": """
Kaede: The first column only requires eyes. The second requires a position.

Kaede: I crossed out 'quiet'. It was true, and it was a hiding place.
"""},
			]},
			{"face": "thoughtful", "text": """
Kaede: I should like a model. You must have one: a preference you hold and have never said aloud, because nobody asked, or because it seemed too small to state.
""", "options": [
				{"say": "I'd rather ride at the back of the column. It's quiet there.", "tone": "share", "mark": "you_pref_back", "reply": """
Kaede: A captain who prefers the rear, and rides at the front regardless.

Kaede: So a preference can be held for years without being acted on, and remain true. That is useful. That is the piece I was missing.
"""},
				{"say": "Rain on canvas. I'd take it over a fine day.", "tone": "share", "mark": "you_pref_rain", "reply": """
Kaede: Against all practical interest. Wet rope, slow roads, cold supper. And preferred.

Kaede: Then a preference need not be defensible. I have been trying to defend mine before writing them. That is why the column is empty.
"""},
				{"say": "Plain bread, warm. Over any feast I've sat through.", "tone": "share", "mark": "you_pref_bread", "reply": """
Kaede: Stated without apology to the feast.

Kaede: I notice you did not explain it. I would have appended three reasons and a precedent. Apparently it stands without them.
"""},
			]},
			{"face": "warm", "text": """
She takes up the brush. She does not rule a line first, or draft it on the blotter, or look at the door.

[?romantic] She writes one word in the second column, and turns the sheet toward you. It is your name.

[?friend] She writes in the second column: these afternoons. Then, after a moment: continued.

Kaede: Stated. No precedent. No witness clause. I find my hand is not entirely steady, which I am recording as a detail and not as a doubt.
""", "options": [
				{"say": "Read it aloud. A preference should be heard.", "tone": "ask", "reply": """
Kaede reads it aloud. Her voice is level, and exact, and slightly louder than the room requires.

Kaede: It is the same in the air as on the page. I had worried there would be a discrepancy.
"""},
				{"say": "The column looks better with something in it.", "tone": "tease", "face": "amused", "reply": """
Kaede: It looks unbalanced. One entry against forty.

Kaede: I have decided not to mind. The forty are what I saw. The one is what I meant.
"""},
				{"say": "Rule me a column. My entry is your name.", "tone": "heart", "when": "romantic",
					"memory": "Kaede asked for a preference you had never said aloud, then wrote down her own: your name. You answered with hers.", "reply": """
Kaede rules a third column, heads it with your name, and waits with the brush. You say hers. She writes it down.

Kaede: Reciprocal, and independently stated. That is as close to proof as this kind of record allows. I am keeping this page. Not in the box. On my person.
"""},
				{"say": "Enter it twice. Once for me.", "tone": "warm", "when": "friend", "face": "amused", "reply": """
Kaede writes 'continued' a second time, beneath the first, and initials it on your behalf with a small crooked mark that is plainly meant to be your hand.

Kaede: A forgery. In my own archive. You are a corrupting influence, and I have preferred it for some time.
"""},
			]},
		],
		"closing_face": "warm", "closing": """
She does not blot the entry. She lets it dry in the air, where anyone coming in would see it.

Kaede: I believed stating a preference would make me a worse witness. It has not. I see the room exactly as before. I only know now where in it I would rather stand.

She pins the sheet above her desk, between a tide table and a list of disputed boundaries, as one more thing that is the case.
""",
		"summary": "Kaede has been trying to list her own preferences and has managed one entry in nine days. She asks you for a preference you have never said aloud, and you give one. Then she writes hers down, without a precedent or a witness clause.",
		"memory": "Kaede asked for a preference you had never said aloud, and then wrote down her own.",
	},
	"kaede_name_used": {
		"title": "The Name, Used", "rank": "S", "requires_any": ["kaede_preference_stated"], "coda": true, "setting": "archive_room",
		"parts": [
			{"face": "warm", "text": """
The old document box is on the desk with its lid off. Kaede has the faded label in front of her, face up, and is sitting very straight.

[?kaede_asked_name] Kaede: You asked me once what this said. I told you: not today. I have reviewed the entry. Today is a different day.

[?kaede_left_name] Kaede: You told me once that I need not say what this says. I have thought about that more than about most treaties. I should like to tell you now, because I was not asked.

[?!kaede_asked_name,!kaede_left_name] Kaede: I told you once that I might tell you another day what this says. I have checked the calendar. It is another day.
""", "options": [
				{"say": "I'm listening.", "tone": "quiet", "reply": """
Kaede: I know. You do it visibly. It is one of the first things I recorded about you.
"""},
				{"say": "Shall I close the door?", "tone": "ask", "reply": """
Kaede: Leave it. I am not hiding it. I am only choosing who hears it first.
"""},
			]},
			{"face": "warm", "text": """
Kaede: Suzume. Sparrow. I was four, and I announced to a room of scholars that I would be an archivist, and it came out as a chirp. My aunt said the sparrow had spoken. It lasted eight years, and then I forbade it.

She says it without ceremony, in the voice she uses for dates.

Kaede: You may use it. Once, tonight. After that we shall see what the record supports.
""", "options": [
				{"say": "Suzume.", "tone": "quiet", "reply": """
Kaede closes her eyes for the length of the word.

Kaede: Yes. That is how it sounded. Not the same voice. The same license.
"""},
				{"say": "Sparrow. It suits an archivist. Small, exact, everywhere.", "tone": "tease", "face": "amused", "reply": """
Kaede: She said: small, loud, and impossible to keep out of the grain store.

Kaede: Yours is kinder. I shall keep both definitions and cross-reference them.
"""},
				{"say": "Suzume. I'd like to be the one who says it.", "tone": "heart", "when": "romantic",
					"memory": "Kaede told you the name her aunt gave her, and gave the saying of it into your keeping.", "reply": """
Kaede: Then say it when nobody else is in the room, and not often, so that it does not wear smooth.

She puts the label into your hand and closes your fingers over it.

Kaede: Custody transferred. I have never done that with anything I could not replace.
"""},
				{"say": "Suzume. It's safe with me.", "tone": "warm", "when": "friend", "reply": """
Kaede: I know it is. I checked, over several seasons, without telling you I was checking.

Kaede: Use it when I am being insufferable about a citation. She did. It was extremely effective.
"""},
			]},
		],
		"closing_face": "warm", "closing": """
Something moves on the stair outside. A compact gray shape arrives on the sill, sits, and looks at the room as though it had called the meeting.

[?kaede_accused_cat] Kaede: The cat. In attendance. You accused it once of a crime it could not have committed. It has clearly come to hear the retraction.

[?!kaede_accused_cat] Kaede: The cat. In attendance. I have never once been able to guarantee that. I am recording the date.

[?you_pref_back] Kaede: It has taken the place at the back, you will notice, where it is quiet. I know someone with the same preference.

[?you_pref_rain] Kaede: It will rain tonight; the cat only comes in ahead of rain. You will like that. I have it written down.

[?you_pref_bread] Kaede: It wants the bread. Not the fish. The bread. I know someone with the same preference.

She puts the lid back on the box, and does not lock it.
""",
		"summary": "Kaede takes out the old label again and tells you the childhood name her aunt gave her, the one she forbade at twelve and nobody has used since her aunt died. She lets you say it. The cat, for once, attends.",
		"memory": "Kaede told you the name her aunt gave her, and let you use it.",
	},
}
