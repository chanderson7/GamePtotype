## The game's icons as small pixel objects, each made of something (steel, brass, bone,
## wood, wax) with a lit edge, a shaded edge and a dark outline round the outside, on the
## same grid as the frames and the sprites. Widgets.icon hands these out; a key that has
## no pixel icon yet falls back to its line drawing in assets/ui.
##
## A grid is twelve rows of twelve: '#' the body, '+' where the light catches it, '-' its
## shaded side, 'o' a second colour, 'g' a metal detail, 'r' red. '.' is clear.
extends RefCounted

const SIZE := 12
## Each grid pixel is this many texture pixels, so an icon shown at half or a quarter of
## its texture (the usual sizes) keeps hard edges.
const SCALE := 4
const OUTLINE := Color("16110d")

## body, light, shade, second colour
const MATERIALS := {
	"brass": [Color("c9983a"), Color("f2d47a"), Color("8a6420"), Color("5a3f10")],
	"steel": [Color("8d97a6"), Color("d6dce4"), Color("59616c"), Color("2a2f38")],
	"red": [Color("a8352a"), Color("e07a66"), Color("6e1d16"), Color("f6ead0")],
	"bone": [Color("cfc6ae"), Color("f4eeda"), Color("8d8570"), Color("2a2420")],
	"wood": [Color("9a6a3a"), Color("c99a5e"), Color("6a4424"), Color("e8e2d0")],
}

