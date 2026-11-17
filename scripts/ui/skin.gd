## The game's surfaces, made of what a company carries: iron frames with rivets, brass
## and iron plates for buttons, wooden signs for tabs, a planked bar along the bottom.
## Each is a small picture drawn here in big square pixels (P screen pixels each, like the
## sprites) and stretched as a nine-patch, so its corners, bevels and rivets keep their
## size on a panel of any size. Words sit on plain, calm surfaces inside the frames.
##
## Built in code, once, and kept: no image files, and the same in the editor, in headless
## tests and in an exported build.
extends RefCounted

## One pixel of a frame, in screen pixels.
const P := 3

const IRON := Color("444b57")
const IRON_LIGHT := Color("78818e")
const IRON_DARK := Color("23272e")
const IRON_FACE := Color("4d5562")        # a secondary button's face: lighter than a frame, to read as a plate
const BRASS := Color("d2a03e")
const BRASS_LIGHT := Color("f2d47a")
const BRASS_DARK := Color("8a6420")
const WOOD := Color("4a3524")
const WOOD_LIGHT := Color("63482f")
const WOOD_DARK := Color("33241a")
const CALM := Color("1e1a17")
const CALM_LIGHT := Color("2a2420")
const GOLD_CALM := Color("2a2212")

static var _made := {}


static func _image(units: int) -> Image:
	return Image.create_empty(units * P, units * P, false, Image.FORMAT_RGBA8)


## Fill the unit square (x, y) to (x + w, y + h) of `img`.
static func _u(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x * P, y * P, w * P, h * P), c)


static func _box(key: String, img: Image, margin: int, pad: Vector4, tile: bool = false) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.set_texture_margin_all(float(margin * P))
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	if tile:
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	_made[key] = sb
	return sb


## A rivet: a dark seat with a lit head, two units square.
static func _rivet(img: Image, x: int, y: int, light: Color, dark: Color) -> void:
	_u(img, x, y, 2, 2, dark)
	img.fill_rect(Rect2i(x * P, y * P, P, P), light)


## A plate to press: `metal` "brass" (the one thing to do) or "iron" (anything else), in
## `state` normal, hover, pressed or disabled. Bevelled, riveted at the corners, standing
## a pixel off the surface; pressed, it sits down into it.
static func plate(metal: String = "iron", state: String = "normal") -> StyleBoxTexture:
	var key := "plate/%s/%s" % [metal, state]
	if _made.has(key):
		return _made[key]
	var face := BRASS if metal == "brass" else IRON_FACE
	var light := BRASS_LIGHT if metal == "brass" else IRON_LIGHT
	var dark := BRASS_DARK if metal == "brass" else IRON_DARK
	if state == "hover":
		face = face.lightened(0.08)
	elif state == "disabled":
		face = face.lerp(CALM, 0.72)
		light = light.lerp(CALM, 0.72)
		dark = dark.lerp(CALM, 0.5)
	var img := _image(12)
	var down := state == "pressed"
	if down:
		# Pushed in: the dark is on top, where the lip now throws its shadow.
		_u(img, 0, 1, 12, 11, face.darkened(0.2))
		_u(img, 0, 1, 12, 1, dark)
		_u(img, 0, 1, 1, 11, dark)
		_u(img, 0, 11, 12, 1, light.darkened(0.3))
	else:
		_u(img, 0, 11, 12, 1, Color(0, 0, 0, 0.55))            # the shadow under its lower edge
		_u(img, 0, 0, 12, 11, face)
		_u(img, 0, 0, 12, 1, light)
		_u(img, 0, 0, 1, 11, light)
		_u(img, 11, 0, 1, 11, dark)
		_u(img, 0, 9, 12, 2, dark)
	for at in [Vector2i(2, 2), Vector2i(8, 2), Vector2i(2, 7), Vector2i(8, 7)]:
		_rivet(img, at.x, at.y + (1 if down and at.y < 5 else 0), light if not down else light.darkened(0.25), dark)
	# Rivets live in the corners, so the nine-patch's margins take the four of them whole.
	return _box(key, img, 5, Vector4(14, 8 + (3 if down else 0), 14, 12 - (3 if down else 0)))


