## What letters say. Each kind of letter (its template key, as SocialSim.add_letter is
## given it) has a version for each candidate, worded for a courtship ("courting") or a
## friendship ("friend"), and a few short replies you can send back. Pure data and
## rendering; the social sim stores the rendered letter so its words never change.
extends RefCounted

const WorldData = preload("res://scripts/world/world_data.gd")

## A sender's wax seal: the letter pressed into it and its colour.
const SEALS := {
	"edda": {"mark": "C", "color": "b8352a"},
	"farid": {"mark": "H", "color": "1f7a6e"},
	"kaede": {"mark": "K", "color": "2c4fae"},
}

## {place} is where the letter was written, {old} the place the sender had to leave.
const LETTERS := {
	"ch2_invitation": {
		"edda": {
			"courting": {
				"subject": "A chair by the fire",
				"salute": "Captain,",
				"body": [
					"The ledgers balance tonight for the first time since the thaw, and I find I have no one to tell. Thornwall's granary has its roof again. Kettlebrook sends its thanks in turnips, which I am assured is a compliment.",
					"If your road bends toward {place}, the hall keeps a chair by the fire. I would like to hear what you saw on the border, and I would like, I think, simply to see you.",
				],
				"sign": "Edda", "sign_title": "of House Caldmoor",
				"ps": "My cousin asks what you cost. I told him: more than he has.",
			},
			"friend": {
				"subject": "The border villages",
				"salute": "Captain,",
				"body": [
					"You offered help, and I have been a steward too long to let an offer go unanswered. Thornwall's granary has its roof again; Kettlebrook's well does not, and its headman has stopped pretending otherwise.",
					"Come to {place} when the road allows. I will have the tallies laid out and the worst of it marked in red, and you may tell me plainly which of it a free company can mend.",
				],
				"sign": "Edda", "sign_title": "Steward of the household",
				"ps": "",
			},
		},
		"farid": {
			"courting": {
				"subject": "A letter with no business in it",
				"salute": "Captain,",
				"body": [
					"I write a great many letters. Every one of them carries a request, a price, or a warning, usually all three, folded so that nobody can tell which is which.",
					"This one carries none of them. I should like you to come to {place}. There is a courtyard here where the caravans water at dusk, and I have never once had a reason to sit in it. I would like you to be the reason.",
				],
				"sign": "Farah", "sign_title": "Envoy of Qasr Hamra",
				"ps": "If anyone asks, this was about tariffs.",
			},
			"friend": {
				"subject": "The address people use",
				"salute": "To the captain, with the envoy's regards,",
				"body": [
					"You were kind enough to offer your company's help, and I am practical enough to accept it. A caravan road east of {place} has gone quiet, and quiet roads are the expensive kind.",
					"Call on me when you pass this way. I will have coffee, a map, and the names of the people who would rather that road stayed closed.",
				],
				"sign": "Farah", "sign_title": "Envoy of Qasr Hamra",
				"ps": "",
			},
		},
		"kaede": {
			"courting": {
				"subject": "On the matter of a map",
				"salute": "Captain,",
				"body": [
					"I have found a map of places no one needs: a ford that silted up a century ago, a shrine moved twice, a road that ends at a field. I have been adding to it for years and have never shown it to anyone.",
					"If you come to {place}, I will show it to you. I cannot promise it will be useful. I can promise that you would be the first, and that I have been thinking about the asking for longer than is sensible.",
				],
				"sign": "Kaede", "sign_title": "Archivist of Kitayama",
				"ps": "",
			},
			"friend": {
				"subject": "A record that needs witnesses",
				"salute": "To the captain of the free company,",
				"body": [
					"The covenant I spoke of has two claimants and one copy, and the copy disagrees with itself. Such things are settled by witnesses, and I need one who belongs to neither clan.",
					"Come to {place} when you can. The work is dull and the tea is worse, but the feud it prevents is neither.",
				],
				"sign": "Kaede", "sign_title": "Archivist of Kitayama",
				"ps": "",
			},
		},
	},
	"ch3_invitation": {
		"edda": {
			"courting": {
				"subject": "The horn, and the villages",
				"salute": "Captain,",
				"body": [
					"The muster horn has been promised for the new moon, and every man in the valley has found an excellent reason to be elsewhere. The elders count riders. I count the houses those riders leave behind.",
					"I would not ask this of you by letter, so I won't. But if you came to {place}, I would ask it to your face, and then I would feed you, which is more than the elders offer.",
				],
				"sign": "Edda",
				"sign_title": "of House Caldmoor",
				"ps": "The chair is still by the fire. The cat has claimed it. Negotiations continue.",
			},
			"friend": {
				"subject": "A muster, and no one to hold the villages",
				"salute": "Captain,",
				"body": [
					"The muster horn has been promised for the new moon. The elders count riders; I count the houses the riders leave behind, and the sum does not please me.",
					"Come to {place} if you can. There is work for a company that keeps its word, and I will set out plainly what it is and what it pays.",
				],
				"sign": "Edda",
				"sign_title": "Steward of the household",
				"ps": "",
			},
		},
		"farid": {
			"courting": {
				"subject": "A quarrel with wagons behind it",
				"salute": "Captain,",
				"body": [
					"Two houses have stopped sharing escorts over an insult at a wedding, and forty wagons of grain are now learning patience at the crossing. I have written to both. Both replied with great courtesy and no escorts.",
					"I am out of letters. I would like to try a person instead. Come to {place}; I will explain over coffee what the grain cannot wait for.",
				],
				"sign": "Farah",
				"sign_title": "Envoy of Qasr Hamra",
				"ps": "This letter has business in it. I apologise. The next one won't.",
			},
			"friend": {
				"subject": "Grain at the crossing",
				"salute": "To the captain, with the envoy's regards,",
				"body": [
					"Two allied houses have stopped sharing escorts over an insult, and relief wagons wait behind their pride at the crossing. Courtesy has failed; I have tried it three times.",
					"A company that belongs to neither house could end this in a week. Come to {place} and I will show you the crossing and the terms.",
				],
				"sign": "Farah",
				"sign_title": "Envoy of Qasr Hamra",
				"ps": "",
			},
		},
		"kaede": {
			"courting": {
				"subject": "Two copies and a ford",
				"salute": "Captain,",
				"body": [
					"The clans have produced their copies of the covenant, and the copies disagree in exactly the places that matter. Each side has sent a polite young man to tell me the other is lying. They are both correct.",
					"I need witnesses, and a ford held long enough for witnesses to be heard. Come to {place}. I will show you the two copies and let you be annoyed by them yourself.",
				],
				"sign": "Kaede",
				"sign_title": "Archivist of Kitayama",
				"ps": "I have added the ford to the private map. Marked 'contested; pleasant in the mornings'.",
			},
			"friend": {
				"subject": "The covenant, in two versions",
				"salute": "To the captain of the free company,",
				"body": [
					"The clans' copies of the old covenant disagree exactly where it matters, and each side has sent someone to explain that the other is lying. Both explanations are accurate.",
					"I need a witness neither clan can claim, and a ford kept quiet while the records are compared. Come to {place} and I will show you both copies.",
				],
				"sign": "Kaede",
				"sign_title": "Archivist of Kitayama",
				"ps": "",
			},
		},
	},
	"ch4_invitation": {
		"edda": {
			"courting": {
				"subject": "Before the council sits",
				"salute": "Captain,",
				"body": [
					"The house head has called a council for the week's end, and I know already what he will say, because he has been saying it at supper. Riders east, the valley stripped, glory by the cartload.",
					"I don't ask you to take my side. I ask you to be at {place} when it's said, so that one person in that hall has seen what the villages look like after.",
				],
				"sign": "Edda",
				"sign_title": "of House Caldmoor",
				"ps": "I have rehearsed what I'll say to him. It gets shorter every time.",
			},
			"friend": {
				"subject": "The council at week's end",
				"salute": "Captain,",
				"body": [
					"The house head has called a council for the week's end. He wants the riders east and the valley stripped; I want a garrison, and I am one voice against a table of cousins.",
					"Your word carries weight in that hall now. Come to {place} and give it, whichever way you give it.",
				],
				"sign": "Edda",
				"sign_title": "Steward of the household",
				"ps": "",
			},
		},
		"farid": {
			"courting": {
				"subject": "My relatives have opinions",
				"salute": "Captain,",
				"body": [
					"The settlement is drafted and the road nearly open, and now my relatives have discovered the negotiation and wish to win it. They want terms the other house cannot sign without shame. I promised the merchants terms they could.",
					"Council sits when you reach {place}. I have never asked anyone to stand in a room for me. I am asking.",
				],
				"sign": "Farah",
				"sign_title": "Envoy of Qasr Hamra",
				"ps": "I tried to make this letter about tariffs. It refused.",
			},
			"friend": {
				"subject": "The council and the merchants",
				"salute": "To the captain, with the envoy's regards,",
				"body": [
					"The settlement is drafted, and my relatives have found it and wish to make it a triumph. The merchants were promised a peace they can live under, not a victory they must apologise for.",
					"You know the road and what it needs. Come to {place} before the council sits, and say what you saw.",
				],
				"sign": "Farah",
				"sign_title": "Envoy of Qasr Hamra",
				"ps": "",
			},
		},
		"kaede": {
			"courting": {
				"subject": "The brush",
				"salute": "Captain,",
				"body": [
					"The council has decided which version of the covenant is true, and has decided it before reading either. They have asked me to certify it. The brush is already on the table; they are only waiting for my hand.",
					"I promised both villages an honest comparison. I would like you in the room when I keep or break that promise. Come to {place}.",
				],
				"sign": "Kaede",
				"sign_title": "Archivist of Kitayama",
				"ps": "I have not decided what I will do. That is a lie. I have decided; I would like company.",
			},
			"friend": {
				"subject": "A certification I cannot give",
				"salute": "To the captain of the free company,",
				"body": [
					"The council wants the convenient version of the covenant certified, and has placed the brush before me. I promised both villages an honest comparison and have not yet been asked to break it aloud.",
					"Come to {place} before the council sits. A commander's account of the ford would be heard where an archivist's is not.",
				],
				"sign": "Kaede",
				"sign_title": "Archivist of Kitayama",
				"ps": "",
			},
		},
	},
	"ch5_invitation": {
		"edda": {
			"courting": {
				"subject": "What we choose",
				"salute": "Captain,",
				"body": [
					"The season has turned. The granary is roofed, the muster fed, the council survived. I find I have nothing urgent to write to you about, and I find that I am writing anyway.",
					"Come to {place} when the road allows. There is something I would like to ask you, and I would rather watch your face while I ask it.",
				],
				"sign": "Edda",
				"sign_title": "of House Caldmoor",
				"ps": "Don't bring the company. Bring yourself.",
			},
			"friend": {
				"subject": "A quiet season",
				"salute": "Captain,",
				"body": [
					"The season has turned, and for once the valley has nothing to ask of either of us. The granary is roofed, the muster fed, the council survived.",
					"Come to {place} when you can. I would like to talk about what we are to each other's houses, now that the urgent part is done.",
				],
				"sign": "Edda",
				"sign_title": "Steward of the household",
				"ps": "",
			},
		},
		"farid": {
			"courting": {
				"subject": "No business whatsoever",
				"salute": "Captain,",
				"body": [
					"The road is open. The wagons have gone through, the houses have exchanged stiff and correct letters, and no one has needed me to phrase anything for four days.",
					"I am writing to you with no business whatsoever, which I have never done before. Come to {place}. I have something to say that I would like to say badly, in person.",
				],
				"sign": "Farah",
				"sign_title": "Envoy of Qasr Hamra",
				"ps": "If anyone asks, this was about nothing.",
			},
			"friend": {
				"subject": "A road that stays open",
				"salute": "To the captain, with the envoy's regards,",
				"body": [
					"The road is open and, for once, staying that way. The houses write to each other now without my help, which is both the point and slightly wounding.",
					"Come to {place} when you pass. I would like to talk about what our houses owe each other, now that nobody owes me a reply.",
				],
				"sign": "Farah",
				"sign_title": "Envoy of Qasr Hamra",
				"ps": "",
			},
		},
		"kaede": {
			"courting": {
				"subject": "Room in the margin",
				"salute": "Captain,",
				"body": [
					"The covenant is signed with its uncertainties left visible, which the council dislikes and the villages do not. The archive is quiet. I have unrolled the private map twice this week for no reason I can record.",
					"Come to {place}. There is a blank space on it that I have been leaving open on purpose, and I would like to ask you about it.",
				],
				"sign": "Kaede",
				"sign_title": "Archivist of Kitayama",
				"ps": "The uncertain cat has attended three days running. I am choosing to take this as a sign.",
			},
			"friend": {
				"subject": "After the signing",
				"salute": "To the captain of the free company,",
				"body": [
					"The covenant is signed with its uncertainties left visible. The council dislikes this; the villages, who must live under it, do not. The archive is quiet for the first time in a season.",
					"Come to {place} when the road allows. I would like to set down, in the margin where such things go, what our houses are to each other.",
				],
				"sign": "Kaede",
				"sign_title": "Archivist of Kitayama",
				"ps": "",
			},
		},
	},
	"relocation": {
		"edda": {
			"courting": {
				"subject": "We left {old}",
				"salute": "Captain,",
				"body": [
					"{old} is lost. We went out by the river gate with the household's ledgers and as many of the village families as would come. I counted them twice on the road; the number did not improve.",
					"We are at {place} now. I am well, which I write first because you will ask it first. I would rather you heard the rest from me in person than from a herald.",
				],
				"sign": "Edda", "sign_title": "of House Caldmoor",
				"ps": "I kept the chair. It is a terrible chair. It came anyway.",
			},
			"friend": {
				"subject": "The household has moved",
				"salute": "Captain,",
				"body": [
					"{old} has fallen, and the household has removed to {place}. The villages are on their own for now, and I mean to change that as soon as I have a roof and a desk again.",
					"If your company is near, I would be glad of a steady pair of hands, and gladder of a friend's face.",
				],
				"sign": "Edda", "sign_title": "Steward of the household",
				"ps": "",
			},
		},
		"farid": {
			"courting": {
				"subject": "A change of address",
				"salute": "Captain,",
				"body": [
					"You will hear that {old} has changed hands, and you will hear it told several ways. Here is mine: I left with the treaty boxes, two clerks, and my good shoes, and I did not look back until the dust hid the walls.",
					"I am at {place}. Write to me here, or better, do not write at all and simply come.",
				],
				"sign": "Farah", "sign_title": "Envoy, for the present without a seat",
				"ps": "",
			},
			"friend": {
				"subject": "A change of address",
				"salute": "To the captain, with the envoy's regards,",
				"body": [
					"{old} has fallen and the envoy's office has moved to {place}. Correspondence will reach me here; caravans, I fear, will take longer to persuade.",
					"Should your company pass, my door is open and my maps are, for once, out of date. I could use a fresh pair of eyes on them.",
				],
				"sign": "Farah", "sign_title": "Envoy of Qasr Hamra",
				"ps": "",
			},
		},
		"kaede": {
			"courting": {
				"subject": "The archive moves",
				"salute": "Captain,",
				"body": [
					"{old} is lost to us, and with it the east wing of the archive. I carried out what I could hold: the covenant boxes, two lineages, and the map. Of course the map.",
					"I am lodged at {place} now, among people who think records are kindling. I find I am counting the days until a particular company passes this way.",
				],
				"sign": "Kaede", "sign_title": "Archivist, lately of {old}",
				"ps": "",
			},
			"friend": {
				"subject": "The archive moves",
				"salute": "To the captain of the free company,",
				"body": [
					"{old} is lost to us, and with it the east wing of the archive. I carried out what I could hold: the covenant boxes, two lineages, and a map that is no use to anyone but me.",
					"I am lodged at {place} now, among people who think records are kindling. If your company passes this way, I would be glad of a face that remembers what we were trying to keep.",
				],
				"sign": "Kaede", "sign_title": "Archivist, lately of {old}",
				"ps": "",
			},
		},
	},
	"wedding_ready": {
		"edda": {
			"courting": {
				"subject": "The hall is ready",
				"salute": "Captain,",
				"body": [
					"The hall at {place} is swept and the cook is weeping, which I am told is traditional. The cord is bought. The head of the house has found a speech somewhere and is threatening us with it.",
					"Come when the road allows. There is no hurry, and I will not pretend I am not counting the days.",
				],
				"sign": "Edda", "sign_title": "of House Caldmoor",
				"ps": "I have set a spare spoon. You know which one.",
			},
			"friend": {
				"subject": "The hall is ready",
				"salute": "Captain,",
				"body": [
					"The hall at {place} is swept and the cook is weeping, which I am told is traditional. The cord is bought. The head of the house has found a speech somewhere and is threatening us with it.",
					"Come when the road allows. There is no hurry, and I will not pretend I am not counting the days.",
				],
				"sign": "Edda", "sign_title": "of House Caldmoor",
				"ps": "I have set a spare spoon. You know which one.",
			},
		},
		"farid": {
			"courting": {
				"subject": "Everything is arranged",
				"salute": "Captain,",
				"body": [
					"Everything at {place} is arranged: the bread, the salt, the witnesses, and a contract I have rewritten nine times and will not touch again. Probably.",
					"Come when your road allows. I would rather you arrived late and whole than early and tired.",
				],
				"sign": "Farah", "sign_title": "Envoy of Qasr Hamra",
				"ps": "If anyone asks, this was about tariffs. It is not about tariffs.",
			},
			"friend": {
				"subject": "Everything is arranged",
				"salute": "Captain,",
				"body": [
					"Everything at {place} is arranged: the bread, the salt, the witnesses, and a contract I have rewritten nine times and will not touch again. Probably.",
					"Come when your road allows. I would rather you arrived late and whole than early and tired.",
				],
				"sign": "Farah", "sign_title": "Envoy of Qasr Hamra",
				"ps": "If anyone asks, this was about tariffs. It is not about tariffs.",
			},
		},
		"kaede": {
			"courting": {
				"subject": "The register is open",
				"salute": "Captain,",
				"body": [
					"The register at {place} is open to a clean page, the cups are washed, and I have practised writing your name until I am sick of the sight of it. I am not, actually.",
					"Come when you can. The page will wait; so will I.",
				],
				"sign": "Kaede", "sign_title": "Archivist of Kitayama",
				"ps": "",
			},
			"friend": {
				"subject": "The register is open",
				"salute": "Captain,",
				"body": [
					"The register at {place} is open to a clean page, the cups are washed, and I have practised writing your name until I am sick of the sight of it. I am not, actually.",
					"Come when you can. The page will wait; so will I.",
				],
				"sign": "Kaede", "sign_title": "Archivist of Kitayama",
				"ps": "",
			},
		},
	},
	"wedding_postponed": {
		"edda": {
			"courting": {
				"subject": "The flowers will keep",
				"salute": "Captain,",
				"body": [
					"{old} can't host us now; you will have heard why. I am well, and I am not giving up the cord, so you needn't ask.",
					"Come and see me at {place} and we'll choose somewhere else together. The flowers will keep. I will too.",
				],
				"sign": "Edda", "sign_title": "of House Caldmoor",
				"ps": "",
			},
			"friend": {
				"subject": "The flowers will keep",
				"salute": "Captain,",
				"body": [
					"{old} can't host us now; you will have heard why. I am well, and I am not giving up the cord, so you needn't ask.",
					"Come and see me at {place} and we'll choose somewhere else together. The flowers will keep. I will too.",
				],
				"sign": "Edda", "sign_title": "of House Caldmoor",
				"ps": "",
			},
		},
		"farid": {
			"courting": {
				"subject": "A change of venue",
				"salute": "Captain,",
				"body": [
					"{old} can't host a wedding now, and I refuse to be married under siege engines; the acoustics are terrible.",
					"Come to me at {place} and we'll choose another place. The contract needs only one line changed. I have already changed it.",
				],
				"sign": "Farah", "sign_title": "Envoy of Qasr Hamra",
				"ps": "",
			},
			"friend": {
				"subject": "A change of venue",
				"salute": "Captain,",
				"body": [
					"{old} can't host a wedding now, and I refuse to be married under siege engines; the acoustics are terrible.",
					"Come to me at {place} and we'll choose another place. The contract needs only one line changed. I have already changed it.",
				],
				"sign": "Farah", "sign_title": "Envoy of Qasr Hamra",
				"ps": "",
			},
		},
		"kaede": {
			"courting": {
				"subject": "A correction to the record",
				"salute": "Captain,",
				"body": [
					"{old} can't host us now. I have crossed out the place in the register, neatly, and left the rest as it was.",
					"Find me at {place} and we'll write in a new one. Nothing else needs correcting.",
				],
				"sign": "Kaede", "sign_title": "Archivist of Kitayama",
				"ps": "",
			},
			"friend": {
				"subject": "A correction to the record",
				"salute": "Captain,",
				"body": [
					"{old} can't host us now. I have crossed out the place in the register, neatly, and left the rest as it was.",
					"Find me at {place} and we'll write in a new one. Nothing else needs correcting.",
				],
				"sign": "Kaede", "sign_title": "Archivist of Kitayama",
				"ps": "",
			},
		},
	},
}

