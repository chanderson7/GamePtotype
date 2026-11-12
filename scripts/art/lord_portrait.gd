## Lords' and captains' faces, put together from the pixel portrait kit (made by
## tools/pixel_kit, kept in assets/portraits/kit): a head and neck, eyes, brows, nose and
## mouth for the moment, hair, a beard, and what they wear. A lord wears the dress of their
## land in their house's colours, and a crown if they rule; a captain wears their company's
## kit, what their troop carries, the brass of their rank, the token of a veteran role and
## the scars of their wounds. All of it is chosen from the record (LordVoice.portrait_record
## / kin_record, or the captain), so a face always looks the same. The parts hold materials
## and shades, not colours: skin, hair, eyes and cloth are coloured here, so one kit dresses
## everyone.
##
## A look is put together once and kept; an expression only redraws the features.
extends RefCounted

const CaptainFace = preload("res://scripts/art/captain_face.gd")
const Cultures = preload("res://scripts/data/cultures.gd")

const W := 120
const H := 160
const KIT_JSON := "res://assets/portraits/kit/kit.json"
const KIT_PNG := "res://assets/portraits/kit/kit.png"
const EMPTY := 255

## The moments a face is drawn for: its eyes, its mouth, its brows (the near one can differ:
## one brow up), and a colour in the cheeks. The first seven are the ones captains always
## had (CaptainFace.EXPRESSIONS); the rest are for talk.
const MOODS := {
	"": {"eyes": "open", "mouth": "rest", "brows": "rest"},
	"warm": {"eyes": "smile", "mouth": "smile", "brows": "rest"},
	"proud": {"eyes": "open", "mouth": "slight", "brows": "rest"},
	"grim": {"eyes": "squint", "mouth": "flat", "brows": "stern"},
	"grief": {"eyes": "down", "mouth": "frown", "brows": "worried"},
	"pain": {"eyes": "half", "mouth": "grimace", "brows": "worried"},
	"fear": {"eyes": "wide", "mouth": "open", "brows": "worried"},
	"laugh": {"eyes": "laugh", "mouth": "laugh", "brows": "raised"},
	"amused": {"eyes": "smile", "mouth": "smirk", "brows": "rest", "near": "raised"},
	"tease": {"eyes": "open", "mouth": "smirk", "brows": "rest", "near": "raised"},
	"surprised": {"eyes": "wide", "mouth": "o", "brows": "raised"},
	"angry": {"eyes": "squint", "mouth": "teeth", "brows": "angry"},
	"sad": {"eyes": "down", "mouth": "pout", "brows": "sad"},
	"shy": {"eyes": "away", "mouth": "slight", "brows": "worried", "blush": true},
	"thoughtful": {"eyes": "away", "mouth": "flat", "brows": "rest", "near": "raised"},
	"determined": {"eyes": "open", "mouth": "flat", "brows": "stern"},
	"worried": {"eyes": "open", "mouth": "flat", "brows": "worried"},
}
## What a face does over its mood, written after a slash and joined by commas
## ("warm/talk", "grim/talk,shut", "/half"): eyes shut or half shut (a blink, a nod),
## glancing aside, the brows lifted, the mouth open on a word.
const DOING := ["shut", "half", "away", "brow", "talk"]
## The mouth a word is said with, over a mouth that smiles or one that doesn't.
const TALK_SMILING := ["smile", "slight", "smirk", "laugh"]

## What each land wears and how its people look, by weight. Hair styles for men marked with a
## hat are worn under it (a turban hides the hair but at the temples).
const SKIN_W := {"vardish": {"fair": 5, "warm": 3, "olive": 1},
	"kharzani": {"warm": 1, "olive": 4, "brown": 3, "deep": 2},
	"ryumon": {"fair": 2, "warm": 6, "olive": 1}}
const HAIR_W := {"vardish": {"brown": 3, "dark_brown": 2, "chestnut": 2, "auburn": 2, "copper": 1, "blond": 2, "ash": 1, "black": 1},
	"kharzani": {"black": 5, "dark_brown": 4, "brown": 1},
	"ryumon": {"black": 8, "dark_brown": 1}}
