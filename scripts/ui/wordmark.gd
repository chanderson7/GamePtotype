## The game's mark: the three realms' banners over their sea, beside the name and the
## tagline. Painted (assets/branding/wordmark.png, rendered from wordmark.svg by
## tools/render_wordmark.gd) and shown as Home's title. The opening flies the ridge's
## banners into it, so the banners stand in the mark as they stand on the ridge: BANNERS,
## scaled by MARK_SCALE from MARK_OFFSET, in the image's pixels. The SVG is laid out to
## match, and tests/opening_tests.gd checks the image against these numbers.
##
## As a node, this is the mark itself, a child of the title label, drawn in two parts (the
## banners, and the name) so the opening can bring the banners in on their own.
extends Control

const Style = preload("res://scripts/ui/style.gd")

const PATH := "res://assets/branding/wordmark.png"
## The three banners on the opening's ridge, left to right: each a box in the opening's
## frame, measured up from the ridge line. Vardmark stands in the middle, on the tallest pole.
const BANNERS := [["kharzan", Rect2(170, -215, 125, 230)], ["vardmark", Rect2(302, -300, 116, 316)], ["ryumon", Rect2(436, -245, 100, 260)]]
## The same three in the image: a point on the ridge lands at MARK_OFFSET + point * MARK_SCALE.
const MARK_SCALE := 0.92
const MARK_OFFSET := Vector2(-150.0, 316.0)
## The image's banners part ends here, and its name part (name and tagline) begins.
const SPLIT_X := 380.0
## Where the name and tagline are inked, in the image's pixels (the rest of their part is clear).
const NAME_INK := Rect2(398, 107, 1104, 195)
## Where the mark sits on its title label, as a fraction of the label (left, top, width,
## height): a little wider than the word and much taller, so the banners and the tagline fit
## around it. Proportional, so the opening's scaled copy carries it the same way.
const ANCHORS := Rect2(-0.08, -0.45, 1.16, 1.9)
## The glint: how wide its slit is, in the image's pixels, and how much it lifts the light.
const GLINT_WIDTH := 120.0
const GLINT_LIGHT := Color(1.55, 1.45, 1.25)

## How much of the banners part shows. The opening's copy starts with none and brings them
## in as its own banners land.
@export var banners := 1.0
## Where the glint is across the name, 0 to 1; below 0, no glint.
@export var glint := -1.0

static var _tex: Texture2D = null
static var _tried := false


## The painted mark, or null if the file is missing (Home then sets the name in type).
static func texture() -> Texture2D:
	if _tried:
		return _tex
	_tried = true
	if ResourceLoader.exists(PATH, "Texture2D"):
		_tex = load(PATH) as Texture2D
	elif FileAccess.file_exists(PATH):
		var img := Image.load_from_file(PATH)
		if img != null and not img.is_empty():
			_tex = ImageTexture.create_from_image(img)
	return _tex


## Home's title: the mark, painted, over the word "Bannerfall" set clear (the label keeps
## the space and the name for anything that reads it). With no mark to show, the word
## itself in the display face.
static func title(size: int) -> Label:
	var label := Style.label("Bannerfall", size, Style.BRASS)
	label.name = "HomeTitle"
	# The name is the game's mark, not text to read: it keeps its size whatever the text
	# setting, so the painted mark (a little wider than the word) stays on the screen.
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	if texture() == null:
		return label
	label.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	var mark := new()
	mark.name = "Wordmark"
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.anchor_left = ANCHORS.position.x
	mark.anchor_right = ANCHORS.end.x
	mark.anchor_top = ANCHORS.position.y
	mark.anchor_bottom = ANCHORS.end.y
	label.add_child(mark)
	return label


func _ready() -> void:
	resized.connect(queue_redraw)


## Where a ridge banner's box (BANNERS) sits in the image's pixels.
static func box_in_image(box: Rect2) -> Rect2:
	return Rect2(MARK_OFFSET + box.position * MARK_SCALE, box.size * MARK_SCALE)


## Where the whole image is drawn in this node: as large as fits, centred.
func image_rect() -> Rect2:
	var tex := texture()
	if tex == null or size.x <= 0.0 or size.y <= 0.0:
		return Rect2(Vector2.ZERO, size)
	var img := Vector2(tex.get_size())
	var k := minf(size.x / img.x, size.y / img.y)
	return Rect2((size - img * k) * 0.5, img * k)


## A rect in the image's pixels, in this node's own coordinates.
func from_image(r: Rect2) -> Rect2:
	var tex := texture()
	var at := image_rect()
	var k := at.size.x / float(tex.get_width()) if tex != null else 1.0
	return Rect2(at.position + r.position * k, r.size * k)


## The name and tagline's ink, in this node's own coordinates.
func name_ink() -> Rect2:
	return from_image(NAME_INK) if texture() != null else Rect2(Vector2.ZERO, size)


## The name and tagline part, in this node's own coordinates.
func name_rect() -> Rect2:
	var tex := texture()
	if tex == null:
		return Rect2(Vector2.ZERO, size)
	return from_image(Rect2(SPLIT_X, 0.0, tex.get_width() - SPLIT_X, tex.get_height()))


func _draw() -> void:
	var tex := texture()
	if tex == null:
		return
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	if banners > 0.0:
		draw_texture_rect_region(tex, from_image(Rect2(0, 0, SPLIT_X, h)), Rect2(0, 0, SPLIT_X, h), Color(1, 1, 1, banners))
	draw_texture_rect_region(tex, from_image(Rect2(SPLIT_X, 0, w - SPLIT_X, h)), Rect2(SPLIT_X, 0, w - SPLIT_X, h))
	if glint < 0.0:
		return
	# The glint: the name again, lighter, through a slit that runs across it once. It brightens
	# the letters that are there and nothing else. Soft at its edges, in a few strips.
	var mid := lerpf(SPLIT_X - GLINT_WIDTH, w + GLINT_WIDTH, glint)
	var strips := 6
	for i in strips:
		var x0 := mid - GLINT_WIDTH * 0.5 + GLINT_WIDTH * float(i) / strips
		var x1 := x0 + GLINT_WIDTH / strips
		x0 = maxf(x0, SPLIT_X)
		x1 = minf(x1, w)
		if x1 <= x0:
			continue
		var f := (float(i) + 0.5) / strips
		var a := sin(f * PI)
		var src := Rect2(x0, 0, x1 - x0, h)
		draw_texture_rect_region(tex, from_image(src), src, Color(GLINT_LIGHT, a * a))