## Short answers to each kind of letter: a label for the button, how much it warms them
## (trust, once per letter), and the letter you send. {name} is who you write to.
const REPLIES := {
	"wedding_ready": [
		{"id": "coming", "label": "I'm on my way", "trust": 2,
			"courting": ["{name},", "Keep the spoon, the cup, the page, whatever it is. I'm on my way to {place}.", "Until then,"],
			"friend": ["{name},", "On my way to {place}.", "Until then,"]},
		{"id": "plain", "label": "A soldier's answer", "trust": 0,
			"courting": ["{name},", "Received. Coming.", "Captain,"],
			"friend": ["{name},", "Received. Coming.", "Captain,"]},
	],
	"wedding_postponed": [
		{"id": "comfort", "label": "We'll find another place", "trust": 2,
			"courting": ["{name},", "Then we'll find another place, and it will be better for the waiting. I'll come to {place} and we'll choose.", "Until I see you,"],
			"friend": ["{name},", "We'll find another place. I'll come to {place}.", "Until I see you,"]},
		{"id": "plain", "label": "A soldier's answer", "trust": 0,
			"courting": ["{name},", "Understood. I'll come and we'll choose again.", "Captain,"],
			"friend": ["{name},", "Understood.", "Captain,"]},
	],
	"ch2_invitation": [
		{"id": "coming", "label": "I'll come", "trust": 3,
			"courting": ["{name},", "Keep the chair. The company marches for {place} as soon as the horses are shod, and I will be at the front of it, which my sergeant says is bad form for a captain.", "Until then,"],
			"friend": ["{name},", "Count me in. Lay out the tallies; we march for {place} as soon as the horses are shod.", "Yours in good faith,"]},
		{"id": "soon", "label": "When the road allows", "trust": 1,
			"courting": ["{name},", "The road has opinions of its own this week, but it will bend toward {place} soon. I have not forgotten, and I will not.", "Until then,"],
			"friend": ["{name},", "The company is tied up for now. I'll come to {place} when the road allows, and I'll bring hands that can work.", "Yours in good faith,"]},
		{"id": "plain", "label": "A soldier's answer", "trust": 0,
			"courting": ["{name},", "Received. Will come.", "Captain,"],
			"friend": ["{name},", "Received. Will come when able.", "Captain,"]},
	],
	"relocation": [
		{"id": "comfort", "label": "I'm glad you're safe", "trust": 3,
			"courting": ["{name},", "I read your letter twice before I let myself believe the first line. I am sorry about {old}. I am not sorry you are at {place}, because it means you are somewhere.", "Until I see you,"],
			"friend": ["{name},", "I'm sorry about {old}, and glad beyond words you got out. Hold on at {place}; we'll think of what comes next together.", "Your friend,"]},
		{"id": "practical", "label": "Tell me what you need", "trust": 2,
			"courting": ["{name},", "Tell me what you need at {place}: men, silver, or a wagon for that terrible chair. The company is yours to ask.", "Until I see you,"],
			"friend": ["{name},", "Tell me what you need at {place}. Men, silver, wagons. The company is at your disposal.", "Your friend,"]},
		{"id": "plain", "label": "A soldier's answer", "trust": 0,
			"courting": ["{name},", "Heard about {old}. Glad you're out.", "Captain,"],
			"friend": ["{name},", "Heard about {old}. Glad you're out.", "Captain,"]},
	],
}