const IRIS_W := {"vardish": {"blue": 3, "grey": 2, "green": 2, "hazel": 2, "brown": 2},
	"kharzani": {"brown": 4, "dark": 4, "hazel": 2, "green": 1},
	"ryumon": {"dark": 6, "brown": 3}}
## Hair styles in turn, by the lord's house (LordVoice.portrait_record's house_index): a
## realm's lords come from different houses, so they wear different ones.
const MEN_HAIR := {"vardish": ["swept", "crop", "side", "long", "receding", "swept"],
	"kharzani": ["turban", "curls", "turban", "crop", "long", "swept"],
	"ryumon": ["topknot", "shaved", "long", "topknot", "shaved", "topknot"]}
const WOMEN_HAIR := {"vardish": ["braid_crown", "side_braid", "long", "bun", "braid_crown", "long"],
	"kharzani": ["long", "veil", "bun", "straight", "veil", "long"],
	"ryumon": ["shimada", "straight", "bun", "shimada", "straight", "bun"]}
const BEARD_W := {"vardish": {"none": 3, "stubble": 1, "short": 2, "full": 3, "goatee": 1, "moustache": 1},
	"kharzani": {"short": 3, "full": 4, "goatee": 2, "stubble": 1},
	"ryumon": {"none": 3, "thin": 4, "moustache": 2, "goatee": 1, "stubble": 1}}
const NOSE_W := {"vardish": {"straight": 3, "aquiline": 2, "broad": 1},
	"kharzani": {"aquiline": 3, "straight": 2, "broad": 1},
	"ryumon": {"straight": 2, "small": 2, "broad": 1}}
const CUTS := {"vardish": {"m": ["mantle", "surcoat"], "f": ["gown", "surcoat"]},
	"kharzani": {"m": ["kaftan", "cloak"], "f": ["collar", "coat"]},
	"ryumon": {"m": ["kamishimo", "armour"], "f": ["uchikake", "kosode"]}}
## A ruler's headwear, by land and sex.
const CROWNS := {"vardish": {"m": "crown_m", "f": "crown_f"}, "kharzani": {"m": "turban_jewel", "f": "tiara"},
	"ryumon": {"m": "eboshi", "f": "kanzashi_rich"}}
const BLUSH := Color("d85a5a")

## A captain's face is the one CaptainFace always drew for them (its features), in the
## kit's parts: the same skin, hair and eyes, the same kind of head, hair worn the same way
## (a woman's in a style of her land), and the same outfit.
const CAPT_SKIN := ["fair", "warm", "olive", "brown", "deep", "deep"]
const CAPT_HAIR_COLOR := ["black", "dark_brown", "brown", "auburn", "chestnut", "blond"]
const CAPT_MEN_HAIR := {"vardish": {"short": "crop", "side": "side", "long": "long", "braid": "long", "crop": "crop", "receding": "receding"},
	"kharzani": {"short": "crop", "curls": "curls", "long": "long", "turban": "turban", "wrap": "turban"},
	"ryumon": {"topknot": "topknot", "tied": "topknot", "short": "crop", "long": "long", "shaved": "shaved"}}
const CAPT_WOMEN_HAIR := {"vardish": {"braid": "side_braid", "long": "long", "side": "braid_crown", "receding": "braid_crown"},
	"kharzani": {"long": "long", "turban": "veil", "wrap": "veil"},
	"ryumon": {"long": "straight", "tied": "straight", "topknot": "bun"}}
const CAPT_TROOPS := ["infantry", "spearmen", "archers", "cavalry"]
const CAPT_TOKENS := ["Scout", "Quartermaster", "Drillmaster", "Champion"]
## The small picture (rosters, lists): head and shoulders, shrunk by averaging, so the face
## is as big there as a 60 x 80 face was.
const BUST := Rect2i(16, 2, 84, 112)
const BUST_SIZE := Vector2i(60, 80)

static var _kit: Dictionary = {}
static var _atlas: Image
static var _mat: Dictionary = {}
static var _sprites: Dictionary = {}
static var _bases: Dictionary = {}
static var _backs: Dictionary = {}