## key: [material, rows, second colour (or null for the material's own)]
const ICONS := {
	"men": ["steel", [
		"............",
		"...##...##..",
		"..#++#.#++#.",
		"..#++#.#++#.",
		"...##...##..",
		".######.####",
		"#++####-#++#",
		"#+#####-#+##",
		"#######-####",
		"#######-####",
		".-----..---.",
		"............",
	], null],
	"silver": ["steel", [
		"............",
		"...######...",
		"..#++++++#..",
		".#++####++#.",
		".#+#----#+#.",
		".#+#-##-#+#.",
		".#+#-##-#+#.",
		".#+#----#+#.",
		".#++####+-#.",
		"..#------#..",
		"...######...",
		"............",
	], null],
	"food": ["brass", [
		".....#......",
		"....#+#.....",
		".#..#+#..#..",
		"#+#.#+#.#+#.",
		"#+#..#..#+#.",
		".#.#.#.#.#..",
		"..#+#.#+#...",
		"..#+#.#+#...",
		"...#..#.....",
		".....#......",
		".....#......",
		".....-......",
	], null],
	"renown": ["brass", [
		".....##.....",
		".....++.....",
		"....#++#....",
		"####++++####",
		".#++++++++#.",
		"..#++++++#..",
		"...#++++#...",
		"..#++##++#..",
		"..#+#..#+#..",
		".#+#....#+#.",
		".##......##.",
		"............",
	], null],
	"bond": ["brass", [
		"............",
		"..###..###..",
		".#++##.#++#.",
		"#+#..#+#..##",
		"#+#..#+#..##",
		"#+#..#+#..##",
		"#+#..#+#..##",
		".#++##.#++#.",
		"..---..---..",
		"............",
		"............",
		"............",
	], null],
	"clock": ["bone", [
		"...######...",
		"..#++++++#..",
		".#++oo+++#-.",
		"#+++oo++++#-",
		"#+++oo++++#-",
		"#+++ooooo+#-",
		"#+++++++++#-",
		"#+++++++++#-",
		".#+++++++#-.",
		"..#######-..",
		"...------...",
		"............",
	], null],
	"mappin": ["red", [
		"...#####....",
		"..#+++++#...",
		".#++ooo++#..",
		".#+o...o+#..",
		".#+o...o+#..",
		".#++ooo++-..",
		"..#+++++-...",
		"...#+++-....",
		"....#+-.....",
		".....#......",
		"...-----....",
		"............",
	], null],
	"crown": ["brass", [
		"............",
		"#....##....#",
		"##..#++#..##",
		"#+#.#++#.#+#",
		"#++##++##++#",
		"#++++++++++#",
		"#++++++++++#",
		"#+o++oo++o+#",
		"#----------#",
		"############",
		"............",
		"............",
	], Color("a8352a")],
	"advance": ["brass", [
		".....##.....",
		"....#++#....",
		"...#++++#...",
		"..#++##++#..",
		".#++#..#++#.",
		".##..##..##.",
		"....#++#....",
		"...#++++#...",
		"..#++##++#..",
		".#++#..#++#.",
		".##......##.",
		"............",
	], null],
	"fight": ["steel", [
		"#+........+#",
		"#++......++#",
		".#++....++#.",
		"..#++..++#..",
		"...#++++#...",
		"....#++#....",
		"...#++++#...",
		".o#++..++#o.",
		"ooo#....#ooo",
		".ooo....ooo.",
		"oo.o....o.oo",
		"o..........o",
	], Color("c9983a")],
	"hold": ["steel", [
		".##########.",
		".#++++++++#.",
		".#+++oo+++-.",
		".#+++oo+++-.",
		".#+oooooo+-.",
		".#+oooooo+-.",
		".#+++oo+++-.",
		"..#++oo++-..",
		"..#++++++-..",
		"...#++++-...",
		"....#++-....",
		".....##.....",
	], Color("3d5a96")],
	"bow": ["wood", [
		"...##.......",
		"...o.##.....",
		"...o...#+...",
		"...o....#+..",
		"r..o....#+g.",
		"oooooooooogg",
		"r..o....#+g.",
		"...o....#+..",
		"...o...#+...",
		"...o.##.....",
		"...##.......",
		"............",
	], null],
	"skull": ["bone", [
		"...######...",
		"..#++++++#..",
		".#++++++++#.",
		".#+oo++oo+#.",
		".#+oo++oo+-.",
		".#++++++++-.",
		"..#++oo++-..",
		"..#++++++-..",
		"...#+#+#-...",
		"...#+#+#-...",
		"....-.-.....",
		"............",
	], null],
	"heart": ["red", [
		"............",
		"..###..###..",
		".#+++##+++#.",
		"#++++++++++#",
		"#++++++++++-",
		"#++++++++++-",
		".#++++++++-.",
		"..#++++++-..",
		"...#++++-...",
		"....#++-....",
		".....#-.....",
		"............",
	], null],
	"book": ["wood", [
		"............",
		".#########..",
		".#-+++++++o.",
		".#-+++++++o.",
		".#-++gg+++o.",
		".#-++gg+++o.",
		".#-+++++++o.",
		".#-+++++++o.",
		".#-+++++++o.",
		".#########o.",
		"..ooooorooo.",
		".......r....",
	], null],
	"lock": ["steel", [
		"....####....",
		"...#+..+#...",
		"..#+....+#..",
		"..#+....+#..",
		".##########.",
		".#++++++++#.",
		".#+++oo+++-.",
		".#+++oo+++-.",
		".#++++o+++-.",
		".#++++++++-.",
		".#---------.",
		"............",
	], null],
	"sun": ["brass", [
		"....#..#....",
		"#...#..#...#",
		".#........#.",
		"...#++++#...",
		"..#++++++#..",
		"##++++++++##",
		"##++++++++##",
		"..#++++++#..",
		"...#++++#...",
		".#........#.",
		"#...#..#...#",
		"....#..#....",
	], null],
	"moon": ["bone", [
		"....####....",
		"..##++......",
		".#+++.......",
		".#++........",
		"#+++........",
		"#+++........",
		"#++++.......",
		".#++++....#.",
		".#+++++++#-.",
		"..##++++#-..",
		"....####....",
		"............",
	], null],
	"keep": ["bone", [
		"##.##..##.##",
		"#+.+#..#+.+#",
		"#++++##++++#",
		"#++++++++++#",
		"#++++++++++-",
		"#+++oooo+++-",
		"#++oooooo++-",
		"#++oooooo++-",
		"#++oooooo++-",
		"#++oooooo++-",
		"############",
		"............",
	], Color("2a2420")],
	"cup": ["brass", [
		"############",
		"#++++++++++#",
		".#++++++++-.",
		".#++++++++-.",
		"..#++++++-..",
		"...#++++-...",
		"....#++-....",
		".....##.....",
		".....##.....",
		"...######...",
		"..#------#..",
		"............",
	], null],
	"company": ["wood", [
		"#...........",
		"#ooooooooo..",
		"#oooooooooo.",
		"#ooo++ooooo.",
		"#ooo++oooo..",
		"#oooooooooo.",
		"#ooooooooo..",
		"#...........",
		"#...........",
		"#...........",
		"#...........",
		"-...........",
	], Color("3d5a96")],
	"level": ["brass", [
		".....##.....",
		"....#++#....",
		"...#++++#...",
		"..#++++++#..",
		".#++#++#++#.",
		".##.#++#.##.",
		"....#++#....",
		"....#++#....",
		"....#++#....",
		"....#++#....",
		"....####....",
		"............",
	], null],
	"wounded": ["bone", [
		"............",
		"..########..",
		".#++++++++#.",
		".#+++oo+++#.",
		".#+++oo+++#.",
		".#+oooooo+#.",
		".#+oooooo+#.",
		".#+++oo+++#.",
		".#+++oo+++-.",
		".#++++++++-.",
		"..--------..",
		"............",
	], Color("a8352a")],
	"objective": ["wood", [
		".#..........",
		".#oooooo....",
		".#ooooooo...",
		".#oooooooo..",
		".#ooooooo...",
		".#oooooo....",
		".#..........",
		".#..........",
		".#..........",
		".#..........",
		"####........",
		"............",
	], Color("a8352a")],
	"mail": ["bone", [
		"............",
		"############",
		"#+########+#",
		"#++#++++#++#",
		"#+++#++#+++#",
		"#++++##++++#",
		"#++++++++++#",
		"#++++++++++#",
		"#++++++++++-",
		"#----------#",
		"############",
		"............",
	], null],
	"day": ["bone", [
		"..#......#..",
		".##########.",
		".#oooooooo#.",
		".#++++++++#.",
		".#+#+#+#++#.",
		".#++++++++#.",
		".#+#+#+#++#.",
		".#++++++++#.",
		".#+#+#++++#.",
		".#++++++++-.",
		".##########.",
		"............",
	], Color("a8352a")],
}