## How you sign your own letters.
const PLAYER_SIGN := "The Captain"
const PLAYER_SIGN_TITLE := "of the free company"

const ORDINALS := ["first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth",
	"eleventh", "twelfth", "thirteenth", "fourteenth", "fifteenth", "sixteenth", "seventeenth", "eighteenth",
	"nineteenth", "twentieth"]


## The letter `key` from `candidate_id`, written as a courtship or a friendship. `ctx`
## gives {place, old, hour}. Missing words fall back to a plain note.
static func render(key: String, candidate_id: String, courting: bool, ctx: Dictionary) -> Dictionary:
	var by_person: Dictionary = LETTERS.get(key, {})
	var versions: Dictionary = by_person.get(candidate_id, {})
	var t: Dictionary = versions.get("courting" if courting else "friend", versions.get("friend", {}))
	if t.is_empty():
		t = {"subject": "A letter", "salute": "Captain,",
			"body": ["I write from {place}, where you will find me if your road comes this way."],
			"sign": String(ctx.get("sender", "A friend")), "sign_title": "", "ps": ""}
	var body: Array = []
	for para in t["body"]:
		body.append(_fill(String(para), ctx))
	var seal: Dictionary = SEALS.get(candidate_id, {"mark": String(t["sign"]).left(1), "color": "8e1f17"})
	return {
		"subject": _fill(String(t["subject"]), ctx),
		"place_line": place_line(String(ctx.get("place", "")), float(ctx.get("hour", 0.0))),
		"salute": _fill(String(t["salute"]), ctx),
		"body": body,
		"sign": String(t["sign"]),
		"sign_title": _fill(String(t["sign_title"]), ctx),
		"ps": _fill(String(t.get("ps", "")), ctx),
		"seal": seal["mark"],
		"seal_color": seal["color"],
		"courting": courting,
	}