## An iron frame round a calm surface, a rivet in each corner: every card, tile and sheet.
## `gold` frames it in brass, for the one thing on a page that matters now.
static func frame(gold: bool = false, pad: Vector4 = Vector4(22, 18, 22, 20)) -> StyleBoxTexture:
	var key := "frame/%s/%s" % [gold, pad]
	if _made.has(key):
		return (_made[key] as StyleBoxTexture)
	var edge := BRASS_DARK if gold else IRON
	var light := BRASS if gold else IRON_LIGHT
	var dark := BRASS_DARK.darkened(0.35) if gold else IRON_DARK
	var img := _image(16)
	_u(img, 0, 0, 16, 16, edge)
	_u(img, 0, 0, 16, 1, light)
	_u(img, 0, 15, 16, 1, dark)
	_u(img, 2, 2, 12, 12, GOLD_CALM if gold else CALM)
	_u(img, 2, 2, 12, 1, dark)                                  # the frame's shadow on the surface
	for at in [Vector2i(0, 0), Vector2i(13, 0), Vector2i(0, 13), Vector2i(13, 13)]:
		_u(img, at.x, at.y, 3, 3, edge)
		_rivet(img, at.x, at.y, light, dark)
	return _box(key, img, 4, pad)


## A wooden sign hanging in a row of tabs; the one you're on is a brass plate.
static func sign(on: bool, gold: bool = false, hover: bool = false) -> StyleBoxTexture:
	var key := "sign/%s/%s/%s" % [on, gold, hover]
	if _made.has(key):
		return _made[key]
	var img := _image(12)
	if on:
		_u(img, 0, 0, 12, 12, BRASS if not gold else BRASS_LIGHT)
		_u(img, 0, 0, 12, 2, BRASS_LIGHT)
		_u(img, 0, 10, 12, 2, BRASS_DARK)
	else:
		_u(img, 0, 0, 12, 12, WOOD.lightened(0.08) if hover else WOOD)
		_u(img, 0, 0, 12, 1, WOOD_LIGHT)
		_u(img, 0, 10, 12, 2, WOOD_DARK)
		_u(img, 0, 5, 12, 1, WOOD_DARK)                         # where two planks meet
		if gold:
			_u(img, 0, 0, 12, 1, BRASS)
			_u(img, 0, 11, 12, 1, BRASS_DARK)
	return _box(key, img, 3, Vector4(8, 6, 8, 8))


## The rail the signs hang from: iron, along the top of the tab row.
static func rail() -> StyleBoxTexture:
	if _made.has("rail"):
		return _made["rail"]
	var img := _image(8)
	_u(img, 0, 0, 8, 2, IRON)
	_u(img, 0, 0, 8, 1, IRON_LIGHT)
	return _box("rail", img, 2, Vector4(0, 12, 0, 0))


## Planks, with an iron edge along the top: the bar across the foot of a page.
static func bar(pad: Vector4 = Vector4(32, 14, 32, 14)) -> StyleBoxTexture:
	var key := "bar/%s" % pad
	if _made.has(key):
		return _made[key]
	var img := Image.create_empty(32 * P, 16 * P, false, Image.FORMAT_RGBA8)
	img.fill(WOOD_DARK.darkened(0.25))
	for row in [[3, WOOD_DARK], [9, WOOD_DARK.darkened(0.1)]]:
		img.fill_rect(Rect2i(0, int(row[0]) * P, 32 * P, P), row[1])
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for i in 14:                                                 # grain
		var gx := rng.randi_range(0, 27)
		var gy := rng.randi_range(2, 15)
		img.fill_rect(Rect2i(gx * P, gy * P, rng.randi_range(2, 5) * P, P), WOOD_DARK.darkened(0.05) if i % 2 == 0 else WOOD_DARK.darkened(0.4))
	img.fill_rect(Rect2i(0, 0, 32 * P, 2 * P), IRON)
	img.fill_rect(Rect2i(0, 0, 32 * P, P), IRON_LIGHT)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.texture_margin_top = 2.0 * P
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	_made[key] = sb
	return sb


## Your own people's colour, as it is worn on the page: deep enough for a header band
## that brass and cream read on. Woad for Vardish, saffron for Kharzani, madder for Ryumon.
static func livery() -> Color:
	var tree := Engine.get_main_loop() as SceneTree
	var gs = tree.root.get_node_or_null("GameState") if tree != null else null
	var culture := String(gs.culture) if gs != null and gs.get("culture") != null else "vardish"
	match culture:
		"kharzani":
			return Color("6e4a14")
		"ryumon":
			return Color("6a2420")
	return Color("263a66")


## The band across the head of a card, behind its title: your colour over a brass rule.
## Drawn by the card under its own children (connect to the panel's `draw`).
static func draw_band(panel: Control, to_y: float) -> void:
	var inset := 2.0 * P
	panel.draw_rect(Rect2(inset, inset, panel.size.x - inset * 2.0, to_y - inset), livery())
	panel.draw_rect(Rect2(inset, to_y, panel.size.x - inset * 2.0, P), BRASS_DARK)