## Keys that share another's picture.
const SAME := {"journal": "book", "rings": "bond"}

static var _made := {}


static func has(key: String) -> bool:
	return ICONS.has(String(SAME.get(key, key)))


## The icon for `key`, or null if there is no pixel icon for it.
static func texture(key: String) -> Texture2D:
	key = String(SAME.get(key, key))
	if _made.has(key):
		return _made[key]
	if not ICONS.has(key):
		return null
	var spec: Array = ICONS[key]
	var tones: Array = MATERIALS[String(spec[0])]
	var second: Color = spec[2] if spec[2] != null else tones[3]
	var colours := {"#": tones[0], "+": tones[1], "-": tones[2], "o": second,
		"g": Color("d6dce4") if key == "bow" else Color("d9a944"), "r": Color("a8352a")}
	var n := SIZE + 2
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var rows: Array = spec[1]
	for y in SIZE:
		var row := String(rows[y])
		for x in SIZE:
			if row[x] != ".":
				img.set_pixel(x + 1, y + 1, colours[row[x]])
	# The outline goes round the outside only: a gap inside a shape (between a bow's
	# string and its limb) stays open. Outside is what can be reached from the corner.
	var outside := {}
	var todo: Array[Vector2i] = [Vector2i(0, 0)]
	while not todo.is_empty():
		var at: Vector2i = todo.pop_back()
		if outside.has(at) or at.x < 0 or at.y < 0 or at.x >= n or at.y >= n or img.get_pixelv(at).a > 0.0:
			continue
		outside[at] = true
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			todo.append(at + step)
	var edged := img.duplicate() as Image
	for at in outside:
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var to: Vector2i = at + step
			if to.x >= 0 and to.y >= 0 and to.x < n and to.y < n and img.get_pixelv(to).a > 0.0:
				edged.set_pixelv(at, OUTLINE)
				break
	edged.resize(n * SCALE, n * SCALE, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(edged)
	_made[key] = tex
	return tex