## The replies you could send to letter `key`. Every chapter's invitation takes the same
## three answers.
static func replies(key: String) -> Array:
	if not REPLIES.has(key) and key.ends_with("_invitation"):
		return REPLIES["ch2_invitation"]
	return REPLIES.get(key, [])


static func reply(key: String, reply_id: String) -> Dictionary:
	for r in replies(key):
		if r["id"] == reply_id:
			return r
	return {}


## Your reply as a letter: {salute, body, close, sign, sign_title}.
static func render_reply(key: String, reply_id: String, courting: bool, ctx: Dictionary) -> Dictionary:
	var r := reply(key, reply_id)
	if r.is_empty():
		return {}
	var lines: Array = r["courting" if courting else "friend"]
	return {
		"place_line": place_line(String(ctx.get("from", "")), float(ctx.get("hour", 0.0))),
		"salute": _fill(String(lines[0]), ctx),
		"body": [_fill(String(lines[1]), ctx)],
		"close": _fill(String(lines[2]), ctx),
		"sign": PLAYER_SIGN,
		"sign_title": PLAYER_SIGN_TITLE,
	}


## "Ravensford, the fourteenth day, by lamplight". On the road it's "On the road".
static func place_line(place: String, hour: float) -> String:
	var day := int(hour / 24.0) + 1
	var nth: String = ORDINALS[day - 1] if day <= ORDINALS.size() else "%d%s" % [day, _suffix(day)]
	var h := fmod(hour, 24.0)
	var when := ""
	if h < 5.0 or h >= 20.0:
		when = ", by lamplight"
	elif h < 9.0:
		when = ", at first light"
	elif h >= 17.0:
		when = ", toward evening"
	var where := place if place != "" else "On the road"
	return "%s, the %s day%s" % [where, nth, when]


static func _suffix(n: int) -> String:
	if n % 100 in [11, 12, 13]:
		return "th"
	match n % 10:
		1: return "st"
		2: return "nd"
		3: return "rd"
	return "th"


static func _fill(text: String, ctx: Dictionary) -> String:
	return text.replace("{place}", String(ctx.get("place", ""))).replace("{old}", String(ctx.get("old", "")))\
		.replace("{name}", String(ctx.get("name", "")))


## A settlement's name, or the id itself if it isn't one.
static func place_name(id: String) -> String:
	return String(WorldData.settlement(id)["name"]) if WorldData.SETTLEMENTS.has(id) else id