static func available() -> bool:
	if _atlas != null:
		return true
	var res = load(KIT_JSON) if ResourceLoader.exists(KIT_JSON) else null
	var data = res.data if res is JSON else JSON.parse_string(FileAccess.get_file_as_string(KIT_JSON))
	if not (data is Dictionary):
		return false
	var tex := load(KIT_PNG) as Texture2D if ResourceLoader.exists(KIT_PNG) else null
	var img: Image = tex.get_image() if tex != null else Image.load_from_file(ProjectSettings.globalize_path(KIT_PNG))
	if img == null or img.is_empty():
		return false
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	_kit = data
	_atlas = img
	var mats: Array = _kit.get("materials", [])
	for i in mats.size():
		_mat[String(mats[i])] = i
	return true


## The parts a lord wears, chosen from who they are.
static func look(rec: Dictionary) -> Dictionary:
	var culture := String(rec.get("culture", "vardish"))
	if not SKIN_W.has(culture):
		culture = "vardish"
	var who := String(rec.get("first", ""))
	if who == "":
		who = String(rec.get("name", ""))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(rec.get("id", 0)), culture, who, "kit"])
	var lady := bool(rec.get("woman", false)) or bool(rec.get("kin", false))
	var g := "f" if lady else "m"
	var noble := String(rec.get("noble", ""))
	var ruler := noble == "ruler"
	var heads: Array = _kit.get("heads", {}).get(g, ["m_square"])
	var age_roll := rng.randi_range(0, 9)
	var age := (0 if age_roll < 3 else (1 if age_roll < 7 else 2)) if not ruler else (1 if age_roll < 5 else 2)
	if lady:
		age = mini(age, 1)
	var f := {
		"culture": culture, "lady": lady, "g": g, "ruler": ruler, "kin": bool(rec.get("kin", false)),
		"head": heads[rng.randi_range(0, heads.size() - 1)],
		"skin": _pick(rng, SKIN_W[culture]), "hair_color": _pick(rng, HAIR_W[culture]), "iris": _pick(rng, IRIS_W[culture]),
		"age": age, "grey": 0.0,
	}
	if age == 2:
		f["grey"] = 0.35 + rng.randf() * 0.3
	elif age == 1 and rng.randf() < 0.3:
		f["grey"] = 0.15
	var turn := int(rec.get("house_index", -1))
	if turn < 0:
		turn = absi(String(rec.get("house", "")).hash())
	if lady:
		f["hair"] = WOMEN_HAIR[culture][turn % WOMEN_HAIR[culture].size()]
		f["beard"] = ""
		f["eye"] = "round" if rng.randf() < 0.4 else "almond"
		f["brow"] = "arched" if rng.randf() < 0.45 else "thin"
		f["nose"] = "small" if rng.randf() < 0.75 else "straight"
		f["lips"] = "lady"
	else:
		f["hair"] = MEN_HAIR[culture][turn % MEN_HAIR[culture].size()]
		if f["hair"] == "receding" and age == 0:
			f["hair"] = "swept"
		var beard := _pick(rng, BEARD_W[culture])
		if beard == "full" and age == 2 and rng.randf() < 0.4:
			beard = "long"
		f["beard"] = "" if beard == "none" else beard
		f["eye"] = _pick(rng, {"almond": 3, "hooded": 1 + age, "narrow": 3 if culture == "ryumon" else 1})
		f["brow"] = "thick" if rng.randf() < 0.5 else "medium"
		f["nose"] = _pick(rng, NOSE_W[culture])
		f["lips"] = "full" if rng.randf() < 0.35 else "thin"
	# What they wear: their land's two cuts, in turn by house.
	var house := String(rec.get("house", "808080"))
	var cuts: Array = CUTS[culture][g]
	f["cut"] = cuts[1] if bool(f["kin"]) else cuts[(turn + turn / 2) % cuts.size()]
	var seconds: Array = (_kit.get("seconds", {}).get(culture, {}) as Dictionary).keys()
	seconds.sort()
	var k := absi(("2" + house).hash())
	f["second"] = seconds[k % seconds.size()] if not seconds.is_empty() else ""
	f["third"] = seconds[(k + 1 + (k >> 4) % maxi(1, seconds.size() - 1)) % seconds.size()] if not seconds.is_empty() else ""
	# Headwear, and what it does to the hair beneath.
	var hat := ""
	if f["hair"] == "turban":
		hat = "turban"
		f["hair"] = "crop"
	if f["hair"] == "veil":
		hat = "veil"
		f["hair"] = "sleek"
	if lady and culture == "kharzani" and hat == "" and f["hair"] == "long" and rng.randf() < 0.6:
		hat = "circlet"
	if lady and culture == "ryumon" and f["hair"] == "shimada":
		hat = "kanzashi"
	if ruler:
		var crown: String = CROWNS[culture][g]
		if crown == "tiara" and hat == "":
			f["hair"] = "sleek"
			hat = "veil+tiara"
		elif crown == "tiara":
			hat = "veil+tiara"
			f["hair"] = "sleek"
		elif crown == "kanzashi_rich":
			f["hair"] = "shimada"
			hat = "kanzashi_rich"
		elif crown == "eboshi":
			f["hair"] = "topknot"
			hat = "eboshi"
		elif crown == "turban_jewel":
			hat = crown
		else:
			hat = crown if hat == "" else hat + "+" + crown
	f["hat"] = hat
	f["ears"] = not (hat.contains("turban") or hat.contains("veil")) and \
		not (lady and f["hair"] in ["long", "straight", "shimada"]) and f["hair"] != "long"
	# Their bearing shows at rest: a vengeful lord's brows draw down, a bold one half smiles.
	f["rest_brows"] = "stern" if String(rec.get("temperament", "")) == "Vengeful" else "rest"
	f["rest_mouth"] = "slight" if String(rec.get("quirk", "")) == "Bold" else "rest"
	return f


