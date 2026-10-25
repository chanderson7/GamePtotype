## The three cultures of the Glass Sea. Pure data: names, colors and the words each
## culture uses for its troops. Every culture fields the same four roles with the same
## stats for now; only what they're called and who leads them differs.
extends RefCounted

const VARDISH := "vardish"
const KHARZANI := "kharzani"
const RYUMON := "ryumon"
const ORDER := [VARDISH, KHARZANI, RYUMON]

const DATA := {
	VARDISH: {
		"realm": "Kingdom of Vardmark", "people": "Vardish", "faction": "vardmark",
		"color": Color("4a74d1"),
		"blurb": "A feudal kingdom of stone keeps and armored knights on the northwest shore of the Glass Sea.",
		"troops": {"infantry": "Men-at-arms", "spearmen": "Pikemen", "archers": "Crossbowmen", "cavalry": "Knights"},
		"company": {"infantry": "Shields", "spearmen": "Pikes", "archers": "Crossbows", "cavalry": "Lances"},
		"first": [
			"Brann", "Mira", "Aldric", "Tamsin", "Corwin", "Edda", "Rhys", "Isolde", "Garrick", "Wenna",
			"Osric", "Liane", "Hale", "Briony", "Torvald", "Ysolde", "Cade", "Maren", "Doran", "Elspeth",
			"Fenwick", "Gwen", "Ivo", "Jessa", "Kell", "Lorne", "Nell", "Piers", "Rowan", "Sabine",
			"Tobin", "Una", "Varo", "Wyn", "Ansel", "Brisa", "Cato", "Dagny", "Emrys", "Freya",
		],
		"origins": [
			"Ostmark", "the Fens", "Highcliff", "Ravensford", "the Marches", "Kettlebrook", "Saltmere",
			"Thornwall", "Duncroft", "the Ash Hills", "Westerby", "Holloway", "Graymoor", "Brackenridge",
		],
	},
	KHARZANI: {
		"realm": "Sultanate of Kharzan", "people": "Kharzani", "faction": "kharzan",
		"color": Color("d9962b"),
		"blurb": "A sultanate of walled cities and swift riders across the southern deserts.",
		"troops": {"infantry": "Askari", "spearmen": "Spear guard", "archers": "Bowmen", "cavalry": "Faris"},
		"company": {"infantry": "Blades", "spearmen": "Spears", "archers": "Bows", "cavalry": "Riders"},
		"first": [
			"Tariq", "Layla", "Rustam", "Nasrin", "Kamal", "Selim", "Yasmin", "Farid", "Leyla", "Orhan",
			"Zafer", "Dilara", "Karim", "Soraya", "Idris", "Mina", "Bahram", "Ayla", "Jalal", "Parisa",
		],
		"origins": [
			"Khalun", "Bir Sahra", "Nahrabad", "Qal'at Zeyra", "the Red Wastes", "Darvan", "Sefid Oasis",
			"Tamarisk Gate",
		],
	},
	RYUMON: {
		"realm": "Ryumon Shogunate", "people": "Ryumon", "faction": "ryumon",
		"color": Color("c9473d"),
		"blurb": "An island shogunate of disciplined archers and spearmen beyond the eastern strait.",
		"troops": {"infantry": "Samurai", "spearmen": "Ashigaru", "archers": "Yumi archers", "cavalry": "Mounted samurai"},
		"company": {"infantry": "Swords", "spearmen": "Yari", "archers": "Yumi", "cavalry": "Riders"},
		"first": [
			"Hideo", "Aiko", "Kenji", "Sayo", "Takeshi", "Haru", "Masaru", "Emi", "Ryota", "Chiyo",
			"Daisuke", "Kaede", "Isamu", "Natsu", "Yoshiro", "Mitsu", "Goro", "Rin", "Tadashi", "Ume",
		],
		"origins": [
			"Kurogane", "Hamazaki", "Shiraumi", "Takamine", "Kiri Valley", "Mizunaka", "Tsuyu Pass",
			"the Ash Coast",
		],
	},
}


static func has(culture: String) -> bool:
	return DATA.has(culture)


static func info(culture: String) -> Dictionary:
	return DATA.get(culture, DATA[VARDISH])


## What this culture calls a troop type: "Pikemen", "Ashigaru".
static func troop_name(culture: String, type: String) -> String:
	return String(info(culture)["troops"].get(type, type.capitalize()))


## The word after a captain's name for a company of this type: "Brann's Pikes".
static func company_noun(culture: String, type: String) -> String:
	return String(info(culture)["company"].get(type, "Company"))


static func color(culture: String) -> Color:
	return info(culture)["color"]