static func _pick(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var keys: Array = weights.keys()
	var total := 0
	for key in keys:
		total += int(weights[key])
	var roll := rng.randi_range(1, maxi(1, total))
	for key in keys:
		roll -= int(weights[key])
		if roll <= 0:
			return String(key)
	return String(keys[0])


## Whether `rec` is a captain's (not a lord's or their kin's).
static func is_captain(rec: Dictionary) -> bool:
	return String(rec.get("noble", "")) == "" and not bool(rec.get("kin", false))


## The parts a captain wears, from the face CaptainFace has always drawn for them and from
## their career: their troop, rank, role, wounds, a bandage while they recover.
static func captain_look(c: Dictionary) -> Dictionary:
	var feat := CaptainFace.features(c)
	var culture := String(feat.get("culture", "vardish"))
	if not CAPT_MEN_HAIR.has(culture):
		culture = "vardish"
	var first := String(c.get("first", String(c.get("name", "")).get_slice(" ", 0)))
	var lady := bool(feat.get("woman", false)) or bool(c.get("woman", false)) or Cultures.is_womans_name(first, culture)
	var g := "f" if lady else "m"
	var head_i := clampi(int(feat["head"]), 0, 3)
	var head: String = (["f_oval", "f_heart", "f_round", "f_oval"] if lady else ["m_square", "m_lean", "m_broad", "m_soft"])[head_i]
	if bool(feat.get("soft", false)) and not lady:
		head = "m_soft"
	var hair := String((CAPT_WOMEN_HAIR if lady else CAPT_MEN_HAIR)[culture].get(String(feat["hair"]), "bun" if lady else "crop"))
	var hat := ""
	if hair == "turban":
		hair = "crop"
		hat = "turban"
	elif hair == "veil":
		hair = "sleek"
		hat = "veil"
	var battles := int(c.get("battles", 0))
	var age := mini(int(feat["age"]), 1 if lady else 2)
	var grey := 0.55 if int(feat["age"]) >= 2 else (0.35 if battles >= 20 else 0.0)
	var eyes_i := clampi(int(feat["eyes"]), 0, 3)
	var level := CaptainFace.rank(c)
	var type := String(c.get("type", ""))
	var spec := String(c.get("specialization", ""))
	var history = c.get("history", {})
	var wounds := mini(3, int(history.get("wounds", 0))) if typeof(history) == TYPE_DICTIONARY else 0
	var cloth: Array = CaptainFace.CLOTH.get(culture, CaptainFace.CLOTH["vardish"])[clampi(int(feat["cloth"]), 0, 5)]
	var f := {
		"captain": true, "culture": culture, "lady": lady, "g": g, "ruler": false, "kin": false,
		"head": head, "hair": hair, "hat": hat, "age": age, "grey": grey,
		"beard": "" if lady or String(feat["beard"]) == "none" else String(feat["beard"]),
		"eye": (["almond", "round", "almond", "round"] if lady else ["almond", "hooded", "narrow", "round"])[eyes_i],
		"brow": (["thin", "arched", "thin"] if lady else ["medium", "thick", "medium"])[clampi(int(feat["brow"]), 0, 2)],
		"nose": "small" if lady else ["straight", "aquiline", "broad"][clampi(int(feat["nose"]), 0, 2)],
		"lips": "lady" if lady else ("full" if int(feat.get("lip", 0)) == 1 else "thin"),
		"skin": CAPT_SKIN[clampi(int(feat["skin"]), 0, 5)],
		"hair_color": CAPT_HAIR_COLOR[clampi(int(feat["hair_color"]), 0, 5)],
		"iris": ["dark", "brown", "blue", "green", "hazel"][eyes_i] if culture == "vardish" else ("brown" if culture == "kharzani" else "dark"),
		"outfit": "capt/%s_%s_%d" % [culture, g, clampi(int(feat["outfit"]), 0, 3)],
		"troop": type if type in CAPT_TROOPS else "",
		"level": level, "token": spec if spec in CAPT_TOKENS else "",
		"wounds": wounds, "scar_seed": int(feat.get("scar_seed", 0)), "bandaged": int(c.get("wounded", 0)) > 0,
		"cloth": [cloth[0].to_html(false), cloth[1].to_html(false), cloth[2].to_html(false)],
		"ears": hat == "" and not (lady and hair in ["long", "straight"]) and hair != "long",
		# Their temper shows at rest, as it always has: a vengeful captain's brows knit, a
		# fragile one's worried; a bold or lucky one half smiles.
		"rest_brows": {"Vengeful": "stern", "Fragile": "worried"}.get(String(c.get("temperament", "")), "rest"),
		"rest_mouth": "slight" if String(c.get("quirk", "")) in ["Bold", "Lucky"] else "rest",
	}
	return f


## The face for `expression` ("" at rest, a mood, "mood/doing" or "blink"; see MOODS and
## DOING), over a soft disc of their colour if `backdrop`.
static func image(rec: Dictionary, backdrop: bool = false, expression: String = "") -> Image:
	if not available():
		return null
	var base := _base(rec)
	var doing: Array = []
	var mood := expression
	if expression.contains("/"):
		doing = expression.get_slice("/", 1).split(",", false)
		mood = expression.get_slice("/", 0)
	elif expression == "blink":
		doing = ["shut"]
		mood = ""
	var f: Dictionary = base["look"]
	var m: Dictionary = MOODS.get(mood, MOODS[""])
	var brows := String(m["brows"])
	var near := String(m.get("near", brows))
	var mouth := String(m["mouth"])
	var state := String(m["eyes"])
	if mood == "" or not MOODS.has(mood):
		brows = String(f["rest_brows"])
		near = brows
		mouth = String(f["rest_mouth"])
	# A mood always shows, even on a face whose bearing already wears it at rest (a bold
	# lord's half smile is his resting face; pride widens it).
	elif brows == String(f["rest_brows"]) and near == brows and mouth == String(f["rest_mouth"]) and state == "open":
		mouth = "smile" if mouth == "slight" else ("frown" if mouth == "flat" else "slight")
	for d in doing:
		match String(d):
			"shut", "half":
				state = String(d)
			"away":
				if state not in ["laugh", "shut"]:
					state = "away"
			"brow":
				brows = "raised"
				near = "raised"
			"talk":
				mouth = "talk_smile" if mouth in TALK_SMILING else "talk"
	var g := String(f["g"])
	var data: PackedByteArray = (base["rgba"] as PackedByteArray).duplicate()
	var layer: PackedByteArray = base["layer"]
	var mat: PackedByteArray = base["mat"]
	var front: int = base["feat_z"]
	var pal: Dictionary = base["pal"]
	var skin: int = _mat.get("skin", -1)
	var parts := ["eye/far/%s/%s/%s" % [f["eye"], state, g], "eye/near/%s/%s/%s" % [f["eye"], state, g],
		"brow/far/%s/%s" % [f["brow"], brows], "brow/near/%s/%s" % [f["brow"], near],
		"mouth/%s/%s" % [f["lips"], mouth]]
	if bool(m.get("blush", false)):
		parts.push_front("mark/blush")
	for part in parts:
		var on_skin: bool = part == "mark/blush"
		var px := _sprite(part)
		for v in px:
			var i: int = v & 0x7FFF
			if layer[i] != EMPTY and layer[i] >= front:
				continue
			if on_skin and (layer[i] == EMPTY or mat[i] != skin):
				continue
			var c: PackedByteArray = pal.get((v >> 15) & 31, PackedByteArray())
			if c.is_empty():
				continue
			var t: int = ((v >> 20) & 7) * 3
			data[i * 4] = c[t]
			data[i * 4 + 1] = c[t + 1]
			data[i * 4 + 2] = c[t + 2]
			data[i * 4 + 3] = 255
	var img := Image.create_from_data(W, H, false, Image.FORMAT_RGBA8, data)
	if not backdrop:
		return img
	var back := _backdrop(rec, f)
	back.blend_rect(img, Rect2i(0, 0, W, H), Vector2i.ZERO)
	return back


static func texture(rec: Dictionary, backdrop: bool = true, expression: String = "") -> ImageTexture:
	var img := image(rec, backdrop, expression)
	return ImageTexture.create_from_image(img) if img != null else null


## The small picture: head and shoulders of `img` (a whole face, 120 x 160), shrunk to
## 60 x 80 by averaging (trilinear: as smooth as a box filter here, and quick).
static func bust(img: Image) -> Image:
	if img == null:
		return null
	var b := img.get_region(BUST)
	b.fix_alpha_edges()
	b.resize(BUST_SIZE.x, BUST_SIZE.y, Image.INTERPOLATE_TRILINEAR)
	return b


## Everything but the features, put together and outlined, kept per face.
static func _base(rec: Dictionary) -> Dictionary:
	var captain := is_captain(rec)
	var f := {}
	var key := ""
	if captain:
		f = captain_look(rec)
		key = "c|%d|%s" % [int(rec.get("id", 0)), str(f)]
	else:
		key = "%d|%s|%s|%s|%s|%s|%s|%s" % [int(rec.get("id", 0)), String(rec.get("culture", "")),
			String(rec.get("first", rec.get("name", ""))), String(rec.get("noble", "")), String(rec.get("house", "")),
			str(rec.get("woman", false)), str(rec.get("kin", false)), String(rec.get("temperament", "")) + String(rec.get("quirk", ""))]
	if _bases.has(key):
		return _bases[key]
	if not captain:
		f = look(rec)
	var g := String(f["g"])
	var hair := g + "_" + String(f["hair"])
	var hats: Array = String(f["hat"]).split("+", false) if String(f["hat"]) != "" else []
	var order: Array = []
	for h in hats:
		order.append("hat/%s/back" % h)
	order.append("hair/%s/back" % hair)
	if captain:
		if String(f["troop"]) != "":
			order.append("troop/%s/%s/back" % [f["troop"], g])
		order += ["neck/" + g, String(f["outfit"])]
		if int(f["level"]) >= 2:
			order.append("rank/%d/%s" % [mini(3, int(f["level"])), g])
		if String(f["troop"]) != "":
			order.append("troop/%s/%s/front" % [f["troop"], g])
		if String(f["token"]) != "":
			order.append("token/" + String(f["token"]))
		order.append("head/" + String(f["head"]))
	else:
		var garb := "garb/%s_%s_%s" % [f["culture"], g, f["cut"]]
		order += [garb + "/back", "neck/" + g, garb + "/front", "head/" + String(f["head"])]
	if int(f["age"]) > 0:
		order.append("age/%s%d" % [g, f["age"]])
	if captain and int(f["wounds"]) > 0:
		var scars := int(_kit.get("scars", 0))
		var rng := RandomNumberGenerator.new()
		rng.seed = int(f["scar_seed"])
		var picked := []
		while picked.size() < mini(int(f["wounds"]), scars):
			var i := rng.randi_range(0, scars - 1)
			if not picked.has(i):
				picked.append(i)
		for i in picked:
			order.append("scar/%d" % i)
	var feat_z := -1
	order.append("<features>")
	order += ["nose/" + String(f["nose"]), "hair/%s/front" % hair]
	if String(f["beard"]) != "":
		order.append("beard/%s/%s" % [f["beard"], f["head"]])
	if bool(f["ears"]):
		order.append("ears/" + String(f["head"]))
	for h in hats:
		order.append("hat/" + h)
		order.append("hat/%s/front" % h)
	if captain and bool(f["bandaged"]):
		order.append("mark/bandage")
	var n := W * H
	var mat := PackedByteArray(); mat.resize(n)
	var tone := PackedByteArray(); tone.resize(n)
	var flag := PackedByteArray(); flag.resize(n)
	var layer := PackedByteArray(); layer.resize(n); layer.fill(EMPTY)
	var li := 0
	for part in order:
		if part == "<features>":
			feat_z = li
			continue
		if not (_kit["sprites"] as Dictionary).has(part):
			continue
		for v in _sprite(part):
			var i: int = v & 0x7FFF
			mat[i] = (v >> 15) & 31
			tone[i] = (v >> 20) & 7
			flag[i] = (v >> 23) & 1
			layer[i] = li
		li += 1
	# An outline wherever a layer meets nothing or something behind it (not along the
	# frame's bottom edge, which only cuts the figure off).
	var line_t := int(_kit.get("line", 5))
	for y in H:
		for x in W:
			var i := y * W + x
			var l := layer[i]
			if l == EMPTY or flag[i] == 1:
				continue
			var lined := x == 0 or layer[i - 1] == EMPTY or layer[i - 1] < l
			lined = lined or x == W - 1 or layer[i + 1] == EMPTY or layer[i + 1] < l
			lined = lined or y == 0 or layer[i - W] == EMPTY or layer[i - W] < l
			if y < H - 1:
				lined = lined or layer[i + W] == EMPTY or layer[i + W] < l
			if lined:
				tone[i] = line_t
	var pal := _palettes(rec, f)
	var rgba := PackedByteArray(); rgba.resize(n * 4)
	for i in n:
		if layer[i] == EMPTY:
			continue
		var c: PackedByteArray = pal.get(int(mat[i]), PackedByteArray())
		if c.is_empty():
			continue
		var t := int(tone[i]) * 3
		rgba[i * 4] = c[t]
		rgba[i * 4 + 1] = c[t + 1]
		rgba[i * 4 + 2] = c[t + 2]
		rgba[i * 4 + 3] = 255
	var base := {"look": f, "rgba": rgba, "layer": layer, "mat": mat, "feat_z": feat_z if feat_z >= 0 else li, "pal": pal}
	if _bases.size() > 64:
		_bases.clear()
	_bases[key] = base
	return base


## A part's pixels, packed: index (15 bits), material (5), shade (3), no-outline flag (1).
static func _sprite(name: String) -> PackedInt32Array:
	if _sprites.has(name):
		return _sprites[name]
	var out := PackedInt32Array()
	var r = (_kit.get("sprites", {}) as Dictionary).get(name, null)
	if r != null:
		var ax := int(r[0]); var ay := int(r[1]); var w := int(r[2]); var h := int(r[3])
		var ox := int(r[4]); var oy := int(r[5])
		var src := _atlas.get_data()
		var aw := _atlas.get_width()
		for y in h:
			for x in w:
				var o := ((ay + y) * aw + ax + x) * 4
				if src[o + 3] == 0:
					continue
				var tx := ox + x
				var ty := oy + y
				if tx < 0 or ty < 0 or tx >= W or ty >= H:
					continue
				out.append((ty * W + tx) | (int(src[o]) << 15) | (int(src[o + 1]) << 20) | ((int(src[o + 2]) & 1) << 23))
	_sprites[name] = out
	return out


# ---------------------------------------------------------------- colour

static func _palettes(rec: Dictionary, f: Dictionary) -> Dictionary:
	var pal := {}
	var fixed: Dictionary = _kit.get("fixed", {})
	for name in fixed:
		pal[_mat.get(name, -1)] = _bytes(fixed[name])
	var skins: Dictionary = (_kit["skins"] as Dictionary).get(f["skin"], (_kit["skins"] as Dictionary).values()[0])
	var lady := bool(f["lady"])
	pal[_mat["skin"]] = _bytes(skins["skin"])
	var blush := []
	for h in skins["skin"]:
		blush.append(Color(String(h)).lerp(BLUSH, 0.22 if lady else 0.14).to_html(false))
	pal[_mat["blush"]] = _bytes(blush)
	pal[_mat["lip"]] = _bytes(skins["lip_f" if lady else "lip_m"])
	var hair: Array = (_kit["hairs"] as Dictionary).get(f["hair_color"], (_kit["hairs"] as Dictionary)["black"])
	var grey := float(f["grey"])
	if grey > 0.0:
		var greys: Array = (_kit["hairs"] as Dictionary)["grey"]
		var mixed := []
		for i in hair.size():
			mixed.append(Color(String(hair[i])).lerp(Color(String(greys[i])), grey).to_html(false))
		hair = mixed
	pal[_mat["hair"]] = _bytes(hair)
	pal[_mat["iris"]] = _bytes((_kit["irises"] as Dictionary).get(f["iris"], (_kit["irises"] as Dictionary)["brown"]))
	if f.has("cloth"):
		for i in 3:
			pal[_mat[["cloth_a", "cloth_b", "cloth_c"][i]]] = _bytes(house_ramp(Color(String(f["cloth"][i]))))
		return pal
	var seconds: Dictionary = (_kit["seconds"] as Dictionary).get(f["culture"], {})
	pal[_mat["cloth_a"]] = _bytes(house_ramp(Color(String(rec.get("house", "808080")))))
	pal[_mat["cloth_b"]] = _bytes(house_ramp(Color(String(seconds.get(f["second"], "404040")))))
	pal[_mat["cloth_c"]] = _bytes(house_ramp(Color(String(seconds.get(f["third"], "d8ccb0")))))
	return pal


## Six shades from one colour: the lights warmer and paler, the darks cooler and richer
## (the same rule as tools/pixel_kit/palettes.py).
static func house_ramp(c: Color) -> Array:
	var steps: Array = _kit.get("house_steps", [])
	var warm := float(_kit.get("warm", 0.09))
	var cool := float(_kit.get("cool", 0.68))
	# dyed cloth, not paint: never too bright or too pure
	var s0 := clampf(c.s, 0.18, 0.52)
	var v0 := clampf(c.v, 0.30, 0.68)
	var out := []
	for s in steps:
		var pull := float(s[2])
		var h := c.h
		if pull != 0.0:
			var target := warm if pull > 0.0 else cool
			var d := fposmod(target - h + 0.5, 1.0) - 0.5
			h = fposmod(h + clampf(d, -absf(pull), absf(pull)), 1.0)
		out.append(Color.from_hsv(h, minf(1.0, s0 * float(s[1])), minf(1.0, v0 * float(s[0]))).to_html(false))
	return out


static func _bytes(hexes: Array) -> PackedByteArray:
	var b := PackedByteArray()
	for h in hexes:
		var c := Color(String(h))
		b.append(c.r8); b.append(c.g8); b.append(c.b8)
	return b


## A soft disc behind the head: a lord's house colour, a captain's land's.
static func _backdrop(rec: Dictionary, f: Dictionary = {}) -> Image:
	var tint: Color
	var house := String(rec.get("house", "3d5c94"))
	if bool(f.get("captain", false)):
		tint = CaptainFace.BACKDROPS.get(String(f["culture"]), CaptainFace.BACKDROPS["vardish"])
		house = "land:" + String(f["culture"])
	if _backs.has(house):
		return (_backs[house] as Image).duplicate()
	if not house.begins_with("land:"):
		tint = Color(String(house_ramp(Color(house))[3]))
	var back := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var dx := (float(x) + 0.5 - 60.0) / 60.0
			var dy := (float(y) + 0.5 - 76.0) / 76.0
			var a := clampf(1.0 - sqrt(dx * dx + dy * dy), 0.0, 1.0)
			a = floorf(a * 4.0) / 4.0
			back.set_pixel(x, y, Color(tint.r, tint.g, tint.b, minf(1.0, a * 1.3)))
	_backs[house] = back
	return back.duplicate()
