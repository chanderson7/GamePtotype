## The battle screen: draws the simulation, turns taps into placements and orders,
## and runs the HUD. All rules live in battle_sim.gd.
##
## Deployment: every squad in the warband is a card in the tray. Tap a card, then tap
## the blue zone to place it; tap a placed squad, then somewhere else to move it.
## Auto-place lines up whatever is left. Fight starts the battle once every squad is on
## the field.
##
## Battle: squads hold their ground until ordered. Advance and Hold command the whole
## army, or only the selected squad. Select a squad by tapping its card, its standard or
## its men; then tap an enemy squad to attack it, open ground twice to march there, or its
## ability button. A line drawn with no squad selected is for the whole warband and waits
## for a tap on it. The camera follows the fighting until you pinch, scroll or drag it.
extends Node2D

const Sim = preload("res://scripts/battle/battle_sim.gd")
const Commander = preload("res://scripts/battle/commander_ai.gd")
const Troops = preload("res://scripts/data/troops.gd")
const Style = preload("res://scripts/ui/style.gd")
const Art = preload("res://scripts/art/unit_art.gd")
const SiegeArt = preload("res://scripts/art/siege_art.gd")
const Captains = preload("res://scripts/data/captains.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const Units = preload("res://scripts/data/units.gd")
const Heraldry = preload("res://scripts/ui/heraldry.gd")
const MapArt = preload("res://scripts/art/map_art.gd")
const BattleSite = preload("res://scripts/battle/battle_site.gd")
const FieldArt = preload("res://scripts/battle/field_art.gd")
const Terrain = preload("res://scripts/battle/terrain.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")

const TOP_BAR := 96.0
const CHIP_H := 84.0
## Siege cards are taller, to carry a badge saying what the company is doing.
const SIEGE_CHIP_H := 108.0
## The order buttons: an icon over a short word.
const CMD_H := 104.0
## The order buttons' words: a step under SMALL, so two lines fit under the icon.
const ORDER_FONT := 20
const ABILITY_ICONS := {"infantry": "shieldwall", "spearmen": "schiltron", "archers": "volley", "cavalry": "wheel"}
## A company's siege badge: icon, word, and the pill's colours.
const ROLE_BADGES := {
	"ladder": ["ladder", "Ladder", Color("5a4a1a"), Color("ffe08a")],
	"climb": ["ladder", "Climb", Color("5a4a1a"), Color("ffe08a")],
	"ram": ["ram", "Ram", Color("5a3b1d"), Color("ffd79a")],
	"walls": ["walls", "Walls", Color("2b5a2f"), Color("b8f5b0")],
	"inside": ["inside", "Inside", Color("2b4f7a"), Color("bfe0ff")],
	"bows": ["bow", "Bows", Color("3a3156"), Color("d8cdfa")],
	"gate": ["gate", "Gate", Color("5a3b1d"), Color("ffd79a")],
	"tower": ["gate", "Stones", Color("4a4a52"), Color("e2e0dc")],
	"head": ["ladder", "Ladder", Color("2b5a2f"), Color("b8f5b0")],
	"breach": ["breach", "Breach", Color("5a2a24"), Color("ffc0b0")],
}
const CHIP_GAP := 8.0
const MAX_CHIPS_PER_ROW := 8
const ORDER_WORDS := {"hold": "holding", "advance": "advancing", "attack": "attacking", "move": "marching"}
## Each order state's icon in the info strip.
const ORDER_ICONS := {"hold": "hold", "advance": "advance", "attack": "fight", "move": "mappin",
	"wheeling": "wheel", "braced": "shieldwall", "fighting": "fight"}
## The order bar has words under its icons for a campaign's first few battles, while the
## orders are new; after that the icons alone, each word kept in its tooltip. The same
## battles narrate every order in the hint toast; after them only refusals and first
## sights do.
const ORDER_WORD_BATTLES := 3
## The icon at the head of each word called over a squad. Zoomed out, the icon alone.
const CALLOUT_ICONS := {"CHARGE": "wheel", "BRACED": "shieldwall", "BROKEN": "retreat", "FLANK": "flank",
	"REAR": "rear", "TARGET": "fight", "FURY": "vengeful", "STEADY": "steadfast", "SHAKEN": "fragile",
	"VOLLEY": "volley"}
const CALLOUT_WORDS_ZOOM := 1.3
## How long a hint stays over the field, and the fade at its end.
const HINT_LIFE := 3.6
const HINT_FADE := 0.4
## How long the readout of a tapped enemy stays up.
const INSPECT_LIFE := 4.0

## The camera frames every squad still fighting, with this much room around them, and
## zooms in up to MAX_ZOOM over the whole-field view.
const CAMERA_MARGIN := 110.0
const MAX_ZOOM := 1.8
## How far a pinch or the mouse wheel can bring the field in, and how much a wheel notch does.
const MANUAL_ZOOM := 3.2
const WHEEL_ZOOM := 1.12
const CAMERA_EASE := 1.6
## Standards: pole length, flag size, in screen units.
const POLE := 46.0
const FLAG := Vector2(34.0, 26.0)
## A tap this close (screen units) to a standard selects its squad.
const STANDARD_TAP := 30.0
## The death roll: the battle slows to ROLL_PACE while it plays out over ROLL_TIME seconds.
const ROLL_TIME := 4.2
const ROLL_PACE := 0.12
## When the tumbling die lands.
const ROLL_LANDS := 1.5
## A cavalry charge freezes the battle when it lands on or by your men: longer the more
## men it strikes, once for charges landing together.
const HITSTOP_MIN := 0.05
const HITSTOP_MAX := 0.12
## A captain's fall stops the field for this long before the slow time or the death roll.
const CAPTAIN_HITSTOP := 0.08
## And the view punches in toward it, easing back.
const PUNCH := 0.03
const PUNCH_TIME := 0.25
## A press on the field that moves this far (screen pixels) draws a line instead of tapping.
const DRAG_START := 24.0
## A second tap this close (screen units) to a march ring or a waiting line confirms it.
const CONFIRM_TAP := 56.0
## Seconds the line just ordered stays on the field.
const LINE_SHOWN := 1.4
## The sound of the ground the battle is fought on, under the music.
const AMBIENCE := {"river": "water", "woods": "birds"}
## Branches that shoot bolts rather than arrows.
const CROSSBOWS := ["vardish_crossbowmen"]
## The ring and blades over an enemy squad you've sent someone to attack.
const TARGET_RED := Color(0.93, 0.28, 0.22)

var sim: Sim
var field_origin := Vector2.ZERO
var field_scale := 1.0
## Deployment: the roster id of the squad the next tap on the field puts down, or -1.
var selected_id := -1
## Battle: the squad Advance, Hold and the ability button apply to. null means the
## whole army.
var selected_squad = null
var speed := 1.0
var paused := false
var autoplay := false
var font: Font

var floaters: Array = []
var ticker: Array = []
## Short-lived field marks for impacts, charges and broken formations.
var bursts: Array = []
## Cue budget: at most this many bursts at once; critical ones (routs, falls) push out
## routine ones first.
const MAX_BURSTS := 36
## The battle's effects, all in field coordinates: sparks and spatter where blows land,
## dust kicked up by squads on the move and by arrows coming down, men falling, gear and
## standards left on the ground.
var _sparks: Array = []
var _puffs: Array = []
var _falling: Array = []
var _litter: Array = []
var _fallen_flags: Array = []
var _hit_seen := {}
var _last_corpse = null
var _sq_last_avg := {}
var _sq_speed := {}
var _puff_clock := 0.0
## A decisive moment: the field darkens round it (and time slows, for a captain of theirs).
var _spot := {}
var _slow := 0.0
## When the battle was decided, for the winners' cheer before the result.
var _decided_at := -1.0
const MAX_SPARKS := 260
const MAX_PUFFS := 220
## A stride in four frames: a step, the legs passing, the other step, the legs passing
## (see tools/unit_sprites.py). A man takes one every STRIDE of ground, twice as fast
## when he runs for his life.
const WALK := [0, 3, 1, 3]
const STRIDE := 14.0
## Rings on the water where men wade a ford: [{p, age}].
const MAX_RIPPLES := 70
const RIPPLE_LIFE := 0.7
var _wades: Array = []
const MAX_LITTER := 160
const MAX_FALLING := 40
## Seconds a man takes to fall: a stagger, then down.
const STAGGER_TIME := 0.15
const FALL_TIME := 0.6
## How a man moves through a blow, in field units and seconds. The sim sets his swing to
## SWING when the blow lands; he lunges and holds STRIKE_HOLD, then eases back. In the
## WINDUP before his next blow he draws back. A hit knocks him FLINCH back while its flash
## lasts; a charge shoves the men it hits SHOVE back over SHOVE_TIME, the rank behind half.
const SWING := 0.3
const STRIKE_HOLD := 0.08
const LUNGE := 4.5
const WINDUP := 0.12
const WIND_BACK := 2.5
const FLINCH := 3.5
const SHOVE := 9.0
const SHOVE_TIME := 0.35
const SHOVE_REACH := 30.0
## Men a charge has shoved, while it lasts: soldier -> {dir, k, age}.
var _shoved := {}
## How set for the blow each squad is drawn (0 to 1, eased): braced, a shield wall, a schiltron.
var _set_k := {}
## Seconds the winners cheer before the result comes up (a beat, if you lost).
const CHEER_TIME := 1.8
const LOSS_PAUSE := 0.8
## How slow time runs while a captain of theirs falls, and for how long.
const SLOW_PACE := 0.35
const SLOW_TIME := 1.1
## How fast the fight runs while a thumb holds the slow handle, whatever the speed button
## says, and the handle's size on the field's right edge.
const HAND_PACE := 0.25
const SLOW_HANDLE := Vector2(80.0, 120.0)
const CRITICAL_BURSTS := ["rout", "fall"]
## The hours: dawn, day, dusk, night. Each: the wash over the ground and over the men, the
## shadows' offset (field units), how far they stretch and how dark, the vignette.
const HOURS := {
	"dawn": {"ground": Color(1.0, 0.78, 0.55, 0.14), "air": Color(1.0, 0.8, 0.6, 0.06), "shadow": Vector2(6.0, 2.0), "long": 1.8, "alpha": 0.28, "vignette": 0.25},
	"day": {"ground": Color(0, 0, 0, 0), "air": Color(0, 0, 0, 0), "shadow": Vector2(1.5, 3.0), "long": 1.0, "alpha": 0.32, "vignette": 0.0},
	"dusk": {"ground": Color(1.0, 0.38, 0.22, 0.24), "air": Color(1.0, 0.42, 0.25, 0.1), "shadow": Vector2(-6.0, 2.0), "long": 1.8, "alpha": 0.3, "vignette": 0.45},
	"night": {"ground": Color(0.12, 0.18, 0.43, 0.42), "air": Color(0.1, 0.15, 0.4, 0.16), "shadow": Vector2(0.0, 1.5), "long": 1.0, "alpha": 0.12, "vignette": 0.7},
}
## The words for the ground the battle is fought on, by land.
const GROUND_WORDS := {"vardish": "Vardish meadow", "kharzani": "Kharzani steppe", "ryumon": "Ryumon moss"}
const SITE_WORDS := {"woods": "woods", "river": "a ford", "hills": "hills", "pass": "a rocky pass", "village": "a village"}
## The title card when the fight starts: how long it holds (a tap clears it sooner).
const TITLE_TIME := 0.85
## The word when it's decided: how long a loss waits before the result.
const DEFEAT_PAUSE := 1.3
## Callouts: a squad's word lasts CALLOUT_LIFE and doesn't repeat inside CALLOUT_REPEAT; a
## moment lasts MOMENT_LIFE and hushes the squads' words for MOMENT_HUSH; it stamps in over
## STAMP_TIME, from STAMP_SCALE.
const CALLOUT_LIFE := 1.2
const CALLOUT_REPEAT := 3.0
const MOMENT_LIFE := 2.0
const MOMENT_HUSH := 0.6
const STAMP_TIME := 0.12
const STAMP_SCALE := 1.3
## A squad at or below this morale is wavering: warned before it breaks.
const WAVER_MORALE := 35.0
## What bracing is, said once, with the first Hold.
const BRACED_WORDS := "After two seconds standing still they're braced: they hit a third harder and take a quarter less from the front. Advance gives it up."

var _wavered := {}
var _prev_order := {}
var _pre_step_order := {}
var _settled_at := {}
var _last_ack := -9.0
var _view := Rect2()
var _fit_scale := 1.0
var cam_zoom := 1.0
var cam_center := Sim.ARENA * 0.5
var _insets := {"top": 0.0, "bottom": 0.0}
var _clock := 0.0
var _hitstop := 0.0
var _shake := 0.0
var _shake_offset := Vector2.ZERO
## The way the shake knocks the view (zero: every way), and how long it has run.
var _shake_dir := Vector2.ZERO
var _shake_t := 0.0
var _punch := 0.0
var _punch_at := Vector2.ZERO
var _stop_at := -9.0
## Volley arrows in the air last frame, to see where each comes down.
var _volley_seen := {}
## The hour the battle is fought at (from the world's clock when it began, fixed for the
## battle) and what it does to the field: a wash over the ground and a lighter one over the
## men, where the shadows fall and how long, a vignette, light round the standards at night.
var _band := "day"
var _ground_tint := Color(0, 0, 0, 0)
var _air_tint := Color(0, 0, 0, 0)
## The performance readout (Settings › Show performance): what a frame costs, in ms, as
## averages and worst cases over the last second. Kept whether or not it's shown, so a test
## or a benchmark can read it.
var perf := {"fps": 0.0, "frame": 0.0, "frame_worst": 0.0, "sim": 0.0, "sim_worst": 0.0, "draw": 0.0, "draw_worst": 0.0,
	"render": 0.0, "gpu": 0.0, "men": 0, "squads": 0, "frames": 0}
var _perf_win := {}
var _perf_sim_us := 0
var _perf_draw_us := 0
const PERF_WINDOW := 1.0
## The field is drawn in three canvas items, bottom to top: this node (the ground, the dead,
## orders and effects), the troop layer (shadows and every man, each a single draw from
## the unit atlas) and the top layer (trees, arrows in flight, flags and words). `_c` is
## the one being drawn, so the drawing code works on any of them.
var _c: CanvasItem
var _troop_layer: Node2D
var _top_layer: Node2D
## The men and their shadows, batched: one instance each in a MultiMesh, written into a
## flat buffer (a transform, a tint, and the atlas cell and hit flash) and drawn at once.
var _men_mm: MultiMesh
var _shadow_mm: MultiMesh
var _men_buf := PackedFloat32Array()
var _shadow_buf := PackedFloat32Array()
var _men_n := 0
var _shadow_n := 0
## Drawn around the men: captains' rings and charging horsemen's streaks under them, and a
## wavering man's "!" over them.
var _rings := []
var _streaks := []
var _glances := []
## The dead, one MultiMesh per body's texture.
var _corpse_mm := {}
## A man's pose, as _pose_now leaves it: offset, turn, frame (-1: his own stride), crouch,
## and a facing of its own when _pf_set.
var _po := Vector2.ZERO
var _pt := 0.0
var _pi := -1
var _ps := 1.0
var _pf := Vector2.ZERO
var _pf_set := false
var _shadow_cell := Rect2()
var _shadow_col := Color.BLACK
## Each side's shadow, faintly in its own color, so in a melee the two hosts stay apart.
var _shadow_cols := [Color.BLACK, Color.BLACK]
const BATCH_FLOATS := 16
## The top layer's shader: flag cloth waves here rather than being rebuilt in script every
## frame. A vertex whose UV.x is 1.5 or more is cloth (see Heraldry.cloth_mesh):
## UV.x - 2 is how far along the fly it is, UV.y its flag's phase. Its drop is the same
## as Heraldry.flag's ripple. Nothing else drawn on the layer has a UV past 1.
const FLAG_SHADER := """
shader_type canvas_item;
uniform float clock = 0.0;
uniform float drop = 3.38;
void vertex() {
	if (UV.x >= 1.5) {
		float u = UV.x - 2.0;
		VERTEX.y += sin(clock * 5.0 + UV.y + u * 4.0) * drop * u;
		UV = vec2(0.0);
	}
}
"""
## The bodies' batches grow this many at a time.
const CORPSE_STEP := 64
## The white disc behind _dot, made once for every battle.
static var _disc_cache: Texture2D = null
var _disc_tex: Texture2D = null
## Whether this frame's men are drawn without the flash of a blow (Reduced motion), read
## once a frame rather than once a man.
var _still_men := false
const TROOP_SHADER := """
shader_type canvas_item;
varying float flash;
// INSTANCE_CUSTOM: the cell's top-left (xy) in the atlas; its width plus the hit flash in
// 64ths (z); 1 plus its height (w). A draw that isn't one of the batch has w = 0.
void vertex() {
	flash = 0.0;
	if (INSTANCE_CUSTOM.w > 0.5) {
		UV = INSTANCE_CUSTOM.xy + UV * vec2(fract(INSTANCE_CUSTOM.z), INSTANCE_CUSTOM.w - 1.0);
		flash = floor(INSTANCE_CUSTOM.z) / 64.0;
	}
}
// COLOR arrives as the texture times the instance's tint; the flash whitens it.
void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash);
}
"""
var _shadow_off := Vector2(1.5, 3.0)
var _shadow_long := 1.0
var _shadow_a := 0.32
var _vignette := 0.0
## One wind for the battle: the dust drifts with it.
var _wind := Vector2.ZERO
## The two beats: the title card when the fight starts, and the word when it's decided.
var _title := {}
var _beat := {}
var beat_layer: Control
## The grade over the field: how grey it is drawn (a lost battle drains, a pause greys).
var _grade: ColorRect
var _grey := 0.0
## Where the last enemy squad to break was, for the end.
var _last_rout_at := Vector2.ZERO
## The tray's cards feel the battle: when each of your squads was last struck from the side
## or by a charge, and when it broke.
var _card_hit := {}
var _card_broke := {}
## What the cards and the strength bar show, eased toward the truth: each squad's morale,
## when its ability last came ready, and each side's men (the gap drawn as a pale bite).
var _card_morale := {}
var _ready_was := {}
var _ready_at := {}
var _shown_men := [-1.0, -1.0]
## Tier-1 moments waiting their turn, and tier-2 callouts hushed until this time.
var _moments: Array = []
var _hush_until := -9.0
## When each squad's last callout went up, by its words, so the same one doesn't repeat.
var _said := {}
## When each squad broke (for the toppling standard), last charged (to space out
## callouts) and was last ordered (for the standard's dip).
var _broke_at := {}
var _charged_at := {}
var _ordered_at := {}
var _std_x := {}
var _std_tops := {}
## The death roll on screen, and any waiting their turn.
var _roll := {}
var _roll_queue: Array = []

var _cards: Array = []
## What the enemy's troops are called: their culture's words.
var _enemy_culture := Cultures.VARDISH
## The land the battle is fought in, which sets the ground and what grows on it, and
## the rocks and bushes scattered over the field: [{name, pos, scale, flip}].
var _biome := Cultures.VARDISH
## Whose castle a siege is fought at: the people who built it, for its look.
var _castle_culture := Cultures.VARDISH
## Whose banners fly in a siege: the garrison's realm, and your own side's.
var _garrison_realm := "vardmark"
var _my_realm := "vardmark"
var _doodads: Array = []
## The land past the field's edge, and marks on the field itself, for looks only: trees
## and paddies beyond the edge, a track, crop strips or wind ripples on the ground.
var _beyond: Array = []
var _track := PackedVector2Array()
var _strips := Rect2()
var _ripples: Array = []
var _paddies: Array = []
## The culture each squad was raised in, by "team/roster id", which dresses its men.
var _cultures := {}
## When the next clash of steel sounds, and how many arrows were in the air last frame.
var _clash_clock := 0.0
## The missiles in the air last frame, so each volley is heard once.
var _heard := {}
## The ram's swing last frame, to hear each blow land.
var _ram_swing := 0.0
## Which blows each kind of fighter trades: a pick from these banks for each clash.
const BLOWS := {Troops.INFANTRY: ["sword", "shield", "sword"], Troops.SPEARMEN: ["spear", "shield", "spear"],
	Troops.CAVALRY: ["heavy", "sword"], Troops.ARCHERS: ["sword", "shield"]}
## Player companies that have already sounded their low-morale warning this battle.
var _low_morale_heard := {}
## A press on the field: where it went down (on screen and on the field), where it is
## now, and whether it has become a line.
var _camera_hold := false
var _camera_grace := 0.0
var camera_button: Button
var _pressing := false
var _drawing := false
var _press_at := Vector2.ZERO
var _press_field := Vector2.ZERO
var _drag_to := Vector2.ZERO
## A press that went down on one of your standards: the squad, carried by the finger to
## an enemy (attack) or to ground (march there) instead of drawing a line.
var _press_squad = null
## A second finger's press while the slow handle is held: mouse emulation only follows
## the first finger, so this one is read from the touches themselves (-1: none).
var _press_touch := -1
## Fingers (touch indexes) and the mouse on the slow handle: while any is down, the fight
## runs at HAND_PACE.
var _slow_touches := {}
var _slow_mouse := false
var _slow_taught := false
## The line just ordered, fading: {spots, face, at}.
var _line_shown := {}
## Whether the hint has shown how to command one squad yet this battle.
var _taught := false
## Field touches by finger (screen positions), for a pinch; the pinch under way; whether
## the fingers of a pinch are still down (no tap or line comes of them); a mouse drag
## panning the view (right or middle button).
var _touches := {}
var _pinch := {}
var _pinch_lock := false
var _pan_mouse := false
## Orders that wait for a second tap: a march for the selected squad to a ring on the
## ground ({squad, at}, `at` on the field), and a line for the whole warband ({a, b}).
var _pending_march := {}
var _pending_line := {}
## Your squads placed by hand before the fight (by roster id): a line over them waits for
## a tap rather than moving them at once.
var _hand_placed := {}
## The map said there was no way out (riders cut off the road, or an ambush): Retreat is
## a run for it under the enemy's blades rather than a withdrawal at a price.
var _cut_off := false
## The one-shot card about the ground or the objective has been looked for (after Fight).
var _ground_card_checked := false
var _accumulator := 0.0
var _result_shown := false
var _left_battle := false
var _pending_result := {}
## A test battle from Settings: twelve companies a side, the computer commanding both, the
## readout on; it never touches the campaign.
var _test := false
var _retreat_armed := 0.0

var top_panel: PanelContainer
var bottom_panel: PanelContainer
var menu_button: Button
var title_label: Label
var status_label: Label
var power_bar: Control
var speed_button: Button
var tray: GridContainer
## The tray scrolls sideways while deploying (one row of squads); in battle it fits.
var tray_scroll: ScrollContainer
## The scouts' verdict on the enemy commander, as a chip in the top bar while deploying.
var scout_chip: Button
## Camera controls, shown only once the battle is on.
var view_row: HBoxContainer
const SCOUT_SHORT := {"reckless": "Reckless commander", "patient": "Patient commander", "hammer": "Hammer and anvil"}
var chip_buttons: Array = []
var info_label: Label
var auto_button: Button
var fight_button: Button
var advance_button: Button
var hold_button: Button
var ability_button: Button
var hold_fire_button: Button
## Storming a castle: sends the foot over the walls (see BattleSim.order_storm).
var storm_button: Button
## Defending a siege: "Man the walls" while the gate holds, "Hold the breach" after.
var post_button: Button
## The storm plan on show (squad id -> "ladder", "ram" or "bows") before it's given; the
## battle waits while it's up. Storm! gives it, Cancel drops it.
var _storm_plan: Dictionary = {}
## The engine of yours picked to aim (a stone thrower or a bolt thrower), or null.
var selected_engine = null
## Callouts already given for the siege's engines (each once).
var _engine_said := {}
var storm_go_button: Button
var cancel_button: Button
var objective_chip: PanelContainer
var objective_label: Label
## The gate on the map: what it had last frame, damage not yet shown, and a flash.
var _gate_seen := -1.0
var _gate_dmg := 0.0
var _gate_pop := 0.0
var _gate_flash := 0.0
## A big line over the field for a moment that turns the battle (the breach).
var _banner := {}
var hint_label: Label
## The hint floats over the field above the bottom panel and fades.
var hint_toast: PanelContainer
var _hint_age := 99.0
## Narrations already shown this battle, by key.
var _hinted := {}
## Words on the order bar (the first few battles of a campaign) or icons alone.
var _order_words := true
## The selection as icons and numbers, drawn; info_label keeps the sentence for its tooltip.
var info_strip: Control
var _strip_items: Array = []
## Deploying: a pip for each squad, filled once it's placed.
var deploy_pips: Control
## A tapped enemy: its sprite, men, morale and level, for a moment.
var inspect_pill: PanelContainer
var _inspect_age := 99.0
var objective_icon: TextureRect
var terrain_hint_rows: VBoxContainer
var roll_layer: Control
var pause_panel: PanelContainer
var pause_note: Label
var retreat_button: Button
var result_panel: PanelContainer
var result_scrim: ColorRect
var result_title: Label
var result_body: Label
var result_content: VBoxContainer
var terrain_hint_panel: PanelContainer
var terrain_hint_title: Label
var terrain_hint_body: Label
## The field's slopes and features (woods floor, river, rocks, houses), baked once into one
## texture (FieldArt.overlay).
var _plate_tex: ImageTexture = null
var _trees: Array = []
## Woods on the battlefield: the shade of the forest floor, in rings, and how solid the
## treetops over the men are.
const TREETOP_ALPHA := 0.78
var _terrain_site_type := ""
## The field's static layers: ground, water, props, then what falls on the ground (see
## _make_layers). The last is redrawn when `_litter_sig` changes.
var _field_layers: Array = []
## Each standard's cloth, built once per look (see _draw_waving_flag).
var _flag_geo := {}
var _litter_sig := []
## When the litter layer was last redrawn, and the newest body, arrow and piece of litter
## it holds: anything newer is drawn each frame until the next redraw.
var _litter_at := -99.0
var _snap_corpse = null
var _snap_arrow = null
var _snap_litter := 0
## The litter layer is redrawn at most this often, in seconds: arrows land nearly every
## frame in a big fight.
const LITTER_EVERY := 0.5


func _ready() -> void:
	_c = self
	_make_layers()
	font = ThemeDB.fallback_font
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_perf_reset()
	# Pixel art: hard edges, and the grass tile repeats.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# `-- --autoplay` lets the computer fight both sides (used for headless smoke tests).
	autoplay = OS.get_cmdline_user_args().has("--autoplay")
	sim = Sim.new()
	# A fight the map set up (bandits on the road), or one made up on the spot.
	var pending: Dictionary = GameState.pending_battle
	var site = pending.get("site")
	if site == null:
		var pos: Vector2 = GameState.world.party_pos(GameState.world.player()) if GameState.world != null else Vector2.ZERO
		site = BattleSite.pick(GameState.world, pos)
	if pending.is_empty():
		sim.setup(GameState.army, GameState.enemy_army(), 0, site)
		sim.ai[Sim.ENEMY] = Commander.new(Sim.ENEMY)
	else:
		_enemy_culture = String(pending.get("culture", Cultures.VARDISH))
		var obj: String = String(pending.get("objective", Sim.OBJECTIVE_ROUT))
		_test = bool(pending.get("test", false))
		var player_host: Array = (pending["army"] as Array).duplicate(true) if _test else GameState.army.duplicate(true)
		var has_allies := false
		if pending.has("allies") and not pending["allies"].is_empty():
			player_host.append_array(pending["allies"])
			has_allies = true
		sim.siege_kind = String(pending.get("siege_kind", "castle"))
		sim.siege_defender = Sim.PLAYER if bool(pending.get("siege_defend", false)) else Sim.ENEMY
		sim.siege_engines = (pending.get("siege_engines", {}) as Dictionary).duplicate(true)
		sim.setup(player_host, pending["enemy"], 0, site, obj)
		if has_allies:
			sim.allied_ai = Commander.new(Sim.PLAYER, "", true)
		if pending.has("chief_name") and pending["chief_name"] != "":
			sim.chief_name = String(pending["chief_name"])
		sim.ai[Sim.ENEMY] = Commander.new(Sim.ENEMY, String(pending.get("temperament", "")))
	_cut_off = _no_way_out(pending)
	# Bandits fight in their own realm; a battle off the map is fought in yours.
	_biome = _enemy_culture if not pending.is_empty() else GameState.culture
	_castle_culture = _enemy_culture
	var siege_at := String(pending.get("siege_target", ""))
	if siege_at != "" and WorldData.SETTLEMENTS.has(siege_at):
		_castle_culture = WorldData.culture_of(WorldData.settlement(siege_at)["faction"])
		_biome = _castle_culture
		if GameState.world != null:
			_garrison_realm = String(GameState.world.owner_of(siege_at))
	_my_realm = Heraldry.realm_of_culture(GameState.culture)
	if GameState.is_crowned():
		_my_realm = WorldData.CROWN
	elif not GameState.contract.is_empty() and Heraldry.REALM_SIZES.has(String(GameState.contract.get("realm", ""))):
		_my_realm = String(GameState.contract["realm"])
	if sim.siege_defender == Sim.PLAYER and GameState.world != null and siege_at != "":
		_my_realm = String(GameState.world.owner_of(siege_at))
	_setup_terrain_visuals()
	_scatter_doodads()
	_set_hour(float(GameState.world.hour) if GameState.world != null else 12.0)
	for layer in _field_layers:
		layer.queue_redraw()
	# Words on the order bar while the orders are new (the objective is in its chip under
	# the top bar, for every kind of battle).
	_order_words = GameState.battles < ORDER_WORD_BATTLES
	# The enemy's people set the music; an assault on walls has its own.
	Sound.play_battle("siege" if sim.objective == Sim.OBJECTIVE_SIEGE else _enemy_culture)
	# A river runs through a ford; birds sing in a wood.
	Sound.set_loop(AMBIENCE.get(_terrain_site_type, ""))
	# The enemy lines up first, so you can see what you're facing while you deploy.
	sim.ai[Sim.ENEMY].deploy(sim)
	if sim.allied_ai != null:
		sim.allied_ai.deploy(sim)
	if sim.caught_on_march(Sim.PLAYER):
		sim.auto_deploy(Sim.PLAYER)
	_cards = sim.roster(Sim.PLAYER).filter(func(e): return not bool(e.get("is_ally", false)))
	_build_hud()
	get_viewport().size_changed.connect(_layout)
	_layout()
	if autoplay or _test:
		sim.ai[Sim.PLAYER] = Commander.new(Sim.PLAYER)
		sim.ai[Sim.PLAYER].deploy(sim)
		speed = 1.0 if _test else 4.0
		_start_battle()
	else:
		# The one-shot card about the ground waits for Fight (see _end_title), so it never
		# lands on the deployment hint.
		_select_next_card()
	_refresh_hud()


## Whether the map said this fight had no way out: an ambush, or a lord whose riders cut
## off the road. Read from the map's own rule (WorldSim.can_withdraw), which gives the same
## answer for the same hour.
func _no_way_out(pending: Dictionary) -> bool:
	if sim.objective == Sim.OBJECTIVE_AMBUSH:
		return true
	if pending.is_empty() or _test:
		return false
	if pending.has("can_withdraw"):
		return not bool(pending["can_withdraw"])
	var w = GameState.world
	if int(pending.get("party_id", -1)) < 0 or w == null or int(w.encounter) == -1:
		return false
	return not bool(w.can_withdraw())


## Which part of the day `hour` falls in: dawn, day, dusk or night.
static func hour_band(hour: float) -> String:
	var h := fposmod(hour, 24.0)
	if h >= 5.0 and h < 8.0:
		return "dawn"
	if h >= 8.0 and h < 17.0:
		return "day"
	if h >= 17.0 and h < 20.0:
		return "dusk"
	return "night"


## Lights the field for the hour the battle is fought at. Looks only.
func _set_hour(hour: float) -> void:
	_band = hour_band(hour)
	var look: Dictionary = HOURS[_band]
	_ground_tint = look["ground"]
	_air_tint = look["air"]
	_shadow_off = look["shadow"]
	_shadow_long = look["long"]
	_shadow_a = look["alpha"]
	_vignette = look["vignette"]
	var seed_text := "%s/%d/%s" % [_terrain_site_type, int(hour), _biome]
	_wind = Vector2.from_angle(float(seed_text.hash() % 628) / 100.0) * 6.0


func _exit_tree() -> void:
	Sound.set_loop("")
	Sound.set_movement_loop("")
	Sound.end_battle_sounds()
	if sim != null:
		sim.dispose()


func _notification(what: int) -> void:
	# A phone call or a swipe home pauses the battle.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if sim != null and sim.phase == Sim.PHASE_BATTLE and sim.winner == -1 and not autoplay:
			_set_paused(true)


func _layout() -> void:
	var vs := get_viewport_rect().size
	_insets = Style.safe_insets(get_viewport())
	var top_h: float = TOP_BAR + _insets["top"]
	var bottom_h: float = _bottom_height() + _insets["bottom"]
	if top_panel != null:
		top_panel.add_theme_stylebox_override("panel", _bar_box(true))
		bottom_panel.add_theme_stylebox_override("panel", _bar_box(false))
		top_panel.offset_bottom = top_h
		bottom_panel.offset_top = -bottom_h
	_view = Rect2(Vector2(8.0, top_h + 8.0), Vector2(vs.x - 16.0, vs.y - top_h - bottom_h - 16.0))
	_fit_scale = maxf(0.1, minf(_view.size.x / Sim.ARENA.x, _view.size.y / Sim.ARENA.y))
	# While deploying, the field fills the width; the camera keeps your half in view (see
	# _update_camera), so only the far edge of the enemy's rear can fall off the top.
	if _deploying():
		_fit_scale = maxf(0.1, _view.size.x / Sim.ARENA.x)
	if objective_chip != null:
		objective_chip.offset_top = top_h + 14.0
	if hint_toast != null:
		hint_toast.offset_bottom = -bottom_h - 10.0
	if inspect_pill != null:
		inspect_pill.offset_top = top_h + 72.0
	_layout_tray()
	_apply_camera()
	_redraw()


func _bottom_height() -> float:
	if _deploying():
		# one row of squads, then Auto-place and Fight (hints float above, as a toast)
		return 14.0 + CHIP_H + 10.0 + _cmd_h() + 14.0
	var rows := _tray_rows()
	return 14.0 + rows * _chip_h() + (rows - 1) * CHIP_GAP + 10.0 + 34.0 + 10.0 + _cmd_h() + 14.0 + Style.TOUCH + 10.0


func _chip_h() -> float:
	return SIEGE_CHIP_H if sim != null and sim.objective == Sim.OBJECTIVE_SIEGE and not _deploying() else CHIP_H


func _deploying() -> bool:
	return sim != null and sim.phase == Sim.PHASE_DEPLOY


func _tray_rows() -> int:
	return 1 if _cards.size() <= MAX_CHIPS_PER_ROW else 2


# ---------------------------------------------------------------- camera

func _apply_camera() -> void:
	field_scale = _fit_scale * cam_zoom
	var half := _view.size / field_scale * 0.5
	var c := cam_center
	c.x = clampf(c.x, half.x, Sim.ARENA.x - half.x) if half.x * 2.0 < Sim.ARENA.x else Sim.ARENA.x * 0.5
	c.y = clampf(c.y, half.y, Sim.ARENA.y - half.y) if half.y * 2.0 < Sim.ARENA.y else Sim.ARENA.y * 0.5
	# Deploying, a field shorter than the room for it sits down by the squad tray, leaving
	# the space above it for the objective.
	if _deploying() and half.y * 2.0 >= Sim.ARENA.y:
		c.y = Sim.ARENA.y - half.y
	cam_center = c
	field_origin = _view.get_center() - c * field_scale + _shake_offset
	if _punch > 0.0:
		# Punched in toward the impact: that spot stays put on screen, the rest grows round it.
		var anchor := field_origin + _punch_at * field_scale
		field_scale *= 1.0 + _punch
		field_origin = anchor - _punch_at * field_scale


## The whole field while deploying; once the battle is on, every squad still fighting.
func _update_camera(delta: float) -> void:
	_camera_grace = maxf(0.0, _camera_grace - delta)
	_punch = maxf(0.0, _punch - delta * PUNCH / PUNCH_TIME)
	if _pressing or _camera_hold or _camera_grace > 0.0:
		_shake = maxf(0.0, _shake - delta * 30.0)
		_shake_offset = Vector2.ZERO
		_punch = 0.0
		_apply_camera()
		return
	var want_zoom := 1.0
	var want_center := Sim.ARENA * 0.5
	if _deploying():
		want_center.y = Sim.ARENA.y # clamped to show your whole zone and the enemy's front
	if sim.phase == Sim.PHASE_BATTLE and sim.winner == -1:
		var box := Rect2()
		var first := true
		for sq in sim.squads:
			if not sq.is_active():
				continue
			var half: Vector2 = Vector2.ONE * (sq.extent + CAMERA_MARGIN)
			var r := Rect2(sq.avg - half, half * 2.0)
			box = r if first else box.merge(r)
			first = false
		if not first:
			want_center = box.get_center()
			want_zoom = clampf(minf(_view.size.x / (box.size.x * _fit_scale), _view.size.y / (box.size.y * _fit_scale)), 1.0, MAX_ZOOM)
	var k := 1.0 - exp(-delta * CAMERA_EASE * (4.0 if not _title.is_empty() else 1.0))
	cam_zoom = lerpf(cam_zoom, want_zoom, k)
	cam_center = cam_center.lerp(want_center, k)
	_shake = maxf(0.0, _shake - delta * 30.0)
	_shake_t += delta
	_shake_offset = Vector2.ZERO
	if _shake > 0.0 and not Style.motion_reduced():
		if _shake_dir != Vector2.ZERO:
			# Knocked the way the charge went, rocking back and forth as it dies.
			_shake_offset = _shake_dir * sin(_shake_t * 42.0) * _shake
		else:
			_shake_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	_apply_camera()


# ---------------------------------------------------------------- the beats

## The fight begins: the place and the odds over the field while the view pulls out from
## your line, the horns under it. The battle waits for it (a tap clears it at once).
func _begin_title() -> void:
	if autoplay:
		return
	var mine := Vector2.ZERO
	var n := 0
	for sq in sim.squads:
		if sq.team == Sim.PLAYER and sq.is_active():
			mine += sq.avg
			n += 1
	_title = {"age": 0.0, "place": _place_line(), "ground": _ground_line(), "odds": "%d against %d" % [sim.men_on_field(Sim.PLAYER), sim.men_on_field(Sim.ENEMY)],
		"who": _scouting()}
	if n > 0 and not Style.motion_reduced():
		cam_center = mine / float(n)
		cam_zoom = MAX_ZOOM
		_apply_camera()
	_dim_hud(0.35)


func _end_title() -> void:
	_title = {}
	_dim_hud(1.0)
	# The ground's (or the objective's) one-shot card comes up once the fight is on, and
	# the battle waits for it.
	if not _ground_card_checked:
		_ground_card_checked = true
		_maybe_show_terrain_hint()


func _dim_hud(a: float) -> void:
	if top_panel != null:
		top_panel.modulate.a = a
		bottom_panel.modulate.a = a


## Where the battle is fought: "Near Highcliff", "At Qasr Hamra"; "In the field" off the map.
func _place_line() -> String:
	var at := _battle_place()
	if at == "":
		return "In the field"
	return ("At %s" if GameState.pending_battle.has("siege_target") else "Near %s") % WorldData.settlement(at)["name"]


func _battle_place() -> String:
	var w = GameState.world
	if w == null or GameState.pending_battle.is_empty():
		return ""
	var place: String = String(GameState.pending_battle.get("siege_target", ""))
	if place == "":
		place = w.here() if w.here() != "" else w.nearest_place(w.party_pos(w.player()))
	return place if WorldData.SETTLEMENTS.has(place) else ""


## "Vardish meadow, woods · dusk"
func _ground_line() -> String:
	var ground := String(GROUND_WORDS.get(_biome, "open ground"))
	if SITE_WORDS.has(_terrain_site_type):
		ground += ", " + String(SITE_WORDS[_terrain_site_type])
	if sim.objective == Sim.OBJECTIVE_SIEGE:
		ground = "the walls"
	var when := String({"dawn": "dawn", "day": "midday", "dusk": "dusk", "night": "night"}[_band])
	return "%s · %s" % [ground, when]


## It's decided: the word stamps onto the field over the cheer (or, lost, the colour drains
## while your men run), and only then the result.
func _decided() -> void:
	var won := sim.winner == Sim.PLAYER
	_beat = {"age": 0.0, "won": won, "why": "Their army broke and fled" if won else "Your army broke and fled"}
	match String(_pending_reason()):
		"time":
			_beat["why"] = "Time ran out with more of yours standing" if won else "Time ran out with more of theirs standing"
		"walls_held":
			_beat["why"] = "The gate held"
		"village_held":
			_beat["why"] = "The village square is held"
		"village_lost", "village_burned":
			_beat["why"] = "The raiders hold the square"
		"retreat":
			_beat["why"] = "The enemy withdrew" if won else "You pulled your army off the field"
	if won and _last_rout_at != Vector2.ZERO:
		_spotlight(_last_rout_at, CHEER_TIME)
	_hush_until = _clock + CHEER_TIME
	Sound.haptic(true)


func _pending_reason() -> String:
	var r: Dictionary = _result()
	return String(r.get("reason", ""))


## The HUD catches up with the battle: morale bars and the strength bar ease rather than
## jump, and an ability coming ready pulses once on its card with a click.
func _ease_hud(delta: float) -> void:
	if sim.phase != Sim.PHASE_BATTLE:
		return
	for sq in sim.squads:
		if sq.team != Sim.PLAYER:
			continue
		_card_morale[sq] = move_toward(float(_card_morale.get(sq, sq.morale)), sq.morale, delta * 60.0)
		var ready: bool = sq.is_active() and sim.ability_ready(sq)
		if ready and not bool(_ready_was.get(sq, true)):
			_ready_at[sq] = _clock
			Sound.play("click", -4.0)
		_ready_was[sq] = ready
	for team in [Sim.PLAYER, Sim.ENEMY]:
		var men := float(sim.men_on_field(team))
		if _shown_men[team] < 0.0 or men > _shown_men[team]:
			_shown_men[team] = men
		else:
			_shown_men[team] = lerpf(_shown_men[team], men, 1.0 - exp(-delta * 4.0))
			if _shown_men[team] - men < 0.05:
				_shown_men[team] = men


## The grade over the field: grey while paused; drained to grey when the battle is lost.
func _update_grade(delta: float) -> void:
	if _grade == null:
		return
	var want := 0.0
	if not _beat.is_empty() and not bool(_beat["won"]) and not _result_shown:
		want = 0.85
	elif paused and not _result_shown:
		want = 0.4
	var rate := (1.0 / 0.8) if want > 0.5 else (1.0 / 0.3)
	_grey = move_toward(_grey, want, delta * rate)
	_grade.visible = _grey > 0.01
	if _grade.visible:
		(_grade.material as ShaderMaterial).set_shader_parameter("grey", _grey)
		(_grade.material as ShaderMaterial).set_shader_parameter("dim", _grey * 0.18)


## The title card and the end word, over everything on the field.
func _draw_beats() -> void:
	var ci := beat_layer
	var big: Font = Style.display_font()
	if big == null:
		big = font
	var vs := ci.get_viewport_rect().size
	var still := Style.motion_reduced()
	if not _title.is_empty():
		var age := float(_title["age"])
		var a := clampf(minf(age / 0.15, (TITLE_TIME - age) / 0.2), 0.0, 1.0)
		var bar := 64.0 * a
		ci.draw_rect(Rect2(_view.position, Vector2(_view.size.x, bar)), Color(0, 0, 0, 0.85 * a))
		ci.draw_rect(Rect2(_view.position + Vector2(0, _view.size.y - bar), Vector2(_view.size.x, bar)), Color(0, 0, 0, 0.85 * a))
		var cy := _view.get_center().y
		var rise := 0.0 if still else 10.0 * (1.0 - _ease_out(age / 0.3))
		ci.draw_rect(Rect2(Vector2(_view.position.x, cy - 70.0), Vector2(_view.size.x, 140.0)), Color(0, 0, 0, 0.35 * a))
		var title := String(_title["place"]).to_upper()
		var fs := 40
		while fs > 24 and big.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > vs.x - 40.0:
			fs -= 2
		ci.draw_string_outline(big, Vector2(0, cy - 12.0 + rise), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, fs, 8, Color(0, 0, 0, 0.8 * a))
		ci.draw_string(big, Vector2(0, cy - 12.0 + rise), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, fs, Color(Style.TEXT, a))
		ci.draw_string(font, Vector2(0, cy + 22.0 + rise), "%s · %s" % [_title["ground"], _title["odds"]], HORIZONTAL_ALIGNMENT_CENTER, vs.x, _fs(Style.BODY), Color(Style.BRASS, a))
		ci.draw_rect(Rect2(vs.x * 0.5 - 80.0, cy + 36.0 + rise, 160.0, 1.0), Color(Style.BRASS, 0.6 * a))
		if String(_title["who"]) != "":
			ci.draw_string(font, Vector2(24.0, cy + 62.0 + rise), String(_title["who"]), HORIZONTAL_ALIGNMENT_CENTER, vs.x - 48.0, _fs(Style.SMALL), Color(Style.MUTED, a))
		ci.draw_string(font, Vector2(0, _view.end.y - bar * 0.5 + 6.0), "tap to skip", HORIZONTAL_ALIGNMENT_CENTER, vs.x, _fs(Style.SMALL), Color(Style.MUTED, 0.8 * a))
	if not _beat.is_empty() and not _result_shown:
		var age := float(_beat["age"])
		var won := bool(_beat["won"])
		var a := clampf(age / 0.1, 0.0, 1.0)
		var stamp := 1.0 if still else lerpf(1.45, 1.0, _ease_out(age / 0.16))
		var cy := _view.get_center().y - 30.0
		var word := "VICTORY" if won else "DEFEAT"
		var col := Style.BRASS if won else Style.ENEMY_LIGHT
		if won:
			for k in 8:
				ci.draw_circle(Vector2(vs.x * 0.5, cy), 170.0 - k * 18.0, Color(1.0, 0.8, 0.4, 0.035 * a))
		ci.draw_set_transform(Vector2(vs.x * 0.5, cy), 0.0, Vector2(stamp, stamp))
		var fs := 64
		while fs > 36 and big.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > vs.x - 40.0:
			fs -= 2
		ci.draw_string_outline(big, Vector2(-vs.x * 0.5, fs * 0.35), word, HORIZONTAL_ALIGNMENT_CENTER, vs.x, fs, 10, Color(0.1, 0.06, 0.02, 0.95 * a))
		ci.draw_string(big, Vector2(-vs.x * 0.5, fs * 0.35), word, HORIZONTAL_ALIGNMENT_CENTER, vs.x, fs, Color(col, a))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var sub_a := clampf((age - 0.25) / 0.2, 0.0, 1.0)
		ci.draw_string_outline(font, Vector2(0, cy + 52.0), String(_beat["why"]), HORIZONTAL_ALIGNMENT_CENTER, vs.x, _fs(Style.BODY), 6, Color(0, 0, 0, 0.8 * sub_a))
		ci.draw_string(font, Vector2(0, cy + 52.0), String(_beat["why"]), HORIZONTAL_ALIGNMENT_CENTER, vs.x, _fs(Style.BODY), Color(Style.TEXT, sub_a))


## Shakes the view by `amount` (screen units), along `dir` if given. One shake at a time:
## a bigger one replaces it, a smaller one is lost in it. The Settings scale it.
func _kick(amount: float, dir: Vector2 = Vector2.ZERO) -> void:
	amount *= float(Sound.shake)
	if amount <= 0.0 or amount < _shake:
		return
	_shake = amount
	_shake_dir = dir.normalized()
	_shake_t = 0.0


func _toggle_camera() -> void:
	_camera_hold = not _camera_hold
	camera_button.text = "Held" if _camera_hold else "Following"
	camera_button.icon = Widgets.icon("pin" if _camera_hold else "eye")


## The view was moved by hand (a pinch, the wheel, a drag): it stays where it was put, and
## the camera button says so, until Re-center hands it back to the fight.
func _hold_camera() -> void:
	if not _camera_hold:
		_toggle_camera()
	_shake = 0.0
	_shake_offset = Vector2.ZERO
	_punch = 0.0


## Zoom the view by `factor` about a point on the screen, which stays under the finger.
func _zoom_at(at: Vector2, factor: float) -> void:
	var spot := _to_field(at)
	_hold_camera()
	cam_zoom = clampf(cam_zoom * factor, 1.0, MANUAL_ZOOM)
	_aim_camera(spot, at)


## Slide the view by `by` screen units, the field following the finger.
func _pan_by(by: Vector2) -> void:
	_hold_camera()
	cam_center -= by / maxf(0.01, _fit_scale * cam_zoom)
	_apply_camera()


## Put the field point `spot` at the screen point `at`, at the present zoom.
func _aim_camera(spot: Vector2, at: Vector2) -> void:
	var k := maxf(0.01, _fit_scale * cam_zoom)
	cam_center = spot - (at - _view.get_center()) / k
	_apply_camera()


## The mouse and trackpad move the view: the wheel zooms about the pointer, a right or
## middle drag pans, a trackpad pinches and swipes. Returns whether it used the event.
func _camera_input(event: InputEvent) -> bool:
	var mb := event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if not mb.pressed or not _view.has_point(mb.position):
				return false
			var notches: float = mb.factor if mb.factor > 0.0 else 1.0
			var step: float = pow(WHEEL_ZOOM, notches)
			_zoom_at(mb.position, step if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / step)
			return true
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed and _view.has_point(mb.position):
				_pan_mouse = true
				return true
			if not mb.pressed and _pan_mouse:
				_pan_mouse = false
				return true
		return false
	var mm := event as InputEventMouseMotion
	if mm != null and _pan_mouse:
		_pan_by(mm.relative)
		return true
	var mg := event as InputEventMagnifyGesture
	if mg != null and _view.has_point(mg.position):
		_zoom_at(mg.position, mg.factor)
		return true
	var pg := event as InputEventPanGesture
	if pg != null and _view.has_point(pg.position):
		_pan_by(-pg.delta * 12.0)
		return true
	return false


## A second finger on the field: whatever the first had begun (a tap, a line, a carried
## squad) is dropped, and the two pinch and pan the view.
func _begin_pinch() -> void:
	_pressing = false
	_drawing = false
	_press_squad = null
	_press_touch = -1
	_pinch_lock = true
	var pts: Array = _touches.values()
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[1]
	_hold_camera()
	_pinch = {"dist": maxf(1.0, a.distance_to(b)), "zoom": cam_zoom, "spot": _to_field((a + b) * 0.5)}


func _move_pinch() -> void:
	var pts: Array = _touches.values()
	if pts.size() < 2 or _pinch.is_empty():
		return
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[1]
	cam_zoom = clampf(float(_pinch["zoom"]) * a.distance_to(b) / float(_pinch["dist"]), 1.0, MANUAL_ZOOM)
	_aim_camera(_pinch["spot"], (a + b) * 0.5)


func _recenter_camera() -> void:
	_camera_hold = false
	_camera_grace = 0.0
	camera_button.text = "Following"
	camera_button.icon = Widgets.icon("eye")
	_update_camera(1.0)


## An order was given to `sq`: its standard dips, and the hand feels it (lightly, and not
## once per squad when a whole line is ordered).
func _mark_ordered(sq) -> void:
	_ordered_at[sq] = _clock
	if _clock - _last_ack > 0.12:
		_last_ack = _clock
		Sound.haptic(false)


func _to_screen(p: Vector2) -> Vector2:
	return field_origin + p * field_scale


func _to_field(p: Vector2) -> Vector2:
	return (p - field_origin) / field_scale


# ---------------------------------------------------------------- effects

## Moves the battle's effects on by `delta` (0 while paused), and starts new ones for what
## has just happened: blows landing, men falling, squads on the move.
func _update_effects(delta: float) -> void:
	if sim == null:
		return
	_slow = maxf(0.0, _slow - delta)
	if not _spot.is_empty():
		_spot["age"] = float(_spot["age"]) + delta
		if float(_spot["age"]) >= float(_spot["life"]) and _roll.is_empty():
			_spot = {}
	for e in _sparks:
		e["age"] += delta
		e["p"] += e["v"] * delta
		e["v"] *= maxf(0.0, 1.0 - delta * 5.0)
	_sparks = _sparks.filter(func(e): return e["age"] < e["life"])
	for e in _puffs:
		e["age"] += delta
		e["p"] += (e["v"] + _wind) * delta
	_puffs = _puffs.filter(func(e): return e["age"] < e["life"])
	for e in _wades:
		e["age"] += delta
	_wades = _wades.filter(func(e): return e["age"] < RIPPLE_LIFE)
	for e in _falling:
		var was: float = e["age"]
		e["age"] += delta
		# He hits the ground: a little dust where he lands.
		if was < FALL_TIME and float(e["age"]) >= FALL_TIME and not Sound.reduced_motion:
			var at: Vector2 = e["corpse"]["pos"]
			_puff(at, Vector2.ZERO, 3.0, 9.0, 0.5, _ground_dust(at), 0.3)
	_falling = _falling.filter(func(e): return e["age"] < FALL_TIME)
	for so in _shoved.keys():
		_shoved[so]["age"] = float(_shoved[so]["age"]) + delta
		if float(_shoved[so]["age"]) >= SHOVE_TIME or not so.alive:
			_shoved.erase(so)
	# A volley coming down: the men under it duck, hit or not.
	if delta > 0.0:
		var flying := {}
		for p in sim.projectiles:
			if p.volley:
				flying[p] = true
		for p in _volley_seen.keys():
			if not flying.has(p) and p.target != null and p.target.squad != null:
				var dir: Vector2 = (p.aim - p.origin).normalized()
				for so in p.target.squad.soldiers:
					if so.alive and so.pos.distance_squared_to(p.aim) < 196.0 and not _shoved.has(so):
						_shoved[so] = {"dir": dir, "k": 0.3, "age": 0.0}
		_volley_seen = flying
	for sq in sim.squads:
		var want := 1.0 if sq.is_active() and not sq.routing and (sq.braced() or sq.shield_wall() or sq.schiltron()) else 0.0
		_set_k[sq] = move_toward(float(_set_k.get(sq, 0.0)), want, delta / 0.3)
	if delta <= 0.0:
		return
	# Blows that have just landed: sparks thrown off steel away from the striker, and a
	# spatter now and then.
	for sq in sim.squads:
		for so in sq.soldiers:
			if so.flash >= 0.95 and not _hit_seen.has(so):
				_hit_seen[so] = true
				_blow(so)
			elif so.flash < 0.5 and _hit_seen.has(so):
				_hit_seen.erase(so)
	# Men who have just fallen: each takes a moment to go down.
	var fresh := []
	for i in range(sim.corpses.size() - 1, -1, -1):
		if is_same(sim.corpses[i], _last_corpse):
			break
		fresh.append(sim.corpses[i])
	if not sim.corpses.is_empty():
		_last_corpse = sim.corpses.back()
	for c in fresh:
		if _falling.size() < MAX_FALLING:
			_falling.append({"corpse": c, "age": 0.0})
	# Dust behind every squad on the move, more behind horses.
	_puff_clock -= delta
	var spawn := _puff_clock <= 0.0
	if spawn:
		_puff_clock = 0.07
	for sq in sim.squads:
		var now: Vector2 = sq.avg
		var was: Vector2 = _sq_last_avg.get(sq, now)
		_sq_last_avg[sq] = now
		var v := (now - was) / delta
		_sq_speed[sq] = lerpf(float(_sq_speed.get(sq, 0.0)), v.length(), 0.3)
		# Men wading a ford, on the move or fighting in it, leave rings on the water.
		if spawn and sq.is_active() and (sq.engaged or float(_sq_speed[sq]) >= 8.0):
			_ripple_under(sq)
		if not spawn or not sq.is_active() or sq.engaged or float(_sq_speed[sq]) < 8.0:
			continue
		var cav: bool = sq.type == Troops.CAVALRY
		var dir := v.normalized()
		for k in (3 if cav else 1):
			var at: Vector2 = now - dir * (sq.extent + randf_range(2.0, 10.0)) + dir.orthogonal() * randf_range(-1.0, 1.0) * sq.extent
			_puff(at, -dir * randf_range(4.0, 14.0), randf_range(5.0, 8.0), 12.0 if not cav else 20.0, randf_range(1.0, 1.6), _ground_dust(at), 0.26)


## A ring on the water under one of `sq`'s men, if he stands in a ford. None under
## Reduced motion.
func _ripple_under(sq) -> void:
	if Sound.reduced_motion or sim.terrain == null or sq.soldiers.is_empty() or randf() > 0.6:
		return
	var so = sq.soldiers[randi() % sq.soldiers.size()]
	if not so.alive or sim.terrain.water_at(so.pos) != Terrain.WATER_SHALLOW:
		return
	if _wades.size() >= MAX_RIPPLES:
		_wades.pop_front()
	_wades.append({"p": so.pos + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)), "age": 0.0})


## Sparks off a blow that has just landed on `so`.
func _blow(so) -> void:
	# A blow throws up to nine: only start one if all of them fit.
	if _sparks.size() + 9 > MAX_SPARKS:
		return
	var dir := Vector2.from_angle(randf() * TAU)
	if so.target != null:
		dir = (so.pos - so.target.pos).normalized()
	var at: Vector2 = so.pos - dir * 4.0
	for k in 6:
		var c := Color(1.0, 0.97, 0.75) if k < 2 else (Color(1.0, 0.75, 0.3) if k < 4 else Color(0.95, 0.45, 0.15))
		_sparks.append({"p": at, "v": dir.rotated(randf_range(-1.1, 1.1)) * randf_range(40.0, 110.0), "age": 0.0,
			"life": randf_range(0.16, 0.32), "c": c, "size": 1.6})
	if randf() < 0.3:
		for k in 3:
			_sparks.append({"p": at, "v": dir.rotated(randf_range(-0.5, 0.5)) * randf_range(18.0, 45.0), "age": 0.0,
				"life": 0.38, "c": Color(0.55, 0.06, 0.05), "size": 1.8})


func _puff(at: Vector2, v: Vector2, r0: float, r1: float, life: float, color: Color, alpha: float) -> void:
	if _puffs.size() >= MAX_PUFFS:
		_puffs.pop_front()
	_puffs.append({"p": at, "v": v, "r0": r0, "r1": r1, "age": 0.0, "life": life, "c": color, "a": alpha})


## A squad breaks: shields and spears dropped where its men turned to run, and its
## standard left lying where it fell.
func _strew(sq) -> void:
	for so in sq.soldiers:
		if so.alive and randf() < 0.45 and _litter.size() < MAX_LITTER:
			_litter.append({"p": so.pos - so.facing * randf_range(4.0, 14.0), "a": randf() * TAU,
				"team": sq.team, "shield": randf() < 0.6})
	_fallen_flags.append({"p": sq.avg, "team": sq.team, "type": sq.type, "lean": deg_to_rad(80.0) * (1.0 if sq.team == Sim.PLAYER else -1.0)})


## The field darkens round `at` (field coordinates) for `life` seconds.
func _spotlight(at: Vector2, life: float) -> void:
	_spot = {"pos": at, "age": 0.0, "life": life}


## Sparks and spatter, over everything on the field.
func _draw_sparks() -> void:
	for e in _sparks:
		var a := 1.0 - float(e["age"]) / float(e["life"])
		var size: float = e["size"]
		_c.draw_rect(Rect2(e["p"] - Vector2(size, size) * 0.5, Vector2(size, size)), Color(e["c"], a))


## Dust on the ground: kicked up behind squads and where arrows come down.
func _draw_puffs() -> void:
	for e in _wades:
		var k: float = float(e["age"]) / RIPPLE_LIFE
		_c.draw_arc(e["p"], 2.0 + 8.0 * k, 0.0, TAU, 14, Color(0.88, 0.95, 1.0, 0.55 * (1.0 - k)), 1.2)
	for e in _puffs:
		var t := float(e["age"]) / float(e["life"])
		var r: float = lerpf(e["r0"], e["r1"], t)
		_dot(e["p"], r, Color(Color(e["c"]).lightened(0.18), float(e["a"]) * (1.0 - t) * minf(1.0, t * 6.0 + 0.2)))


## Where the lines meet: a warm glow along the front, under the men.
func _draw_front() -> void:
	if sim.phase != Sim.PHASE_BATTLE:
		return
	var pulse := 0.0 if Sound.reduced_motion else 0.02 * sin(_clock * 6.0)
	for sq in sim.squads:
		if not sq.engaged:
			continue
		var i := 0
		for so in sq.soldiers:
			i += 1
			if i % 2 == 1 or not so.alive or so.target == null or not so.target.alive or so.target.squad == null or so.target.squad.team == sq.team:
				continue
			var mid: Vector2 = so.pos.lerp(so.target.pos, 0.5)
			_dot(mid, 12.0, Color(1.0, 0.6, 0.2, 0.08 + pulse))
			_dot(mid, 5.0, Color(1.0, 0.82, 0.45, 0.11 + pulse))


## Where a volley will land: a shadow on the ground, darker as the arrows come down.
func _draw_volley_shadows() -> void:
	var groups := {}
	for p in sim.projectiles:
		var key := Vector2i(int(p.aim.x / 60.0), int(p.aim.y / 60.0))
		var done: float = p.origin.distance_to(p.pos)
		var total: float = done + p.pos.distance_to(p.aim)
		var g: Array = groups.get(key, [Vector2.ZERO, 0, 0.0])
		groups[key] = [Vector2(g[0]) + p.aim, int(g[1]) + 1, maxf(float(g[2]), done / maxf(1.0, total))]
	for key in groups:
		var g: Array = groups[key]
		if int(g[1]) < 3:
			continue
		var c: Vector2 = Vector2(g[0]) / float(g[1])
		var near: float = g[2]
		_c.draw_set_transform(field_origin + c * field_scale, 0.0, Vector2(field_scale, field_scale * 0.62))
		_c.draw_circle(Vector2.ZERO, 22.0, Color(0.08, 0.04, 0.02, 0.06 + 0.18 * near))
		_c.draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 36, Color(1.0, 0.82, 0.45, 0.2 + 0.4 * near), 1.6)
	_c.draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))


## Men going down, and what they dropped.
func _draw_falling() -> void:
	for e in _falling:
		var c: Dictionary = e["corpse"]
		var age := float(e["age"])
		var p: Vector2 = c["pos"]
		var end := fposmod(p.x * 12.9898 + p.y * 78.233, TAU)
		var type := String(c.get("type", Troops.INFANTRY))
		var culture := GameState.culture if int(c["team"]) == Sim.PLAYER else _enemy_culture
		if age < STAGGER_TIME and not Sound.reduced_motion:
			# The blow that kills him: he reels, whitened, before he goes down.
			var st := age / STAGGER_TIME
			_sprite(type, int(c["team"]), 2, p, end - 1.4 - deg_to_rad(10.0) * sin(st * PI), Color(1, 1, 1).lerp(Color(0.85, 0.82, 0.8), st), 1.0, culture)
			_c.draw_texture(Art.flash(type, 2, culture), -Art.pivot(type, culture), Color(1, 1, 1, 0.5 * (1.0 - st)))
			continue
		var t := clampf((age - STAGGER_TIME) / (FALL_TIME - STAGGER_TIME), 0.0, 1.0)
		var fall := t * t
		var tint := Color(1, 1, 1).lerp(Color(0.75, 0.72, 0.7), fall)
		_sprite(type, int(c["team"]), 2 if t < 0.25 else 1, p + Vector2(0, 2.0 * fall), lerp_angle(end - 1.4, end, fall), tint, 1.0 - 0.1 * fall, culture)


## What the fallen leave beside them: a dark patch, a weapon, a shield. Drawn kind by kind
## (every patch, then every weapon, then every shield), so each kind goes as one batch.
func _draw_gear(bodies: Array) -> void:
	var n: int = bodies.size()
	if n == 0:
		return
	var pool := Color(0.33, 0.06, 0.05, 0.26)
	var shaft := Color(0.5, 0.37, 0.22, 0.9)
	var head := Color(0.82, 0.82, 0.8, 0.9)
	var rim := Color(0.12, 0.08, 0.04, 0.7)
	var faces := [Style.PLAYER.darkened(0.35), Style.ENEMY.darkened(0.35)]
	var dirs := PackedVector2Array()
	dirs.resize(n)
	var i := 0
	for c in bodies:
		var p: Vector2 = c["pos"]
		_dot(p + Vector2(1.5, 1.5), 8.0, pool, 0.6)
		dirs[i] = Vector2.from_angle(fposmod(p.x * 12.9898 + p.y * 78.233, TAU) + 1.2)
		i += 1
	i = 0
	for c in bodies:
		var p: Vector2 = c["pos"]
		var d: Vector2 = dirs[i]
		_c.draw_line(p + d * 6.0, p + d * 14.0, shaft, 1.3)
		_c.draw_line(p + d * 12.5, p + d * 15.0, head, 1.6)
		i += 1
	i = 0
	for c in bodies:
		var at: Vector2 = Vector2(c["pos"]) - dirs[i].rotated(0.6) * 7.5
		_dot(at, 3.4, rim)
		_dot(at, 2.6, faces[0 if int(c["team"]) == Sim.PLAYER else 1])
		i += 1


## Shields and spears dropped by men who ran.
func _draw_litter(items: Array) -> void:
	# Every spear, then every shield, so each kind goes as one batch.
	for e in items:
		if not bool(e["shield"]):
			var p: Vector2 = e["p"]
			var d := Vector2.from_angle(float(e["a"]))
			_c.draw_line(p - d * 7.0, p + d * 7.0, Color(0.5, 0.37, 0.22, 0.9), 1.2)
	var rim := Color(0.12, 0.08, 0.04, 0.7)
	var faces := [Style.PLAYER.darkened(0.4), Style.ENEMY.darkened(0.4)]
	for e in items:
		if bool(e["shield"]):
			_dot(e["p"], 3.2, rim)
			_dot(e["p"], 2.4, faces[0 if int(e["team"]) == Sim.PLAYER else 1])


## Standards lying where their squads broke (screen space).
func _draw_fallen_flags() -> void:
	for f in _fallen_flags:
		var base := _to_screen(f["p"])
		var lean: float = f["lean"]
		var top := base + Vector2(sin(lean), -cos(lean)) * POLE * 0.8
		_c.draw_line(base, top, Color(0.32, 0.22, 0.13, 0.9), 2.5)
		_draw_flag(_c, top, FLAG * 0.75, int(f["team"]), String(f["type"]), true, false, lean)


## A decisive moment: the field darkens round it and black bars slide in.
func _draw_spotlight() -> void:
	var focus_at: Vector2
	var amount := 1.0
	if not _roll.is_empty() and _roll.has("pos"):
		focus_at = _to_screen(_roll["pos"])
	elif not _spot.is_empty():
		focus_at = _to_screen(_spot["pos"])
		var t := float(_spot["age"]) / float(_spot["life"])
		amount = clampf(minf(t * 6.0, (1.0 - t) * 4.0), 0.0, 1.0)
	else:
		return
	var reach := _view.size.length()
	for i in 14:
		var r := lerpf(reach * 0.6, 130.0, float(i) / 14.0)
		_c.draw_circle(focus_at, r, Color(0.02, 0.02, 0.05, 0.045 * amount))
	_c.draw_arc(focus_at, 130.0, 0.0, TAU, 64, Color(1.0, 0.85, 0.5, 0.45 * amount), 2.5)
	var bar := 46.0 * amount
	_c.draw_rect(Rect2(_view.position, Vector2(_view.size.x, bar)), Color(0, 0, 0, 0.85))
	_c.draw_rect(Rect2(_view.position + Vector2(0, _view.size.y - bar), Vector2(_view.size.x, bar)), Color(0, 0, 0, 0.85))


# ---------------------------------------------------------------- frame

func _process(delta: float) -> void:
	_perf_frame(delta)
	_clock += delta
	if not _roll.is_empty():
		var before := float(_roll["t"])
		_roll["t"] = before + delta
		# The die rattles as it tumbles; a bell tolls if it lands on death.
		if before == 0.0:
			Sound.play("dice")
		if before < ROLL_LANDS and float(_roll["t"]) >= ROLL_LANDS and _roll["fate"] == "killed":
			Sound.play("bell")
		if float(_roll["t"]) >= ROLL_TIME:
			_next_roll()
	if not _title.is_empty():
		_title["age"] = float(_title["age"]) + delta
		if float(_title["age"]) >= TITLE_TIME:
			_end_title()
	if not _beat.is_empty():
		_beat["age"] = float(_beat["age"]) + delta
	_update_grade(delta)
	_ease_hud(delta)
	if sim.winner == -1 and sim.phase == Sim.PHASE_BATTLE and not paused and _storm_plan.is_empty() and _title.is_empty() \
			and not terrain_hint_panel.visible:
		var pace := ROLL_PACE if not _roll.is_empty() else (SLOW_PACE if _slow > 0.0 else 1.0)
		var rate := speed
		if slow_held():
			# The thumb's slow is the same pace at 1× or 2×, and a captain's fall slows it no
			# further than it already is.
			rate = 1.0
			pace = minf(pace, HAND_PACE) if not _roll.is_empty() else HAND_PACE
		if _hitstop > 0.0:
			_hitstop -= delta
			# Under Reduced motion the field never freezes for a blow.
			if not Style.motion_reduced():
				pace = 0.0
		_accumulator += minf(delta, 0.1) * rate * pace
		# Orders as they stood before the sim steps, so a squad that marches and arrives in
		# the same frame is still seen to halt.
		for sq in sim.squads:
			if sq.team == Sim.PLAYER:
				_pre_step_order[sq] = sq.order
		var steps := 0
		var t_sim := Time.get_ticks_usec()
		while _accumulator >= Sim.STEP and steps < 16:
			sim.step()
			_accumulator -= Sim.STEP
			steps += 1
		_perf_sim_us += Time.get_ticks_usec() - t_sim
		_consume_events()
		_battle_sounds(delta)
		_watch_gate(delta)
		if selected_squad != null and not selected_squad.is_active():
			selected_squad = null
	elif sim.winner != -1 and not _result_shown and _roll.is_empty():
		_consume_events()
		# The winners cheer a moment before the result comes up, under the word for it.
		if _decided_at < 0.0:
			_decided_at = _clock
			_decided()
		var wait := CHEER_TIME if sim.winner == Sim.PLAYER else DEFEAT_PAUSE
		if _roll.is_empty() and _clock - _decided_at >= wait:
			_show_result()
	_update_effects(0.0 if paused else delta)
	_update_camera(delta)
	for f in floaters:
		f["age"] += delta
	floaters = floaters.filter(func(f): return f["age"] < f["life"])
	for t in ticker:
		t["age"] += delta
	ticker = ticker.filter(func(t): return t["age"] < t["life"])
	if not _banner.is_empty() and _roll.is_empty():
		_banner["age"] = float(_banner["age"]) + delta
		if float(_banner["age"]) >= float(_banner["life"]):
			_banner = {}
			if not _moments.is_empty():
				_start_moment(_moments.pop_front())
	for burst in bursts:
		burst["age"] += delta
	bursts = bursts.filter(func(burst): return burst["age"] < burst["life"])
	_age_overlays(delta)
	_refresh_hud()
	_redraw()


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()
		return
	if _camera_input(event):
		get_viewport().set_input_as_handled()
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _roll.is_empty():
		get_viewport().set_input_as_handled()
		_next_roll()
		return
	if not _title.is_empty():
		get_viewport().set_input_as_handled()
		_end_title()
		return
	# Paused, the field still takes orders: select, target, draw a line.
	if sim.winner != -1 or terrain_hint_panel.visible:
		return
	if not _view.has_point(mb.position) or _press_touch != -1 or _pinch_lock:
		return
	get_viewport().set_input_as_handled()
	_begin_press(mb.position)


## A press on the field is a tap when it's let go, or a line if it's dragged; one that goes
## down on your own standard carries that squad instead.
func _begin_press(at: Vector2) -> void:
	_pressing = true
	_drawing = false
	_press_at = at
	_shake_offset = Vector2.ZERO
	_punch = 0.0
	_apply_camera()
	_press_field = _to_field(at)
	_drag_to = at
	_press_squad = null
	if _storm_plan.is_empty():
		var std = _standard_at(at)
		if std != null and std.team == Sim.PLAYER and std.is_active() and not std.is_ally:
			_press_squad = std


func _move_press(at: Vector2) -> void:
	_drag_to = at
	if not _drawing and at.distance_to(_press_at) >= DRAG_START:
		_drawing = true


func _end_press(at: Vector2) -> void:
	_pressing = false
	_camera_grace = 0.85
	var drew := _drawing
	_drawing = false
	var carried = _press_squad
	_press_squad = null
	if sim.winner != -1:
		return
	if drew and carried != null:
		_drop_pending()
		_drop_squad(carried, at)
		return
	if drew:
		_line_drawn(_press_field, _to_field(at))
		return
	# A line waiting for its tap: a tap on it gives the order, a tap anywhere else drops it.
	if not _pending_line.is_empty():
		var waiting: Dictionary = _pending_line
		_pending_line = {}
		if _on_pending_line(_press_at, waiting):
			_order_line(waiting["a"], waiting["b"], null)
		else:
			_hint("Line dropped. Drag again to draw another.")
		return
	var tapped = _standard_at(_press_at)
	if sim.phase == Sim.PHASE_DEPLOY:
		_tap_deploy(_press_field, tapped)
	else:
		_tap_battle(_press_field, tapped)


## Follows a press on the field until it's let go, wherever the finger goes; and the slow
## handle, held by a thumb while the other hand gives orders.
func _input(event: InputEvent) -> void:
	var st := event as InputEventScreenTouch
	if st != null:
		if st.pressed and _slow_handle().has_point(st.position):
			_slow_touches[st.index] = true
			_on_slow_held()
			get_viewport().set_input_as_handled()
			return
		if not st.pressed and _slow_touches.has(st.index):
			_slow_touches.erase(st.index)
			get_viewport().set_input_as_handled()
			return
		# Two fingers on the field pinch and pan the view.
		if st.pressed and _view.has_point(st.position):
			_touches[st.index] = st.position
			if _touches.size() >= 2:
				_begin_pinch()
				get_viewport().set_input_as_handled()
				return
		elif not st.pressed and _touches.has(st.index):
			_touches.erase(st.index)
			if _touches.size() < 2:
				_pinch = {}
			var was_pinching := _pinch_lock
			if _touches.is_empty():
				_pinch_lock = false
			if was_pinching:
				get_viewport().set_input_as_handled()
				return
		# Another finger on the field while the thumb holds time back.
		if st.pressed and slow_held() and not _pressing and _view.has_point(st.position):
			_press_touch = st.index
			get_viewport().set_input_as_handled()
			_begin_press(st.position)
			return
		if not st.pressed and st.index == _press_touch:
			_press_touch = -1
			get_viewport().set_input_as_handled()
			if _pressing:
				_end_press(st.position)
			return
		return
	var sd := event as InputEventScreenDrag
	if sd != null:
		if _touches.has(sd.index):
			_touches[sd.index] = sd.position
			if not _pinch.is_empty():
				_move_pinch()
				get_viewport().set_input_as_handled()
				return
		if sd.index == _press_touch and _pressing:
			_move_press(sd.position)
			get_viewport().set_input_as_handled()
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed and not _pressing and _slow_handle().has_point(mb.position):
			_slow_mouse = true
			_on_slow_held()
			get_viewport().set_input_as_handled()
			return
		if not mb.pressed and _slow_mouse:
			_slow_mouse = false
			get_viewport().set_input_as_handled()
			return
	if not _pressing or _press_touch != -1:
		return
	var mm := event as InputEventMouseMotion
	if mm != null:
		_move_press(mm.position)
		get_viewport().set_input_as_handled()
		return
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or mb.pressed:
		return
	get_viewport().set_input_as_handled()
	_end_press(mb.position)


# ---------------------------------------------------------------- slow time

## Whether the slow handle can be held now: in the fight, running, nothing in the way.
func _slow_ready() -> bool:
	return sim != null and sim.phase == Sim.PHASE_BATTLE and sim.winner == -1 and not paused \
		and _storm_plan.is_empty() and _title.is_empty()


## The slow handle: a tab on the field's right edge, low down, where a right thumb rests.
func _slow_handle() -> Rect2:
	if not _slow_ready():
		return Rect2()
	return Rect2(Vector2(_view.end.x - SLOW_HANDLE.x, _view.end.y - SLOW_HANDLE.y - 54.0), SLOW_HANDLE)


## Whether a thumb (or the mouse) is holding time back.
func slow_held() -> bool:
	return (not _slow_touches.is_empty() or _slow_mouse) and _slow_ready()


func _on_slow_held() -> void:
	Sound.haptic()
	if not _slow_taught:
		_slow_taught = true
		_hint("Time slowed. Tap orders with your other hand; let go and the fight runs on.")


## Lets go of the handle for every finger: when the battle stops or pauses under it. A
## pinch under way is let go too (its fingers' lifts may never come, if the app lost focus).
func _release_slow() -> void:
	_slow_touches.clear()
	_slow_mouse = false
	_touches.clear()
	_pinch = {}
	_pinch_lock = false
	_pan_mouse = false


# ---------------------------------------------------------------- carrying a squad

## Where a carried squad would go if the finger lifted at `at` (on screen): {foe} for an
## enemy under it, {ground, ok, why} for open ground, or {} for back on its own standard.
func _drop_target(sq, at: Vector2) -> Dictionary:
	var p := _to_field(at)
	var std = _standard_at(at)
	if std == sq or (std == null and sim.squad_at(Sim.PLAYER, p) == sq):
		return {}
	var foe = std if std != null and std.team == Sim.ENEMY else sim.squad_at(Sim.ENEMY, p, 52.0)
	if foe != null and foe.is_active() and sim.phase == Sim.PHASE_BATTLE:
		return {"foe": foe}
	var ok := true
	var why := ""
	if sim.phase == Sim.PHASE_DEPLOY:
		if not sim.in_deploy_zone(Sim.PLAYER, p):
			ok = false
			why = "outside your zone"
	elif sim.terrain != null and not sim.terrain.passable(p):
		ok = false
		why = "no footing there"
	return {"ground": p, "ok": ok, "why": why}


## The finger lifts with a squad in hand: attack what it's on, or march to the ground.
func _drop_squad(sq, at: Vector2) -> void:
	var t := _drop_target(sq, at)
	if t.is_empty():
		_tap_battle(sq.average_pos(), sq) if sim.phase == Sim.PHASE_BATTLE else _tap_deploy(sq.average_pos(), sq)
		return
	if sim.phase == Sim.PHASE_DEPLOY:
		if not bool(t["ok"]):
			_hint("Place your squads in the blue zone, your half of the field.")
			return
		if sim.place(Sim.PLAYER, sq.roster_id, t["ground"]) == null:
			_hint("No room there. Try a more open spot.")
			return
		_hand_placed[sq.roster_id] = true
		Sound.haptic()
		_hint("%s stand there. Drag another flag, or press Fight." % _company_or_type(sq), "placed")
		return
	selected_squad = sq
	if t.has("foe"):
		_order_attack(sq, t["foe"])
	else:
		_order_move(sq, t["ground"])


func _order_attack(sq, foe) -> void:
	sim.order_attack(sq, foe)
	_mark_ordered(sq)
	_mark_ordered(foe)
	_callout(foe, "TARGET", Style.ENEMY_LIGHT, true)
	Sound.play("clash2", -6.0, 0.05)
	_hint("%s attack the enemy %s, and stay on them until they break." % [_company_or_type(sq), _name(foe.type, Sim.ENEMY).to_lower()], "attack")


## Why `sq` can't march to `p`, or "" if it can.
func _march_refusal(sq, p: Vector2) -> String:
	if sim.terrain != null and not sim.terrain.passable(p):
		return "Cannot march there: %s" % _terrain_hint(p)
	if Sim.Pathing.find_path(sim.terrain, sq.center, p, sq.type == Troops.CAVALRY, false).is_empty():
		return "Cannot march there: no route to that ground."
	return ""


func _order_move(sq, p: Vector2) -> void:
	var why := _march_refusal(sq, p)
	if why != "":
		_hint(why)
		return
	sim.order_move(sq, p)
	_mark_ordered(sq)
	_hint("%s march there and hold." % _company_or_type(sq), "move")


## How a squad of `type` fares against `foe_type`: [arrow, words, colour].
func _matchup(type: String, foe_type: String) -> Array:
	if Troops.COUNTERED_BY.get(foe_type, "") == type:
		return ["▲", "they fight them best", Style.MORALE_HIGH]
	if Troops.COUNTERED_BY.get(type, "") == foe_type:
		return ["▼", "the enemy has the edge", Style.MORALE_LOW]
	return ["·", "an even fight", Style.MORALE_MID]


## A line has been drawn from `a` to `b`. For the one squad selected it is an order at
## once. For the whole warband it waits for a tap on it, so a stray swipe never re-forms
## the army: in battle always, and before the fight once you have placed a company by hand
## (a line over an army still unplaced, or placed by Auto-place or a line, goes at once).
func _line_drawn(a: Vector2, b: Vector2) -> void:
	if not _storm_plan.is_empty():
		return
	var only = selected_squad if sim.phase == Sim.PHASE_BATTLE else null
	if only != null or (sim.phase == Sim.PHASE_DEPLOY and _hand_placed.is_empty()):
		_order_line(a, b, only)
		return
	if sim.line_preview(Sim.PLAYER, a, b, null).is_empty():
		_hint("Cannot form a line there. Choose clear ground in the deployment zone.")
		return
	_pending_march = {}
	_pending_line = {"a": a, "b": b}
	Sound.play("page", -6.0, 0.05)
	if sim.phase == Sim.PHASE_DEPLOY:
		_hint("Tap the line to move the whole warband onto it, the companies you placed too. Tap elsewhere to keep them where they are.")
	else:
		_hint("Tap the line to form the whole warband on it. Tap elsewhere to drop it.")


## Whether a tap at `at` (on screen) lands on the waiting line `line`.
func _on_pending_line(at: Vector2, line: Dictionary) -> bool:
	var a := _to_screen(line["a"])
	var b := _to_screen(line["b"])
	return Geometry2D.get_closest_point_to_segment(at, a, b).distance_to(at) <= CONFIRM_TAP


## Drops any order waiting for its second tap.
func _drop_pending() -> void:
	_pending_line = {}
	_pending_march = {}


## Form up along a line drawn from `a` to `b`: the squad `only`, or the whole army (before
## the battle, the whole army always: it's placed there at once).
func _order_line(a: Vector2, b: Vector2, only) -> void:
	if not _storm_plan.is_empty():
		return
	if sim.phase != Sim.PHASE_BATTLE:
		only = null
	var spots := sim.order_line(Sim.PLAYER, a, b, only)
	if spots.is_empty():
		_hint("Cannot form a line there. Choose clear ground in the deployment zone.")
		return
	for spot in spots:
		_mark_ordered(spot["squad"])
	_line_shown = {"spots": spots, "face": sim.line_face(Sim.PLAYER, a, b), "at": _clock}
	Sound.play("page", 0.0, 0.05)
	if sim.phase == Sim.PHASE_DEPLOY:
		selected_id = -1
		_hand_placed.clear()
		_hint("Your army stands on the line. Drag again to redraw it, tap a squad to move it, or press Fight.", "line")
	elif only != null:
		_hint("%s form up along the line, %d men wide, and hold there." % [_company_or_type(only), int(spots[0]["files"])], "line")
	else:
		_hint("The army forms up along the line, each squad to its own stretch of it, and holds there.", "line")


## The squad whose standard is under a tap, or null.
func _standard_at(at: Vector2):
	var best = null
	var best_d := STANDARD_TAP
	for sq in _std_tops:
		var top: Vector2 = _std_tops[sq]
		var d := at.distance_to(top + FLAG * 0.5)
		if d < best_d:
			best_d = d
			best = sq
	return best


func _tap_deploy(p: Vector2, tapped) -> void:
	var mine = tapped if tapped != null and tapped.team == Sim.PLAYER else sim.squad_at(Sim.PLAYER, p)
	if sim.works != null and selected_id == -1 and mine == null:
		var eng = _engine_at(p)
		if eng != null:
			_hint(_engine_blurb(eng))
			return
	if mine != null:
		if mine.is_ally:
			_hint("%s are allied troops under their lord's command." % _company_or_type(mine))
			return
		if mine.roster_id == selected_id:
			_select_next_card() # tapping the picked-up squad again leaves it where it is
		else:
			selected_id = mine.roster_id
			_hint("Tap where you want %s to stand." % _company_or_type(mine), "place")
		return
	var foe = tapped if tapped != null and tapped.team == Sim.ENEMY else sim.squad_at(Sim.ENEMY, p, 52.0)
	if foe != null:
		_inspect(foe)
		return
	if selected_id == -1:
		var thint := _terrain_hint(p)
		if thint != "":
			_hint(thint)
			return
		if sim.all_placed(Sim.PLAYER):
			_hint("Tap one of your squads to move it, or press Fight.")
		else:
			_hint("Tap a card first.")
		return
	if not sim.in_deploy_zone(Sim.PLAYER, p):
		_hint("Place your squads in the blue zone, your half of the field.")
		return
	if sim.caught_on_march(Sim.PLAYER):
		_hint("No time to form up: they're on you from both ends. Press Fight.")
		return
	if sim.place(Sim.PLAYER, selected_id, p) == null:
		_hint("No room there. Try a more open spot.")
		return
	_hand_placed[selected_id] = true
	# The squad lands: a ring closes on the spot and dust kicks up.
	if not Style.motion_reduced():
		_burst(p, "land", Style.BRASS, 0.35)
		_burst(p, "dust", _ground_dust(p), 0.45)
	Sound.haptic()
	_select_next_card()


## Pick the first card not yet on the field, so placing a whole army is one tap per squad.
func _select_next_card() -> void:
	selected_id = -1
	for e in _cards:
		if sim.placed_squad(Sim.PLAYER, e["roster_id"]) == null:
			selected_id = e["roster_id"]
			_hint("Tap the blue zone to place %s, or drag a line for everyone." % _card_name(e), "place_next")
			return
	if sim.caught_on_march(Sim.PLAYER):
		_hint("Ambushed on the march, strung out along the road! No time to form up. Press Fight.")
		return
	_hint("Everyone's placed. Move a squad or drag a new line, then Fight.", "all_placed")


func _tap_battle(p: Vector2, tapped) -> void:
	var mine = tapped if tapped != null and tapped.team == Sim.PLAYER else sim.squad_at(Sim.PLAYER, p)
	if sim.works != null and _storm_plan.is_empty() and _tap_engines(p, mine):
		return
	if not _storm_plan.is_empty():
		# While the storm plan is up, a tap on one of your companies swaps its way in.
		if mine != null and mine.is_active() and not mine.is_ally:
			_swap_storm(mine)
		return
	if mine != null and mine.is_active():
		if mine.is_ally:
			_hint("%s are allied troops under their lord's command." % _company_or_type(mine))
			return
		_select(null if mine == selected_squad else mine)
		return
	var foe = tapped if tapped != null and tapped.team == Sim.ENEMY else sim.squad_at(Sim.ENEMY, p, 52.0)
	if selected_squad == null:
		if foe != null:
			_inspect(foe)
		else:
			var thint := _terrain_hint(p)
			if thint != "":
				_hint(thint)
			else:
				_hint("Tap a squad to command it, or drag a line across the field and tap it to re-form the army.")
		return
	if foe != null and foe.is_active():
		_pending_march = {}
		_order_attack(selected_squad, foe)
		return
	# Open ground: a ring goes down where the squad would march, and a second tap on it
	# sends them, so a stray tap only moves the ring. (Dragging the squad's flag marches it
	# in one go, with the matchup card shown on the way.)
	var why := _march_refusal(selected_squad, p)
	if why != "":
		_pending_march = {}
		_hint(why)
		return
	if not _pending_march.is_empty() and _pending_march["squad"] == selected_squad \
			and _to_screen(_pending_march["at"]).distance_to(_press_at) <= CONFIRM_TAP:
		var to: Vector2 = _pending_march["at"]
		_pending_march = {}
		_order_move(selected_squad, to)
		return
	_pending_march = {"squad": selected_squad, "at": p}
	_hint("%s: tap the ring again to march there." % _company_or_type(selected_squad))


func _select(sq) -> void:
	selected_squad = sq
	_drop_pending()
	if sq == null:
		_hint("Orders go to the whole army.", "army")
		return
	if not _taught:
		_taught = true
		_hint("%s: drag their flag onto an enemy to attack or onto ground to march, or drag a line to form them up along it." % _company_or_type(sq))
		return
	var ab := Troops.ability(sq.type)
	var who := _company_or_type(sq)
	if not sq.info.is_empty():
		who += ", led by %s (%s)" % [sq.info["first"], Captains.traits(sq.info)]
	_hint("%s. %s: %s" % [who, ab["name"], ab["blurb"]], "select_%s" % sq.type)


func _on_chip(index: int) -> void:
	if sim.winner != -1:
		return
	var e: Dictionary = _cards[index]
	if sim.phase == Sim.PHASE_BATTLE:
		var sq = sim.placed_squad(Sim.PLAYER, e["roster_id"])
		if sq == null or not sq.is_active():
			_hint("%s are out of the fight." % _card_name(e))
			return
		if not _storm_plan.is_empty():
			_swap_storm(sq)
			return
		_select(null if sq == selected_squad else sq)
		return
	if selected_id == e["roster_id"]:
		selected_id = -1
		_hint("Tap a card to place or move that squad.")
		return
	selected_id = e["roster_id"]
	var placed: bool = sim.placed_squad(Sim.PLAYER, selected_id) != null
	var level: int = e["level"]
	var veteran := " Level %d veterans." % level if level > 1 else ""
	_hint("%s%s %s" % [_card_story(e), veteran,
		"Tap the field to move them." if placed else "Tap the blue zone to place them."], "card_%d" % int(e["roster_id"]))


func _on_auto() -> void:
	sim.auto_deploy(Sim.PLAYER)
	_select_next_card()
	if sim.all_placed(Sim.PLAYER):
		_hint("Your army is in a battle line. Tap any squad to move it, then press Fight.")


func _on_fight() -> void:
	if sim.phase != Sim.PHASE_DEPLOY or sim.winner != -1:
		return
	if not sim.all_placed(Sim.PLAYER):
		_hint("Place every squad first, or tap Auto-place.")
		return
	_start_battle()
	_begin_title()


func _start_battle() -> void:
	sim.start_battle()
	_call("start", Sim.PLAYER)
	# The horn sounds the advance as the title goes up, and the music answers.
	Sound.play("horn", 0.0, 0.03)
	Sound.haptic(true)
	Sound.battle_clash()
	selected_id = -1
	selected_squad = null
	_drop_pending()
	_layout()
	_hint("Your squads hold, braced, until ordered. Tap a squad to command it, or drag a line across the field and tap it to re-form the army.", "start")


## Storm the walls, first tap: the plan goes up on the field (who takes a ladder, who goes
## to the ram) and the battle waits. Tapping a card swaps that company between ladder and
## ram; Storm! gives the order, Cancel drops it.
func _on_storm() -> void:
	if sim.phase != Sim.PHASE_BATTLE or sim.winner != -1 or sim.gate_hp <= 0.0:
		return
	_select(null)
	_storm_plan = sim.storm_plan(Sim.PLAYER)
	_hint(_storm_plan_text() + (" Tap a company to change its job." if sim.works != null and (sim.works.has("tower", Sim.PLAYER) or sim.works.has("thrower", Sim.PLAYER)) else " Tap a card to swap ladder and ram."), "storm_plan")


func _storm_plan_text() -> String:
	var ladders := PackedStringArray()
	var ram := PackedStringArray()
	var tower := PackedStringArray()
	var crews := PackedStringArray()
	for sq in sim.squads:
		if sq.team != Sim.PLAYER or not _storm_plan.has(sq.id) or sq.is_ally:
			continue
		var who := _captain_first(sq)
		if _storm_plan[sq.id] == "ladder":
			ladders.append(who)
		elif _storm_plan[sq.id] == "ram":
			ram.append(who)
		elif _storm_plan[sq.id] == "tower":
			tower.append(who)
		elif String(_storm_plan[sq.id]).begins_with("crew"):
			crews.append(who)
	var parts := PackedStringArray()
	if not tower.is_empty():
		parts.append("%s push%s the tower" % [_and_list(tower), "es" if tower.size() == 1 else ""])
	if not crews.is_empty():
		var thrower_name := "stone throwers"
		var ts: Array = sim.works.crewable(Sim.PLAYER).filter(func(e): return e.kind == "thrower") if sim.works != null else []
		if not ts.is_empty():
			thrower_name = sim.works.engine_name(ts[0]) + ("s" if ts.size() > 1 else "")
		parts.append("%s work%s the %s" % [_and_list(crews), "s" if crews.size() == 1 else "", thrower_name])
	if not ladders.is_empty():
		parts.append("%s take%s the ladders" % [_and_list(ladders), "s" if ladders.size() == 1 else ""])
	if not ram.is_empty():
		parts.append("%s go%s to the ram" % [_and_list(ram), "es" if ram.size() == 1 else ""])
	if _storm_plan.values().has("bows"):
		parts.append("the bows shoot the walls")
	return "; ".join(parts) + "." if not parts.is_empty() else "Everyone advances on the walls."


func _and_list(names: PackedStringArray) -> String:
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[names.size() - 1]


## A squad's captain's first name, or what the squad is.
func _captain_first(sq) -> String:
	if not sq.info.is_empty():
		return String(sq.info["first"])
	return _company_or_type(sq)


func _on_storm_go() -> void:
	if _storm_plan.is_empty() or sim.winner != -1:
		_storm_plan = {}
		return
	sim.order_storm(Sim.PLAYER, _storm_plan)
	_storm_plan = {}
	for sq in sim.squads:
		if sq.team == Sim.PLAYER and sq.is_active():
			_mark_ordered(sq)
	Sound.play("charge", 0.0, 0.05, 0.6)
	Sound.haptic(false)
	_hint("Storm the walls! The ladder men climb, the rest put the ram to the gate, the bows shoot the walls.", "storm_go")


func _on_storm_cancel() -> void:
	_storm_plan = {}
	_hint("Orders go to the whole army.", "army")


## On the storm plan, a tapped card moves its company to its next job: ladder, ram, the
## siege tower, the stone throwers (the jobs there are for it).
func _swap_storm(sq) -> void:
	if not _storm_plan.has(sq.id) or String(_storm_plan[sq.id]) == "bows":
		_hint("%s shoot the walls." % _company_or_type(sq))
		return
	var jobs := []
	if sim.can_climb(sq):
		jobs.append("ladder")
	jobs.append("ram")
	if sim.works != null:
		var tower = sim.works.tower_of(Sim.PLAYER)
		if tower != null and not tower.docked and sim.can_climb(sq):
			jobs.append("tower")
		var throwers: Array = sim.works.crewable(Sim.PLAYER).filter(func(e): return e.kind == "thrower")
		if not throwers.is_empty():
			jobs.append("crew:%d" % throwers[0].id)
	if jobs.size() <= 1:
		_hint("%s can't climb a ladder." % _company_or_type(sq))
		return
	var now := String(_storm_plan[sq.id])
	var i := jobs.find(now)
	_storm_plan[sq.id] = jobs[(i + 1) % jobs.size()]
	_hint(_storm_plan_text(), "storm_swap")


func _on_advance() -> void:
	if sim.phase != Sim.PHASE_BATTLE or sim.winner != -1:
		return
	_drop_pending()
	if selected_squad != null:
		sim.order_advance(selected_squad)
		_mark_ordered(selected_squad)
		_hint("%s advance on the enemy they fight best." % _company_or_type(selected_squad), "advance")
	else:
		sim.order_all(Sim.PLAYER, "advance")
		for sq in sim.squads:
			if sq.team == Sim.PLAYER:
				_mark_ordered(sq)
		if sim.objective == Sim.OBJECTIVE_SIEGE and sim.siege_defender == Sim.PLAYER:
			_hint("Sally! The garrison leaves its posts and goes for the enemy.", "advance")
		else:
			_hint("The whole army advances. Each squad goes for the enemy it fights best.", "advance")


## Defending a siege: send every company to its post on the walls, or, once the gate is
## down, the foot to the crescent behind it.
func _on_post() -> void:
	if sim.phase != Sim.PHASE_BATTLE or sim.winner != -1 or sim.siege_defender != Sim.PLAYER:
		return
	_select(null)
	if sim.gate_hp > 0.0:
		sim.man_the_walls(Sim.PLAYER)
		_hint("Man the walls! Bows to the walk, a company to the gate tower with stones, the rest behind the gate.", "post")
	else:
		var sent: Array = sim.form_breach(Sim.PLAYER)
		_hint("Hold the breach! %s form up behind the gate and let them come." % ("Your foot" if sent.size() != 1 else _company_or_type(sent[0])), "post_breach")
	for sq in sim.squads:
		if sq.team == Sim.PLAYER and sq.is_active() and not sq.is_ally:
			_mark_ordered(sq)
	Sound.play("call_start", 0.0, 0.05, 0.6)
	Sound.haptic(false)


func _on_hold() -> void:
	if sim.phase != Sim.PHASE_BATTLE or sim.winner != -1:
		return
	_drop_pending()
	# The first Hold says what bracing is (the README's rule, in a sentence).
	if selected_squad != null:
		sim.order_hold(selected_squad)
		_mark_ordered(selected_squad)
		_hint("%s hold where they stand. %s" % [_company_or_type(selected_squad), BRACED_WORDS], "hold")
	else:
		sim.order_all(Sim.PLAYER, "hold")
		for sq in sim.squads:
			if sq.team == Sim.PLAYER:
				_mark_ordered(sq)
		_hint("The whole army holds and fights anyone who comes close. %s" % BRACED_WORDS, "hold")


func _on_ability() -> void:
	var sq = selected_squad
	if sim.winner != -1:
		return
	if sq == null:
		_volley_all()
		return
	var ab := Troops.ability(sq.type)
	if sim.use_ability(sq):
		_hint("%s: %s" % [ab["name"], ab["blurb"]], "ability_%s" % sq.type)
	elif sq.ability_cd > 0.0:
		_hint("%s is ready again in %d seconds." % [ab["name"], ceili(sq.ability_cd)])
	elif sq.type == Troops.ARCHERS:
		_hint("No enemy in bow range." if sq.arrows > 0 else "Out of arrows.")


## With no squad selected: every company of archers that can looses a volley at once.
func _volley_all() -> void:
	var fired := 0
	var soonest := INF
	for bow in _player_bows(true):
		if sim.use_ability(bow):
			fired += 1
			_mark_ordered(bow)
		elif bow.ability_cd > 0.0:
			soonest = minf(soonest, float(bow.ability_cd))
	if fired > 0:
		_hint("Volley from %d compan%s of bows." % [fired, "y" if fired == 1 else "ies"])
	elif soonest < INF:
		_hint("Volley is ready again in %d seconds." % ceili(soonest))
	else:
		_hint("No enemy in bow range.")


## Your companies still shooting (arrows left), not your allies'; only archers with
## `volley_only`, since horse archers' ability is the wheel.
func _player_bows(volley_only: bool = false) -> Array:
	var out := []
	for bow in sim.squads:
		if bow.team == Sim.PLAYER and bow.is_active() and not bow.is_ally and bow.ranged and (not volley_only or bow.type == Troops.ARCHERS):
			out.append(bow)
	return out


## Archers keep their arrows, or loose at will again: the selected company, or with none
## selected every company of bows.
func _on_hold_fire() -> void:
	var sq = selected_squad
	if sim.winner != -1:
		return
	if sq == null:
		var bows := _player_bows()
		if bows.is_empty():
			return
		var hold: bool = not bows.all(func(holder): return holder.hold_fire)
		for bow in bows:
			sim.set_hold_fire(bow, hold)
			_mark_ordered(bow)
		_hint("Every company of bows holds its fire and keeps its arrows." if hold else "Every company of bows looses at will.")
		return
	if not sq.ranged:
		return
	sim.set_hold_fire(sq, not sq.hold_fire)
	_mark_ordered(sq)
	if sq.hold_fire:
		_hint("%s hold their fire and keep their arrows. They draw blades if the enemy reaches them." % _company_or_type(sq), "holdfire")
	else:
		_hint("%s loose at will." % _company_or_type(sq), "loose")


func _on_menu() -> void:
	if sim.winner != -1:
		return
	_set_paused(not paused)


## Escape (the Scenes autoload turns the phone's back button into Escape too): shuts what
## is open over the field (the ground card, the pause card, the title, an order waiting
## for its second tap, the storm plan), else pauses.
func _on_back() -> void:
	if _result_shown or sim.winner != -1:
		return
	if terrain_hint_panel.visible:
		terrain_hint_panel.visible = false
	elif paused:
		_set_paused(false)
	elif not _title.is_empty():
		_end_title()
	elif not _pending_line.is_empty() or not _pending_march.is_empty():
		_drop_pending()
	elif not _storm_plan.is_empty():
		_on_storm_cancel()
	else:
		_set_paused(true)


func _set_paused(on: bool) -> void:
	paused = on and sim.winner == -1
	_release_slow()
	pause_panel.visible = paused
	_retreat_armed = 0.0
	_retreat_words()


## The Retreat button says what pulling out costs, and the note over it why: men left
## behind as the companies break off, or, with no way out, a run for your edge with the
## enemy cutting down whoever they catch. `armed`: the first tap is in, waiting for the second.
func _retreat_words(armed: bool = false) -> void:
	retreat_button.visible = sim.withdrawing == -1
	var text := "Tap again to retreat" if armed else "Retreat"
	var note := ""
	if _cut_off:
		text = "Tap again to run for it" if armed else "Retreat: run for it"
		note = "There is no way out: they hold the road. Retreat and every company breaks and runs for your edge, and they cut down whoever they catch."
	elif sim.phase != Sim.PHASE_BATTLE:
		note = "Leave before the fight and you lose no men."
	else:
		var cost: int = sim.withdraw_cost(Sim.PLAYER)
		if cost > 0:
			text = ("Tap again: leave %d men" if armed else "Retreat: lose %d men") % cost
			note = "Pulling out costs %d men, cut down as your companies break off: more from those locked in a fight." % cost
	retreat_button.text = text
	pause_note.text = note
	pause_note.visible = note != ""


func _on_speed() -> void:
	speed = 2.0 if speed < 1.5 else 1.0


func _on_retreat() -> void:
	if sim.winner != -1 or sim.withdrawing != -1:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _retreat_armed:
		_set_paused(false)
		if not _cut_off:
			sim.concede(Sim.PLAYER)
			return
		# Cut off: the battle goes on while your men run for it.
		if sim.phase == Sim.PHASE_DEPLOY:
			_start_battle()
		sim.concede(Sim.PLAYER, true)
		selected_squad = null
		_drop_pending()
		_call("retreat", Sim.PLAYER)
		_moment("Run for it!", "Every company breaks for your edge", Style.ENEMY_LIGHT, "retreat", true)
		return
	_retreat_armed = now + 3.0
	_retreat_words(true)


## A line over the field, above the orders, that fades after a few seconds. Refusals,
## answers to a tap and first sights always show. A narration of an order the field
## already confirms with a mark (`key`) shows once a battle, and only in a campaign's
## first few battles, while the player is learning what the marks mean.
##
## A keyed line that isn't a narration (`narration` false: a state the field has just
## changed, like a company running out of arrows) shows once a battle in every battle.
func _hint(text: String, key: String = "", narration: bool = true) -> void:
	if hint_label == null:
		return
	if key != "":
		if _hinted.has(key) or (narration and not _order_words):
			return
		_hinted[key] = true
	hint_label.text = text
	_hint_age = 0.0 if text != "" else 99.0
	if hint_toast != null:
		hint_toast.visible = text != ""
		hint_toast.modulate.a = 1.0


## The hint toast and the enemy readout fade on their own clocks, paused or not.
func _age_overlays(delta: float) -> void:
	if hint_toast != null and hint_toast.visible:
		_hint_age += delta
		var life := HINT_LIFE + 0.03 * hint_label.text.length()
		hint_toast.modulate.a = clampf((life - _hint_age) / HINT_FADE, 0.0, 1.0)
		if _hint_age >= life:
			hint_toast.visible = false
	if inspect_pill != null and inspect_pill.visible:
		_inspect_age += delta
		inspect_pill.modulate.a = clampf((INSPECT_LIFE - _inspect_age) / HINT_FADE, 0.0, 1.0)
		if _inspect_age >= INSPECT_LIFE:
			inspect_pill.visible = false


# ---------------------------------------------------------------- words

## What a troop type is called on one side: in the enemy's words, or for one of your
## squads in the words of the culture it was raised in (yours unless you hired it abroad).
func _name(type: String, team: int = Sim.PLAYER, roster_id: int = -1) -> String:
	if team != Sim.PLAYER:
		var foe = sim.placed_squad(Sim.ENEMY, roster_id) if roster_id != -1 else null
		return Units.troop_name({"unit": foe.unit if foe != null else "", "type": type}, _enemy_culture)
	var record := _squad_record(roster_id)
	if record.is_empty():
		record = {"type": type}
	return Units.troop_name(record, GameState.culture)


## "Brann's Shields, led by Brann of Ostmark (Vengeful, Lucky). Bonds: Mira (B)."
func _led_by(sq) -> String:
	if sq.info.is_empty():
		return "%s, without a captain." % _company_or_type(sq)
	var who := "%s, led by %s (%s)" % [_company(sq.roster_id), sq.info["name"], Captains.traits(sq.info)]
	if sq.captain == null:
		who = "%s. %s is down" % [_company(sq.roster_id), sq.info["name"]]
	return who + _bond_text(sq.info) + "."


func _card_story(e: Dictionary) -> String:
	var squad := _squad_record(e["roster_id"])
	var c = squad.get("captain")
	if c == null:
		return "%s have no captain." % squad.get("name", _name(e["type"], Sim.PLAYER, e["roster_id"]))
	if int(c.get("wounded", 0)) > 0:
		return "%s is wounded and sits this one out (%d more). %s fight without a captain." % [c["name"], c["wounded"], squad["name"]]
	return "%s, led by %s (%s)%s." % [squad["name"], c["name"], Captains.traits(c), _bond_text(c)]


func _card_name(e: Dictionary) -> String:
	var name := String(_squad_record(e["roster_id"]).get("name", ""))
	return name if name != "" else "your " + _name(e["type"], Sim.PLAYER, e["roster_id"]).to_lower()


func _bond_text(c: Dictionary) -> String:
	var parts := PackedStringArray()
	for other_id in c.get("bonds", {}):
		var rank := Captains.rank_letter(float(c["bonds"][other_id]))
		var other = GameState.captain_by_id(int(other_id))
		if rank != "" and other != null:
			parts.append("%s (%s)" % [other["first"], rank])
	return "" if parts.is_empty() else ". Bonds: " + ", ".join(parts)


func _squad_record(roster_id: int) -> Dictionary:
	for s in GameState.army:
		if int(s["id"]) == roster_id:
			return s
	return {}


func _company(roster_id: int) -> String:
	return String(_squad_record(roster_id).get("name", ""))


func _company_or_type(sq) -> String:
	if sq.team == Sim.PLAYER:
		var name := _company(sq.roster_id)
		if name != "":
			return name
		return "Your " + _name(sq.type, Sim.PLAYER, sq.roster_id).to_lower()
	return "The enemy " + _name(sq.type, Sim.ENEMY).to_lower()


func _describe(sq) -> String:
	var text := "Enemy %s · %d men" % [_name(sq.type, Sim.ENEMY).to_lower(), sq.alive_count()]
	if not sq.info.is_empty():
		text += " · Captain %s%s" % [sq.info["name"], "" if sq.captain != null else " (down)"]
	if sq.level > 1:
		text += " · Lv%d" % sq.level
	if sq.arrows == 0:
		text += " · out of arrows"
	if sq.routing:
		text += " · running"
	elif sim.phase == Sim.PHASE_BATTLE:
		text += " · %d%% morale" % maxi(0, int(sq.morale))
	return "%s. %s" % [text, Troops.stats(sq.type)["blurb"]]


## A tapped enemy read at a glance under the objective: its sprite, its men, its morale,
## its level as pips, and a skull for a captain at its head. The sentence it replaces
## (with the troop's blurb) is the pill's tooltip.
func _inspect(sq) -> void:
	if inspect_pill == null:
		return
	for c in inspect_pill.get_children():
		inspect_pill.remove_child(c)
		c.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	inspect_pill.add_child(row)
	var sprite := TextureRect.new()
	sprite.texture = Art.icon(sq.type, Sim.ENEMY, _culture_of(sq))
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.custom_minimum_size = Vector2(44, 44)
	row.add_child(sprite)
	var name_label := Style.label(_name(sq.type, Sim.ENEMY), Style.SMALL, Style.ENEMY_LIGHT)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	var men := Widgets.icon_value("men", str(sq.alive_count()))
	men.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(men)
	if sim.phase == Sim.PHASE_BATTLE and not sq.routing:
		var m := Widgets.meter(sq.morale / 100.0, Style.morale_color(sq.morale), 12.0)
		m.custom_minimum_size.x = 80.0
		m.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		m.tooltip_text = "%d%% morale" % maxi(0, int(sq.morale))
		row.add_child(m)
		# The number beside it, so the meter reads without its colour.
		var nerve := Style.label("%d" % maxi(0, int(sq.morale)), Style.SMALL, Style.morale_color(sq.morale))
		nerve.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(nerve)
	elif sq.routing:
		var run := Widgets.icon_rect("retreat", 28.0)
		run.modulate = Style.MORALE_LOW
		row.add_child(run)
	if sq.level > 1:
		row.add_child(_pips(sq.level - 1, Style.BRASS))
	if sq.arrows == 0:
		var q := Widgets.icon_rect("holdfire", 28.0)
		q.modulate = Style.MUTED
		row.add_child(q)
	if not sq.info.is_empty():
		var skull := Widgets.icon_rect("skull", 28.0)
		skull.modulate = Style.ENEMY_LIGHT if sq.captain != null else Style.MUTED
		row.add_child(skull)
	inspect_pill.tooltip_text = _describe(sq)
	inspect_pill.visible = true
	inspect_pill.modulate.a = 1.0
	inspect_pill.reset_size()
	_inspect_age = 0.0


## `n` small filled dots: a level's pips, a wound's battles out.
func _pips(n: int, color: Color, r: float = 5.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(n * (r * 2.0 + 5.0), r * 2.0 + 4.0)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		for i in n:
			c.draw_circle(Vector2(r + 1.0 + i * (r * 2.0 + 5.0), c.size.y * 0.5), r, color))
	return c


func _scouting() -> String:
	var ai = sim.ai[Sim.ENEMY]
	return String(Commander.SCOUTING.get(ai.temperament, "")) if ai != null else ""


# ---------------------------------------------------------------- sound

## The din of the fight: steel ringing faster the more squads are locked in melee, a
## rush of air when a volley goes up, and the music swelling with the fighting.
func _battle_sounds(delta: float) -> void:
	var engaged := 0
	var active := 0
	var foot_moving := false
	var cavalry_moving := false
	# Who is winning: the men still standing on each side, weighed by their morale.
	var strength := [0.0, 0.0]
	var fighting := []
	for sq in sim.squads:
		if sq.is_active():
			active += 1
			if sq.engaged:
				engaged += 1
				fighting.append(sq)
			if not sq.routing:
				strength[sq.team] += float(sq.alive_count()) * clampf(sq.morale / 100.0, 0.15, 1.0)
			if sq.team == Sim.PLAYER and not sq.engaged and sq.order != "hold":
				if sq.type == Troops.CAVALRY:
					cavalry_moving = true
				else:
					foot_moving = true
			if sq.team == Sim.PLAYER and sq.morale <= 35.0 and not _low_morale_heard.has(sq.id):
				_low_morale_heard[sq.id] = true
				Sound.play("morale_low", 0.0, 0.02, 1.0)
			# Wavering: warned once, before the break.
			if wavering(sq) and not _wavered.has(sq):
				_wavered[sq] = true
				var mine_w: bool = sq.team == Sim.PLAYER
				if mine_w:
					_tick("%s is wavering. Pull them back or send help." % _company_or_type(sq), Style.MORALE_LOW)
			# A squad that has just come to a halt settles into its ground.
			var was_order := String(_prev_order.get(sq, "hold"))
			if was_order == "hold":
				was_order = String(_pre_step_order.get(sq, "hold"))
			if sq.team == Sim.PLAYER and sq.order == "hold" and was_order != "hold" and not sq.engaged:
				_settled_at[sq] = _clock
			_prev_order[sq] = sq.order
	Sound.set_movement_loop("hooves" if cavalry_moving else ("footsteps" if foot_moving else ""))
	Sound.set_battle_intensity(float(engaged) / maxf(1.0, active) * 1.6)
	var total: float = strength[Sim.PLAYER] + strength[Sim.ENEMY]
	if sim.phase == Sim.PHASE_BATTLE and total > 0.0:
		Sound.set_battle_balance((strength[Sim.PLAYER] - strength[Sim.ENEMY]) / total * 1.5)
	# The din of the melee under everything, and over it single blows where the lines meet,
	# of the kinds the men fighting there trade.
	Sound.set_melee(clampf(float(engaged) / 6.0, 0.0, 1.0) if sim.phase == Sim.PHASE_BATTLE else 0.0)
	Sound.set_field_distance(1.0 - (cam_zoom - 1.0) / maxf(0.01, MAX_ZOOM - 1.0))
	if engaged > 0 and _roll.is_empty() and _hitstop <= 0.0:
		_clash_clock -= delta * speed * (0.6 + engaged * 0.3)
		if _clash_clock <= 0.0:
			_clash_clock = randf_range(0.22, 0.5)
			var sq = fighting[randi() % fighting.size()]
			var kinds: Array = BLOWS.get(sq.type, ["sword"])
			Sound.play_at(String(kinds[randi() % kinds.size()]), _to_screen(sq.average_pos()), randf_range(-2.5, 0.0), 0.08)
	# Each kind of missile has its own sound going up, where it was loosed, and coming down,
	# where it lands, played when enough of them fly at once.
	var loosed := {}
	var landed := {}
	var seen := {}
	for p in sim.projectiles:
		seen[p] = [_missile_sound(p), p.pos]
		if not _heard.has(p):
			_tally(loosed, String(seen[p][0]), p.origin)
	for p in _heard:
		if not seen.has(p):
			_tally(landed, LANDING[String(_heard[p][0])], _heard[p][1])
			var down: Vector2 = _heard[p][1]
			_puff(down, Vector2(0, -6), 2.0, 6.0, 0.5, _ground_dust(down), 0.35)
	_heard = seen
	for kind in loosed:
		if int(loosed[kind][0]) >= (6 if kind == "arrows" else 3):
			Sound.play_at(kind, _to_screen(loosed[kind][1] / float(loosed[kind][0])), 0.0, 0.08, 0.6)
	for kind in landed:
		if int(landed[kind][0]) >= (4 if kind == "arrows_land" else 2):
			Sound.play_at(kind, _to_screen(landed[kind][1] / float(landed[kind][0])), 0.0, 0.08, 0.25)
	# The ram: a blow each time it swings home.
	if sim.objective == Sim.OBJECTIVE_SIEGE and sim.gate_hp > 0.0 and sim.gate_blows > 0.0:
		var swing := sin(_clock * 7.0)
		if _ram_swing < 0.9 and swing >= 0.9:
			Sound.play_at("ram", _to_screen(sim.gate_center), 0.0, 0.05)
		_ram_swing = swing


## The sound of each missile coming down.
const LANDING := {"arrows": "arrows_land", "horsebow": "arrows_land", "crossbow": "bolts_land", "javelin": "javelins_land"}


## Count a missile of `kind` at `pos` into `tally` (kind -> [count, summed position]).
func _tally(tally: Dictionary, kind: String, pos: Vector2) -> void:
	var t: Array = tally.get(kind, [0, Vector2.ZERO])
	tally[kind] = [int(t[0]) + 1, Vector2(t[1]) + pos]


## A side's call (its realm's horn, shawm or conch): "start", "charge" or "retreat".
func _call(which: String, team: int) -> void:
	var culture := String(GameState.culture) if team == Sim.PLAYER else _enemy_culture
	if not ["vardish", "kharzani", "ryumon"].has(culture):
		culture = "vardish"
	Sound.play("call_%s_%s" % [which, culture], 0.0, 0.0, 4.0)


## The sound a missile makes going up: a javelin, a crossbow bolt, a horse archer's
## arrow, or a plain arrow.
func _missile_sound(p) -> String:
	if p.kind == "javelin":
		return "javelin"
	if p.source != null and CROSSBOWS.has(p.source.unit):
		return "crossbow"
	if p.source != null and p.source.type == Troops.CAVALRY:
		return "horsebow"
	return "arrows"


# ---------------------------------------------------------------- events

## Each land builds its own: [stone, stone light, stone dark, wall walk, courtyard paving,
## roof, roof light, keep top]; and whether towers are round, keeps domed or tiered.
const CASTLE_STYLES := {
	"vardish": {"stone": Color("8a8d94"), "light": Color("b0b3ba"), "dark": Color("5b5e66"), "walk": Color("9a9da4"),
		"paving": Color("6b6e74"), "roof": Color("4a5262"), "roof_light": Color("5e687c"), "top": Color("6e7178"),
		"round": false, "dome": false, "tiers": false, "dome_color": Color("3a8a8a")},
	"kharzani": {"stone": Color("c99a5c"), "light": Color("e2bc80"), "dark": Color("94683a"), "walk": Color("d6aa6c"),
		"paving": Color("b89a62"), "roof": Color("e8dcc4"), "roof_light": Color("f4ead8"), "top": Color("b07e48"),
		"round": true, "dome": true, "tiers": false, "dome_color": Color("3a8a8a")},
	"ryumon": {"stone": Color("7a7468"), "light": Color("f0ece2"), "dark": Color("55504a"), "walk": Color("e8e2d4"),
		"paving": Color("8a8478"), "roof": Color("2a2a34"), "roof_light": Color("3c3c4a"), "top": Color("f0ece2"),
		"round": false, "dome": false, "tiers": true, "dome_color": Color("3a8a8a")},
}
## Towers along the wall, by column (clear of the gate and the ladders).
const TOWER_COLS := [1, 9, 18, 26]


## The castle: its courtyard with the keep and houses, the wall with its towers and
## battlements, the gatehouse and its gate (cracking as it weakens), the ladders, and the
## ram when it's at work.
func _draw_walls() -> void:
	var st: Dictionary = CASTLE_STYLES.get(_castle_culture, CASTLE_STYLES["vardish"])
	var cell := Terrain.CELL
	var top: float = sim.wall_row * cell
	var w: float = Sim.ARENA.x
	# `inward` points from the wall into the courtyard.
	var inward := -1.0 if sim.siege_defender == Sim.ENEMY else 1.0
	var court := Rect2(0, 0, w, top) if inward < 0.0 else Rect2(0, top + cell, w, Sim.ARENA.y - top - cell)
	_c.draw_rect(court, Color(st["paving"], 0.55))
	for cy in range(int(court.position.y / cell), int(court.end.y / cell)):
		for cx in Terrain.COLS:
			if (cx * 7 + cy * 13) % 5 == 0:
				_c.draw_rect(Rect2(cx * cell + 3.0 + (cy % 2) * 12.0, cy * cell + 4.0, 14.0, 9.0), Color(Color(st["paving"]).lightened(0.12), 0.45))
	# Buildings.
	for b in sim.castle_buildings:
		var cr: Rect2i = b["cell"]
		var r := Rect2(cr.position.x * cell, cr.position.y * cell, cr.size.x * cell, cr.size.y * cell).grow(-3.0)
		_c.draw_rect(Rect2(r.position + Vector2(7, 7), r.size), Color(0, 0, 0, 0.35))
		if String(b["kind"]) == "keep":
			_c.draw_rect(r, st["stone"])
			_c.draw_rect(r.grow(-7.0), st["top"])
			var x := r.position.x
			while x < r.end.x - 4.0:
				_c.draw_rect(Rect2(x, r.position.y - 4.0, 8.0, 7.0), st["light"])
				_c.draw_rect(Rect2(x, r.end.y - 3.0, 8.0, 7.0), st["light"])
				x += 14.0
			if st["dome"]:
				_c.draw_circle(r.get_center(), minf(r.size.x, r.size.y) * 0.32, st["dome_color"])
				_c.draw_circle(r.get_center() - Vector2(8, 8), minf(r.size.x, r.size.y) * 0.1, Color(st["dome_color"]).lightened(0.3))
			elif st["tiers"]:
				_c.draw_rect(r.grow(-16.0), st["roof"])
				_c.draw_rect(r.grow(-30.0), st["roof_light"])
			else:
				_c.draw_rect(r.grow(-20.0), Color(st["top"]).darkened(0.15))
			# the realm's flag over the keep
			var pole := Vector2(r.end.x - 10.0, r.position.y + 8.0)
			var held := _garrison_realm if sim.siege_defender == Sim.ENEMY else _my_realm
			Heraldry.realm_banner(_c, held if Heraldry.REALM_SIZES.has(held) else "bandits", Rect2(pole + Vector2(-2, -62), Vector2(46, 64)),
				true, false, Transform2D(0.0, Vector2(field_scale, field_scale), 0.0, field_origin))
		else:
			_c.draw_rect(r, st["roof"])
			_c.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.5)), st["roof_light"])
			_c.draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), Color(st["roof"]).darkened(0.3), 2.0)
			if st["dome"]:
				_c.draw_circle(r.get_center(), minf(r.size.x, r.size.y) * 0.28, st["dome_color"])
	# The wall walk's depth: the stretch behind the battlements where men are covered.
	var cover: float = Sim.WALL_COVER - cell * 0.5
	var band := Rect2(0, top - cover, w, cover) if inward < 0.0 else Rect2(0, top + cell, w, cover)
	_c.draw_rect(band, Color(st["walk"], 0.55))
	var inner_y: float = band.position.y if inward < 0.0 else band.end.y
	_c.draw_line(Vector2(0, inner_y), Vector2(w, inner_y), Color(st["dark"], 0.7), 2.0)
	# The wall: its body, a wall walk on the inside, battlements on the outside.
	var body := Rect2(0, top, w, cell)
	_c.draw_rect(Rect2(body.position + Vector2(0, 8.0 * -inward), body.size), Color(0, 0, 0, 0.3))
	_c.draw_rect(body, st["stone"])
	var walk_y := top + (cell - 4.0 if inward > 0.0 else -10.0)
	_c.draw_rect(Rect2(0, walk_y, w, 14.0), st["walk"])
	var outer_y := top + (cell if inward < 0.0 else -8.0)
	var x2 := 0.0
	while x2 < w:
		_c.draw_rect(Rect2(x2 + 2.0, outer_y, 9.0, 8.0), st["light"])
		x2 += 15.0
	_c.draw_rect(Rect2(0, top + cell - 5.0 if inward < 0.0 else top, w, 5.0), st["dark"])
	# Towers.
	for tc in TOWER_COLS:
		var tr := Rect2(tc * cell - 6.0, top - 14.0, cell + 12.0, cell + 28.0)
		_c.draw_rect(Rect2(tr.position + Vector2(5, 6), tr.size), Color(0, 0, 0, 0.3))
		_c.draw_rect(tr, st["stone"])
		if st["round"]:
			_c.draw_circle(tr.get_center(), tr.size.x * 0.36, st["roof"])
			_c.draw_circle(tr.get_center(), tr.size.x * 0.2, st["roof_light"])
		elif st["tiers"]:
			_c.draw_rect(tr.grow(-5.0), st["roof"])
			_c.draw_rect(tr.grow(-11.0), st["roof_light"])
		else:
			_c.draw_rect(tr.grow(-5.0), st["top"])
			var bx := tr.position.x
			while bx < tr.end.x - 3.0:
				_c.draw_rect(Rect2(bx, tr.position.y - 4.0, 6.0, 5.0), st["light"])
				bx += 10.0
	# The gatehouse and its gate.
	var gate := Rect2(Sim.GATE_COLS[0] * cell, top, cell * Sim.GATE_COLS.size(), cell)
	for side in [-1.0, 1.0]:
		var gx := gate.position.x - 34.0 if side < 0.0 else gate.end.x + 4.0
		var gt := Rect2(gx, top - 18.0, 30.0, cell + 36.0)
		_c.draw_rect(Rect2(gt.position + Vector2(5, 6), gt.size), Color(0, 0, 0, 0.3))
		_c.draw_rect(gt, st["stone"])
		_c.draw_rect(gt.grow(-5.0), st["top"])
	var share := sim.gate_hp / maxf(1.0, sim.gate_max)
	if sim.gate_hp > 0.0:
		_c.draw_rect(gate, Color("2a1a10"))
		for i in 7:
			var gx2 := gate.position.x + 3.0 + i * (gate.size.x - 6.0) / 6.0
			_c.draw_line(Vector2(gx2, gate.position.y), Vector2(gx2, gate.end.y), Color("8a8f98"), 2.0)
		for j in 4:
			var gy := gate.position.y + 3.0 + j * (gate.size.y - 6.0) / 3.0
			_c.draw_line(Vector2(gate.position.x, gy), Vector2(gate.end.x, gy), Color("8a8f98"), 2.0)
		# cracks as it weakens
		var cracks := int((1.0 - share) * 6.0)
		for k in cracks:
			var a := gate.position + Vector2(6.0 + (k * 17) % int(gate.size.x - 12.0), 3.0 + (k * 7) % 10)
			_c.draw_polyline(PackedVector2Array([a, a + Vector2(5, 7), a + Vector2(1, 14), a + Vector2(6, 22)]), Color("e8a03c"), 2.0)
	else:
		for i in 5:
			var a2 := gate.position + Vector2(4.0 + i * 11.0, 4.0 + (i % 2) * 14.0)
			_c.draw_line(a2, a2 + Vector2(9.0, 6.0 - (i % 3) * 5.0), Color("6b4a2a"), 3.0)
	# Ladders against the outside of the wall.
	for lp in sim.ladder_points():
		var foot := Vector2(lp.x, top + (cell + 30.0 if inward < 0.0 else -30.0))
		var head := Vector2(lp.x, top + (-4.0 if inward < 0.0 else cell + 4.0))
		for rail in [-7.0, 7.0]:
			_c.draw_line(foot + Vector2(rail, 0), head + Vector2(rail * 0.7, 0), Color("8a5a2a"), 3.0)
		var t := 0.0
		while t <= 1.0:
			var p := foot.lerp(head, t)
			_c.draw_line(p + Vector2(-7, 0), p + Vector2(7, 0), Color("8a5a2a"), 2.0)
			t += 0.12
	# The ram under its roof, swinging while men work it (drawn as an engine when the
	# siege has its engines: see _draw_engines).
	if sim.gate_hp > 0.0 and sim.gate_blows > 0.0 and sim.works == null:
		var swing := 4.0 * sin(_clock * 7.0) if not Style.motion_reduced() else 0.0
		var outside := -inward
		var shed := Rect2(gate.get_center().x - 18.0, 0, 36.0, 46.0)
		shed.position.y = (gate.end.y + 4.0) if outside > 0.0 else (gate.position.y - 50.0)
		_c.draw_rect(Rect2(shed.position + Vector2(4, 4), shed.size), Color(0, 0, 0, 0.3))
		_c.draw_rect(shed, Color("6e4629"))
		var py := shed.position.y + 4.0
		while py < shed.end.y:
			_c.draw_line(Vector2(shed.position.x, py), Vector2(shed.end.x, py), Color("4a2f1c"), 2.0)
			py += 7.0
		var log_tip := Vector2(gate.get_center().x, gate.end.y - 4.0 if outside > 0.0 else gate.position.y + 4.0) + Vector2(0, swing * outside)
		_c.draw_line(log_tip, log_tip + Vector2(0, 58.0 * outside), Color("c09060"), 8.0)
		_c.draw_circle(log_tip, 5.0, Color("5b5e66"))


func _consume_events() -> void:
	# Charges that strike near your men this frame: one stop and one shake for all of them.
	var struck := 0
	var struck_dir := Vector2.ZERO
	var struck_at := Vector2.ZERO
	for e in sim.events:
		match e["type"]:
			"ram_at_gate":
				if sim.siege_defender == Sim.PLAYER:
					_tick("Their ram is at the gate!", Style.ENEMY_LIGHT, "ram")
				else:
					_tick("The ram is at the gate!", Style.PLAYER_LIGHT, "ram")
			"ladders_up":
				Sound.play_at("ladders", _to_screen(Vector2(sim.gate_center.x, sim.wall_y)))
				if sim.siege_defender == Sim.PLAYER:
					_tick("They're on the ladders! Throw them down!", Style.ENEMY_LIGHT, "ladder")
				else:
					_tick("Your men are on the ladders!", Style.PLAYER_LIGHT, "ladder")
			"stones":
				_drop_stones(e["at"])
			"engine_throw", "engine_bolt", "stone_lands", "wall_hit", "gate_hit", "wall_breached", "tower_docked", \
					"engine_burning", "engine_lost", "oil", "fire_arrows", "sally_out", "engine_fire_out":
				_engine_event(e)
			"siege_moment":
				var sq = e["squad"]
				var mine: bool = sq.team == Sim.PLAYER
				if e["kind"] == "stones":
					if mine:
						_tick("%s drop stones on the ram!" % _company_or_type(sq), Style.PLAYER_LIGHT, "gate")
					else:
						_tick("Stones from the gatehouse!", Style.ENEMY_LIGHT, "gate")
				elif e["kind"] == "thrown_down":
					if mine:
						_tick("%s throw them off the ladder!" % _company_or_type(sq), Style.PLAYER_LIGHT, "ladder")
					else:
						_tick("Thrown from the ladder!", Style.ENEMY_LIGHT, "ladder")
				elif e["kind"] == "first_over":
					Sound.play_at("warcry", _to_screen(sq.average_pos()), 0.0, 0.05, 2.0)
					if mine:
						_tick("%s are over the wall!" % _company_or_type(sq), Style.PLAYER_LIGHT, "walls")
					else:
						_tick("They're over the wall!", Style.ENEMY_LIGHT, "walls")
				elif e["kind"] == "courtyard":
					Sound.play_at("warcry", _to_screen(sq.average_pos()), 0.0, 0.05, 2.0)
					if mine:
						_tick("%s are in the courtyard!" % _company_or_type(sq), Style.PLAYER_LIGHT, "inside")
					else:
						_tick("They're in the courtyard!", Style.ENEMY_LIGHT, "inside")
			"gate_breached":
				_burst(sim.gate_center, "charge", Style.BRASS, 1.0)
				_burst(sim.gate_center, "dust", Color("e9d3a0"), 1.2)
				var defending: bool = sim.siege_defender == Sim.PLAYER
				# One message: the band across the field (no ticker line as well).
				_moment("The gate is broken!", "Hold the breach!" if defending else "Into the courtyard!",
					Style.ENEMY_LIGHT if defending else Color("ffd77a"), "breach", true)
				Sound.play_at("gate_break", _to_screen(sim.gate_center))
				Sound.haptic(true)
				_kick(12.0)
				Sound.duck()
			"rout":
				var sq = e["squad"]
				_broke_at[sq] = _clock
				if sq.team == Sim.ENEMY:
					_last_rout_at = sq.average_pos()
				_burst(sq.average_pos(), "rout", Style.ENEMY_LIGHT if sq.team == Sim.PLAYER else Style.PLAYER_LIGHT, 1.0)
				var mine: bool = sq.team == Sim.PLAYER
				_strew(sq)
				# They scatter shouting; across the field, the other side cheers.
				Sound.play_at("panic", _to_screen(sq.average_pos()), 0.0, 0.05, 0.8)
				if mine:
					_call("retreat", Sim.PLAYER)
				else:
					Sound.play("cheer", -2.0, 0.04, 4.0)
				if mine:
					# Yours breaking is the moment; theirs is a word over the squad. Running for
					# it, the whole warband has one moment (see _on_retreat).
					if sim.withdrawing != Sim.PLAYER:
						_moment("%s break" % _company_or_type(sq), "They run for the edge", Style.ENEMY_LIGHT, "retreat")
					_card_broke[sq] = _clock
					Sound.haptic(true)
				else:
					_callout(sq, "BROKEN", Style.PLAYER_LIGHT, true)
			"charge":
				var sq = e["squad"]
				_shove(e["victim"], e["pos"], sq)
				if sq.team == Sim.PLAYER or e["victim"].team == Sim.PLAYER:
					struck += 1
					struck_at = e["pos"]
					struck_dir = (Vector2(e["pos"]) - sq.avg).normalized()
				if _clock - float(_charged_at.get(sq, -9.0)) > 1.5:
					_charged_at[sq] = _clock
					_burst(e["pos"], "charge", Style.BRASS, 0.55)
					_burst(e["pos"], "dust", _ground_dust(e["pos"]), 0.8)
					_callout(sq, "CHARGE", Style.BRASS)
					# Horsemen thunder in; men on foot roar and crash into the line.
					var at := _to_screen(e["pos"])
					if sq.type == Troops.CAVALRY:
						Sound.play_at("cav_impact", at, 0.0, 0.05, 0.6)
					else:
						Sound.play_at("warcry", at, 0.0, 0.05, 1.2)
						Sound.play_at("heavy", at, 2.0, 0.08)
					if sq.team == Sim.PLAYER:
						_call("charge", Sim.PLAYER)
					if e["victim"].team == Sim.PLAYER:
						Sound.haptic(false)
				if e["victim"].team == Sim.PLAYER:
					_card_hit[e["victim"]] = _clock
			"out_of_arrows":
				var sq = e["squad"]
				var mine: bool = sq.team == Sim.PLAYER
				# No words: the standard and the card carry an empty quiver from now on.
				Sound.play_at("quiver_empty", _to_screen(sq.average_pos()))
				if mine:
					_hint("Your archers are out of arrows and draw their blades. They are weak in a melee, so keep them out of one.", "no_arrows", false)
			"captain_down":
				_captain_down(e)
			"grief":
				_grief(e)
			"ability":
				var sq = e["squad"]
				var mine: bool = sq.team == Sim.PLAYER
				if sq.type == Troops.ARCHERS:
					Sound.play_at("arrows", _to_screen(sq.average_pos()), 2.0, 0.05, 0.3)
				_callout(sq, String(e["name"]).to_upper(), Style.PLAYER_LIGHT if mine else Style.ENEMY_LIGHT, false,
					String(ABILITY_ICONS.get(sq.type, "fight")))
			"braced":
				var sq = e["squad"]
				_callout(sq, "BRACED", Style.BRASS if sq.team == Sim.PLAYER else Style.ENEMY_LIGHT)
				Sound.play_at("brace", _to_screen(sq.average_pos()), 0.0, 0.05, 0.4)
			"reinforcements":
				if int(e["team"]) == Sim.ENEMY:
					Sound.play("reinforce_" + (_enemy_culture if ["vardish", "kharzani", "ryumon"].has(_enemy_culture) else "vardish"), 0.0, 0.0, 2.0)
					_tick("More of them come on from the %s!" % String(e["edge"]), Style.ENEMY_LIGHT)
			"chief_broken":
				Sound.play("objective")
				_hitstop = maxf(_hitstop, CAPTAIN_HITSTOP)
				_moment("The chief falls back", "His guard is broken", Style.BRASS, "crown")
			"chief_slain":
				Sound.play("objective")
				_moment("%s is cut down" % String(e["chief_name"] if e["chief_name"] != "" else "Their chief"), "The band loses its head", Style.BRASS, "crown")
			"lord_broken":
				Sound.play("objective")
				_moment("The lord's guard breaks", "%s's host quails" % String(e.get("lord_name", "The lord")), Style.BRASS, "crown")
			"lord_captured":
				# One roll decides it (see BattleSim._captain_falls): he falls, and the line
				# under it says what the result will: taken.
				Sound.play("objective")
				_hitstop = maxf(_hitstop, CAPTAIN_HITSTOP)
				_moment("%s falls" % String(e.get("lord_name", "The lord")), "Taken alive in the press of shields", Style.BRASS, "crown")
			"lord_slain":
				Sound.play("objective")
				_hitstop = maxf(_hitstop, CAPTAIN_HITSTOP)
				_moment("%s falls" % String(e.get("lord_name", "The lord")), "Slain in the fray", Style.BRASS, "crown")
			"flanked":
				var sq = e["squad"]
				var where := "REAR" if e["rear"] else "FLANK"
				Sound.play_at("heavy", _to_screen(e["pos"]), 3.0, 0.1, 0.3)
				_callout(sq, where, Style.ENEMY_LIGHT if sq.team == Sim.PLAYER else Style.BRASS)
				# The REAR or FLANK arrow over the squad and its card's red edge say it.
				if sq.team == Sim.PLAYER:
					_card_hit[sq] = _clock
	sim.events.clear()
	if struck > 0:
		_impact(struck, struck_at, struck_dir)


## A charge lands on or by your men, striking `men` of them: the battle stops for a beat
## (longer the more it hit), the view is knocked the way the horses went and punches in.
## Charges landing within a moment of each other share one.
func _impact(men: int, at: Vector2, dir: Vector2) -> void:
	if _clock - _stop_at < 0.3:
		return
	_stop_at = _clock
	_hitstop = clampf(HITSTOP_MIN + 0.006 * float(men - 1), HITSTOP_MIN, HITSTOP_MAX)
	_kick(4.0 + minf(float(men), 10.0) * 0.4, dir)
	if not Style.motion_reduced() and not _camera_hold:
		_punch = PUNCH
		_punch_at = at


## A charge lands on `victim` at `at`: the men it hits are shoved back the way the charge
## came, the rank behind them half as far. Drawn only; the sim keeps them where they are.
func _shove(victim, at: Vector2, charger) -> void:
	var dir: Vector2 = (at - charger.avg).normalized() if at.distance_to(charger.avg) > 1.0 else charger.facing
	for so in victim.soldiers:
		if not so.alive:
			continue
		var d: float = so.pos.distance_to(at)
		if d > SHOVE_REACH * 1.7:
			continue
		var k := 1.0 if d <= SHOVE_REACH else 0.5
		if float(_shoved.get(so, {}).get("k", 0.0)) > k and float(_shoved[so]["age"]) < SHOVE_TIME * 0.5:
			continue
		_shoved[so] = {"dir": dir, "k": k, "age": 0.0}


func _captain_down(e: Dictionary) -> void:
	var sq = e["squad"]
	# The field holds its breath for a beat before the fall plays out.
	_hitstop = maxf(_hitstop, CAPTAIN_HITSTOP)
	Sound.play_at("captain_down", _to_screen(e["pos"]), 0.0 if sq.team == Sim.PLAYER else -4.0)
	_burst(e["pos"], "fall", Style.ENEMY_LIGHT if sq.team == Sim.PLAYER else Style.PLAYER_LIGHT, 1.1)
	var info: Dictionary = sq.info
	if sq.team != Sim.PLAYER:
		# Their captain falls: time slows and the field darkens round him for a moment.
		_spotlight(e["pos"], SLOW_TIME + 0.4)
		_slow = SLOW_TIME
		# A lord's fall has its own moment (lord_slain or lord_captured, from the same roll),
		# so it isn't said twice in two different words.
		if not sq.is_lord:
			_moment("%s falls" % String(info.get("name", info.get("first", "Their captain"))), "Their %s waver" % _name(sq.type, Sim.ENEMY).to_lower(), Style.PLAYER_LIGHT, "skull")
		return
	_kick(9.0)
	_hush_until = _clock + 0.6
	Sound.duck()
	Sound.haptic(true)
	var roll := {
		"t": 0.0, "name": String(info.get("name", "")), "company": _company(sq.roster_id), "pos": e["pos"],
		"captain": info,
		"roll": int(e["roll"]), "needed": int(e["needed"]), "fate": String(e["fate"]),
		"words": String(sq.last_words), "holding": bool(e.get("holding", false)),
		"friends": bool(e.get("friends", false)), "lucky": bool(e.get("lucky", false)),
	}
	if _roll.is_empty():
		_roll = roll
	else:
		_roll_queue.append(roll)


## The roll on screen is done (or skipped): the plate said the outcome, so nothing echoes
## it; the next captain's roll, if any, takes its place.
func _next_roll() -> void:
	_roll = {} if _roll_queue.is_empty() else _roll_queue.pop_front()


func _grief(e: Dictionary) -> void:
	var sq = e["squad"]
	if sq.team != Sim.PLAYER:
		return
	var who := String(sq.info.get("first", ""))
	var lost := String(e["for"].info.get("first", ""))
	match String(e["temperament"]):
		Captains.VENGEFUL:
			_callout(sq, "FURY", Style.ENEMY_LIGHT, true)
			_tick("%s saw %s fall: fury, harder blows and no retreat for %d seconds." % [who, lost, int(Captains.FURY_SECONDS)], Style.BRASS)
		Captains.STEADFAST:
			_callout(sq, "STEADY", Style.BRASS, true)
			_tick("%s saw %s fall, and steadies the line." % [who, lost], Style.BRASS)
		Captains.FRAGILE:
			_callout(sq, "SHAKEN", Style.MUTED, true)
			_tick("%s saw %s fall and is shaken. Their squad's nerve is slipping." % [who, lost], Style.ENEMY_LIGHT)


## A word at a spot on the field that belongs to no squad (where a march was ordered, the
## gate's damage). Words that would land on one another stack upward.
func _float_text(text: String, at: Vector2, color: Color, life: float = 1.3) -> void:
	for f in floaters:
		if f["text"] == text and f["sq"] == null and at.distance_to(f["pos"]) < 70.0 and f["age"] < 0.6:
			return
	var pos := at
	for i in 6:
		var clear := true
		for f in floaters:
			var fp: Vector2 = f["pos"]
			if f["sq"] == null and f["age"] < 1.0 and absf(fp.x - pos.x) < 150.0 and absf(fp.y - pos.y) < 30.0:
				clear = false
				break
		if clear:
			break
		pos.y -= 32.0
	floaters.append({"text": text, "pos": pos, "color": color, "age": 0.0, "life": life, "sq": null})


## Tier 2: a word over a squad's standard (CHARGE, BRACED, FLANK, a broken enemy), led by
## its icon (`icon`, or the word's own from CALLOUT_ICONS); zoomed out, the icon alone. One
## per squad: a new one replaces the last. The same words on the same squad wait 3 seconds,
## and while a moment holds the field (`always` aside, for answers to your own orders) they
## wait.
func _callout(sq, text: String, color: Color, always: bool = false, icon: String = "") -> void:
	if sq == null:
		return
	if not always and _clock < _hush_until:
		return
	var key := "%d/%s" % [sq.get_instance_id(), text]
	if _clock - float(_said.get(key, -9.0)) < CALLOUT_REPEAT:
		return
	_said[key] = _clock
	floaters = floaters.filter(func(f): return f["sq"] != sq)
	floaters.append({"text": text, "pos": sq.average_pos(), "color": color, "age": 0.0, "life": CALLOUT_LIFE, "sq": sq,
		"icon": icon if icon != "" else String(CALLOUT_ICONS.get(text, ""))})


## Tier 1: a plate across the field for a moment that turns the battle. One at a time; the
## rest wait their turn. While it's up the squads' callouts hold their tongue and the din
## dips. `big` is the band across the whole field (the gate, the end).
func _moment(title: String, sub: String, color: Color, icon: String = "", big: bool = false) -> void:
	var m := {"title": title, "sub": sub, "color": color, "icon": icon, "big": big, "age": 0.0, "life": MOMENT_LIFE if not big else 1.9}
	if _banner.is_empty():
		_start_moment(m)
	else:
		_moments.append(m)


func _start_moment(m: Dictionary) -> void:
	_banner = m
	_hush_until = _clock + MOMENT_HUSH
	Sound.duck()


func _burst(at: Vector2, kind: String, color: Color, life: float) -> void:
	if bursts.size() >= MAX_BURSTS:
		var drop := -1
		for i in bursts.size():
			if not CRITICAL_BURSTS.has(String(bursts[i]["kind"])):
				drop = i
				break
		if drop == -1 and not CRITICAL_BURSTS.has(kind):
			return
		bursts.remove_at(maxi(drop, 0))
	bursts.append({"pos": at, "kind": kind, "color": color, "age": 0.0, "life": life})


# ---------------------------------------------------------------- siege engines

## The shadows engines cast: as the men's, by the hour, but longer for what stands taller.
const ENGINE_SHADOW := 0.3

## The wall where stones have hit it: cracks as a section weakens, rubble where it fell.
func _draw_wall_damage() -> void:
	if sim.works == null:
		return
	var st: Dictionary = CASTLE_STYLES.get(_castle_culture, CASTLE_STYLES["vardish"])
	var cell := Terrain.CELL
	var top: float = sim.wall_row * cell
	for i in sim.works.sections.size():
		var sec: Dictionary = sim.works.sections[i]
		var cols: Array = sec["cols"]
		var share: float = float(sec["hp"]) / maxf(1.0, float(sec["hp_max"]))
		if sec["broken"]:
			# Fallen stone heaped where the wall stood, in the walls' own stone.
			var px := SiegeArt.PIXEL
			var tint: Color = Color(st["stone"]).lightened(0.25)
			for cx in sec["open"]:
				_c.draw_rect(Rect2(float(cx) * cell, top - 4.0, cell, cell + 8.0), Color(st["paving"]).darkened(0.35))
				var tile := SiegeArt.texture("rubble", int(cx) % 3)
				_c.draw_set_transform(field_origin + Vector2(float(cx) * cell - 1.0, top - 3.0) * field_scale, 0.0, Vector2(px * field_scale, px * field_scale))
				_c.draw_texture(tile, Vector2.ZERO, tint)
				_c.draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
		elif share < 0.999:
			var cracks := 1 + int((1.0 - share) * 5.0)
			for k in cracks:
				var x := float(cols[0]) * cell + 5.0 + float((k * 29) % maxi(1, cols.size() * 30 - 10))
				var a := Vector2(x, top + 2.0)
				_c.draw_polyline(PackedVector2Array([a, a + Vector2(4, 7), a + Vector2(-2, 15), a + Vector2(3, cell - 3.0)]), Color(0.12, 0.09, 0.08, 0.85), 2.0)


## Every engine on the field in its land's pixel art (SiegeArt, drawn like the men), each
## with a shadow as long as it is tall: stone throwers working their arms, the tower
## rolling and then its bridge down on the wall, the ram swinging while men work it,
## mantlets before the bows, bolt throwers on the wall's towers, a courtyard thrower on its
## platform; fire on what burns, and the charred frames of what has burned.
func _draw_engines() -> void:
	if sim.works == null:
		return
	for e in sim.works.engines:
		var land := String(e.land)
		var up: bool = (sim.inward() < 0.0) == (e.team == sim.works.attacker)
		match String(e.kind):
			"thrower", "yard_thrower":
				if String(e.kind) == "yard_thrower":
					_engine_sprite("platform", 0, e.pos, up, false)
				_engine_sprite(land + "/thrower", _thrower_frame(e), e.pos, up, e.burnt, "thrower")
			"tower":
				var rolling := 0 if Style.motion_reduced() else int(e.pos.distance_to(e.home) / 6.0) % 2
				_engine_sprite(land + "/tower", 2 if e.docked else rolling, e.pos, up, e.burnt, "tower")
			"mantlets":
				if not e.burnt:
					_engine_sprite(land + "/mantlet", 0, e.pos, up, false, "mantlet")
			"bolt":
				_engine_sprite(land + "/bolt", 0 if e.reload > 0.6 else 1, e.pos, up, e.burnt, "bolt")
			"ram":
				# At the gate while men work it (swinging home and back); charred where it burned.
				if e.burnt or sim.gate_blows > 0.0 or sim.gate_hp <= 0.0:
					var swing := 0 if Style.motion_reduced() or sim.gate_blows <= 0.0 else int(_clock * 2.4) % 2
					_engine_sprite(land + "/ram", swing, e.pos, up, e.burnt, "ram")
		if e.burning > 0.0 and not e.burnt:
			var at: Vector2 = e.pos
			var n := 3 if String(e.kind) in ["thrower", "yard_thrower", "tower"] else 1
			for k in n:
				var off := Vector2((float(k) - float(n - 1) * 0.5) * 22.0, float(k % 2) * 10.0 - 6.0)
				_engine_fire(at + off, k)
		if not e.burnt and String(e.kind) in ["thrower", "yard_thrower", "tower", "bolt"]:
			_draw_engine_marks(e)
	for f in sim.works.flames:
		_engine_fire(f["pos"], int(f["pos"].x) % 4, clampf(float(f["left"]) / 2.0, 0.4, 1.0))


## Which frame a thrower shows: thrown for a moment after a stone goes, then swinging back
## down, then wound and waiting.
func _thrower_frame(e) -> int:
	if Style.motion_reduced():
		return 0
	var since: float = sim.works.reload_of(e) - e.reload
	if since < 0.35:
		return 2
	if since < 0.9:
		return 1
	return 0


## Sprite `name` (SiegeArt) standing at field point `at`, facing up the field or down it,
## charred if `burnt`, with a shadow by its height (`height_key` in SiegeArt.HEIGHT).
func _engine_sprite(name: String, frame: int, at: Vector2, up: bool, burnt: bool, height_key: String = "platform") -> void:
	var tex := SiegeArt.texture(name, frame, burnt)
	if tex == null:
		return
	var px := SiegeArt.PIXEL * field_scale
	var rot := 0.0 if up else PI
	var piv := SiegeArt.pivot(name)
	var fall: Vector2 = _shadow_off.normalized() * float(SiegeArt.HEIGHT.get(height_key, 3.0))
	_c.draw_set_transform(field_origin + (at + fall) * field_scale, rot, Vector2(px, px))
	_c.draw_texture(SiegeArt.texture(name, frame, false, true), -piv, Color(0, 0, 0, ENGINE_SHADOW))
	_c.draw_set_transform(field_origin + at * field_scale, rot, Vector2(px, px))
	_c.draw_texture(tex, -piv)
	_c.draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))


## A wood fire's tongues licking up at `at` (`phase` staggers the flicker); a steady flame
## under Reduced motion.
func _engine_fire(at: Vector2, phase: int, size: float = 1.0) -> void:
	var frame := 0 if Style.motion_reduced() else (int(_clock * 8.0) + phase) % 4
	var px := SiegeArt.PIXEL * field_scale * size
	_c.draw_set_transform(field_origin + at * field_scale, 0.0, Vector2(px, px))
	_c.draw_texture(SiegeArt.texture("flame", frame), -SiegeArt.pivot("flame"))
	_c.draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
	if not Style.motion_reduced():
		for k in 2:
			var rise := fmod(_clock * 16.0 + float(k) * 17.0 + float(phase) * 9.0, 44.0)
			_dot(at + Vector2(float(k) * 6.0 - 3.0, -26.0 - rise), 4.0 + rise * 0.15, Color(0.22, 0.2, 0.2, 0.32 * (1.0 - rise / 44.0)))


## An engine's state when it matters: its wood when hurt, whether it has a crew, and what
## your picked engine is aimed at.
func _draw_engine_marks(e) -> void:
	var share: float = e.hp / maxf(1.0, e.hp_max)
	var p: Vector2 = e.pos + Vector2(0.0, -34.0)
	var mine: bool = e.team == Sim.PLAYER
	if share < 0.999 or e == selected_engine:
		_c.draw_rect(Rect2(p - Vector2(18, 3), Vector2(36, 6)), Color(0, 0, 0, 0.6))
		_c.draw_rect(Rect2(p - Vector2(17, 2), Vector2(34.0 * share, 4)), Style.PLAYER_LIGHT if mine else Style.ENEMY_LIGHT)
	if mine and String(e.kind) != "bolt":
		_c.draw_circle(p + Vector2(24, 0), 4.0, Color("6fd06a") if e.crewed() else Color(0.6, 0.6, 0.6, 0.8))
	if e == selected_engine:
		_c.draw_arc(e.pos, 30.0, 0.0, TAU, 28, Style.BRASS, 3.0)
		var aim: Dictionary = e.aim
		var to = null
		match String(aim.get("kind", "auto")):
			"section":
				to = sim.works.section_center(int(aim["ref"]))
			"gate":
				to = sim.gate_center
			"engine":
				if aim.get("ref") != null:
					to = aim["ref"].pos
			"squad":
				if aim.get("ref") != null and aim["ref"].is_active():
					to = aim["ref"].avg
		if to != null:
			_c.draw_dashed_line(e.pos, to, Color(Style.BRASS, 0.8), 3.0, 14.0)
			_c.draw_arc(to, 18.0, 0.0, TAU, 24, Style.BRASS, 3.0)


## Stones in the air on their arcs, growing as they climb toward you, a shadow on the
## ground beneath; naphtha pots glowing; bolts along their line.
func _draw_engine_shots() -> void:
	if sim.works == null:
		return
	for sh in sim.works.shots:
		var k: float = clampf(float(sh["t"]) / float(sh["flight"]), 0.0, 1.0)
		var from: Vector2 = sh["from"]
		var to: Vector2 = sh["to"]
		var ground := from.lerp(to, k)
		var px := SiegeArt.PIXEL * field_scale
		if String(sh["kind"]) == "stone":
			var arc := minf(160.0, from.distance_to(to) * 0.3)
			var lift := sin(k * PI) * arc
			var grow := 1.0 + (lift / arc if arc > 0.0 else 0.0) * 0.8
			_dot(ground + Vector2(3, 3), 5.0 * (1.2 - lift / maxf(1.0, arc) * 0.5), Color(0, 0, 0, 0.32))
			var name := "naphtha" if bool(sh.get("naphtha", false)) else "stone"
			_c.draw_set_transform(field_origin + (ground - Vector2(0, lift)) * field_scale, k * 6.0, Vector2(px * grow, px * grow))
			_c.draw_texture(SiegeArt.texture(name), -SiegeArt.pivot(name))
		else:
			var dir := (to - from).normalized()
			_c.draw_set_transform(field_origin + ground * field_scale, dir.angle() + PI * 0.5, Vector2(px, px))
			_c.draw_texture(SiegeArt.texture("bolt_shot"), -SiegeArt.pivot("bolt_shot"))
		_c.draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))


func _engine_event(e: Dictionary) -> void:
	var defending: bool = sim.siege_defender == Sim.PLAYER
	match String(e["type"]):
		"engine_throw":
			var en = e["engine"]
			Sound.play_at("ram", _to_screen(en.pos), -6.0, 0.15, 0.6, 0.7)
			if not _engine_said.has("throw_%d" % en.team):
				_engine_said["throw_%d" % en.team] = true
				var name: String = sim.works.engine_name(en)
				if en.team == Sim.PLAYER:
					_tick("Your %s has the range!" % name, Style.PLAYER_LIGHT, "gate")
				else:
					_tick("Their %s has the range!" % name, Style.ENEMY_LIGHT, "gate")
		"engine_bolt":
			Sound.play_at("crossbow", _to_screen(e["engine"].pos), -4.0, 0.1, 0.4)
		"stone_lands":
			_burst(e["at"], "dust", Color("d8cdb4"), 0.7)
			Sound.play_at("heavy", _to_screen(e["at"]), -6.0, 0.1, 0.3)
		"wall_hit", "gate_hit":
			_burst(e["at"], "dust", Color("cfc4ac"), 0.9)
			Sound.play_at("ram", _to_screen(e["at"]), -3.0, 0.1, 0.3, 0.8)
		"wall_breached":
			_burst(e["at"], "rubble", Color("d8cdb4"), 1.6)
			_kick(9.0)
			Sound.play_at("gate_break", _to_screen(e["at"]), -2.0)
			if defending:
				_tick("They've broken the wall!", Style.ENEMY_LIGHT, "walls")
			else:
				_tick("A breach in the wall!", Style.PLAYER_LIGHT, "walls")
		"tower_docked":
			Sound.play_at("ladders", _to_screen(e["engine"].pos), 0.0)
			if e["engine"].team == Sim.PLAYER:
				_tick("The tower is at the wall!", Style.PLAYER_LIGHT, "walls")
			else:
				_tick("Their tower is at the wall!", Style.ENEMY_LIGHT, "walls")
		"engine_burning":
			var en2 = e["engine"]
			var key := "fire_%d" % en2.id
			if _engine_said.has(key) or String(en2.kind) == "mantlets":
				return
			_engine_said[key] = true
			var name2: String = sim.works.engine_name(en2)
			if en2.team == Sim.PLAYER:
				_tick("Your %s is burning!" % name2, Style.ENEMY_LIGHT, "fire")
			else:
				_tick("Their %s is burning!" % name2, Style.PLAYER_LIGHT, "fire")
		"engine_lost":
			var en3 = e["engine"]
			_burst(en3.pos, "dust", Color("3a2a1e"), 1.2)
			if String(en3.kind) in ["thrower", "yard_thrower", "tower", "ram"]:
				var name3: String = sim.works.engine_name(en3)
				if en3.team == Sim.PLAYER:
					_tick("Your %s is lost!" % name3, Style.ENEMY_LIGHT, "fire")
				else:
					_tick("Their %s is done for!" % name3, Style.PLAYER_LIGHT, "fire")
		"oil":
			for at in (e["at"] as Array).slice(0, 6):
				_burst(at, "oil", Color(0.1, 0.06, 0.03), 0.9)
			Sound.play_at("heavy", _to_screen(sim.gate_center), -2.0, 0.1, 0.5, 0.6)
			if not _engine_said.has("oil"):
				_engine_said["oil"] = true
				if defending:
					_tick("Oil on their ram!", Style.PLAYER_LIGHT, "gate")
				else:
					_tick("Oil from the gatehouse!", Style.ENEMY_LIGHT, "gate")
		"fire_arrows":
			var sq = e["squad"]
			var target = e["engine"]
			for k in 3:
				bursts.append({"pos": target.pos + Vector2(randf_range(-12, 12), randf_range(-12, 12)),
					"from": sq.average_pos() + Vector2(randf_range(-20, 20), randf_range(-8, 8)), "kind": "fire_arrow",
					"color": Color(1.0, 0.6, 0.2), "age": 0.0, "life": 0.7})
		"sally_out":
			var sq2 = e["squad"]
			if sq2.team == Sim.PLAYER:
				_tick("%s slip out by the postern!" % _company_or_type(sq2), Style.PLAYER_LIGHT, "walls")
			else:
				_tick("A sally from the postern!", Style.ENEMY_LIGHT, "walls")


## The engine at field point `p` (within reach of a finger), or null.
func _engine_at(p: Vector2):
	var best = null
	var best_d := 40.0
	for e in sim.works.engines:
		if e.burnt or String(e.kind) in ["ram", "mantlets"]:
			continue
		var d: float = e.pos.distance_to(p)
		if d < best_d:
			best_d = d
			best = e
	return best


## What an engine is and what you can do with it, for a tap on it.
func _engine_blurb(e) -> String:
	var name: String = sim.works.engine_name(e)
	var hp := "%d of %d" % [int(e.hp), int(e.hp_max)]
	if e.team == Sim.PLAYER:
		match String(e.kind):
			"thrower", "yard_thrower":
				return "Your %s (%s). A company standing at it works it; tap it, then tap a wall section, the gate, an enemy engine or a company to aim it." % [name, hp]
			"tower":
				return "Your siege tower (%s). Its company pushes it to the wall when you Storm, then goes over its bridge." % hp
			"bolt":
				return "Your bolt thrower (%s), worked by whoever holds the walk beside it. Tap it, then tap what to shoot." % hp
	match String(e.kind):
		"tower":
			return "Their siege tower (%s). Pick a company of bows and tap it to set it alight." % hp
		"thrower", "yard_thrower":
			if sim.siege_defender == Sim.PLAYER and sim.works.has_postern():
				return "Their %s (%s). Pick a company on foot and tap it to sally out by the postern and burn it; bows can set it alight from close enough." % [name, hp]
			return "Their %s (%s). Bows can set it alight from close enough; men who reach it can hack it down." % [name, hp]
		"bolt":
			return "Their bolt thrower (%s), on the wall's tower. Men who get over the wall can hack it down." % hp
	return name


## A tap during the battle, on or about an engine. Returns whether the tap was taken.
func _tap_engines(p: Vector2, mine) -> bool:
	var eng = _engine_at(p)
	# Aiming the picked engine.
	if selected_engine != null:
		var e = selected_engine
		selected_engine = null
		if eng == e:
			e.aim = {"kind": "auto"}
			_hint("%s chooses its own marks." % sim.works.engine_name(e).capitalize())
			return true
		var aim := {}
		if eng != null and eng.team != e.team:
			aim = {"kind": "engine", "ref": eng}
		elif absf(p.y - sim.wall_y) < 30.0 and String(e.kind) in ["thrower"]:
			var cx := int(p.x / Terrain.CELL)
			if Sim.GATE_COLS.has(cx):
				aim = {"kind": "gate"}
			elif sim.works.section_at(cx) >= 0:
				aim = {"kind": "section", "ref": sim.works.section_at(cx)}
		if aim.is_empty():
			var foe = sim.squad_at(Sim.ENEMY, p, 52.0)
			if foe != null:
				aim = {"kind": "squad", "ref": foe}
		if aim.is_empty():
			_hint("Nothing to aim at there. Tap the %s again to pick it up." % sim.works.engine_name(e))
			return true
		e.aim = aim
		Sound.play("click", -6.0)
		_hint("%s: aimed." % sim.works.engine_name(e).capitalize())
		return true
	if eng == null:
		return false
	# Your engine: a company picked goes to work it; otherwise pick it up to aim.
	if eng.team == Sim.PLAYER:
		if selected_squad != null and String(eng.kind) in ["thrower", "yard_thrower", "tower"]:
			sim.order_crew(selected_squad, eng)
			_mark_ordered(selected_squad)
			_hint("%s go to the %s." % [_company_or_type(selected_squad), sim.works.engine_name(eng)])
			return true
		if String(eng.kind) in ["thrower", "yard_thrower", "bolt"]:
			_select(null)
			selected_engine = eng
			_hint(_engine_blurb(eng))
			return true
		_hint(_engine_blurb(eng))
		return true
	# Theirs: bows set it alight, foot sally at it (holding the walls) or go for it.
	if selected_squad != null and selected_squad.is_active():
		var sq = selected_squad
		if sq.ranged:
			sim.order_burn(sq, eng)
			_mark_ordered(sq)
			_hint("%s shoot fire at their %s." % [_company_or_type(sq), sim.works.engine_name(eng)])
			return true
		if sim.siege_defender == Sim.PLAYER and sim.gate_hp > 0.0 and sim.works.has_postern():
			if sim.order_sally(sq, eng):
				_mark_ordered(sq)
				_hint("%s go out by the postern for their %s." % [_company_or_type(sq), sim.works.engine_name(eng)])
				return true
		_order_move(sq, eng.pos)
		return true
	_hint(_engine_blurb(eng))
	return true


## Stones falling from the gate tower onto the men at the ram: a few of the volley drawn,
## each a grey dot dropping from the wall top and a puff where it lands.
func _drop_stones(hits: Array) -> void:
	if hits.is_empty():
		return
	var top: float = sim.wall_y + sim.inward() * 10.0
	for i in mini(5, hits.size()):
		var at: Vector2 = hits[i]
		bursts.append({"pos": at, "from": Vector2(at.x + randf_range(-10.0, 10.0), top), "kind": "stone",
			"color": Color("a8a39a"), "age": 0.0, "life": 0.45})
	Sound.play_at("heavy", _to_screen(sim.gate_center), -4.0, 0.08, 1.0)


## A line in the ticker along the top of the field, for what's happening in the story.
func _tick(text: String, color: Color, icon: String = "") -> void:
	for t in ticker:
		if t["text"] == text:
			return
	ticker.append({"text": text, "color": color, "age": 0.0, "life": 4.5, "icon": icon})
	if ticker.size() > 3:
		ticker.pop_front()


# ---------------------------------------------------------------- results

func _show_result() -> void:
	_result_shown = true
	if _test:
		_back_to_camp()
		return
	paused = false
	pause_panel.visible = false
	selected_id = -1
	selected_squad = null
	_pending_result = _result()
	var won: bool = _pending_result["won"]
	var reasons := {
		"rout": ["Their army broke and fled.", "Your army broke and fled."],
		"time": ["Time ran out with more of your army still standing.", "Time ran out with more of theirs still standing."],
		"retreat": ["The enemy withdrew.", "You pulled your army off the field."],
		"walls_held": ["The gate held. The attackers gave up the assault.", "The gate held. The garrison kept its walls."],
		"village_held": ["You held the village square until the raiders gave up.", ""],
		"village_lost": ["", "The raiders held the village square when time ran out."],
		"village_burned": ["", "The raiders held the square long enough to fire the village."],
	}
	# Where it was fought is on the picture above this line ("Near Thornwall"), so the line
	# says only why it ended.
	var why: String = reasons.get(_pending_result["reason"], ["", ""])[0 if won else 1]
	result_title.text = "Victory" if won else "Defeat"
	result_title.add_theme_color_override("font_color", Style.BRASS if won else Style.ENEMY_LIGHT)
	Sound.stinger("victory" if won else "defeat")
	Sound.end_battle_sounds()
	if won:
		Sound.play("cheer", 0.0, 0.03)
	_rebuild_result(GameState.battle_report(_pending_result), why)
	result_panel.visible = true
	result_scrim.visible = true
	Style.ease_in(result_panel, Vector2(0.5, 0.5))
	_play_result_sequence()
	if autoplay:
		get_tree().create_timer(0.8).timeout.connect(_back_to_camp)


## The result tells itself in order, in under two seconds: the title stamps in with the
## stinger, the picture and why it ended, then the tallies count up from nothing, the
## spoils roll in with the coins, and the companies follow one by one. A tap on the card
## finishes it at once. Under Reduced motion it's all there from the start.
var _result_seq: Array = []
const RESULT_STEP := 0.12
const RESULT_COUNT := 0.45
const RESULT_MAX := 1.9


func _play_result_sequence() -> void:
	for t in _result_seq:
		if t is Tween and (t as Tween).is_valid():
			(t as Tween).kill()
	_result_seq.clear()
	if Style.motion_reduced():
		return
	if not result_panel.gui_input.is_connected(_on_result_tap):
		result_panel.gui_input.connect(_on_result_tap)
	result_title.pivot_offset = result_title.size * 0.5
	# VICTORY has already stamped on the field; the card's title only settles in.
	result_title.scale = Vector2(1.15, 1.15)
	result_title.modulate.a = 0.0
	var stamp := result_title.create_tween().set_parallel()
	stamp.tween_property(result_title, "modulate:a", 1.0, 0.1)
	stamp.tween_property(result_title, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_result_seq.append(stamp)
	var at := 0.22
	for c in result_content.get_children():
		var ci := c as CanvasItem
		if ci == null or not ci.visible:
			continue
		ci.modulate.a = 0.0
		var t := ci.create_tween()
		t.tween_interval(minf(at, RESULT_MAX))
		t.tween_property(ci, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_result_seq.append(t)
		if (c.name as String).begins_with("RankUp_"):
			# A bond's new rank stamps in.
			var cc := c as Control
			t.parallel().tween_callback(func():
				cc.pivot_offset = cc.size * 0.5
				cc.scale = Vector2(1.18, 1.18)
				cc.create_tween().tween_property(cc, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				Sound.play("bond_rank", 0.0, 0.03)).set_delay(0.0)
		if c.name in ["Tally", "Rewards"]:
			for v in c.find_children("Value", "Label", true, false):
				_count_up(v as Label, minf(at, RESULT_MAX))
			if c.name == "Rewards":
				t.tween_callback(Sound.play.bind("coins", 0.0, 0.05))
			at += RESULT_COUNT
		else:
			at += RESULT_STEP if not (c.name as String).begins_with("Company_") else 0.08


## A tile's number counts up from nothing to what it shows, after `delay`.
func _count_up(label: Label, delay: float) -> void:
	var text := label.text
	var plus := text.begins_with("+")
	var digits := ""
	for ch in text:
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits == "":
		return
	var n := int(digits)
	label.text = ("+" if plus else "") + "0"
	var t := label.create_tween()
	t.tween_interval(delay)
	t.tween_method(func(v: float):
		if is_instance_valid(label):
			label.text = ("+" if plus else "") + Widgets.thousands(int(round(v))), 0.0, float(n), RESULT_COUNT) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		if is_instance_valid(label):
			label.text = text)
	_result_seq.append(t)


## A tap on the result while it tells itself: everything lands at once.
func _on_result_tap(e: InputEvent) -> void:
	if not ((e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed):
		return
	finish_result_sequence()


func finish_result_sequence() -> void:
	for t in _result_seq:
		if t is Tween and (t as Tween).is_valid() and (t as Tween).is_running():
			(t as Tween).custom_step(60.0)
	_result_seq.clear()


func _rebuild_result(report: Dictionary, why: String) -> void:
	for t in _result_seq:
		if t is Tween and (t as Tween).is_valid():
			(t as Tween).kill()
	_result_seq.clear()
	for child in result_content.get_children():
		result_content.remove_child(child)
		# The line saying why it ended is kept and put back; everything else is new.
		if child != result_body:
			child.free()
	var siege: bool = sim.objective == Sim.OBJECTIVE_SIEGE
	if siege:
		result_content.add_child(_siege_vignette())
	else:
		result_content.add_child(_field_vignette())
	result_body.text = why
	result_content.add_child(result_body)

	# The tally as tiles: your slain and wounded, theirs down. (The report's story sentence
	# said the same in words; the hardest fighting is a star on that captain's face below.)
	var lost := int(report.get("lost", 0))
	var wounded := int(round(lost * 0.5))
	var tally := [
		Widgets.tile("skull", str(lost - wounded), "slain", Style.ENEMY_LIGHT),
		Widgets.tile("wounded", str(wounded), "wounded", Style.MORALE_MID),
		Widgets.tile("fight", str(int(report.get("killed", 0))), "theirs down" if siege and sim.siege_defender == Sim.PLAYER else "enemy down", Style.BRASS),
	]
	if siege:
		var defending: bool = sim.siege_defender == Sim.PLAYER
		tally.append(Widgets.tile("ladder", str(sim.climbed), "came over" if defending else "went up"))
		tally.append(Widgets.tile("ram", str(int(sim.gate_max - sim.gate_hp)), "blows on the gate" if defending else "ram blows"))
		if sim.works != null:
			var att: int = sim.works.attacker
			if int(sim.works.stones[att]) > 0:
				tally.append(Widgets.tile("walls", str(sim.works.stones[att]), "their stones" if defending else "stones thrown"))
			if sim.works.sections_broken > 0:
				tally.append(Widgets.tile("breach", str(sim.works.sections_broken), "walls broken"))
			var lost_engines := int(sim.works.burned[Sim.PLAYER])
			var took_engines := int(sim.works.burned[Sim.ENEMY])
			if lost_engines + took_engines > 0:
				tally.append(Widgets.tile("fire", "%d · %d" % [took_engines, lost_engines], "engines burned, theirs · yours"))
	var tally_grid := Widgets.tile_grid(tally, 3)
	tally_grid.name = "Tally"
	result_content.add_child(tally_grid)
	if wounded > 0:
		var mend := _result_note("Wounded rejoin over the coming days; they still eat and are paid.", Style.MUTED)
		mend.name = "WoundedNote"
		mend.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
		result_content.add_child(mend)

	var rewards: Dictionary = report.get("rewards", {})
	if int(rewards.get("silver", 0)) + int(rewards.get("food", 0)) + int(rewards.get("renown", 0)) > 0:
		var tiles := []
		var counts := []
		for r in [["silver", "silver"], ["food", "rations"], ["renown", "renown"]]:
			var n := int(rewards.get(r[0], 0))
			var t := Widgets.tile(r[0], "+%s" % Widgets.thousands(n), r[1], Style.BRASS)
			tiles.append(t)
			counts.append([t, n])
		var grid := Widgets.tile_grid(tiles, 3)
		grid.name = "Rewards"
		result_content.add_child(grid)

	if siege:
		result_content.add_child(Widgets.section("How it went"))
		result_content.add_child(_siege_timeline())

	_result_companies(report)
	_result_bonds(report.get("bonds", []), report.get("memorials", []))


## Only the companies with something to tell: a captain fallen or wounded, men lost,
## enemies cut down, newly ready to train, or a deed on the walls. The rest are one line.
func _result_companies(report: Dictionary) -> void:
	var captains := {}
	for c in report.get("captains", []):
		captains[String(c.get("company", ""))] = c
	var hardest := _hardest_company(report.get("squads", []))
	var rows := []
	var quiet := 0
	for squad in report.get("squads", []):
		var captain: Dictionary = captains.get(String(squad.get("name", "")), {})
		var fate := String(captain.get("fate", "standing"))
		var note := _siege_note(captain) if not captain.is_empty() else ""
		var weight := int(squad.get("kills", 0)) + int(squad.get("lost", 0))
		if fate == "killed":
			weight += 1000
		elif fate == "wounded":
			weight += 500
		if bool(squad.get("newly_ready", false)) or note != "":
			weight += 1
		if weight == 0:
			quiet += 1
			continue
		rows.append({"squad": squad, "captain": captain, "note": note, "weight": weight})
	if rows.is_empty():
		return
	rows.sort_custom(func(a, b): return int(a["weight"]) > int(b["weight"]))
	result_content.add_child(Widgets.section("Your companies"))
	for r in rows:
		result_content.add_child(_result_company(r["squad"], r["captain"], String(r["note"]), String(r["squad"].get("name", "")) == hardest))
	if quiet > 0:
		var rest := _result_note("%d other compan%s saw no fighting." % [quiet, "y" if quiet == 1 else "ies"], Style.MUTED)
		rest.name = "QuietCompanies"
		rest.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
		result_content.add_child(rest)


## The company that cut down the most, if any did: its captain gets the star.
func _hardest_company(squads: Array) -> String:
	var best := ""
	var most := 0
	for sq in squads:
		if int(sq.get("kills", 0)) > most:
			most = int(sq.get("kills", 0))
			best = String(sq.get("name", ""))
	return best


func _result_note(text: String, color: Color = Style.TEXT) -> Label:
	var label := Style.label(text, Style.BODY, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## A face with its fate badged on the corner: a star for the hardest fighting, the wounded
## mark, or a skull for the fallen (dimmed).
func _badged_face(face: Dictionary, badge: String, tint: Color, size: Vector2 = Vector2(54, 72), dim: bool = false) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait := CaptainArt.portrait(face, size)
	if dim:
		portrait.modulate = Color(0.55, 0.55, 0.6)
	holder.add_child(portrait)
	if badge != "":
		var dot := PanelContainer.new()
		dot.name = "Badge"
		dot.add_theme_stylebox_override("panel", Style.box(Style.NIGHT, tint, 2, 16))
		dot.position = Vector2(size.x - 22.0, size.y - 26.0)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := Widgets.icon_rect(badge, 20.0)
		ic.modulate = tint
		dot.add_child(ic)
		holder.add_child(dot)
	return holder


## One company: its captain's face with a badge for the fate (a star for the hardest
## fighting), its first name, the men who came out over those who went in, and only the
## marks that aren't zero.
func _result_company(squad: Dictionary, captain: Dictionary, note: String, hardest: bool) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Company_%d" % int(squad.get("id", 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var fate := String(captain.get("fate", "standing"))
	if not captain.is_empty():
		var face: Dictionary = captain.get("face", captain)
		if fate == "wounded":
			face = face.duplicate(true)
			face["wounded"] = maxi(1, int(face.get("wounded", 0)))
		var badge := ""
		var tint := Style.BRASS
		if fate == "killed":
			badge = "skull"
			tint = Style.ENEMY_LIGHT
		elif fate == "wounded":
			badge = "wounded"
			tint = Style.ENEMY_LIGHT
		elif hardest:
			badge = "renown"
		row.add_child(_badged_face(face, badge, tint, Vector2(54, 72), fate == "killed"))
	else:
		var rec := _squad_record(int(squad.get("id", -1)))
		if not rec.is_empty():
			var sprite := TextureRect.new()
			sprite.texture = Art.icon(String(rec.get("type", Troops.INFANTRY)), Sim.PLAYER, String(rec.get("culture", GameState.culture)))
			sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.custom_minimum_size = Vector2(48, 48)
			sprite.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(sprite)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 6)
	row.add_child(words)
	var title := Style.label(String(squad.get("name", "Company")), Style.BODY, Style.TEXT)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.custom_minimum_size.x = 10
	words.add_child(title)
	# Men before and after: the meter's track is the men it went in with, the fill those
	# who came out. Only when some were lost.
	var before := int(squad.get("men_before", 0))
	var after := int(squad.get("men_after", 0))
	if int(squad.get("lost", 0)) > 0 and before > 0:
		var men_row := HBoxContainer.new()
		men_row.add_theme_constant_override("separation", 10)
		men_row.add_child(Widgets.icon_value("men", "%d/%d" % [after, before]))
		men_row.add_child(Widgets.meter(float(after) / maxf(1.0, float(before)), Style.MORALE_MID, 12.0))
		words.add_child(men_row)
	var marks: Array = []
	var kills := int(squad.get("kills", 0))
	if kills > 0:
		marks.append(Widgets.stat("fight", str(kills)))
	if hardest and fate == "standing":
		marks.append(Widgets.chip("Hardest fighting", Style.BRASS, "★", "", true))
	if fate == "wounded" or fate == "killed":
		marks.append(_roll_chip(int(captain.get("roll", 0)), int(captain.get("needed", 0)), fate == "killed"))
	if fate == "wounded":
		var out := Widgets.chip("", Style.ENEMY_LIGHT, "", "wounded")
		out.name = "OutFor"
		out.tooltip_text = "Out for %d battles" % Captains.WOUND_BATTLES
		(out.get_child(0) as HBoxContainer).add_child(_pips(Captains.WOUND_BATTLES, Style.ENEMY_LIGHT))
		marks.append(out)
	elif fate == "killed":
		marks.append(Widgets.chip("%s fell" % String(captain.get("first", captain.get("name", ""))), Style.ENEMY_LIGHT, "▼"))
	if note != "":
		marks.append(Widgets.chip(note, Style.BRASS, "★", "", true))
	if bool(squad.get("newly_ready", false)):
		var tag := Widgets.chip("Ready to train", Style.BRASS, "▲", "", true)
		tag.name = "ReadyToTrain"
		marks.append(tag)
	if not marks.is_empty():
		words.add_child(Widgets.chip_row(marks))
	return panel


## The death roll as the die showed it: what came up over what was needed ("37 / 41"),
## red if it killed.
func _roll_chip(roll: int, needed: int, killed: bool) -> PanelContainer:
	var chip := Widgets.chip("%d / %d" % [roll, needed], Style.ENEMY_LIGHT if killed else Style.TEXT)
	chip.name = "DeathRoll"
	chip.tooltip_text = "Death roll %d, needed %d or more to live" % [roll, needed]
	var row := chip.get_child(0) as HBoxContainer
	var shape := row.get_node_or_null("Shape")
	if shape != null:
		row.remove_child(shape)
		shape.queue_free()
	var die := Control.new()
	die.custom_minimum_size = Vector2(24, 24)
	die.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	die.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ink := Style.ENEMY_LIGHT if killed else Style.TEXT
	die.draw.connect(func():
		var r := Rect2(Vector2(2, 2), die.size - Vector2(4, 4))
		die.draw_style_box(Style.box(Color(0, 0, 0, 0), ink, 2, 5), r)
		var c := r.get_center()
		for d in [Vector2(-5, -5), Vector2.ZERO, Vector2(5, 5)]:
			die.draw_circle(c + d, 2.0, ink))
	row.add_child(die)
	row.move_child(die, 0)
	return chip


## What a captain did in the siege worth a line of their own.
func _siege_note(captain: Dictionary) -> String:
	if sim.objective != Sim.OBJECTIVE_SIEGE:
		return ""
	var notes := PackedStringArray()
	for e in sim.siege_log:
		var sq = e["squad"]
		if sq == null or sq.team != Sim.PLAYER or sq.info.is_empty() or int(sq.info["id"]) != int(captain.get("id", -1)):
			continue
		if e["kind"] == "first_over":
			notes.append("First over the wall")
		elif e["kind"] == "courtyard":
			notes.append("First into the courtyard")
		elif e["kind"] == "stones":
			notes.append("Stones on the ram")
		elif e["kind"] == "thrown_down":
			notes.append("Threw them off the ladders")
	return " · ".join(notes)


func _clock_text(t: float) -> String:
	return "%d:%02d" % [floori(t / 60.0), int(t) % 60]


## The siege, moment by moment: ram, first over the wall, the gate, the courtyard, the end.
func _siege_timeline() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var defending: bool = sim.siege_defender == Sim.PLAYER
	var rows: Array = []
	for e in sim.siege_log:
		var sq = e["squad"]
		var who := "Their men"
		if sq != null and sq.team == Sim.PLAYER:
			who = _captain_first(sq) + "'s men" if not sq.info.is_empty() else _company_or_type(sq)
		match String(e["kind"]):
			"ram":
				rows.append([e["t"], "ram", "Their ram reached the gate" if defending else "The ram reached the gate", Color("ffd79a")])
			"first_over":
				rows.append([e["t"], "ladder", "%s first over the wall" % who, Color("ffe08a")])
			"gate":
				rows.append([e["t"], "breach", "The ram broke the gate", Color("ffc06a")])
			"courtyard":
				rows.append([e["t"], "inside", "%s took the courtyard" % who, Color("bfe0ff")])
			"stones":
				var from := who if defending else "The gatehouse"
				rows.append([e["t"], "gate", "%s dropped stones on the ram (%d in all)" % [from, sim.stones_dropped], Color("e2e0dc")])
			"thrown_down":
				var by := who if defending else "The garrison"
				rows.append([e["t"], "ladder", "%s threw a man off a ladder (%d in all)" % [by, sim.thrown_down], Color("b8f5b0")])
			"section":
				var thrower: String = sim.works.engine_name(sim.works.engines.filter(func(x): return x.kind == "thrower")[0]) if sim.works != null and sim.works.has("thrower") else "stones"
				rows.append([e["t"], "breach", ("Their %s broke the wall" if defending else "Your %s broke the wall") % thrower, Color("ffc06a")])
			"tower":
				rows.append([e["t"], "walls", "Their tower reached the wall" if defending else "The tower reached the wall", Color("ffe08a")])
			"oil":
				rows.append([e["t"], "gate", "Oil poured on the ram (%d times)" % (sim.works.pours if sim.works != null else 1), Color("e8a03c")])
			"engine_lost_0", "engine_lost_1":
				var ours: bool = String(e["kind"]) == "engine_lost_%d" % Sim.PLAYER
				rows.append([e["t"], "fire", "One of your engines burned" if ours else "One of their engines burned", Style.ENEMY_LIGHT if ours else Color("b8f5b0")])
	var attacker_won: bool = sim.winner != sim.siege_defender
	var end_line := "The garrison broke and ran" if attacker_won else "The walls held"
	if defending:
		end_line = "The garrison broke" if attacker_won else "They gave up the assault"
	rows.append([sim.time, "objective", end_line, Color("b8f5b0") if attacker_won != defending else Style.ENEMY_LIGHT])
	for r in rows:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		var dot := PanelContainer.new()
		var db := Style.box(Color(r[3]).darkened(0.65), Color(r[3], 0.5), 1, 20)
		dot.add_theme_stylebox_override("panel", db)
		var ic := Widgets.icon_rect(String(r[1]), 26.0)
		ic.modulate = r[3]
		dot.add_child(ic)
		h.add_child(dot)
		var t := Style.label(_clock_text(float(r[0])), Style.SMALL, Style.BRASS)
		t.custom_minimum_size = Vector2(64, 0)
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(t)
		var words := Style.label(String(r[2]), Style.SMALL, Style.TEXT)
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(words)
		col.add_child(h)
	return col


## The castle's keep with whoever holds it now flying their flag, and a ribbon saying
## whether it fell.
func _siege_vignette() -> Control:
	var c := Control.new()
	c.name = "SiegeVignette"
	c.custom_minimum_size = Vector2(0, 240)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var place := "The castle"
	var at := String(GameState.pending_battle.get("siege_target", ""))
	if at != "" and WorldData.SETTLEMENTS.has(at):
		place = String(WorldData.settlement(at)["name"])
	var attacker_won: bool = sim.winner != sim.siege_defender
	var title := ""
	if sim.siege_defender == Sim.ENEMY:
		title = ("%s is taken" if attacker_won else "%s holds out") % place
	else:
		title = ("%s has fallen" if attacker_won else "%s holds") % place
	var attacker_team := Sim.PLAYER if sim.siege_defender == Sim.ENEMY else Sim.ENEMY
	var holder: int = attacker_team if attacker_won else sim.siege_defender
	var held := _my_realm if holder == Sim.PLAYER else _garrison_realm
	c.draw.connect(_draw_vignette.bind(c, title, held if Heraldry.REALM_SIZES.has(held) else "bandits", holder == Sim.PLAYER))
	return c


## A field battle's picture for the result: its ground under the hour it was fought at, the
## winners' standard up and the losers' in the mud, and where it was.
func _field_vignette() -> Control:
	var c := Control.new()
	c.name = "FieldVignette"
	c.custom_minimum_size = Vector2(0, 168)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	c.draw.connect(_draw_field_vignette.bind(c, sim.winner == Sim.PLAYER))
	return c


func _draw_field_vignette(c: Control, won: bool) -> void:
	var size := c.size
	var frame := Rect2(Vector2.ZERO, size)
	var px := Art.GRASS_PIXEL * 1.4
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(px, px))
	c.draw_texture_rect(Art.ground(_biome), Rect2(Vector2.ZERO, size / px), true)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _ground_tint.a > 0.0:
		c.draw_rect(frame, _ground_tint)
	# A few of the fallen, and arrows in the turf.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_biome + _band)
	for i in 14:
		var at := Vector2(rng.randf_range(20.0, size.x - 20.0), rng.randf_range(30.0, size.y - 70.0))
		var team := Sim.PLAYER if rng.randf() < (0.35 if won else 0.65) else Sim.ENEMY
		var s := Art.pixel_size("corpse") * 1.3
		c.draw_set_transform(at, rng.randf() * TAU, Vector2(s, s))
		c.draw_texture(Art.frame("corpse", team, 0, GameState.culture if team == Sim.PLAYER else _enemy_culture), -Art.pivot("corpse"), Color(1, 1, 1, 0.85))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The winners' standard up, the losers' down.
	var up_team := Sim.PLAYER if won else Sim.ENEMY
	var pole := Vector2(size.x * 0.5 + 40.0, size.y - 66.0)
	c.draw_line(pole, pole - Vector2(0, 92), Color("6b4a2a"), 4.0)
	_draw_flag(c, pole - Vector2(0, 92), FLAG * 1.6, up_team, Troops.INFANTRY, false, true, 0.0)
	var down := Vector2(size.x * 0.5 - 90.0, size.y - 74.0)
	c.draw_line(down, down + Vector2(-60, -14), Color(0.32, 0.22, 0.13, 0.9), 3.0)
	_draw_flag(c, down + Vector2(-60, -14), FLAG, Sim.ENEMY if won else Sim.PLAYER, Troops.INFANTRY, true, false, deg_to_rad(-76.0))
	if _vignette > 0.0:
		for i in 6:
			c.draw_rect(frame.grow(-i * 8.0), Color(0.02, 0.03, 0.08, _vignette * 0.12 * (1.0 - i / 6.0)), false, 8.0)
	var band := Rect2(0, size.y - 44.0, size.x, 44.0)
	c.draw_rect(band, Color(Style.NIGHT, 0.88))
	var big: Font = Style.display_font()
	if big == null:
		big = font
	var title := _place_line()
	var fs := _fs(26)
	while fs > Style.SMALL and big.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 40.0:
		fs -= 2
	c.draw_string(big, Vector2(0, band.position.y + 31.0), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color("f3cf7a") if won else Style.ENEMY_LIGHT)
	c.draw_rect(frame, Color("6d5222"), false, 2.0)


func _draw_vignette(c: Control, title: String, realm: String, ours: bool) -> void:
	var st: Dictionary = CASTLE_STYLES.get(_castle_culture, CASTLE_STYLES["vardish"])
	var size := c.size
	var frame := Rect2(Vector2.ZERO, size)
	c.draw_rect(frame, Color(st["paving"]).darkened(0.35))
	var y := 18.0
	while y < size.y:
		var x := fmod(y * 0.7, 46.0) - 46.0
		while x < size.x:
			c.draw_rect(Rect2(x, y, 34.0, 12.0), Color(Color(st["paving"]).darkened(0.2), 0.6))
			x += 46.0
		y += 22.0
	var r := Rect2(size.x * 0.5 - 130.0, 34.0, 260.0, 140.0)
	c.draw_rect(Rect2(r.position + Vector2(9, 9), r.size), Color(0, 0, 0, 0.35))
	c.draw_rect(r, st["stone"])
	c.draw_rect(r.grow(-9.0), st["top"])
	var bx := r.position.x
	while bx < r.end.x - 5.0:
		c.draw_rect(Rect2(bx, r.position.y - 6.0, 10.0, 9.0), st["light"])
		c.draw_rect(Rect2(bx, r.end.y - 4.0, 10.0, 9.0), st["light"])
		bx += 18.0
	if st["dome"]:
		c.draw_circle(r.get_center(), r.size.y * 0.32, st["dome_color"])
		c.draw_circle(r.get_center() - Vector2(10, 10), r.size.y * 0.1, Color(st["dome_color"]).lightened(0.3))
	elif st["tiers"]:
		c.draw_rect(r.grow(-22.0), st["roof"])
		c.draw_rect(r.grow(-40.0), st["roof_light"])
	else:
		c.draw_rect(r.grow(-26.0), Color(st["top"]).darkened(0.15))
	Heraldry.realm_banner(c, realm, Rect2(Vector2(r.end.x - 12.0, 8.0), Vector2(130, 124)))
	# The ribbon.
	var band := Rect2(0, size.y - 62.0, size.x, 62.0)
	c.draw_rect(band, Color(Style.NIGHT, 0.88))
	var big: Font = Style.display_font()
	if big == null:
		big = font
	var fs := 34
	while fs > 22 and big.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 90.0:
		fs -= 2
	var tw := big.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var crown := Widgets.icon("crown" if ours else "breach")
	var ink := Color("f3cf7a") if ours else Style.ENEMY_LIGHT
	var x0 := (size.x - tw - 40.0) * 0.5
	if crown != null:
		c.draw_texture_rect(crown, Rect2(x0, band.position.y + 16.0, 30, 30), false, ink)
	c.draw_string(big, Vector2(x0 + 40.0, band.position.y + 43.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	c.draw_rect(frame, Color("6d5222"), false, 2.0)


## Bonds, told only when something changed: ranks reached, and bonds a death has ended.
## Pairs that only grew a little closer go unsaid; their talks wait at the fire.
func _result_bonds(bonds: Array, memorials: Array) -> void:
	var ups: Array = bonds.filter(func(b): return bool(b.get("rank_up", false)))
	if ups.is_empty() and memorials.is_empty():
		return
	result_content.add_child(Widgets.section("Bonds"))
	for bond in ups:
		result_content.add_child(_result_rank_up(bond))
	for m in memorials:
		result_content.add_child(_result_memorial(m))
	if not ups.is_empty():
		var hint := _result_note("A talk waits at the fire for each new rank.", Style.MUTED)
		hint.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
		result_content.add_child(hint)


func _result_rank_up(bond: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.name = "RankUp_%d_%d" % [int(bond.get("a_id", 0)), int(bond.get("b_id", 0))]
	panel.add_theme_stylebox_override("panel", Style.box(Color("2a2210"), Style.BRASS, 2, 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var a: Dictionary = bond.get("a_face", {"id": bond.get("a_id", 0), "first": bond.get("a_name", "")})
	var b: Dictionary = bond.get("b_face", {"id": bond.get("b_id", 0), "first": bond.get("b_name", "")})
	row.add_child(CaptainArt.portrait(a, Vector2(54, 72)))
	row.add_child(CaptainArt.portrait(b, Vector2(54, 72)))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := Style.label("%s & %s" % [bond.get("a_name", ""), bond.get("b_name", "")], Style.BODY, Style.BRASS)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(title)
	words.add_child(Widgets.chip_row(_bond_effects(float(bond.get("after", 0.0)))))
	row.add_child(words)
	row.add_child(Widgets.rank_badge(String(bond.get("rank_after", "")), 52.0))
	return panel


## What a bond does in battle at `points`, as chips: morale a second nearby, extra damage.
func _bond_effects(points: float) -> Array:
	var rank := Captains.rank_for(points)
	if rank <= 0:
		return [Widgets.chip("No effect until C", Style.MUTED, "◆")]
	var out: Array = [Widgets.stat("morale", "+%.1f/s" % Captains.RANK_REGEN[rank])]
	var damage := roundi(Captains.RANK_POWER[rank] * 100.0)
	if damage > 0:
		out.append(Widgets.stat("damage", "+%d%%" % damage))
	return out


func _result_memorial(m: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Memorial"
	panel.add_theme_stylebox_override("panel", Style.box(Color("15151c"), Color("4a4a58"), 2, 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	row.add_child(CaptainArt.portrait(m.get("survivor_face", {}), Vector2(54, 72), "grief"))
	row.add_child(_badged_face(m.get("fallen_face", {}), "skull", Style.MUTED, Vector2(54, 72), true))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := Style.label("%s remembers %s" % [m.get("survivor", ""), m.get("fallen", "")], Style.BODY, Style.TEXT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(title)
	var marks: Array = []
	if String(m.get("rank", "")) != "":
		marks.append(Widgets.rank_badge(String(m.get("rank", ""))))
	var shared := int(m.get("shared", 0))
	if shared > 0:
		marks.append(Widgets.stat("battle", str(shared)))
	if not marks.is_empty():
		words.add_child(Widgets.chip_row(marks))
	var line := Style.label("One place by the fire will stay empty tonight.", Style.SMALL, Style.MUTED)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(line)
	row.add_child(words)
	return panel


## The squads in one swipeable row while deploying; in battle, every squad in view at once.
func _layout_tray() -> void:
	if tray == null:
		return
	var deploying := _deploying()
	tray.columns = maxi(1, _cards.size()) if deploying else (mini(maxi(1, _cards.size()), MAX_CHIPS_PER_ROW) if _tray_rows() == 1 else ceili(_cards.size() / 2.0))
	for b in chip_buttons:
		b.custom_minimum_size.x = 118.0 if deploying else 0.0
	tray_scroll.custom_minimum_size.y = CHIP_H if deploying else _tray_rows() * _chip_h() + (_tray_rows() - 1) * CHIP_GAP
	for b in chip_buttons:
		b.custom_minimum_size.y = CHIP_H if deploying else _chip_h()
	view_row.visible = not deploying
	info_strip.visible = not deploying
	scout_chip.visible = deploying and _scouting() != ""
	if scout_chip.visible:
		var ai = sim.ai[Sim.ENEMY]
		scout_chip.text = String(SCOUT_SHORT.get(String(ai.temperament).to_lower(), "Scouts' report"))
	menu_button.icon = Widgets.icon("menu" if deploying else "pause")
	menu_button.add_theme_constant_override("icon_max_width", 34)


## Your side's result, plus what's left of the enemy, so a band that beats you stays
## weakened on the map.
func _result() -> Dictionary:
	var r := sim.result_for(Sim.PLAYER)
	r["enemy_squads"] = sim.result_for(Sim.ENEMY)["squads"]
	return r


func _back_to_camp() -> void:
	if _left_battle:
		return
	_left_battle = true
	if _test:
		GameState.pending_battle = {}
		Scenes.go("res://scenes/main_menu.tscn")
		return
	if _pending_result.is_empty():
		_pending_result = _result()
	var campaign: bool = GameState.has_campaign() and not GameState.pending_battle.is_empty()
	# Its result card has been on screen: the map doesn't tell the same numbers again.
	_pending_result["shown"] = true
	GameState.apply_result(_pending_result)
	if autoplay:
		GameState.autoplay_battles += 1
	if campaign:
		GameState.save_game()
		Scenes.go("res://scenes/world_map.tscn")
	else:
		Scenes.go("res://scenes/main_menu.tscn")


# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	# The grade sits over the field and under the HUD.
	var grade_layer := CanvasLayer.new()
	grade_layer.layer = 1
	add_child(grade_layer)
	_grade = ColorRect.new()
	_grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/battle_grade.gdshader")
	_grade.material = mat
	_grade.visible = false
	grade_layer.add_child(_grade)
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = Style.make_theme()
	layer.add_child(hud)

	# Top bar: the menu, then deployment progress or the battle's balance of strength.
	top_panel = PanelContainer.new()
	top_panel.add_theme_stylebox_override("panel", _bar_box(true))
	top_panel.anchor_right = 1.0
	top_panel.offset_bottom = TOP_BAR
	hud.add_child(top_panel)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	top_panel.add_child(top_row)
	menu_button = _button("", Vector2(Style.TOUCH, Style.TOUCH), _on_menu)
	menu_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_button.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
	top_row.add_child(menu_button)
	title_label = Style.label("Deploy", Style.LARGE, Style.BRASS)
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(title_label)
	# "3 of 5 placed" as pips; the cards' ticks say which. The words stay as a tooltip.
	status_label = Style.label("", Style.BODY)
	status_label.visible = false
	top_row.add_child(status_label)
	deploy_pips = Control.new()
	deploy_pips.name = "DeployPips"
	deploy_pips.custom_minimum_size = Vector2(0, 30)
	deploy_pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deploy_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	deploy_pips.mouse_filter = Control.MOUSE_FILTER_PASS
	deploy_pips.draw.connect(_draw_deploy_pips)
	top_row.add_child(deploy_pips)
	scout_chip = _button("", Vector2(0, Style.TOUCH), func(): _hint(_scouting()))
	scout_chip.name = "ScoutChip"
	scout_chip.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
	scout_chip.add_theme_color_override("font_color", Color("f3b0a8"))
	_set_icon(scout_chip, "eye", false, Color("f3b0a8"))
	var chip_box := _chip_box(Color("3a1c1c"), Color(Style.ENEMY_LIGHT, 0.55))
	for st in ["normal", "hover", "pressed", "focus"]:
		scout_chip.add_theme_stylebox_override(st, chip_box)
	scout_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(scout_chip)
	power_bar = Control.new()
	power_bar.custom_minimum_size = Vector2(0, 44)
	power_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	power_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_bar.draw.connect(_draw_power)
	top_row.add_child(power_bar)
	speed_button = _button("1×", Vector2(Style.TOUCH, Style.TOUCH), _on_speed)
	top_row.add_child(speed_button)

	# Bottom panel: the squad tray, the selection as icons, the orders. Hints float above it.
	bottom_panel = PanelContainer.new()
	bottom_panel.add_theme_stylebox_override("panel", _bar_box(false))
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.anchor_right = 1.0
	bottom_panel.offset_top = -_bottom_height()
	bottom_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.add_child(bottom_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	bottom_panel.add_child(col)

	tray_scroll = ScrollContainer.new()
	tray_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tray_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	tray_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(tray_scroll)
	tray = GridContainer.new()
	tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tray.add_theme_constant_override("h_separation", int(CHIP_GAP))
	tray.add_theme_constant_override("v_separation", int(CHIP_GAP))
	tray_scroll.add_child(tray)
	for i in _cards.size():
		var b := _button("", Vector2(0, CHIP_H), _on_chip.bind(i))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# let a drag across the cards scroll the row
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.draw.connect(_draw_chip.bind(i))
		tray.add_child(b)
		chip_buttons.append(b)

	# The selection as icons and numbers. The sentence it replaces stays in info_label,
	# never shown, as the strip's tooltip.
	info_strip = Control.new()
	info_strip.name = "InfoStrip"
	info_strip.custom_minimum_size = Vector2(10, 34)
	info_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_strip.mouse_filter = Control.MOUSE_FILTER_PASS
	info_strip.draw.connect(_draw_info_strip)
	col.add_child(info_strip)
	info_label = Style.label("", Style.SMALL, Style.TEXT)
	info_label.visible = false
	info_strip.add_child(info_label)

	var buttons_row := HBoxContainer.new()
	buttons_row.add_theme_constant_override("separation", 10)
	col.add_child(buttons_row)
	auto_button = _order_button("Auto-place", "auto", _on_auto, buttons_row)
	fight_button = _order_button("Fight", "fight", _on_fight, buttons_row, true, true)
	advance_button = _order_button("Advance all", "advance", _on_advance, buttons_row, true)
	hold_button = _order_button("Hold all", "hold", _on_hold, buttons_row)
	storm_button = _order_button("Storm", "storm", _on_storm, buttons_row)
	storm_button.name = "StormButton"
	storm_button.visible = false
	cancel_button = _order_button("Cancel", "cancel", _on_storm_cancel, buttons_row)
	cancel_button.name = "StormCancel"
	cancel_button.visible = false
	storm_go_button = _order_button("Storm!", "storm", _on_storm_go, buttons_row, true, true)
	storm_go_button.name = "StormGo"
	storm_go_button.visible = false
	post_button = _order_button("Man the walls", "walls", _on_post, buttons_row)
	post_button.name = "PostButton"
	post_button.visible = false
	ability_button = _order_button("", "fight", _on_ability, buttons_row)
	ability_button.draw.connect(_draw_ability_cooldown)
	hold_fire_button = _order_button("Hold fire", "holdfire", _on_hold_fire, buttons_row)
	for b in [advance_button, hold_button, storm_button, post_button, ability_button, hold_fire_button]:
		_order_label(b, b.text)


	view_row = HBoxContainer.new()
	view_row.add_theme_constant_override("separation", 10)
	col.add_child(view_row)
	camera_button = _view_button("Following", "eye", _toggle_camera)
	_view_button("Re-center", "center", _recenter_camera)
	_view_button("Whole army", "company", func(): _select(null))

	# The objective, under the top bar, for every battle: the kit's chip, dark for the field.
	objective_chip = Widgets.chip("Objective", Color("f3cf7a"), "", "objective")
	objective_chip.name = "ObjectiveChip"
	objective_chip.add_theme_stylebox_override("panel", _chip_box(Color(Style.NIGHT, 0.92), Color("6d5222"), 2))
	objective_chip.anchor_left = 0.5
	objective_chip.anchor_right = 0.5
	objective_chip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	objective_chip.visible = false
	objective_icon = objective_chip.find_child("Icon", true, false) as TextureRect
	objective_label = objective_chip.find_child("Text", true, false) as Label
	objective_label.add_theme_color_override("font_color", Color("f3cf7a"))
	hud.add_child(objective_chip)

	# A tapped enemy, read at a glance, under the objective.
	inspect_pill = PanelContainer.new()
	inspect_pill.name = "InspectPill"
	inspect_pill.add_theme_stylebox_override("panel", _chip_box(Color(Style.NIGHT, 0.92), Color(Style.ENEMY_LIGHT, 0.55), 2))
	inspect_pill.anchor_left = 0.5
	inspect_pill.anchor_right = 0.5
	inspect_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	inspect_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspect_pill.visible = false
	hud.add_child(inspect_pill)

	# The hint: a toast above the orders that fades, so the field keeps its room.
	hint_toast = PanelContainer.new()
	hint_toast.name = "HintToast"
	var tb := _chip_box(Color(Style.NIGHT, 0.9), Color(Style.BRASS, 0.35))
	tb.set_corner_radius_all(18)
	tb.content_margin_left = 18.0
	tb.content_margin_right = 18.0
	tb.content_margin_top = 8.0
	tb.content_margin_bottom = 10.0
	hint_toast.add_theme_stylebox_override("panel", tb)
	hint_toast.anchor_left = 0.0
	hint_toast.anchor_right = 1.0
	hint_toast.anchor_top = 1.0
	hint_toast.anchor_bottom = 1.0
	hint_toast.offset_left = 20.0
	hint_toast.offset_right = -20.0
	hint_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_toast.visible = false
	hud.add_child(hint_toast)
	hint_label = Style.label("", Style.SMALL, Style.TEXT)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.max_lines_visible = 4
	hint_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hint_toast.add_child(hint_label)

	# The death roll plays over the field.
	roll_layer = Control.new()
	roll_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	roll_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	roll_layer.draw.connect(_draw_roll)
	hud.add_child(roll_layer)
	beat_layer = Control.new()
	beat_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	beat_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	beat_layer.draw.connect(_draw_beats)
	hud.add_child(beat_layer)

	pause_panel = _centered_panel(hud)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 16)
	pause_panel.add_child(pv)
	var paused_title := Style.label("Paused", Style.TITLE_SIZE, Style.BRASS)
	paused_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(paused_title)
	pause_note = Style.label("", Style.SMALL, Style.MUTED)
	pause_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_note.custom_minimum_size = Vector2(480, 0)
	pause_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(pause_note)
	var resume := _button("Resume", Vector2(0, Style.TOUCH), _on_menu)
	Style.make_primary(resume)
	_set_icon(resume, "resume", false, Style.BRASS_INK)
	pv.add_child(resume)
	retreat_button = _button("Retreat", Vector2(0, Style.TOUCH), _on_retreat)
	_set_icon(retreat_button, "retreat", false, Style.ENEMY_LIGHT)
	retreat_button.add_theme_color_override("font_color", Style.ENEMY_LIGHT)
	pv.add_child(retreat_button)

	result_scrim = ColorRect.new()
	result_scrim.color = Color(Style.NIGHT, 0.88)
	result_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	result_scrim.visible = false
	hud.add_child(result_scrim)
	result_panel = PanelContainer.new()
	result_panel.anchor_left = 0.05
	result_panel.anchor_right = 0.95
	result_panel.anchor_top = 0.045
	result_panel.anchor_bottom = 0.955
	result_panel.visible = false
	hud.add_child(result_panel)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 12)
	result_panel.add_child(rv)
	result_title = Style.label("Victory", 64, Style.BRASS)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(result_title)
	var result_scroll := ScrollContainer.new()
	result_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(result_scroll)
	result_content = VBoxContainer.new()
	result_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_content.add_theme_constant_override("separation", 12)
	result_scroll.add_child(result_content)
	result_body = Style.label("", Style.BODY)
	result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var back := _button("Back to the map" if not GameState.pending_battle.is_empty() else "Back to camp", Vector2(0, Style.TOUCH), _back_to_camp)
	Style.make_primary(back)
	rv.add_child(back)

	terrain_hint_panel = _centered_panel(hud)
	var thv := VBoxContainer.new()
	thv.add_theme_constant_override("separation", 16)
	terrain_hint_panel.add_child(thv)
	terrain_hint_title = Style.label("Battlefield Ground", Style.TITLE_SIZE, Style.BRASS)
	terrain_hint_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thv.add_child(terrain_hint_title)
	terrain_hint_body = Style.label("", Style.BODY)
	terrain_hint_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	terrain_hint_body.custom_minimum_size = Vector2(500, 0)
	terrain_hint_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thv.add_child(terrain_hint_body)
	terrain_hint_rows = VBoxContainer.new()
	terrain_hint_rows.name = "TerrainRows"
	terrain_hint_rows.custom_minimum_size = Vector2(500, 0)
	terrain_hint_rows.add_theme_constant_override("separation", 12)
	thv.add_child(terrain_hint_rows)
	var dismiss_btn := _button("Understood", Vector2(0, Style.TOUCH), func(): terrain_hint_panel.visible = false)
	Style.make_primary(dismiss_btn)
	thv.add_child(dismiss_btn)


func _bar_box(top: bool) -> StyleBoxFlat:
	var sb := Style.box(Style.NIGHT, Color(0, 0, 0, 0), 0, 0)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0 + (float(_insets["top"]) if top else 6.0)
	sb.content_margin_bottom = 8.0 if top else 8.0 + float(_insets["bottom"])
	return sb


func _centered_panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.visible = false
	parent.add_child(p)
	return p


func _button(text: String, min_size: Vector2, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	return b


## An order button: an icon over a short word, or for the one big call to action (`wide`)
## an icon beside larger words. `primary` makes it brass.
func _order_button(text: String, icon_key: String, callback: Callable, row: HBoxContainer, primary: bool = false, wide: bool = false) -> Button:
	var b := _wide_button(text, callback, row)
	b.custom_minimum_size.y = _cmd_h()
	b.add_theme_font_size_override("font_size", Style.text_size(Style.LARGE if wide else ORDER_FONT))
	if not wide:
		# Words stay on every button, so a long one ("Hold fire (all bows)") takes two lines.
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if primary:
		Style.make_primary(b)
		b.size_flags_stretch_ratio = 2.4 if wide else 1.6
	_set_icon(b, icon_key, not wide, Style.BRASS_INK if primary else Style.TEXT)
	return b


## The order bar's height: room for an icon over two lines of words, at the text size the
## player chose (never less than CMD_H).
func _cmd_h() -> float:
	return maxf(CMD_H, 44.0 + 2.0 * float(Style.text_size(ORDER_FONT)) * 1.2 + 12.0)


func _view_button(text: String, icon_key: String, callback: Callable) -> Button:
	var b := _wide_button(text, callback, view_row)
	b.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
	_set_icon(b, icon_key, false, Style.MUTED)
	return b


## Puts an icon on a button: over its words (`stacked`) or beside them.
func _set_icon(b: Button, key: String, stacked: bool = true, tint: Color = Style.TEXT) -> void:
	b.icon = Widgets.icon(key)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if stacked else HORIZONTAL_ALIGNMENT_LEFT
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP if stacked else VERTICAL_ALIGNMENT_CENTER
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(c, tint)
	b.add_theme_color_override("icon_disabled_color", Color(tint, 0.35))


func _wide_button(text: String, callback: Callable, row: HBoxContainer) -> Button:
	var b := _button(text, Vector2(0, Style.TOUCH), callback)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", Style.text_size(Style.BODY))
	b.clip_text = true
	row.add_child(b)
	return b


func _refresh_hud() -> void:
	var deploying := sim.phase == Sim.PHASE_DEPLOY
	title_label.visible = deploying
	deploy_pips.visible = deploying
	power_bar.visible = not deploying
	speed_button.visible = not deploying
	auto_button.visible = deploying
	fight_button.visible = deploying
	var planning := not _storm_plan.is_empty()
	# Running for it, nobody is left to take an order.
	var running: bool = sim.withdrawing == Sim.PLAYER
	advance_button.visible = not deploying and not planning and not running
	hold_button.visible = not deploying and not planning and not running
	cancel_button.visible = planning
	storm_go_button.visible = planning
	var goal := _objective_text()
	objective_chip.visible = sim.winner == -1 and goal != ""
	if objective_chip.visible:
		objective_label.text = goal
		objective_icon.texture = Widgets.icon(_objective_icon())
	menu_button.disabled = sim.winner != -1
	menu_button.text = ""
	speed_button.text = "¼×" if slow_held() else ("2×" if speed > 1.5 else "1×")
	# The pause card's note is what Retreat costs (see _retreat_words); the scouting is on
	# the title card and behind the scout chip.
	if deploying:
		_refresh_deploy()
	else:
		_refresh_battle()
	for b in chip_buttons:
		b.queue_redraw()
	power_bar.queue_redraw()
	roll_layer.queue_redraw()
	beat_layer.queue_redraw()


func _refresh_deploy() -> void:
	var unplaced_player := 0
	for e in _cards:
		if sim.placed_squad(Sim.PLAYER, e["roster_id"]) == null:
			unplaced_player += 1
	status_label.text = "%d of %d placed" % [_cards.size() - unplaced_player, _cards.size()]
	deploy_pips.tooltip_text = status_label.text
	deploy_pips.queue_redraw()
	auto_button.disabled = unplaced_player == 0 or sim.winner != -1
	fight_button.disabled = unplaced_player > 0 or sim.winner != -1
	ability_button.visible = false
	hold_fire_button.visible = false
	storm_button.visible = false
	post_button.visible = false
	info_label.text = ""
	_strip_items = []
	info_strip.queue_redraw()


func _refresh_battle() -> void:
	var sq = selected_squad
	var items: Array = []
	# With nothing selected, the bows' two orders go to every company of them at once.
	var bows: Array = _player_bows() if sq == null and _storm_plan.is_empty() else []
	var archers: Array = bows.filter(func(bow): return bow.type == Troops.ARCHERS)
	ability_button.visible = sq != null or not archers.is_empty()
	hold_fire_button.visible = (sq != null and sq.ranged) or not bows.is_empty()
	# Storm stays in the bar for an assault, greyed out once the gate is down.
	storm_button.visible = sq == null and sim.objective == Sim.OBJECTIVE_SIEGE and sim.siege_defender == Sim.ENEMY \
		and sim.winner == -1 and _storm_plan.is_empty()
	storm_button.disabled = sim.gate_hp <= 0.0
	var defending: bool = sim.objective == Sim.OBJECTIVE_SIEGE and sim.siege_defender == Sim.PLAYER
	post_button.visible = sq == null and defending and sim.winner == -1
	if post_button.visible:
		var broken: bool = sim.gate_hp <= 0.0
		_order_label(post_button, "Hold breach" if broken else "Man the walls")
		post_button.icon = Widgets.icon("breach" if broken else "walls")
	if sq != null:
		var title := _company(sq.roster_id)
		if title == "":
			title = _name(sq.type, Sim.PLAYER, sq.roster_id)
		var state: String = ORDER_WORDS.get(sq.order, sq.order)
		if sq.wheeling:
			state = "wheeling"
		elif sq.braced():
			state = "braced"
		elif sq.engaged:
			state = "fighting"
		var base_state := state
		if sq.hold_fire:
			state = "holding fire" if sq.order == "hold" else state + ", holding fire"
		var arrows := ""
		if sq.arrows > 0:
			arrows = " · %d arrows" % sq.arrows
		elif sq.arrows == 0:
			arrows = " · no arrows"
		var mood := " · fury" if sq.fury > 0.0 else ""
		info_label.text = "Selected: %s · %d men · %d%% morale%s%s · %s" % [
			title, sq.alive_count(), maxi(0, int(sq.morale)), mood, arrows, state]
		# Men and morale are on the card and the standard; the strip says what the card
		# doesn't: who, what they're doing, arrows, fury.
		items.append(["", title, Style.TEXT])
		var state_key := base_state if ORDER_ICONS.has(base_state) else String(sq.order)
		items.append([String(ORDER_ICONS.get(state_key, "hold")), base_state, Style.BRASS])
		if sq.hold_fire:
			items.append(["holdfire", "", Style.MUTED])
		if sq.arrows >= 0:
			items.append(["bow", str(sq.arrows), Style.TEXT if sq.arrows > 0 else Style.ENEMY_LIGHT])
		if sq.fury > 0.0:
			items.append(["vengeful", "", Style.ENEMY_LIGHT])
		_order_label(advance_button, "Advance")
		_order_label(hold_button, "Hold")
		var ab := Troops.ability(sq.type)
		_order_label(ability_button, String(ab["name"]))
		ability_button.icon = Widgets.icon(String(ABILITY_ICONS.get(sq.type, "fight")))
		ability_button.modulate = Color(1, 1, 1, 1.0 if sim.ability_ready(sq) else 0.55)
		ability_button.queue_redraw()
		_order_label(hold_fire_button, "Fire at will" if sq.hold_fire else "Hold fire")
		hold_fire_button.icon = Widgets.icon("bow" if sq.hold_fire else "holdfire")
	else:
		var allies_active := 0
		for s in sim.squads:
			if s.team == Sim.PLAYER and s.is_active() and s.is_ally:
				allies_active += 1
		var res_count: int = sim.reserve_queue[Sim.PLAYER].size()
		var extra := ""
		if allies_active > 0 or res_count > 0:
			extra = " · Allies: %d · Reserves: %d" % [allies_active, res_count]
		info_label.text = "Whole army · " + _order_summary() + extra
		# The whole army as counts by order: the company mark, then each order's icon.
		items.append(["company", "", Style.MUTED])
		var counts := _order_counts()
		for word in ORDER_WORDS:
			if counts.has(word):
				items.append([String(ORDER_ICONS[word]), str(counts[word]), Style.TEXT])
		if counts.is_empty():
			items.append(["", "none left", Style.MUTED])
		if allies_active > 0:
			items.append(["bond", str(allies_active), Style.PLAYER_LIGHT])
		if res_count > 0:
			items.append(["plus", str(res_count), Style.PLAYER_LIGHT])
		if not _storm_plan.is_empty():
			var up := 0
			var ram := 0
			for id in _storm_plan:
				up += 1 if _storm_plan[id] == "ladder" else 0
				ram += 1 if _storm_plan[id] == "ram" else 0
			info_label.text = "Storm plan · %d to the ladders · %d to the ram" % [up, ram]
			items = [["storm", "", Style.BRASS], ["ladder", str(up), Color("ffe08a")], ["ram", str(ram), Color("ffd79a")]]
		_order_label(advance_button, "Sally" if defending else "Advance all")
		_order_label(hold_button, "Hold all")
		if not bows.is_empty():
			var all_holding: bool = bows.all(func(holder): return holder.hold_fire)
			_order_label(hold_fire_button, "Fire at will (all bows)" if all_holding else "Hold fire (all bows)")
			hold_fire_button.icon = Widgets.icon("bow" if all_holding else "holdfire")
		if not archers.is_empty():
			_order_label(ability_button, "Volley (all)")
			ability_button.icon = Widgets.icon(String(ABILITY_ICONS[Troops.ARCHERS]))
			ability_button.modulate = Color(1, 1, 1, 1.0 if archers.any(func(archer): return sim.ability_ready(archer)) else 0.55)
			ability_button.queue_redraw()
	advance_button.disabled = sim.winner != -1
	hold_button.disabled = sim.winner != -1
	_strip_items = items
	info_strip.tooltip_text = info_label.text
	info_strip.queue_redraw()


## The objective chip under the top bar, for every kind of battle: a short phrase, and
## for holding the village the time still to hold.
func _objective_text() -> String:
	match String(sim.objective):
		Sim.OBJECTIVE_SIEGE:
			var defending: bool = sim.siege_defender == Sim.PLAYER
			if not _storm_plan.is_empty():
				return "Storm plan"
			if sim.gate_hp <= 0.0:
				return "Hold the breach" if defending else "Rout the garrison"
			return "Man the walls" if defending else "Take the walls"
		Sim.OBJECTIVE_CHIEF:
			return "Slay %s" % (sim.chief_name if sim.chief_name != "" else "their chief")
		Sim.OBJECTIVE_VILLAGE:
			return "Defend %s" % _clock_text(maxf(0.0, Sim.VILLAGE_DURATION - sim.time))
		Sim.OBJECTIVE_AMBUSH:
			return "Protect the column"
		"raid":
			return "Drive off the militia"
	return "Rout their host"


func _objective_icon() -> String:
	match String(sim.objective):
		Sim.OBJECTIVE_SIEGE:
			return "breach" if sim.gate_hp <= 0.0 else "walls"
		Sim.OBJECTIVE_CHIEF:
			return "skull"
		Sim.OBJECTIVE_VILLAGE:
			return "clock"
		Sim.OBJECTIVE_AMBUSH:
			return "company"
		"raid":
			return "fire"
	return "objective"


## "5 holding · 2 advancing" for the squads you still have fighting.
func _order_summary() -> String:
	var counts := _order_counts()
	var parts := PackedStringArray()
	for order in ORDER_WORDS:
		if counts.has(order):
			parts.append("%d %s" % [counts[order], ORDER_WORDS[order]])
	return "none left" if parts.is_empty() else " · ".join(parts)


## How many of your squads still fighting have each order: {"hold": 5, "advance": 2}.
func _order_counts() -> Dictionary:
	var counts := {}
	for sq in sim.squads:
		if sq.team == Sim.PLAYER and sq.is_active() and not sq.is_ally:
			counts[sq.order] = int(counts.get(sq.order, 0)) + 1
	return counts


## An order button's word, under its icon, in every battle (a touch screen has no
## tooltips); the tooltip says it again for the mouse.
func _order_label(b: Button, word: String) -> void:
	b.tooltip_text = word
	if b.text != word:
		b.text = word
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP if word != "" else VERTICAL_ALIGNMENT_CENTER


## The selection as icons and numbers: [icon, text, colour] each, left to right, as many
## as fit.
func _draw_info_strip() -> void:
	var c := info_strip
	var fs := _fs(Style.SMALL)
	var x := 0.0
	var mid := c.size.y * 0.5
	for it in _strip_items:
		var key := String(it[0])
		var text := String(it[1])
		var col: Color = it[2]
		var need := (30.0 if key != "" else 0.0) + (font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if text != "" else 0.0)
		if x + need > c.size.x:
			break
		if key != "":
			var tex := Widgets.icon(key)
			if tex != null:
				c.draw_texture_rect(tex, Rect2(x, mid - 13.0, 26.0, 26.0), false, col if text == "" else Style.MUTED)
			x += 30.0
		if text != "":
			c.draw_string(font, Vector2(x, mid + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			x += font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		x += 18.0


## A pip for each of your squads, brass once it's on the field.
func _draw_deploy_pips() -> void:
	var c := deploy_pips
	var n := _cards.size()
	if n == 0:
		return
	var step := minf(22.0, (c.size.x - 8.0) / float(n))
	var r := minf(7.0, step * 0.38)
	for i in n:
		var placed: bool = sim.placed_squad(Sim.PLAYER, _cards[i]["roster_id"]) != null
		var at := Vector2(8.0 + step * (float(i) + 0.5), c.size.y * 0.5)
		if placed:
			c.draw_circle(at, r, Style.BRASS)
		else:
			c.draw_arc(at, r - 1.0, 0.0, TAU, 16, Style.MUTED, 2.0)


## The tug of war: the share of all each side brought that is still fighting or still to
## come on from its reserve (BattleSim.strength, which the verdict compares when time runs
## out), so the split is left of the middle notch exactly when you are ahead. Men waiting
## in a reserve are the lighter, hatched end of their side, with "+N in reserve" beside its
## share. The clock only shows in the last minute.
func _draw_power() -> void:
	var w := power_bar.size.x
	var h := 26.0
	var y := (power_bar.size.y - h) * 0.5
	var siege: bool = sim.objective == Sim.OBJECTIVE_SIEGE
	if siege:
		# A siege keeps the gate in view under the balance of strength.
		h = 22.0
		y = 0.0
		var gy := h + 8.0
		var share := sim.gate_hp / maxf(1.0, sim.gate_max)
		var label := "%d%%" % int(ceil(share * 100.0)) if sim.gate_hp > 0.0 else ""
		var gate_ink := Style.BRASS if sim.gate_hp > 0.0 else Style.PLAYER_LIGHT
		var gate_icon := Widgets.icon("gate" if sim.gate_hp > 0.0 else "breach")
		if gate_icon != null:
			power_bar.draw_texture_rect(gate_icon, Rect2(0, gy - 6.0, 22, 22), false, gate_ink)
		power_bar.draw_string(font, Vector2(26, gy + 11.0), label, HORIZONTAL_ALIGNMENT_LEFT, 90.0, _fs(Style.SMALL), gate_ink)
		var track := Rect2(118.0, gy, w - 118.0, 10.0)
		power_bar.draw_rect(track, Style.NIGHT)
		power_bar.draw_rect(Rect2(track.position, Vector2(track.size.x * share, track.size.y)), Color(0.91, 0.63, 0.24).lerp(Style.ENEMY, 1.0 - share))
		power_bar.draw_rect(track, Style.RULE, false, 1.0)
	var start_mine := maxf(1.0, float(sim.start_men(Sim.PLAYER)))
	var start_theirs := maxf(1.0, float(sim.start_men(Sim.ENEMY)))
	var res_mine := float(sim.reserve_men(Sim.PLAYER))
	var res_theirs := float(sim.reserve_men(Sim.ENEMY))
	var mine: float = sim.strength(Sim.PLAYER)
	var theirs: float = sim.strength(Sim.ENEMY)
	# The bar shows the men just lost as a pale bite at each side's inner end, draining away.
	var was_mine: float = maxf(mine, (_shown_men[Sim.PLAYER] + res_mine) / start_mine)
	var was_theirs: float = maxf(theirs, (_shown_men[Sim.ENEMY] + res_theirs) / start_theirs)
	var total := maxf(0.0001, was_mine + was_theirs)
	var blue := w * mine / total
	var split := w * was_mine / total
	var red_start := w - w * theirs / total
	power_bar.draw_rect(Rect2(0, y, w, h), Style.RULE)
	power_bar.draw_rect(Rect2(0, y, blue, h), Style.PLAYER)
	power_bar.draw_rect(Rect2(blue, y, split - blue, h), Style.PLAYER_LIGHT)
	power_bar.draw_rect(Rect2(split, y, red_start - split, h), Style.ENEMY_LIGHT)
	power_bar.draw_rect(Rect2(red_start, y, w - red_start, h), Style.ENEMY)
	# Each side's reserve, still to come on: the outer end of its share, hatched.
	_draw_reserve(Rect2(0, y, w * (res_mine / start_mine) / total, h), Style.PLAYER_LIGHT)
	var res_theirs_w := w * (res_theirs / start_theirs) / total
	_draw_reserve(Rect2(w - res_theirs_w, y, res_theirs_w, h), Style.ENEMY_LIGHT)
	# The middle: where the split must be, at the end of time, to win.
	power_bar.draw_rect(Rect2(w * 0.5 - 1.0, y + h - 7.0, 2.0, 9.0), Color(Style.NIGHT, 0.85))
	power_bar.draw_rect(Rect2(split - 2.0, y - 5.0, 4.0, h + 10.0), Style.TEXT)
	var fs := _fs(Style.SMALL)
	var mine_text := "%d%%" % roundi(mine * 100.0)
	var theirs_text := "%d%%" % roundi(theirs * 100.0)
	power_bar.draw_string(font, Vector2(8, y + h - 5.0), mine_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.TEXT)
	power_bar.draw_string(font, Vector2(w - 98.0, y + h - 5.0), theirs_text, HORIZONTAL_ALIGNMENT_RIGHT, 90.0, fs, Style.TEXT)
	var room := w * 0.5 - 24.0
	if res_mine > 0.0:
		var x := 8.0 + font.get_string_size(mine_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 8.0
		power_bar.draw_string(font, Vector2(x, y + h - 5.0), _reserve_text(int(res_mine), fs, room - x), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.TEXT)
	if res_theirs > 0.0:
		var x2 := w - 8.0 - font.get_string_size(theirs_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x - 8.0
		var said := _reserve_text(int(res_theirs), fs, room - (w - x2))
		power_bar.draw_string(font, Vector2(x2 - font.get_string_size(said, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, y + h - 5.0), said, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.TEXT)
	var left := Sim.TIME_LIMIT - sim.time
	if left < 60.0 and sim.winner == -1:
		var clock := "%d:%02d" % [floori(left / 60.0), int(left) % 60]
		power_bar.draw_string_outline(font, Vector2(0, y + h - 5.0), clock, HORIZONTAL_ALIGNMENT_CENTER, w, _fs(Style.SMALL), 5, Style.NIGHT)
		power_bar.draw_string(font, Vector2(0, y + h - 5.0), clock, HORIZONTAL_ALIGNMENT_CENTER, w, _fs(Style.SMALL), Style.TEXT)


## A side's reserve on the strength bar: a lighter stretch, hatched.
func _draw_reserve(r: Rect2, ink: Color) -> void:
	if r.size.x < 0.5:
		return
	power_bar.draw_rect(r, Color(ink, 0.55))
	var x := r.position.x + 3.0
	while x < r.end.x:
		power_bar.draw_line(Vector2(x, r.end.y), Vector2(minf(x + 8.0, r.end.x), r.position.y), Color(Style.NIGHT, 0.35), 2.0)
		x += 9.0


## "+40 in reserve", or just "+40" where there isn't room for the words.
func _reserve_text(men: int, fs: int, width: float) -> String:
	var long := "+%d in reserve" % men
	if font.get_string_size(long, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= width:
		return long
	return "+%d" % men


## A card in the tray: the squad's standard, its captain, its men, and in battle its
## morale and whether its ability is ready.
func _draw_chip(i: int) -> void:
	var b: Button = chip_buttons[i]
	var e: Dictionary = _cards[i]
	var sq = sim.placed_squad(Sim.PLAYER, e["roster_id"])
	var battle := sim.phase == Sim.PHASE_BATTLE
	var out: bool = battle and (sq == null or not sq.is_active())
	var picked: bool = (not battle and e["roster_id"] == selected_id) or (battle and sq != null and sq == selected_squad)
	var placed: bool = sq != null
	var size := b.size
	# A squad that has just broken: its card cracks and shakes.
	var broke_t: float = _clock - float(_card_broke.get(sq, -9.0)) if sq != null else 9.0
	if broke_t < 0.3 and not Style.motion_reduced():
		b.draw_set_transform(Vector2(sin(broke_t * 70.0) * 4.0 * (1.0 - broke_t / 0.3), 0.0), 0.0, Vector2.ONE)
	var bg := Style.RAISED
	if picked:
		bg = Style.RAISED.lightened(0.14)
	elif out or (not battle and placed):
		bg = Style.PANEL
	b.draw_rect(Rect2(Vector2.ZERO, size), bg)
	b.draw_rect(Rect2(Vector2.ZERO, size), Style.BRASS if picked else Style.RULE, false, 3.0 if picked else 2.0)
	var dim := 0.45 if out else 1.0
	var rec := _squad_record(e["roster_id"])
	var c = rec.get("captain")
	var face: Texture2D = CaptainArt.texture(c, "", true) if typeof(c) == TYPE_DICTIONARY else null
	# Deploying, the card shows the troop itself; in battle, the flag its standard flies.
	var troop: Texture2D = Art.icon(String(e["type"]), Sim.PLAYER, String(rec.get("culture", GameState.culture))) if not battle else null
	var mark := Rect2(36, 8, 28, 28) if face != null else Rect2(6, 4, 34, 34)
	if face != null:
		b.draw_texture_rect(face, Rect2(5, 3, 30, 40), false, Color(1, 1, 1, dim))
	if troop != null:
		b.draw_texture_rect(troop, mark, false, Color(1, 1, 1, dim))
	elif face != null:
		_draw_flag(b, Vector2(39, 9), Vector2(22, 16), Sim.PLAYER, String(e["type"]), out, false, 0.0)
	else:
		_draw_flag(b, Vector2(8, 8), Vector2(28, 21), Sim.PLAYER, String(e["type"]), out, false, 0.0)
	var who := _name(e["type"], Sim.PLAYER, e["roster_id"])
	var hurt := false
	if c != null:
		who = String(c["first"])
		hurt = int(c.get("wounded", 0)) > 0
	var men: int = e["men"] if sq == null else sq.alive_count()
	var fs := _fs(Style.SMALL)
	var men_w := font.get_string_size(str(men), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	b.draw_string(font, Vector2(size.x - 6.0 - men_w, 27), str(men), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Style.TEXT, dim))
	var men_icon := Widgets.icon("men")
	if men_icon != null:
		b.draw_texture_rect(men_icon, Rect2(size.x - 8.0 - men_w - 20.0, 10, 20, 20), false, Color(Style.MUTED, dim))
	# A wounded captain: the wounded mark after the name, not a star in it.
	var room := size.x - 12.0 - (24.0 if hurt else 0.0)
	var shown := _fit(who, fs, room)
	var ink := Color(Style.TEXT if not (placed and not battle and not picked) else Style.MUTED, dim)
	b.draw_string(font, Vector2(6, 58), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	if hurt:
		var wtex := Widgets.icon("wounded")
		if wtex != null:
			var nx := 6.0 + font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 4.0
			b.draw_texture_rect(wtex, Rect2(nx, 40, 20, 20), false, Color(1, 1, 1, dim))
	if battle and sq != null:
		if sq.is_active():
			# The nerve's shape (▲ steady, ◆ shaken, ▼ near breaking) before the bar, so
			# it reads without its colour.
			_draw_morale_mark(b, Vector2(11, size.y - 10.5), sq.morale, 5.0)
			var bar := Rect2(20, size.y - 14.0, size.x - 26.0, 7)
			var morale_shown := float(_card_morale.get(sq, sq.morale))
			var m := clampf(morale_shown / 100.0, 0.0, 1.0)
			b.draw_rect(bar, Style.NIGHT)
			if morale_shown > sq.morale + 0.5:
				# What it has just lost, draining away.
				b.draw_rect(Rect2(bar.position, Vector2(bar.size.x * m, bar.size.y)), Color(Style.ENEMY_LIGHT, 0.7))
			b.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(minf(morale_shown, sq.morale) / 100.0, 0.0, 1.0), bar.size.y)), Style.morale_color(sq.morale))
			if sim.ability_ready(sq):
				var dot := Vector2(size.x - 12.0, size.y - 26.0)
				var since: float = _clock - float(_ready_at.get(sq, -9.0))
				var r := 5.0
				if since < 0.3 and not Style.motion_reduced():
					r = 5.0 * (1.0 + 0.6 * sin(since / 0.3 * PI))
					b.draw_arc(dot, 6.0 + since * 40.0, 0.0, TAU, 20, Color(Style.BRASS, 1.0 - since / 0.3), 2.0)
				b.draw_circle(dot, r, Style.BRASS)
			# States, as badges: wavering, out of arrows.
			if wavering(sq):
				var pulse := 1.0 if Style.motion_reduced() else 0.6 + 0.4 * sin(_clock * 9.0)
				b.draw_circle(Vector2(size.x - 12.0, 46.0), 8.0, Color(Style.ENEMY_LIGHT, pulse))
				b.draw_string(font, Vector2(size.x - 15.5, 52.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.05, 0.03, 0.03))
			elif sq.arrows == 0:
				_draw_empty_quiver(b, Vector2(size.x - 12.0, 46.0), 8.0)
			# Struck from the side or by a charge: the card's edge flashes red.
			var hit_t: float = _clock - float(_card_hit.get(sq, -9.0))
			if hit_t < 0.3:
				b.draw_rect(Rect2(Vector2.ZERO, size), Color(Style.MORALE_LOW, 1.0 - hit_t / 0.3), false, 4.0)
			_draw_role_badge(b, sq)
		else:
			b.draw_string(font, Vector2(6, size.y - 6.0), "out", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.MUTED)
			if _card_broke.has(sq):
				# The crack it took when it broke.
				var k := clampf(broke_t / 0.12, 0.0, 1.0)
				var pts := PackedVector2Array([Vector2(size.x * 0.62, 0), Vector2(size.x * 0.48, size.y * 0.3), Vector2(size.x * 0.6, size.y * 0.52), Vector2(size.x * 0.44, size.y * 0.8), Vector2(size.x * 0.52, size.y)])
				var shown_pts := PackedVector2Array()
				for j in pts.size():
					if float(j) / float(pts.size() - 1) <= k:
						shown_pts.append(pts[j])
				if shown_pts.size() >= 2:
					b.draw_polyline(shown_pts, Color(Style.MORALE_LOW, 0.85), 2.0)
	elif int(e["level"]) > 1:
		for l in int(e["level"]) - 1:
			b.draw_circle(Vector2(10 + l * 12, size.y - 12.0), 4.0, Style.BRASS)
	if not battle and placed:
		# placed: a tick in the corner
		var t := Vector2(size.x - 22.0, size.y - 16.0)
		b.draw_polyline(PackedVector2Array([t, t + Vector2(5, 5), t + Vector2(14, -6)]), Style.BRASS, 3.0)
	b.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## In a siege, a pill on the card under the name: what the company is doing (on the storm
## plan, where it's going).
func _draw_role_badge(b: Button, sq) -> void:
	if sim.objective != Sim.OBJECTIVE_SIEGE:
		return
	var role := String(_storm_plan.get(sq.id, "")) if not _storm_plan.is_empty() else sim.siege_role(sq)
	if not ROLE_BADGES.has(role):
		return
	var badge: Array = ROLE_BADGES[role]
	var fs := _fs(Style.SMALL)
	var word := _fit(String(badge[1]), fs, b.size.x - 30.0 - 40.0)
	var h := float(fs) + 8.0
	var r := Rect2(5, b.size.y - h - 14.0, minf(b.size.x - 30.0, 34.0 + font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 10.0), h)
	b.draw_style_box(_chip_box(badge[2], Color(badge[3], 0.35)), r)
	var tex := Widgets.icon(String(badge[0]))
	if tex != null:
		b.draw_texture_rect(tex, Rect2(r.position + Vector2(6, (h - 20.0) * 0.5), Vector2(20, 20)), false, badge[3])
	b.draw_string(font, r.position + Vector2(30, h * 0.5 + fs * 0.36), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, badge[3])


## `text` cut with an ellipsis to fit `width` at `size`, for words drawn on the field and the
## cards, which can't shrink below SMALL.
func _fit(text: String, size: int, width: float) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
		return text
	var t := text
	while t.length() > 1 and font.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		t = t.substr(0, t.length() - 1)
	return t + "…"


## A fill over the ability button that drains as its cooldown runs down.
func _draw_ability_cooldown() -> void:
	var sq = selected_squad
	if sq == null:
		return
	var total: float = sim.ability_cooldown(sq)
	if sq.ability_left > 0.0:
		var run := float(Troops.ability(sq.type)["seconds"])
		var f: float = sq.ability_left / maxf(0.01, run)
		ability_button.draw_rect(Rect2(0, ability_button.size.y - 8.0, ability_button.size.x * f, 8.0), Style.BRASS)
	elif sq.ability_cd > 0.0:
		var f: float = sq.ability_cd / maxf(0.01, total)
		ability_button.draw_rect(Rect2(0, 0, ability_button.size.x * f, ability_button.size.y), Color(0, 0, 0, 0.35))


# ---------------------------------------------------------------- the death roll

func _draw_roll() -> void:
	if _roll.is_empty():
		return
	var ci := roll_layer
	var still := Style.motion_reduced()
	var t: float = _roll["t"]
	var a := clampf(t / 0.25, 0.0, 1.0) * clampf((ROLL_TIME - t) / 0.35, 0.0, 1.0)
	ci.draw_rect(Rect2(_view.position, _view.size), Color(0, 0, 0, 0.5 * a))
	var w := minf(600.0, _view.size.x - 24.0)
	# The plate drops in from above.
	var drop := 0.0 if still else -70.0 * (1.0 - _ease_out(t / 0.25))
	var box := Rect2(Vector2(_view.get_center().x - w * 0.5, _view.position.y + _view.size.y * 0.14 + drop), Vector2(w, 440))
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(Style.PANEL, 0.97 * a)
	plate.border_color = Color(Style.BRASS, a)
	plate.set_border_width_all(3)
	plate.set_corner_radius_all(12)
	plate.shadow_color = Color(0, 0, 0, 0.5 * a)
	plate.shadow_size = 14
	ci.draw_style_box(plate, box)
	var x := box.position.x
	var y := box.position.y
	ci.draw_string(font, Vector2(x, y + 44), "CAPTAIN DOWN", HORIZONTAL_ALIGNMENT_CENTER, w, _fs(Style.SMALL), Color(Style.MUTED, a))
	ci.draw_string(font, Vector2(x, y + 86), String(_roll["name"]), HORIZONTAL_ALIGNMENT_CENTER, w, _fs(34), Color(Style.TEXT, a))
	ci.draw_string(font, Vector2(x, y + 118), String(_roll["company"]), HORIZONTAL_ALIGNMENT_CENTER, w, _fs(Style.SMALL), Color(Style.MUTED, a))
	var face: Texture2D = CaptainArt.texture(_roll.get("captain", {}), "pain", true)
	if face != null:
		# The face in a brass frame.
		var fr := Rect2(Vector2(x + 16, y + 16), Vector2(78, 104))
		ci.draw_rect(fr.grow(3.0), Color(Style.BRASS, a))
		ci.draw_rect(fr, Color(Style.NIGHT, a))
		ci.draw_texture_rect(face, fr, false, Color(1, 1, 1, a))

	# The die tumbles, slowing, then lands with a bounce.
	var needed: int = _roll["needed"]
	var chance := needed - 1
	var landed := t >= ROLL_LANDS
	var shown: int = _roll["roll"]
	var tilt := 0.0
	var scale := 1.0
	if not landed:
		var tick := int(pow(t * 6.0, 1.6))
		shown = 1 + int(posmod(tick * 7919 + 13, 100))
		if not still:
			tilt = deg_to_rad(9.0) * sin(t * 26.0) * (1.0 - t / ROLL_LANDS)
	elif not still:
		var since := t - ROLL_LANDS
		if since < 0.22:
			scale = 1.0 + 0.16 * sin(since / 0.22 * PI)
	var die_c := Vector2(box.get_center().x, y + 188)
	var edge_col := Style.TEXT if not landed else (Style.ENEMY_LIGHT if _roll["fate"] == "killed" else Style.BRASS)
	ci.draw_set_transform(die_c + Vector2(5, 7), tilt, Vector2(scale, scale))
	var die_box := StyleBoxFlat.new()
	die_box.bg_color = Color(0, 0, 0, 0.4 * a)
	die_box.set_corner_radius_all(14)
	ci.draw_style_box(die_box, Rect2(Vector2(-64, -48), Vector2(128, 96)))
	ci.draw_set_transform(die_c, tilt, Vector2(scale, scale))
	die_box = StyleBoxFlat.new()
	die_box.bg_color = Color(Style.RAISED, a)
	die_box.border_color = Color(edge_col, a)
	die_box.set_border_width_all(3)
	die_box.set_corner_radius_all(14)
	ci.draw_style_box(die_box, Rect2(Vector2(-64, -48), Vector2(128, 96)))
	ci.draw_string(font, Vector2(-64, 24), str(shown), HORIZONTAL_ALIGNMENT_CENTER, 128, 60, Color(Style.TEXT, a))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# The odds: dies at or under the chance. The red fills first, so the eye reads the
	# chance before the number lands.
	var bar := Rect2(Vector2(x + 30, y + 258), Vector2(w - 60, 18))
	var fill := 1.0 if still else _ease_out((t - 0.15) / 0.3)
	ci.draw_rect(bar, Color(Style.RAISED, a))
	ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * chance / 100.0 * fill, bar.size.y)), Color(Style.ENEMY, 0.85 * a))
	if landed:
		var mx: float = bar.position.x + bar.size.x * float(_roll["roll"]) / 100.0
		ci.draw_rect(Rect2(mx - 2.0, bar.position.y - 6.0, 4.0, bar.size.y + 12.0), Color(Style.TEXT, a))
	ci.draw_string(font, Vector2(x, y + 312), "Needs %d or more to live" % needed, HORIZONTAL_ALIGNMENT_CENTER, w, _fs(Style.SMALL), Color(Style.TEXT, a))
	var mods := PackedStringArray(["base %d%%" % Captains.DEATH_CHANCE])
	if _roll["holding"]:
		mods.append("squad holding -%d" % Captains.RESCUED_BY_SQUAD)
	if _roll["friends"]:
		mods.append("friends near -%d" % Captains.RESCUED_BY_FRIENDS)
	if _roll["lucky"]:
		mods.append("lucky -%d" % Captains.LUCK)
	ci.draw_string(font, Vector2(x, y + 342), " · ".join(mods), HORIZONTAL_ALIGNMENT_CENTER, w, _fs(Style.SMALL), Color(Style.MUTED, a))

	if landed:
		var killed: bool = _roll["fate"] == "killed"
		var since := t - ROLL_LANDS
		var verdict := "FALLEN" if killed else "WOUNDED · OUT FOR %d BATTLES" % Captains.WOUND_BATTLES
		var vc := Vector2(x + w * 0.5, y + 380)
		var va := a * clampf(since / 0.1, 0.0, 1.0)
		if killed:
			# Death stamps down; a wound slides in.
			var st := 1.0 if still else lerpf(1.5, 1.0, _ease_out(since / 0.14))
			ci.draw_set_transform(vc, 0.0, Vector2(st, st))
			ci.draw_string(font, Vector2(-w * 0.5, 8.0), verdict, HORIZONTAL_ALIGNMENT_CENTER, w, _fs(Style.LARGE), Color(Style.ENEMY_LIGHT, va))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			var slide := 0.0 if still else -24.0 * (1.0 - _ease_out(since / 0.2))
			ci.draw_string(font, Vector2(x + slide, y + 388), verdict, HORIZONTAL_ALIGNMENT_CENTER, w, _fs(Style.LARGE), Color(Style.BRASS, va))
		ci.draw_string(font, Vector2(x + 16, y + 424), "\"%s\"" % _roll["words"], HORIZONTAL_ALIGNMENT_CENTER, w - 32.0, _fs(Style.SMALL), Color(Style.TEXT, va))


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var t := Time.get_ticks_usec()
	_c = self
	_place_field_layers()
	_draw_battle()
	_perf_draw_us += Time.get_ticks_usec() - t


## Set up the test battle: twelve full companies of your people against twelve of another's,
## with no captains, on open ground. Only a fight with nothing pending can be replaced.
static func test_battle(culture: String) -> bool:
	if not GameState.pending_battle.is_empty():
		return false
	var foe := Cultures.KHARZANI if culture != Cultures.KHARZANI else Cultures.RYUMON
	var mine := []
	var theirs := []
	for i in 12:
		var t: String = Troops.ORDER[i % 4]
		var u := Units.recruit(culture, t)
		mine.append({"id": 9000 + i, "type": t, "unit": u, "men": Units.full_size(u), "culture": culture, "xp": 0, "level": 1})
		var t2: String = Troops.ORDER[(i + 1) % 4]
		var u2 := Units.recruit(foe, t2)
		theirs.append({"id": 9100 + i, "type": t2, "unit": u2, "men": Units.full_size(u2), "culture": foe})
	GameState.pending_battle = {"test": true, "army": mine, "enemy": theirs, "culture": foe,
		"site": BattleSite.pick(null, Vector2.ZERO, Sim.OBJECTIVE_ROUT, 7)}
	return true


func _redraw() -> void:
	queue_redraw()
	if _troop_layer != null:
		_troop_layer.queue_redraw()
		_top_layer.queue_redraw()


## A disc of radius `r` at `at` on the canvas being drawn, `squash` times as tall as it is
## wide: the field's discs by the hundred (blood on the ground, dropped shields, dust, the
## glow along the front, arrowheads). It is one white disc texture drawn as a rect, and
## rects with the same texture go to the GPU together, where every draw_circle is a
## polygon of its own, built and drawn alone, each frame: thousands late in a big fight.
func _dot(at: Vector2, r: float, col: Color, squash: float = 1.0) -> void:
	if _disc_tex == null:
		_disc_tex = disc_texture()
	_c.draw_texture_rect(_disc_tex, Rect2(at.x - r, at.y - r * squash, r * 2.0, r * 2.0 * squash), false, col)


## The white disc _dot draws, edge softened over one texel.
static func disc_texture() -> Texture2D:
	if _disc_cache == null:
		var n := 64
		var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
		var mid := n * 0.5
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5 - mid, y + 0.5 - mid).length()
				img.set_pixel(x, y, Color(1, 1, 1, clampf(mid - d, 0.0, 1.0)))
		_disc_cache = ImageTexture.create_from_image(img)
	return _disc_cache


func _make_layers() -> void:
	_troop_layer = Node2D.new()
	_troop_layer.name = "TroopLayer"
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = TROOP_SHADER
	mat.shader = sh
	_troop_layer.material = mat
	_troop_layer.draw.connect(_draw_troop_layer)
	add_child(_troop_layer)
	move_child(_troop_layer, 0)
	_top_layer = Node2D.new()
	_top_layer.name = "TopLayer"
	var flag_mat := ShaderMaterial.new()
	var flag_sh := Shader.new()
	flag_sh.code = FLAG_SHADER
	flag_mat.shader = flag_sh
	flag_mat.set_shader_parameter("drop", FLAG.y * 0.13)
	_top_layer.material = flag_mat
	_top_layer.draw.connect(_draw_top_layer)
	add_child(_top_layer)
	move_child(_top_layer, 1)
	_men_mm = _batch()
	_shadow_mm = _batch()
	# The field under everything, in child items drawn behind this one. They are placed by
	# the camera's transform and redrawn only when what they show changes.
	_field_layers.clear()
	for spec in [["FieldBase", _draw_field_base], ["FieldWater", _draw_field_water],
			["FieldProps", _draw_field_props], ["FieldLitter", _draw_field_litter]]:
		var layer := Node2D.new()
		layer.name = spec[0]
		layer.show_behind_parent = true
		var fn: Callable = spec[1]
		layer.draw.connect(_draw_field_layer.bind(layer, fn))
		add_child(layer)
		move_child(layer, _field_layers.size())
		_field_layers.append(layer)


## A MultiMesh of unit quads, each placed by a 2D transform, tinted, and told which atlas
## cell to show.
static func _batch(custom: bool = true) -> MultiMesh:
	var quad := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = custom
	mm.mesh = quad
	return mm


## Hand a batch its buffer and draw the first `n` instances.
func _flush(mm: MultiMesh, buf: PackedFloat32Array, n: int, tex: Texture2D, stride: int = BATCH_FLOATS) -> void:
	if n <= 0:
		return
	var cap := buf.size() / stride
	if mm.instance_count != cap:
		mm.instance_count = cap
	mm.buffer = buf
	mm.visible_instance_count = n
	_c.draw_multimesh(mm, tex)


func _draw_troop_layer() -> void:
	if sim == null:
		return
	var t := Time.get_ticks_usec()
	_c = _troop_layer
	_draw_troops()
	_c = self
	_perf_draw_us += Time.get_ticks_usec() - t


func _draw_top_layer() -> void:
	var t := Time.get_ticks_usec()
	_c = _top_layer
	(_top_layer.material as ShaderMaterial).set_shader_parameter("clock", _clock)
	if sim != null:
		_draw_above()
	if Sound.show_performance or _test:
		_draw_perf()
	_c = self
	_perf_draw_us += Time.get_ticks_usec() - t


## One of the field layers: drawn in field units, with the layer itself carrying the
## camera's transform (see _place_field_layers), so it is redrawn only when its content
## changes, not when the camera moves.
func _draw_field_layer(layer: Node2D, fn: Callable) -> void:
	if sim == null:
		return
	var t := Time.get_ticks_usec()
	var origin := field_origin
	var scale_was := field_scale
	field_origin = Vector2.ZERO
	field_scale = 1.0
	_c = layer
	fn.call()
	_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_c = self
	field_origin = origin
	field_scale = scale_was
	_perf_draw_us += Time.get_ticks_usec() - t


## What lies on the ground under the men: the hour's wash, the scars, gear and litter
## where men fell, and the arrows stuck in the ground.
func _draw_field_litter() -> void:
	_draw_hour_ground()
	_draw_scars(sim.corpses)
	_draw_gear(sim.corpses)
	_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_litter(_litter)
	_draw_stuck_arrows(sim.stuck_arrows)


## Put the field layers where the camera has the field this frame; redraw the water while
## it glints and the litter when something new lies on the ground.
func _place_field_layers() -> void:
	if _field_layers.is_empty() or sim == null:
		return
	for layer in _field_layers:
		layer.position = field_origin
		layer.scale = Vector2(field_scale, field_scale)
	if _terrain_site_type == "river":
		_field_layers[1].queue_redraw()
	var sig := [sim.corpses.size(), _litter.size(), sim.stuck_arrows.size(), _band]
	if not sim.corpses.is_empty():
		sig.append(sim.corpses.back()["pos"])
	if not sim.stuck_arrows.is_empty():
		sig.append(sim.stuck_arrows.back()["pos"])
	if sig != _litter_sig and (_clock - _litter_at >= LITTER_EVERY or _clock < _litter_at):
		_litter_sig = sig
		_litter_at = _clock
		_snap_corpse = null if sim.corpses.is_empty() else sim.corpses.back()
		_snap_arrow = null if sim.stuck_arrows.is_empty() else sim.stuck_arrows.back()
		_snap_litter = _litter.size()
		_field_layers[3].queue_redraw()


## The items of `items` after `last` (by identity): everything if `last` is null or has
## gone from the list.
static func _since(items: Array, last) -> Array:
	if last == null:
		return items
	var i := items.size() - 1
	while i >= 0 and not is_same(items[i], last):
		i -= 1
	return items.slice(i + 1)


# ---------------------------------------------------------------- the performance readout

func _perf_reset() -> void:
	_perf_win = {"t": 0.0, "frames": 0, "frame": 0.0, "frame_worst": 0.0, "sim": 0.0, "sim_worst": 0.0, "draw": 0.0, "draw_worst": 0.0,
		"render": 0.0, "gpu": 0.0}


## One frame's costs into the window: the frame's length, and the sim and drawing it did
## (the drawing is the last frame's, done after its _process).
func _perf_frame(delta: float) -> void:
	var sim_ms := _perf_sim_us / 1000.0
	var draw_ms := _perf_draw_us / 1000.0
	_perf_sim_us = 0
	_perf_draw_us = 0
	var rid := get_viewport().get_viewport_rid()
	var w := _perf_win
	w["t"] = float(w["t"]) + delta
	w["frames"] = int(w["frames"]) + 1
	w["frame"] = float(w["frame"]) + delta * 1000.0
	w["frame_worst"] = maxf(float(w["frame_worst"]), delta * 1000.0)
	w["sim"] = float(w["sim"]) + sim_ms
	w["sim_worst"] = maxf(float(w["sim_worst"]), sim_ms)
	w["draw"] = float(w["draw"]) + draw_ms
	w["draw_worst"] = maxf(float(w["draw_worst"]), draw_ms)
	w["render"] = float(w["render"]) + RenderingServer.viewport_get_measured_render_time_cpu(rid)
	w["gpu"] = float(w["gpu"]) + RenderingServer.viewport_get_measured_render_time_gpu(rid)
	if float(w["t"]) < PERF_WINDOW:
		return
	var n := float(maxi(1, int(w["frames"])))
	var men := 0
	var squads := 0
	if sim != null:
		for sq in sim.squads:
			if sq.alive_n > 0:
				squads += 1
				men += sq.alive_n
	perf = {"fps": n / float(w["t"]), "frame": float(w["frame"]) / n, "frame_worst": w["frame_worst"],
		"sim": float(w["sim"]) / n, "sim_worst": w["sim_worst"], "draw": float(w["draw"]) / n, "draw_worst": w["draw_worst"],
		"render": float(w["render"]) / n, "gpu": float(w["gpu"]) / n, "men": men, "squads": squads, "frames": int(perf["frames"]) + int(w["frames"])}
	_perf_reset()


## Two lines in a dark box at the bottom left of the field, clear of the callouts: where a
## frame's time goes, and the worst of the last second.
func _draw_perf() -> void:
	_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var size := Style.text_size(Style.SMALL)
	var lines := [
		"sim %.1f · draw %.1f · render %.1f · gpu %.1f ms" % [perf["sim"], perf["draw"], perf["render"], perf["gpu"]],
		"%.0f fps · frame %.1f ms, worst %.0f · %d men, %d companies" % [perf["fps"], perf["frame"], perf["frame_worst"], perf["men"], perf["squads"]],
	]
	var w := 0.0
	for l in lines:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	var top := _view.end.y - (size * 2.6 + 12.0) - 8.0
	_c.draw_rect(Rect2(8.0, top, w + 20.0, size * 2.6 + 12.0), Color(0, 0, 0, 0.72))
	for i in lines.size():
		var tone := Style.TEXT
		if i == 1 and float(perf["frame_worst"]) > 34.0:
			tone = Style.MORALE_LOW if float(perf["frame"]) > 20.0 else Style.MORALE_MID
		_c.draw_string(font, Vector2(18.0, top + 6.0 + size * (1.05 + i * 1.3)), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, tone)


func _draw_battle() -> void:
	if sim == null:
		return
	# The ground, its features and props, and what has fallen on it are the field layers'.
	_c.draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
	_draw_night_lights()
	_draw_zones()
	_draw_objectives()
	var going_down := {}
	for e in _falling:
		going_down[e["corpse"]] = true
	# What has fallen since the litter layer was last redrawn, drawn here until it is.
	var new_bodies := _since(sim.corpses, _snap_corpse)
	_draw_scars(new_bodies)
	_draw_gear(new_bodies)
	_draw_corpses(going_down)
	_c.draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
	_draw_litter(_litter.slice(_snap_litter))
	_draw_stuck_arrows(_since(sim.stuck_arrows, _snap_arrow))
	_draw_puffs()
	_draw_volley_shadows()
	_draw_front()
	_draw_orders()
	_draw_targets()
	_draw_line_order()
	_draw_bonds()
	_draw_bursts()
	_draw_falling()


## The troop layer: every shadow in one draw, the captains' rings and the charging streaks,
## then every man in one draw: the squads out of the fight in turn, then the men of the
## melee back to front across squads.
func _draw_troops() -> void:
	_still_men = Style.motion_reduced()
	_men_n = 0
	_shadow_n = 0
	_rings.clear()
	_streaks.clear()
	_glances.clear()
	_shadow_cell = Art.atlas_disk()
	_shadow_col = Color(0.05, 0.08, 0.02, _shadow_a)
	_shadow_cols[Sim.PLAYER] = Color(0.04, 0.09, 0.34, _shadow_a * 1.25)
	_shadow_cols[Sim.ENEMY] = Color(0.34, 0.05, 0.04, _shadow_a * 1.25)
	var melee := []
	for sq in sim.squads:
		if sq.engaged and sq.is_active():
			melee.append(sq)
		else:
			_draw_men(sq)
	_draw_melee(melee)
	var atlas := Art.atlas()
	_c.draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
	_flush(_shadow_mm, _shadow_buf, _shadow_n, atlas)
	for s in _streaks:
		var pos: Vector2 = s[0]
		var fwd: Vector2 = s[1]
		var back := -fwd
		for k in 3:
			var off: Vector2 = fwd.orthogonal() * (k - 1) * 3.5
			_c.draw_line(pos + back * 11.0 + off, pos + back * (24.0 + k * 4.0) + off, Color(1, 1, 1, 0.35), 1.0)
	for r in _rings:
		var px := field_scale * Art.pixel_size(String(r[2]))
		_c.draw_set_transform(field_origin + Vector2(r[0]) * field_scale, 0.0, Vector2(px, px))
		_c.draw_arc(Vector2.ZERO, 7.5, 0.0, TAU, 20, Color(0, 0, 0, 0.6), 2.6)
		_c.draw_arc(Vector2.ZERO, 7.5, 0.0, TAU, 20, Style.BRASS if int(r[1]) == Sim.PLAYER else Style.ENEMY_LIGHT, 1.4)
	_c.draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
	_flush(_men_mm, _men_buf, _men_n, atlas)


## The top layer: what stands over the men.
func _draw_above() -> void:
	for at in _glances:
		# A "!" over a wavering man's head while he looks back.
		_c.draw_set_transform(field_origin + (Vector2(at) + Vector2(0, -13)) * field_scale, 0.0, Vector2(field_scale, field_scale))
		_c.draw_rect(Rect2(-2.0, -5.0, 4.0, 7.0), Color(1, 1, 1, 0.95))
		_c.draw_rect(Rect2(-0.8, -4.2, 1.6, 3.6), Style.ENEMY)
		_c.draw_rect(Rect2(-0.8, 0.0, 1.6, 1.2), Style.ENEMY)
	_c.draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
	_draw_treetops()
	_draw_arrows()
	_c.draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
	_draw_sparks()
	_draw_settled()
	if sim.objective == Sim.OBJECTIVE_SIEGE:
		_draw_engines()
		_draw_engine_shots()
		_draw_storm_plan()
		_draw_gate_marker()
	_draw_hour_air()
	_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_vignette_edge()
	_draw_fallen_flags()
	_draw_standards()
	_draw_edge_markers()
	_draw_slow()
	_draw_floaters()
	_draw_carry_card()
	_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_spotlight()
	_draw_ticker()
	_draw_banner()


## Pixel-art ground for the land the battle is in, its marks, slopes and baked features.
func _draw_field_base() -> void:
	var px := Art.GRASS_PIXEL
	_c.draw_set_transform(field_origin, 0.0, Vector2(field_scale * px, field_scale * px))
	# The ground runs on past the field, so the screen never shows a dark band around it.
	_c.draw_texture_rect(Art.ground(_biome), Rect2(-BEYOND / px, (Sim.ARENA + BEYOND * 2.0) / px), true)
	_c.draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
	_draw_ground_marks()

	# The slopes, lit and shaded, and the features over them, baked as one texture.
	if _plate_tex != null:
		_c.draw_texture_rect(_plate_tex, Rect2(Vector2.ZERO, Sim.ARENA), false)


## The river's glints, the one part of the ground that moves.
func _draw_field_water() -> void:
	if _terrain_site_type == "river":
		FieldArt.draw_water(_c, sim.terrain, _clock, 0.5 if _band == "night" else 1.0)


## What grows and stands on the field and past it, and the field's edge.
func _draw_field_props() -> void:
	for d in _doodads:
		var s: float = field_scale * Art.PROP_PIXEL * float(d["scale"])
		_c.draw_set_transform(field_origin + Vector2(d["pos"]) * field_scale, 0.0, Vector2(s * float(d["flip"]), s))
		_c.draw_texture(Art.frame(d["name"], 0, 0, _biome), -Art.pivot(d["name"], _biome))
	for d in _beyond:
		var name := String(d["name"])
		if MapArt.has(name):
			# Trees are the map's own, as in the field's woods.
			_c.draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
			var p: Vector2 = d["pos"]
			var sc: float = float(d["scale"]) * 1.6
			var sz := MapArt.size(name)
			var flip: float = float(d["flip"])
			_c.draw_texture_rect(MapArt.texture(name), Rect2(p.x - sz.x * sc * 0.5 * flip, p.y - sz.y * sc, sz.x * sc * flip, sz.y * sc), false)
		else:
			var s: float = field_scale * Art.PROP_PIXEL * float(d["scale"])
			_c.draw_set_transform(field_origin + Vector2(d["pos"]) * field_scale, 0.0, Vector2(s * float(d["flip"]), s))
			_c.draw_texture(Art.frame(name, 0, 0, _biome), -Art.pivot(name, _biome))
	_c.draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
	# Past the edge the land is a touch darker, so the field's bounds still read.
	var dim := Color(0, 0, 0, 0.16)
	_c.draw_rect(Rect2(-BEYOND, Vector2(Sim.ARENA.x + BEYOND.x * 2.0, BEYOND.y)), dim)
	_c.draw_rect(Rect2(Vector2(-BEYOND.x, Sim.ARENA.y), Vector2(Sim.ARENA.x + BEYOND.x * 2.0, BEYOND.y)), dim)
	_c.draw_rect(Rect2(Vector2(-BEYOND.x, 0), Vector2(BEYOND.x, Sim.ARENA.y)), dim)
	_c.draw_rect(Rect2(Vector2(Sim.ARENA.x, 0), Vector2(BEYOND.x, Sim.ARENA.y)), dim)
	_c.draw_rect(Rect2(Vector2.ZERO, Sim.ARENA), Color(0, 0, 0, 0.3), false, 3.0)


## The hour on the ground: its wash, and mist along the far edge at dawn.
func _draw_hour_ground() -> void:
	var all := Rect2(-BEYOND, Sim.ARENA + BEYOND * 2.0)
	if _ground_tint.a > 0.0:
		_c.draw_rect(all, _ground_tint)
	if _band == "dawn":
		for i in 8:
			_c.draw_rect(Rect2(Vector2(-BEYOND.x, -BEYOND.y + i * 40.0), Vector2(Sim.ARENA.x + BEYOND.x * 2.0, BEYOND.y + 40.0)), Color(1.0, 0.95, 0.88, 0.035))


## At night, a warm pool of light round every standard still up (and the gate, in a siege).
func _draw_night_lights() -> void:
	if _band == "night":
		var lights := []
		for sq in sim.squads:
			if sq.is_active() and not sq.routing:
				lights.append(sq.avg)
		if sim.objective == Sim.OBJECTIVE_SIEGE:
			lights.append(sim.gate_center)
		for at in lights:
			for k in 6:
				_dot(at, 110.0 - k * 16.0, Color(1.0, 0.72, 0.4, 0.035))


## The hour over the men: a lighter wash, so they keep their colours.
func _draw_hour_air() -> void:
	if _air_tint.a > 0.0:
		_c.draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
		_c.draw_rect(Rect2(-BEYOND, Sim.ARENA + BEYOND * 2.0), _air_tint)


## Dusk and night close in at the edges of the view.
func _draw_vignette_edge() -> void:
	if _vignette <= 0.0:
		return
	var steps := 9
	for i in steps:
		var inset := float(i) * 14.0
		var r := _view.grow(-inset)
		var a := _vignette * 0.09 * (1.0 - float(i) / float(steps))
		_c.draw_rect(r, Color(0.02, 0.03, 0.08, a), false, 14.0)


## How far the drawn land reaches past the field, in field units.
const BEYOND := Vector2(420.0, 520.0)


## Each land's marks on the open ground, under everything else: Vardmark's cart track and
## crop strips, Kharzan's wind ripples and dry wadi, Ryumon's stone path; and Ryumon's
## paddies past the edge.
func _draw_ground_marks() -> void:
	var look: Dictionary = Art.GROUND.get(_biome, Art.GROUND["vardish"])
	var base: Color = look["base"]
	for paddy in _paddies:
		var r: Rect2 = paddy
		_c.draw_rect(r, Color("8fb8c0"))
		_c.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 6.0), Vector2(r.size.x, 6.0)), Color("6a5a3e"))
		var y := r.position.y + 8.0
		while y < r.end.y - 8.0:
			var x := r.position.x + 6.0
			while x < r.end.x - 4.0:
				_c.draw_rect(Rect2(x, y, 4, 4), Color("5c8a3c"))
				x += 14.0
			y += 12.0
	if _strips.size.x > 0.0:
		var x := _strips.position.x
		var k := 0
		while x < _strips.end.x:
			_c.draw_rect(Rect2(x, _strips.position.y, minf(18.0, _strips.end.x - x), _strips.size.y),
				Color("b9a254") if k % 2 == 0 else Color(base.lightened(0.12)))
			x += 18.0
			k += 1
		# A low hedge along its edge.
		var hx := _strips.position.x
		while hx < _strips.end.x:
			_c.draw_circle(Vector2(hx, _strips.position.y - 6.0), 7.0, Color("3e5a2e"))
			hx += 11.0
	for ripple in _ripples:
		_c.draw_polyline(ripple, Color(look["tuft"], 0.7), 3.0)
		_c.draw_polyline(PackedVector2Array(Array(ripple).map(func(q): return q + Vector2(0, -3))), Color(look["light"], 0.8), 2.0)
	if _track.size() > 1:
		var dirt := Color("8c7452") if _biome != Cultures.RYUMON else Color("9a978e")
		var edge := Color("6f5c40") if _biome != Cultures.RYUMON else Color("77746c")
		var width := 26.0 if _biome == Cultures.KHARZANI else 20.0
		_c.draw_polyline(_track, edge, width + 6.0)
		_c.draw_polyline(_track, dirt, width)
		if _biome == Cultures.RYUMON:
			for i in range(0, _track.size(), 2):
				_c.draw_rect(Rect2(_track[i] - Vector2(6, 4), Vector2(12, 8)), edge)


## Draw treetops over troops, a little see-through so men in the woods still show.
func _draw_treetops() -> void:
	if _trees.is_empty():
		return
	for tree in _trees:
		var tex: Texture2D = MapArt.texture(tree["name"])
		if tex == null:
			continue
		var p: Vector2 = tree["pos"]
		var s: float = float(tree["scale"]) * 1.6
		var flip: float = float(tree["flip"])
		var sz := MapArt.size(tree["name"])
		var dest := Rect2(p.x - sz.x * s * 0.5 * flip, p.y - sz.y * s, sz.x * s * flip, sz.y * s)
		_c.draw_texture_rect(tex, dest, false, Color(1, 1, 1, TREETOP_ALPHA))


func _setup_terrain_visuals() -> void:
	if sim == null or sim.terrain == null:
		return
	var t: Terrain = sim.terrain
	_trees.clear()
	_terrain_site_type = "open"

	var shade := FieldArt.hillshade_image(t, _biome)

	# Populate woods trees
	var tree_name := "tree"
	match _biome:
		Cultures.VARDISH:
			tree_name = "tree"
		Cultures.KHARZANI:
			tree_name = "palm"
		Cultures.RYUMON:
			tree_name = "blossom"
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	for cy in Terrain.ROWS:
		for cx in Terrain.COLS:
			var idx := cy * Terrain.COLS + cx
			if t.woods[idx] == Terrain.WOODS_TREES:
				_terrain_site_type = "woods"
				var cp := t.cell_pos(cx, cy)
				for k in 3:
					var p := cp + Vector2(rng.randf_range(-13.0, 13.0), rng.randf_range(-13.0, 13.0))
					var kind := tree_name
					if _biome == Cultures.VARDISH and t.height_at(p) > 0.4:
						kind = "pine"
					_trees.append({
						"pos": p,
						"name": kind,
						"scale": rng.randf_range(1.1, 1.4),
						"flip": 1.0 if rng.randf() < 0.5 else -1.0,
					})
	_trees.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)
	_plate_tex = FieldArt.overlay(shade, FieldArt.plate_image(t, _biome, _trees, 999))

	for feat in t.features:
		var ft: String = feat.get("type", "")
		if ft == "river":
			_terrain_site_type = "river"
		elif ft == "hill" or ft == "ridge":
			if _terrain_site_type == "open":
				_terrain_site_type = "hills"
		elif ft == "rock":
			_terrain_site_type = "pass"
		elif ft == "building":
			_terrain_site_type = "village"


func _maybe_show_terrain_hint() -> void:
	var cfg := ConfigFile.new()
	cfg.load(Sound.SETTINGS_PATH)

	# 1. Objective hint cards
	var obj_key := sim.objective if sim != null else "rout"
	if obj_key != "rout" and not bool(cfg.get_value("objective_hints", obj_key, false)):
		var obj_texts := {
			"chief": ["Slay the Chief", "The enemy host is led by a named chieftain at the head of an elite bodyguard squad. Break or fell the bodyguard and the rest of the host suffers a catastrophic -35 morale shock. Slay the chief for double bounty and renown; do not let him flee the field!"],
			"ambush": ["Ambushed in the Woods!", "You have been caught marching down a road in dense woods. Your warband starts unbraced in a vulnerable narrow column, while enemy pincers strike simultaneously from both ends. You cannot withdraw; fight to the last man!"],
			"village": ["Village Defense", "Bandits are raiding the village! Hold the central village square for 2 minutes against arriving waves of reinforcements. Win by routing the attackers or holding the square when time expires."],
		}
		var o_card: Array = obj_texts.get(obj_key, [])
		if not o_card.is_empty():
			terrain_hint_title.text = o_card[0]
			terrain_hint_body.text = o_card[1]
			terrain_hint_body.visible = true
			_terrain_rows([])
			terrain_hint_panel.visible = true
			cfg.set_value("objective_hints", obj_key, true)
			cfg.save(Sound.SETTINGS_PATH)
			return

	# 2. Terrain hint cards
	if _terrain_site_type == "" or _terrain_site_type == "open":
		return
	if bool(cfg.get_value("terrain_hints", _terrain_site_type, false)):
		return
	# Each ground's rules as an icon and its modifier, one to a row.
	var texts := {
		"hills": ["Hills & Ridges", [["bow", "+25%", "archer range from high ground"], ["fight", "+25%", "damage fighting downhill"],
			["wheel", "No", "charge shock uphill"]]],
		"woods": ["Woods & Forests", [["speed", "−25%", "foot speed (horse −50%)"], ["holdfire", "½", "of arrows stopped by the trees"],
			["volley", "½", "volley shock"], ["wheel", "No", "charges"]]],
		"river": ["River Fords", [["cancel", "Deep", "water: cross at the fords"], ["damage", "+25%", "damage taken in a ford"],
			["shieldwall", "No", "bracing in water"]]],
		"pass": ["Rocky Pass", [["cancel", "Rock", "narrows the field to a bottleneck"], ["bow", "Over", "arrows fly over the rocks"]]],
		"village": ["Village Streets", [["keep", "Streets", "buildings and walls split the field"], ["company", "Tight", "chokepoints"]]],
	}
	var card_data: Array = texts.get(_terrain_site_type, [])
	if card_data.is_empty():
		return
	terrain_hint_title.text = card_data[0]
	terrain_hint_body.text = ""
	terrain_hint_body.visible = false
	_terrain_rows(card_data[1])
	terrain_hint_panel.visible = true

	cfg.set_value("terrain_hints", _terrain_site_type, true)
	cfg.save(Sound.SETTINGS_PATH)


## The ground card's rows: an icon, the modifier in brass, what it applies to.
func _terrain_rows(rows: Array) -> void:
	for c in terrain_hint_rows.get_children():
		terrain_hint_rows.remove_child(c)
		c.queue_free()
	terrain_hint_rows.visible = not rows.is_empty()
	for r in rows:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		h.add_child(Widgets.icon_rect(String(r[0]), 36.0))
		var amount := Style.label(String(r[1]), Style.LARGE, Style.BRASS)
		amount.custom_minimum_size.x = 96.0
		amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(amount)
		var what := Style.label(String(r[2]), Style.BODY, Style.TEXT)
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		what.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(what)
		terrain_hint_rows.add_child(h)


func _terrain_hint(p: Vector2) -> String:
	if sim == null or sim.terrain == null:
		return ""
	var t: Terrain = sim.terrain
	if t.rock_at(p) != Terrain.ROCK_NONE:
		return "Rock: impassable obstacle. Troops must go around; arrows fly over."
	if t.water_at(p) == Terrain.WATER_DEEP:
		return "Deep Water: impassable river. Troops must cross at shallow fords."
	if t.water_at(p) == Terrain.WATER_SHALLOW:
		return "Shallow Ford: 50% movement speed, +25% damage taken, no charges or bracing."
	if t.in_woods(p):
		return "Woods: slows horse by 50% (foot 25%), 50% arrow block, no charges."
	if t.height_at(p) > 0.35:
		var pct := int(t.height_at(p) * 100.0)
		return "High Ground (%d%% elevation): +25%% archer range, uphill melee damage advantage." % pct
	return ""


## A few rocks and bushes, more scrub and stone in the desert, more green on the isles,
## over broad patches of lighter and darker ground.
## Only for looks: men walk over them.
func _scatter_doodads() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var kinds: Array = {"kharzani": ["rock0", "rock1", "rock1", "bush", "bush"],
		"ryumon": ["bush", "bush", "bush", "rock0", "rock1"]}.get(_biome, ["bush", "bush", "rock0", "rock1"])
	for i in 18:
		var pos := Vector2(rng.randf_range(20.0, Sim.ARENA.x - 20.0), rng.randf_range(20.0, Sim.ARENA.y - 20.0))
		# Nothing grows in a castle's courtyard, or on its wall.
		if sim != null and sim.objective == Sim.OBJECTIVE_SIEGE and (sim.inside_walls(pos) or absf(pos.y - sim.wall_y) < 60.0):
			continue
		_doodads.append({"name": kinds[rng.randi_range(0, kinds.size() - 1)], "pos": pos,
			"scale": rng.randf_range(1.4, 2.2), "flip": 1.0 if rng.randf() < 0.5 else -1.0})
	if sim != null and (sim.objective != Sim.OBJECTIVE_SIEGE):
		_doodads.append_array(FieldArt.props(sim.terrain, rng))
	_scatter_scenery(rng)


## The land around and under the fight, for looks only (men walk over all of it): trees
## past the field's edge, a track and crop strips or ripples on the open ground, paddies
## beyond Ryumon's fields. A siege keeps its ground plain around the walls.
func _scatter_scenery(rng: RandomNumberGenerator) -> void:
	_beyond.clear()
	_ripples.clear()
	_paddies.clear()
	_track = PackedVector2Array()
	_strips = Rect2()
	var siege: bool = sim != null and sim.objective == Sim.OBJECTIVE_SIEGE
	var trees: Array = {"kharzani": ["palm", "bush", "rock1", "palm"], "ryumon": ["pine", "pine", "blossom", "bush"]}.get(_biome, ["tree", "tree", "pine", "bush"])
	var count := 26 if _biome == Cultures.KHARZANI else 70
	var placed := 0
	var tries := 0
	while placed < count and tries < 600:
		tries += 1
		var p := Vector2(rng.randf_range(-BEYOND.x + 20.0, Sim.ARENA.x + BEYOND.x - 20.0), rng.randf_range(-BEYOND.y + 20.0, Sim.ARENA.y + BEYOND.y - 20.0))
		if Rect2(Vector2(-30, -30), Sim.ARENA + Vector2(60, 60)).has_point(p):
			continue
		_beyond.append({"name": trees[rng.randi_range(0, trees.size() - 1)], "pos": p,
			"scale": rng.randf_range(1.2, 1.7), "flip": 1.0 if rng.randf() < 0.5 else -1.0})
		placed += 1
	_beyond.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)
	if _biome == Cultures.RYUMON:
		# Terraced paddies beyond one flank.
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		for k in 5:
			var w := 260.0 - k * 30.0
			var x := -w - 40.0 if side < 0.0 else Sim.ARENA.x + 40.0
			_paddies.append(Rect2(x, 120.0 + k * 210.0, w, 160.0))
	if siege:
		return
	# A track wandering down the field, off to one side of the middle.
	var tx := Sim.ARENA.x * (0.22 if rng.randf() < 0.5 else 0.78)
	var phase := rng.randf() * TAU
	for i in 28:
		var y := -BEYOND.y + (Sim.ARENA.y + BEYOND.y * 2.0) * i / 27.0
		_track.append(Vector2(tx + sin(y / 260.0 + phase) * 60.0 + y * 0.04, y))
	match _biome:
		Cultures.VARDISH:
			# Crop strips in a corner, away from the track.
			var right := tx < Sim.ARENA.x * 0.5
			_strips = Rect2(Vector2(Sim.ARENA.x * (0.62 if right else 0.0), Sim.ARENA.y * 0.82), Vector2(Sim.ARENA.x * 0.38, Sim.ARENA.y * 0.18))
		Cultures.KHARZANI:
			for i in 40:
				var c := Vector2(rng.randf_range(0.0, Sim.ARENA.x), rng.randf_range(0.0, Sim.ARENA.y))
				var line := PackedVector2Array()
				for k in 8:
					line.append(c + Vector2(k * 9.0, sin(k * 0.9) * 4.0))
				_ripples.append(line)


## The culture a squad's men are dressed in: the enemy's, or for one of yours, the
## culture it was raised in.
func _culture_of(sq) -> String:
	var key := "%d/%d" % [sq.team, sq.roster_id]
	if not _cultures.has(key):
		var c := _enemy_culture
		if sq.team == Sim.PLAYER:
			c = String(_squad_record(sq.roster_id).get("culture", GameState.culture))
		_cultures[key] = c
	return _cultures[key]


## Trampled, bloodied ground where men fell, so the field remembers the fight.
func _draw_scars(bodies: Array) -> void:
	for c in bodies:
		var p: Vector2 = c["pos"]
		_dot(p + Vector2(2, 3), 11.0, Color(0.27, 0.19, 0.09, 0.16))
		_dot(p, 5.0, Color(0.36, 0.08, 0.06, 0.18))


func _draw_zones() -> void:
	if sim.phase != Sim.PHASE_DEPLOY or sim.winner != -1:
		return
	_c.draw_dashed_line(Vector2(0.0, Sim.MID_Y), Vector2(Sim.ARENA.x, Sim.MID_Y), Color(1, 1, 1, 0.35), 3.0, 14.0)
	var zone := sim.deploy_zone(Sim.PLAYER)
	var picking := selected_id != -1
	_c.draw_rect(zone, Color(Style.PLAYER, 0.22 if picking else 0.12))
	_c.draw_rect(zone, Color(Style.PLAYER_LIGHT, 0.85 if picking else 0.4), false, 3.0)
	_c.draw_rect(sim.deploy_zone(Sim.ENEMY), Color(Style.ENEMY, 0.08))


func _draw_objectives() -> void:
	if sim == null:
		return
	if sim.objective == Sim.OBJECTIVE_SIEGE:
		_draw_walls()
		_draw_wall_damage()
		_draw_siege_reach()
		_draw_garrison_posts()
	if sim.objective == Sim.OBJECTIVE_VILLAGE:
		var pulse := 0.5 + 0.5 * sin(_clock * 3.0)
		_c.draw_circle(Sim.VILLAGE_ZONE_CENTER, Sim.VILLAGE_ZONE_RADIUS, Color(Style.PLAYER, 0.08 + pulse * 0.04))
		_c.draw_arc(Sim.VILLAGE_ZONE_CENTER, Sim.VILLAGE_ZONE_RADIUS, 0.0, TAU, 48, Color(Style.PLAYER_LIGHT, 0.75), 3.0)
		# How near the raiders are to firing it: they get there by holding the square.
		if sim.village_burn > 0.0:
			var burnt := sim.village_burn / Sim.VILLAGE_BURN
			_c.draw_arc(Sim.VILLAGE_ZONE_CENTER, Sim.VILLAGE_ZONE_RADIUS + 9.0, -PI * 0.5, -PI * 0.5 + TAU * burnt, 48,
				Color(1.0, 0.45, 0.12, 0.9), 7.0)
			var counts: Array = sim.men_in_village()
			if counts[Sim.ENEMY] > counts[Sim.PLAYER] * Sim.VILLAGE_TAKEN:
				_field_label("They're firing the village!", Sim.VILLAGE_ZONE_CENTER + Vector2(0.0, Sim.VILLAGE_ZONE_RADIUS + 40.0),
					Color(1.0, 0.55, 0.25), Color(Style.NIGHT, 0.85), Color(1.0, 0.45, 0.12))
	if sim.objective == Sim.OBJECTIVE_CHIEF:
		for sq in sim.squads:
			if (sq.is_bodyguard or sq.is_chief) and sq.is_active():
				var pulse := 0.5 + 0.5 * sin(_clock * 4.0)
				var r := minf(sq.extent, 65.0) + 14.0 + pulse * 4.0
				_c.draw_arc(sq.average_pos(), r, 0.0, TAU, 36, Color(Style.BRASS, 0.7 + pulse * 0.3), 3.5)
	for r in sim.scheduled_reinforcements:
		if not r.get("spawned", false) and sim.time >= float(r.get("at_time", 0.0)) - 10.0:
			var edge: String = String(r.get("edge", "north"))
			var pt := Vector2(Sim.ARENA.x * 0.5, 40.0)
			var dir := Vector2.DOWN
			match edge:
				"north":
					pt = Vector2(Sim.ARENA.x * 0.5, 40.0)
					dir = Vector2.DOWN
				"south":
					pt = Vector2(Sim.ARENA.x * 0.5, Sim.ARENA.y - 40.0)
					dir = Vector2.UP
				"east":
					pt = Vector2(Sim.ARENA.x - 40.0, Sim.MID_Y)
					dir = Vector2.LEFT
				"west":
					pt = Vector2(40.0, Sim.MID_Y)
					dir = Vector2.RIGHT
			var right := Vector2(-dir.y, dir.x)
			var tip := pt + dir * 20.0
			_c.draw_colored_polygon(PackedVector2Array([tip, pt + right * 14.0, pt - right * 14.0]), Color(Style.ENEMY_LIGHT, 0.85))


func _draw_stuck_arrows(arrows: Array) -> void:
	# Every shaft, then every fletching, so each goes as one batch.
	for a in arrows:
		var p: Vector2 = a["pos"]
		var d := Vector2.from_angle(float(a["angle"]))
		_c.draw_line(p - d * 5.0, p + d * 1.5, Color(0.29, 0.2, 0.12, 0.85), 1.4)
	for a in arrows:
		_dot(Vector2(a["pos"]) - Vector2.from_angle(float(a["angle"])) * 5.0, 1.3, Color(0.93, 0.9, 0.84, 0.85))


## Draw sprite `name` with its pivot at arena point `at`, turned by `angle` (0 = facing
## up), dressed as `culture` dresses it.
func _sprite(name: String, team: int, index: int, at: Vector2, angle: float, tint: Color = Color.WHITE, grow: float = 1.0,
		culture: String = Cultures.VARDISH, squash: float = 1.0) -> void:
	var s := field_scale * Art.pixel_size(name) * grow
	# Troops are slightly narrower than their old painted footprint. Their collision
	# stays unchanged; this exposes the gaps that already exist in the simulation.
	var width := 1.0
	if Troops.TYPES.has(name) or Units.has(name):
		var role := Units.role(name) if Units.has(name) else name
		width = 0.92 if role == Troops.CAVALRY else 0.86
	_c.draw_set_transform(field_origin + at * field_scale, angle, Vector2(s * width, s * squash))
	_c.draw_texture(Art.frame(name, team, index, culture), -Art.pivot(name, culture), tint)


func _draw_orders() -> void:
	var sel = selected_squad
	# While deploying, the picked squad's bow range.
	if sim.phase == Sim.PHASE_DEPLOY:
		var picked = sim.placed_squad(Sim.PLAYER, selected_id)
		if picked != null and picked.ranged:
			_c.draw_arc(picked.center, picked.reach, 0.0, TAU, 64, Color(Style.PLAYER_LIGHT, 0.35), 2.0)
		return
	# Every company keeps a quiet destination mark. A player can glance across the
	# field and see where all orders lead without selecting squads one by one.
	for squad in sim.squads:
		if squad.team != Sim.PLAYER or not squad.is_active():
			continue
		if squad.order == "move" or squad.order == "hold":
			var alpha := 0.5 if squad == selected_squad else 0.24
			_c.draw_arc(squad.order_point, 12.0, 0.0, TAU, 20, Color(Style.BRASS, alpha), 2.0)
			if _clock - float(_ordered_at.get(squad, -9.0)) < 1.0:
				var pulse := 15.0 + (_clock - float(_ordered_at.get(squad, _clock))) * 13.0
				_c.draw_arc(squad.order_point, pulse, 0.0, TAU, 24, Color(Style.BRASS, 0.55), 2.0)
	if sel == null or not sel.is_active():
		return
	var from: Vector2 = sel.average_pos()
	var ring: float = minf(sel.extent, 70.0) + 16.0
	_c.draw_circle(from, ring, Color(Style.BRASS, 0.12))
	_c.draw_arc(from, ring, 0.0, TAU, 48, Color(Style.BRASS, 0.9), 3.0)
	if sel.ranged:
		_c.draw_arc(from, sel.reach, 0.0, TAU, 64, Color(Style.PLAYER_LIGHT, 0.3), 2.0)
	if sel.wheeling:
		_c.draw_dashed_line(from, sel.wheel_point, Color(Style.BRASS, 0.7), 2.0, 10.0)
	elif sel.order == "move" or sel.order == "hold":
		var to: Vector2 = sel.order_point
		if from.distance_to(to) > 20.0:
			_c.draw_dashed_line(from, to, Style.BRASS, 3.0, 12.0)
		_c.draw_arc(to, 16.0, 0.0, TAU, 24, Style.BRASS, 3.0)
	elif sel.order == "attack" and sel.order_target != null and sel.order_target.is_active():
		_c.draw_dashed_line(from, sel.order_target.average_pos(), Style.ENEMY_LIGHT, 3.0, 12.0)
	elif sel.order == "advance" and sel.focus != null and sel.focus.is_active():
		_c.draw_dashed_line(from, sel.focus.average_pos(), Color(Style.ENEMY_LIGHT, 0.6), 2.0, 10.0)


## A subtle link shows when an established bond is actively supporting two nearby
## companies. It turns a hidden combat modifier into readable battlefield teamwork.
func _draw_bonds() -> void:
	for i in sim.squads.size():
		var a = sim.squads[i]
		if a.team != Sim.PLAYER or not a.is_active() or a.bond_power <= 0.0 or a.info.is_empty():
			continue
		for j in range(i + 1, sim.squads.size()):
			var b = sim.squads[j]
			if b.team != Sim.PLAYER or not b.is_active() or b.bond_power <= 0.0 or b.info.is_empty():
				continue
			if a.average_pos().distance_to(b.average_pos()) > Captains.BOND_RANGE:
				continue
			var points := float(a.info.get("bonds", {}).get(str(b.info.get("id", -1)), 0.0))
			if Captains.rank_for(points) <= 0:
				continue
			var pulse := 0.18 + sin(_clock * 3.0) * 0.05
			var ap: Vector2 = a.average_pos()
			var bp: Vector2 = b.average_pos()
			_c.draw_dashed_line(ap, bp, Color(Style.BRASS, pulse), 2.0, 11.0)
			_c.draw_circle(ap, 5.0, Color(Style.BRASS, pulse + 0.1))
			_c.draw_circle(bp, 5.0, Color(Style.BRASS, pulse + 0.1))


func _draw_bursts() -> void:
	for burst in bursts:
		var age := float(burst["age"])
		var life := float(burst["life"])
		var t := clampf(age / life, 0.0, 1.0)
		var color: Color = burst["color"]
		color.a = (1.0 - t) * 0.8
		var pos: Vector2 = burst["pos"]
		match String(burst["kind"]):
			"charge":
				for i in 6:
					var d := Vector2.from_angle(float(i) / 6.0 * TAU)
					_c.draw_line(pos + d * (6.0 + 18.0 * t), pos + d * (18.0 + 28.0 * t), color, 2.5)
			"rout":
				_c.draw_arc(pos, 20.0 + 42.0 * t, 0.0, TAU, 30, color, 3.0)
				_c.draw_arc(pos, 9.0 + 25.0 * t, 0.0, TAU, 24, Color(color, color.a * 0.55), 2.0)
			"land":
				_c.draw_arc(pos, 46.0 - 28.0 * t, 0.0, TAU, 32, Color(color, color.a * (1.0 - t)), 3.0)
			"dust":
				for i in 5:
					var d := Vector2.from_angle(float(i) / 5.0 * TAU + 0.6)
					_dot(pos + d * (8.0 + 16.0 * t), 6.0 + 5.0 * t, Color(color, color.a * 0.55))
			"stone":
				var from: Vector2 = burst.get("from", pos)
				if t < 0.7:
					var k := t / 0.7
					var at := from.lerp(pos, k * k)
					_dot(at + Vector2(2, 2), 4.0, Color(0, 0, 0, 0.35))
					_dot(at, 4.0, Color(burst["color"], 1.0))
					_dot(at + Vector2(-1, -1), 1.6, Color(1, 1, 1, 0.5))
				else:
					var k2 := (t - 0.7) / 0.3
					for i in 4:
						var d := Vector2.from_angle(float(i) / 4.0 * TAU + 0.4)
						_dot(pos + d * (4.0 + 10.0 * k2), 4.0 + 3.0 * k2, Color("d8cdb4", 0.6 * (1.0 - k2)))
			"rubble":
				for i in 9:
					var d := Vector2.from_angle(float(i) / 9.0 * TAU + 0.3)
					_dot(pos + d * (10.0 + 34.0 * t), 9.0 + 9.0 * t, Color(color, color.a * 0.6))
				for i in 6:
					var d2 := Vector2.from_angle(float(i) / 6.0 * TAU + 1.1)
					_c.draw_rect(Rect2(pos + d2 * (6.0 + 26.0 * t) - Vector2(3, 3), Vector2(6, 5)), Color("8a8d94", 1.0 - t))
			"oil":
				for i in 7:
					var d := Vector2.from_angle(float(i) / 7.0 * TAU + 0.2)
					_dot(pos + d * (4.0 + 12.0 * t), 6.0 + 3.0 * t, Color(0.12, 0.08, 0.04, 0.75 * (1.0 - t)))
				_dot(pos, 5.0 + 8.0 * t, Color(1.0, 0.75, 0.3, 0.35 * (1.0 - t)))
			"fire_arrow":
				var from2: Vector2 = burst.get("from", pos)
				if t < 0.6:
					var k3 := t / 0.6
					var at2 := from2.lerp(pos, k3) - Vector2(0.0, sin(k3 * PI) * 30.0)
					var dir2 := (pos - from2).normalized()
					_c.draw_line(at2 - dir2 * 9.0, at2, Color(0.35, 0.25, 0.15, 0.9), 1.5)
					_dot(at2, 2.6, Color(1.0, 0.65, 0.2, 1.0))
				else:
					_dot(pos, 4.0 * (1.0 - t), Color(1.0, 0.55, 0.15, 0.8))
			"fall":
				_c.draw_arc(pos, 14.0 + 30.0 * t, 0.0, TAU, 30, color, 3.0)
				_c.draw_line(pos + Vector2(-8, -8), pos + Vector2(8, 8), color, 2.0)
				_c.draw_line(pos + Vector2(8, -8), pos + Vector2(-8, 8), color, 2.0)


## Soft shadows lift the men off the grass.
## A man's shadow, a flattened disk from the atlas stretched by the hour's sun, under
## where he's drawn (before a cheer lifts him).
func _add_shadow(so, sq, at: Vector2) -> void:
	at += _shadow_off
	var r: float = so.radius + (5.0 if sq.type == Troops.CAVALRY else 1.5)
	var kx := _shadow_long * r / Art.DISK_R
	var ky := 0.62 * r / Art.DISK_R
	_put_shadow(kx * Art.DISK_SIZE, ky * Art.DISK_SIZE, at.x - kx * Art.DISK_C.x, at.y - ky * Art.DISK_C.y, _shadow_cols[clampi(int(sq.team), 0, 1)], _shadow_cell)


func _put_shadow(xx: float, yy: float, ox: float, oy: float, col: Color, cell: Rect2) -> void:
	var j := _shadow_n * BATCH_FLOATS
	if j + BATCH_FLOATS > _shadow_buf.size():
		_shadow_buf.resize(maxi(_shadow_buf.size() * 2, 256 * BATCH_FLOATS))
	_shadow_buf[j] = xx
	_shadow_buf[j + 1] = 0.0
	_shadow_buf[j + 2] = 0.0
	_shadow_buf[j + 3] = ox
	_shadow_buf[j + 4] = 0.0
	_shadow_buf[j + 5] = yy
	_shadow_buf[j + 6] = 0.0
	_shadow_buf[j + 7] = oy
	_shadow_buf[j + 8] = col.r
	_shadow_buf[j + 9] = col.g
	_shadow_buf[j + 10] = col.b
	_shadow_buf[j + 11] = col.a
	_shadow_buf[j + 12] = cell.position.x
	_shadow_buf[j + 13] = cell.position.y
	_shadow_buf[j + 14] = cell.size.x
	_shadow_buf[j + 15] = 1.0 + cell.size.y
	_shadow_n += 1


## A man into the batch: his frame's cell, where he stands, his turn and size, his tint, and
## how white the hit flash makes him.
func _put_man(cell: Rect2, at: Vector2, angle: float, sx: float, sy: float, piv: Vector2, tint: Color, flash: float) -> void:
	var j := _men_n * BATCH_FLOATS
	if j + BATCH_FLOATS > _men_buf.size():
		_men_buf.resize(maxi(_men_buf.size() * 2, 256 * BATCH_FLOATS))
	var c := cos(angle)
	var s := sin(angle)
	var w := sx * cell.size.x * Art.ATLAS
	var h := sy * cell.size.y * Art.ATLAS
	var px := sx * piv.x
	var py := sy * piv.y
	_men_buf[j] = c * w
	_men_buf[j + 1] = -s * h
	_men_buf[j + 2] = 0.0
	_men_buf[j + 3] = at.x - c * px + s * py
	_men_buf[j + 4] = s * w
	_men_buf[j + 5] = c * h
	_men_buf[j + 6] = 0.0
	_men_buf[j + 7] = at.y - s * px - c * py
	_men_buf[j + 8] = tint.r
	_men_buf[j + 9] = tint.g
	_men_buf[j + 10] = tint.b
	_men_buf[j + 11] = tint.a
	_men_buf[j + 12] = cell.position.x
	_men_buf[j + 13] = cell.position.y
	_men_buf[j + 14] = cell.size.x + floorf(flash * 64.0)
	_men_buf[j + 15] = 1.0 + cell.size.y
	_men_n += 1


## The dead, one draw for each kind of body: man or horse, by side. Bodies of a kind lie in
## the order they fell.
func _draw_corpses(going_down: Dictionary) -> void:
	# Four kinds of body: a man or a horse, yours or theirs.
	var groups := [[], [], [], []]
	for c in sim.corpses:
		# A man still falling isn't a body yet.
		if going_down.has(c):
			continue
		groups[(2 if c.get("type", "") == Troops.CAVALRY else 0) + (0 if int(c["team"]) == Sim.PLAYER else 1)].append(c)
	_c.draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
	for g in 4:
		var list: Array = groups[g]
		if list.is_empty():
			continue
		var name := "corpse_horse" if g >= 2 else "corpse"
		var tex := Art.frame(name, Sim.PLAYER if g % 2 == 0 else Sim.ENEMY, 0)
		var k := Art.pixel_size(name)
		var piv := Art.pivot(name)
		var w := tex.get_width() * k
		var h := tex.get_height() * k
		# Room for the bodies in steps of CORPSE_STEP, so the MultiMesh is only remade as
		# the field fills, not every time a man falls.
		var buf := PackedFloat32Array()
		buf.resize(ceili(list.size() / float(CORPSE_STEP)) * CORPSE_STEP * 12)
		var j := 0
		for c in list:
			var p: Vector2 = c["pos"]
			# A steady, random-looking angle per body, so the dead don't spin between frames.
			var angle := fposmod(p.x * 12.9898 + p.y * 78.233, TAU)
			var co := cos(angle)
			var si := sin(angle)
			buf[j] = co * w
			buf[j + 1] = -si * h
			buf[j + 3] = p.x - co * k * piv.x + si * k * piv.y
			buf[j + 4] = si * w
			buf[j + 5] = co * h
			buf[j + 7] = p.y - si * k * piv.x - co * k * piv.y
			buf[j + 8] = 1.0
			buf[j + 9] = 1.0
			buf[j + 10] = 1.0
			buf[j + 11] = 0.8
			j += 12
		if not _corpse_mm.has(g):
			_corpse_mm[g] = _batch(false)
		_flush(_corpse_mm[g], buf, list.size(), tex, 12)


## How far into settling on its ground a squad that has just halted is: up to 1 and back
## to 0 over a third of a second (the ring around it is _draw_settled's).
const SETTLE_TIME := 0.35


func _settle_k(sq) -> float:
	if not _settled_at.has(sq):
		return 0.0
	var t: float = (_clock - float(_settled_at[sq])) / SETTLE_TIME
	return sin(PI * t) if t >= 0.0 and t < 1.0 else 0.0


## How a squad's men are drawn this frame: kit, tint and what the squad as a whole is doing.
func _squad_look(sq) -> Dictionary:
	var still := Sound.reduced_motion
	var moving: bool = float(_sq_speed.get(sq, 0.0)) > 4.0
	return {
		# A trained squad is drawn in its branch's own kit.
		"type": sq.unit if sq.unit != "" else sq.type,
		"culture": _culture_of(sq),
		"tint": Color(0.72, 0.72, 0.72, 0.9) if sq.routing else Color.WHITE,
		"still": still,
		# The winners cheer: weapons up, each man bobbing on his own beat.
		"cheering": sim.winner != -1 and sq.team == sim.winner and sq.is_active(),
		"shaken": wavering(sq) and sim.phase == Sim.PHASE_BATTLE,
		"charging": sq.type == Troops.CAVALRY and sq.is_active() and not sq.engaged and float(_sq_speed.get(sq, 0.0)) > 30.0 and not still,
		# Set for the blow: braced, a shield wall or a schiltron, eased in and out.
		"set": float(_set_k.get(sq, 0.0)),
		# Just halted on its ground: the men sink into their stance and come up (0 to 1 and back).
		"settle": _settle_k(sq),
		# On the march (0 standing to 1 at a walk and faster): the men roll with their steps.
		"march": 0.0 if sq.engaged or sq.routing or not sq.is_active() else clampf((float(_sq_speed.get(sq, 0.0)) - 4.0) / 10.0, 0.0, 1.0),
		"horse": sq.type == Troops.CAVALRY,
		"idle": sim.phase == Sim.PHASE_BATTLE and not sq.engaged and not sq.routing and not moving,
		"ranged": sq.ranged and sq.arrows != 0,
		"team": sq.team,
	}


func _draw_men(sq) -> void:
	var look := _squad_look(sq)
	var i := -1
	for so in sq.soldiers:
		i += 1
		if so.alive:
			_draw_man(so, sq, i, look)


## Engaged squads' men, drawn back to front across squads, so the front rank of one squad
## isn't painted over by the back rank of the next where the lines meet.
func _draw_melee(squads: Array) -> void:
	var looks := []
	var men := []
	var keys := PackedInt64Array()
	for sq in squads:
		var look := _squad_look(sq)
		var i := -1
		for so in sq.soldiers:
			i += 1
			if so.alive:
				# Sorted natively: a key of the man's height on the field, then his place in
				# the list.
				keys.append((int(maxf(0.0, so.pos.y + 64.0) * 64.0) << 20) | men.size())
				men.append(so)
				looks.append([sq, i, look])
	keys.sort()
	for k in keys:
		var n := k & 0xFFFFF
		var l: Array = looks[n]
		_draw_man(men[n], l[0], l[1], l[2])


## Where a man is drawn this frame, against where the sim has him: an offset (field units),
## a turn, a frame and a crouch. Read from what the sim keeps (the swing after a blow, the
## cooldown before the next, the flash of a hit) and from charges the screen saw land; never
## written back. Reduced motion draws every man where he stands.
## Where a man is drawn this frame, as a dictionary: {off, tilt, index, squash, and face
## when he looks somewhere other than his own facing}. For tests and anything off the hot
## path; drawing reads _pose_now's fields.
func _pose(so, sq, i: int, look: Dictionary) -> Dictionary:
	_pose_now(so, sq, i, look)
	var pose := {"off": _po, "tilt": _pt, "index": _pi, "squash": _ps}
	if _pf_set:
		pose["face"] = _pf
	return pose


func _pose_now(so, sq, i: int, look: Dictionary) -> void:
	_po = Vector2.ZERO
	_pt = 0.0
	_pi = -1
	_ps = 1.0
	_pf_set = false
	var fwd: Vector2 = so.facing
	if sq.routing:
		# Running for their own edge, leaning into it, at twice the stride.
		fwd = Vector2.DOWN if sq.team == Sim.PLAYER else Vector2.UP
		_pf = fwd
		_pf_set = true
		_pi = WALK[int(so.stride / (STRIDE * 0.125)) % 4]
		if not look["still"]:
			_pt = sin(so.stride * 0.45 + i) * deg_to_rad(15.0)
		return
	if look["still"]:
		return
	var side := 1.0 if i % 2 == 0 else -1.0
	if so.swing > 0.0:
		# The blow: a lunge at the target, then easing back to his place.
		var e: float = SWING - so.swing
		var k := 1.0 if e < STRIKE_HOLD else 1.0 - _ease_out((e - STRIKE_HOLD) / (SWING - STRIKE_HOLD))
		_po += fwd * LUNGE * k
		_pt += deg_to_rad(6.0) * k * side
		_pi = 2
	elif so.target != null and so.cooldown > 0.0 and ((sq.engaged and so.cooldown < WINDUP) or (look["ranged"] and so.cooldown < WINDUP * 2.0)):
		# The wind-up, just before the next blow (or the bow drawn before the loose).
		var k: float = 1.0 - so.cooldown / (WINDUP * (2.0 if look["ranged"] else 1.0))
		_po -= fwd * WIND_BACK * k
		_pt -= deg_to_rad(12.0) * k * side
		if look["ranged"]:
			_pi = 2
	if so.flash > 0.0:
		# Struck: knocked back from the man he faces, and turned by it.
		_po -= fwd * FLINCH * so.flash
		_pt += deg_to_rad(14.0) * so.flash * side
	var shove = _shoved.get(so)
	if shove != null:
		var t: float = float(shove["age"]) / SHOVE_TIME
		var k: float = t / 0.2 if t < 0.2 else 1.0 - _ease_in_out((t - 0.2) / 0.8)
		k *= float(shove["k"])
		_po += Vector2(shove["dir"]) * SHOVE * k
		_pt += deg_to_rad(28.0) * k * side
	var set_k: float = look["set"]
	if set_k > 0.0:
		# Set for the blow: crouched behind the shield, a step into the line.
		_po += fwd * 1.5 * set_k
		_ps = 1.0 - 0.1 * set_k
	elif float(look.get("settle", 0.0)) > 0.0:
		# Come to a halt: a dip into the stance, and up.
		_ps = 1.0 - 0.09 * float(look["settle"])
	elif look["idle"] and _pi == -1:
		# Waiting, each man breathing on his own beat.
		_po += fwd * sin(_clock * 1.6 + i * 0.9) * 0.8
	elif float(look.get("march", 0.0)) > 0.0 and _pi == -1 and so.flash <= 0.0:
		# Marching: seen from above, boots hardly show, so the step is in the body. A man's
		# shoulders roll with each stride and he sways a little off his line; a horse
		# stretches out and gathers itself as it goes. It eases away as the company halts.
		var k: float = float(look["march"])
		var ph: float = so.stride / STRIDE * TAU
		if bool(look.get("horse", false)):
			_ps = 1.0 + 0.06 * sin(ph * 2.0) * k
			_pt += sin(ph) * deg_to_rad(2.5) * k
		else:
			_pt += sin(ph) * deg_to_rad(5.0) * k
			_po += fwd.orthogonal() * sin(ph) * 0.7 * k
	return


static func _ease_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


static func _ease_in_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _draw_man(so, sq, i: int, look: Dictionary) -> void:
	var type: String = look["type"]
	var culture: String = look["culture"]
	var still: bool = look["still"]
	_pose_now(so, sq, i, look)
	var index: int = 2 if so.swing > 0.0 else WALK[int(so.stride / (STRIDE * 0.25)) % 4]
	if _pi >= 0:
		index = _pi
	var face: Vector2 = _pf if _pf_set else so.facing
	var angle: float = face.angle() + PI * 0.5 + _pt
	var at: Vector2 = so.pos + _po
	_add_shadow(so, sq, at)
	if look["cheering"] and not still:
		var beat := sin(_clock * 9.0 + i * 1.7)
		at += Vector2(0, -absf(beat) * 3.0)
		index = 2 if beat > 0.0 else 0
	elif look["shaken"] and i % 3 == 0:
		# A wavering man glances back over his shoulder now and then.
		var glance := fposmod(_clock * 0.8 + i * 0.37, 1.0) < 0.22
		if glance and not still:
			angle += PI * 0.8
		if glance:
			_glances.append(at)
	if look["charging"]:
		_streaks.append([so.pos, so.facing])
	var grow := 1.0
	if so.captain:
		# Captains stand a head taller, on a gold ring.
		grow = 1.2
		_rings.append([at, sq.team, type])
	if not look.has("cells"):
		var team := int(look["team"])
		look["cells"] = [Art.atlas_cell(type, team, 0, culture), Art.atlas_cell(type, team, 1, culture), Art.atlas_cell(type, team, 2, culture),
			Art.atlas_cell(type, team, 3, culture)]
		look["piv"] = Art.pivot(type, culture)
		var role := Units.role(type) if Units.has(type) else type
		look["width"] = (0.92 if role == Troops.CAVALRY else 0.86) if (Troops.TYPES.has(type) or Units.has(type)) else 1.0
		look["px"] = Art.pixel_size(type)
	var k: float = float(look["px"]) * grow
	# A pale flash of the hit, light enough that the kit still reads (none under Reduced motion).
	var flash: float = so.flash * 0.45 if so.flash > 0.05 and not _still_men else 0.0
	_put_man(look["cells"][clampi(index, 0, 3)], at, angle, k * float(look["width"]), k * _ps, look["piv"], look["tint"], flash)

## Arrows rise and fall on their way, with a shadow on the ground beneath them.
func _draw_arrows() -> void:
	# Every shadow and streak, then every arrow, so the lines go as one batch and the
	# arrows as another, not three draws an arrow.
	var at := PackedVector2Array()
	var turn := PackedFloat32Array()
	_c.draw_set_transform(field_origin, 0.0, Vector2(field_scale, field_scale))
	for p in sim.projectiles:
		var to: Vector2 = p.aim - p.pos
		if to.length() < 0.01:
			continue
		var done: float = p.origin.distance_to(p.pos)
		var total: float = done + to.length()
		var t: float = done / maxf(1.0, total)
		var rise := minf(70.0, total * 0.2)
		var height := 4.0 * rise * t * (1.0 - t)
		var dir := to.normalized()
		_c.draw_line(p.pos - dir * 4.0, p.pos + dir * 4.0, Color(0, 0, 0, 0.22), 1.5)
		var slope := 4.0 * rise * (1.0 - 2.0 * t) / maxf(1.0, total)
		var screen_dir := (dir - Vector2(0, slope)).normalized()
		# A streak behind it, so a volley reads as a flight of arrows.
		var lifted: Vector2 = p.pos - Vector2(0, height)
		_c.draw_line(lifted - screen_dir * 16.0, lifted - screen_dir * 3.0, Color(1, 1, 1, 0.3), 1.0)
		at.append(lifted)
		turn.append(screen_dir.angle() + PI * 0.5)
	for i in at.size():
		_sprite("arrow", 0, 0, at[i], turn[i])


## Every squad carries a standard over it: its type, a morale bar and a head count. A
## squad's standard topples when it breaks. Standards that would overlap fan out.
## Whether `sq` is wavering: still fighting, but close to breaking.
func wavering(sq) -> bool:
	return sq.is_active() and not sq.routing and sq.morale <= WAVER_MORALE


## The colour of what a hoof or a foot throws up at `p`: spray at a ford, leaf litter in a
## wood, sand in the desert, dust or turf elsewhere.
func _ground_dust(p: Vector2) -> Color:
	if sim.terrain != null:
		if sim.terrain.water_at(p) != Terrain.WATER_NONE:
			return Color(0.75, 0.88, 1.0)
		if sim.terrain.in_woods(p):
			return Color(0.36, 0.3, 0.18)
	return Color(0.86, 0.74, 0.5) if _biome == "kharzani" else Color(0.55, 0.47, 0.3)


## Rings where a squad has just halted and settled into its ground.
func _draw_settled() -> void:
	for sq in _settled_at.keys():
		var t: float = (_clock - float(_settled_at[sq])) / 0.6
		if t >= 1.0 or not sq.is_active():
			_settled_at.erase(sq)
			continue
		var r: float = minf(sq.extent, 60.0) + 8.0 + (0.0 if Sound.reduced_motion else 10.0 * t)
		_c.draw_arc(sq.average_pos(), r, 0.0, TAU, 32, Color(Style.BRASS, 0.7 * (1.0 - t)), 3.0)


## Arrows at the edge of the field for your selected company, and any of yours fighting,
## when they're out of sight.
func _draw_edge_markers() -> void:
	if sim.phase != Sim.PHASE_BATTLE:
		return
	var view := get_viewport_rect()
	var top_h: float = top_panel.size.y if top_panel != null else 0.0
	var bottom_h: float = bottom_panel.size.y if bottom_panel != null else 0.0
	var area := Rect2(view.position + Vector2(18.0, top_h + 18.0), view.size - Vector2(36.0, top_h + bottom_h + 36.0))
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	for sq in sim.squads:
		if sq.team != Sim.PLAYER or not sq.is_active():
			continue
		var urgent: bool = sq.engaged or wavering(sq)
		if sq != selected_squad and not urgent:
			continue
		var at := _to_screen(sq.average_pos())
		if area.has_point(at):
			continue
		var c := area.get_center()
		var dir := (at - c).normalized()
		var edge := Vector2(clampf(at.x, area.position.x, area.end.x), clampf(at.y, area.position.y, area.end.y))
		var col := Style.ENEMY_LIGHT if wavering(sq) else (Style.BRASS if sq == selected_squad else Style.PLAYER_LIGHT)
		var tip := edge
		var back := tip - dir * 22.0
		var side := dir.orthogonal() * 11.0
		_c.draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), Color(0, 0, 0, 0.6))
		_c.draw_colored_polygon(PackedVector2Array([tip - dir * 2.0, back + side * 0.75, back - side * 0.75]), col)
	# And what's coming for you from out of sight: enemy horse at the charge near one of
	# your companies, as an open red chevron (yours are filled).
	# They sit clear of the objective at the top of the field, where the enemy mostly comes from.
	var clear := area.grow_individual(0.0, -THREAT_TOP_INSET, 0.0, 0.0)
	for sq in _threats():
		var at := _to_screen(sq.average_pos())
		if area.has_point(at):
			continue
		var dir := (at - clear.get_center()).normalized()
		var tip := Vector2(clampf(at.x, clear.position.x, clear.end.x), clampf(at.y, clear.position.y, clear.end.y))
		var back := tip - dir * 26.0
		var side := dir.orthogonal() * 16.0
		var chevron := PackedVector2Array([back + side, tip, back - side])
		_c.draw_polyline(chevron, Color(0, 0, 0, 0.7), 9.0)
		_c.draw_polyline(chevron, Style.ENEMY_LIGHT, 4.5)


## Enemy horse at the charge within reach of one of your companies: worth a warning at
## the edge of the field when it's out of sight.
const THREAT_REACH := 280.0
const THREAT_TOP_INSET := 70.0


func _threats() -> Array:
	var out := []
	for sq in sim.squads:
		if sq.team == Sim.PLAYER or sq.type != Troops.CAVALRY or not sq.is_active() or sq.routing or sq.engaged:
			continue
		if float(_sq_speed.get(sq, 0.0)) < 30.0:
			continue
		var from: Vector2 = sq.average_pos()
		for mine in sim.squads:
			if mine.team == Sim.PLAYER and mine.is_active() and mine.average_pos().distance_to(from) < THREAT_REACH:
				out.append(sq)
				break
	return out


func _draw_standards() -> void:
	_std_tops.clear()
	var ref_type := ""
	if selected_squad != null:
		ref_type = selected_squad.type
	elif sim.phase == Sim.PHASE_DEPLOY and selected_id != -1:
		for e in _cards:
			if e["roster_id"] == selected_id:
				ref_type = e["type"]
	var shown: Array = []
	for sq in sim.squads:
		if sq.alive_n > 0:
			shown.append(sq)
	# Fan out: start from the squad's own spot, then push overlapping flags apart. Each
	# squad is put on the screen once; only the pairs close enough in height to touch are
	# pushed, and they're found once, not on every pass.
	var n := shown.size()
	var want := PackedFloat64Array()
	var ys := PackedFloat64Array()
	want.resize(n)
	ys.resize(n)
	for i in n:
		var at := _to_screen(shown[i].avg)
		want[i] = at.x
		ys[i] = at.y
	var pairs := PackedInt32Array()
	for i in n:
		for j in range(i + 1, n):
			if absf(ys[i] - ys[j]) <= FLAG.y + 22.0:
				pairs.append(i)
				pairs.append(j)
	var need := FLAG.x + 8.0
	for pass_i in 6:
		for k in range(0, pairs.size(), 2):
			var i := pairs[k]
			var j := pairs[k + 1]
			var gap: float = want[j] - want[i]
			if absf(gap) < need:
				var push := (need - absf(gap)) * 0.5 * (1.0 if gap >= 0.0 else -1.0)
				if absf(gap) < 0.01:
					push = need * 0.5
				want[i] -= push
				want[j] += push
	for i in n:
		var sq = shown[i]
		var x: float = want[i]
		_std_x[sq] = lerpf(float(_std_x.get(sq, x)), x, 0.25)
		_draw_standard(sq, float(_std_x[sq]), ref_type)
	for foe in _targeted():
		if _std_tops.has(foe):
			_draw_crossed_swords(_std_tops[foe] + Vector2(FLAG.x * 0.5, -40.0))


func _draw_standard(sq, flag_x: float, ref_type: String) -> void:
	var mine: bool = sq.team == Sim.PLAYER
	var base := _to_screen(sq.avg)
	var fall := 0.0
	if sq.routing:
		fall = clampf((_clock - float(_broke_at.get(sq, _clock - 1.0))) / 0.7, 0.0, 1.0)
		fall = 1.0 - pow(1.0 - fall, 3.0)
	# Dip forward for a moment when ordered.
	var dip := 0.0
	var since: float = _clock - float(_ordered_at.get(sq, -9.0))
	if since < 0.5:
		dip = sin(since / 0.5 * PI) * 0.35
	var lean := deg_to_rad(68.0) * fall * (1.0 if mine else -1.0) + dip * (1.0 if sq.facing.x >= 0.0 else -1.0)
	# A wavering standard trembles.
	if wavering(sq) and not Sound.reduced_motion:
		flag_x += sin(_clock * 31.0 + sq.id) * 2.5
	var top := Vector2(flag_x, base.y) + Vector2(sin(lean), -cos(lean)) * POLE
	var selected: bool = sq == selected_squad or (mine and sim.phase == Sim.PHASE_DEPLOY and sq.roster_id == selected_id)
	_c.draw_line(base + Vector2(1, 1), top + Vector2(1, 1), Color(0, 0, 0, 0.5), 4.0)
	_c.draw_line(base, top, Color("6b4a2a"), 3.0)
	var ready: bool = mine and sim.ability_ready(sq)
	_dot(top, 5.0 if ready else 3.5, Style.BRASS if ready or not sq.routing else Color(0.5, 0.5, 0.5))
	if not sq.routing:
		_std_tops[sq] = top
	var edge := Style.BRASS if selected or sq.braced() else (Color("5bc0be") if sq.is_ally else Color(0.06, 0.05, 0.08))
	if sim.winner != -1 and sq.team == sim.winner and sq.is_active():
		# The winners' standards glow, held high.
		_dot(top + FLAG * 0.5, FLAG.x * 0.95, Color(1.0, 0.85, 0.4, 0.18 + (0.0 if Sound.reduced_motion else 0.06 * sin(_clock * 4.0))))
	if Sound.reduced_motion or _c != _top_layer:
		_draw_flag(_c, top + Vector2(0, 2), FLAG, sq.team, sq.type, sq.routing, selected or sq.braced(), lean, edge)
	else:
		_draw_waving_flag(top + Vector2(0, 2), sq, selected or sq.braced(), lean, edge)
	if sq.is_bodyguard or sq.is_chief:
		var crown_c := top + Vector2(FLAG.x * 0.5, -16.0)
		_c.draw_colored_polygon(PackedVector2Array([
			crown_c + Vector2(-9, 5), crown_c + Vector2(-9, -4), crown_c + Vector2(-5, 0),
			crown_c + Vector2(0, -7), crown_c + Vector2(5, 0), crown_c + Vector2(9, -4),
			crown_c + Vector2(9, 5)
		]), Style.BRASS)
	if sq.routing or sim.phase != Sim.PHASE_BATTLE:
		if not mine and ref_type != "":
			_draw_counter_hint(top, sq.type, ref_type)
		return
	var bar := Rect2(top + Vector2(-2, FLAG.y + 9.0), Vector2(36, 6))
	var m := clampf(sq.morale / 100.0, 0.0, 1.0)
	if wavering(sq):
		# A warning mark beside the flag, steady with reduced motion, pulsing otherwise.
		var pulse := 1.0 if Sound.reduced_motion else 0.6 + 0.4 * sin(_clock * 9.0)
		var mark := top + Vector2(FLAG.x + 12.0, 8.0)
		_dot(mark, 9.0, Color(Style.ENEMY_LIGHT, pulse))
		_c.draw_string(font, mark + Vector2(-3.5, 6.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.05, 0.03, 0.03))
	if sq.arrows == 0:
		# Out of arrows: an empty quiver beside the flag, for as long as it lasts.
		var q := top + Vector2(FLAG.x + 12.0, 8.0 + (22.0 if wavering(sq) else 0.0))
		_draw_empty_quiver(_c, q, 9.0)
	_c.draw_rect(bar.grow(1.5), Color(0.05, 0.05, 0.08, 0.85))
	_c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * m, bar.size.y)), Style.morale_color(sq.morale))
	_draw_morale_mark(_c, bar.position + Vector2(-9.0, bar.size.y * 0.5), sq.morale, 5.0)
	var count := str(sq.alive_n)
	_c.draw_string_outline(font, top + Vector2(38, FLAG.y + 19.0), count, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(Style.SMALL), 4, Color(0, 0, 0, 0.9))
	_c.draw_string(font, top + Vector2(38, FLAG.y + 19.0), count, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(Style.SMALL), Style.TEXT)
	if sq.ability_left > 0.0 or sq.wheeling:
		_c.draw_rect(Rect2(top + Vector2(-4, -2), FLAG + Vector2(8, 8)), Color(Style.BRASS, 0.8), false, 2.0)
	if not mine and ref_type != "":
		_draw_counter_hint(top, sq.type, ref_type)


## A morale meter's shape, so it reads without its colour: ▲ steady, ◆ shaken, ▼ near
## breaking (the same bands as Style.morale_color), on a dark outline.
## Drawn as two primitives (the dark outline a size up, the shape over it), which batch
## with the rest of the frame where a polygon or polyline would each be drawn alone.
func _draw_morale_mark(ci: CanvasItem, at: Vector2, morale: float, r: float) -> void:
	var dark := Color(0.03, 0.03, 0.05, 0.9)
	var fill := Style.morale_color(morale)
	var outline := _morale_shape(at, morale, r + 1.5)
	var shape := _morale_shape(at, morale, r - 0.3)
	ci.draw_primitive(outline, _ink(dark, outline.size()), PackedVector2Array())
	ci.draw_primitive(shape, _ink(fill, shape.size()), PackedVector2Array())


## A morale mark's corners: ▲ steady, ◆ shaken, ▼ near breaking.
static func _morale_shape(at: Vector2, morale: float, r: float) -> PackedVector2Array:
	if morale > 60.0:
		return PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, r * 0.8), at + Vector2(-r, r * 0.8)])
	if morale > 42.0:
		return PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])
	return PackedVector2Array([at + Vector2(-r, -r * 0.8), at + Vector2(r, -r * 0.8), at + Vector2(0, r)])


static func _ink(c: Color, n: int) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(n)
	out.fill(c)
	return out


## A state badge: a quiver with no arrows in it, on a dark disc.
func _draw_empty_quiver(ci: CanvasItem, at: Vector2, r: float) -> void:
	ci.draw_circle(at, r, Color(0.05, 0.05, 0.08, 0.9))
	ci.draw_arc(at, r, 0.0, TAU, 20, Color(Style.MUTED, 0.9), 1.5)
	var k := r / 9.0
	ci.draw_rect(Rect2(at + Vector2(-2.5, -4.0) * k, Vector2(5.0, 9.0) * k), Color("8a6a3a"))
	ci.draw_line(at + Vector2(-5.0, 5.0) * k, at + Vector2(5.0, -5.0) * k, Style.ENEMY_LIGHT, 2.0 * k)


## Enemy squads one of yours has been ordered to attack, still fighting.
func _targeted() -> Array:
	var out := []
	if sim.phase != Sim.PHASE_BATTLE:
		return out
	for sq in sim.squads:
		if sq.team == Sim.PLAYER and sq.is_active() and sq.order == "attack" and sq.order_target != null \
				and sq.order_target.is_active() and not out.has(sq.order_target):
			out.append(sq.order_target)
	return out


## A pulsing red ring around every enemy squad you've sent someone to attack.
func _draw_targets() -> void:
	var pulse := 0.5 + 0.5 * sin(_clock * 5.0)
	for foe in _targeted():
		var r: float = minf(foe.extent, 70.0) + 18.0 + pulse * 5.0
		_c.draw_arc(foe.average_pos(), r, 0.0, TAU, 40, Color(0, 0, 0, 0.55), 8.0)
		_c.draw_arc(foe.average_pos(), r, 0.0, TAU, 40, Color(TARGET_RED, 0.75 + 0.25 * pulse), 4.5)


## Two blades crossed over a standard: this squad is someone's target.
func _draw_crossed_swords(c: Vector2) -> void:
	for side in [-1.0, 1.0]:
		var tip := c + Vector2(-13.0 * side, -13.0)
		var hilt := c + Vector2(10.0 * side, 10.0)
		var guard := (hilt - tip).normalized().orthogonal() * 6.0
		for pass_i in 2:
			var w := 7.0 if pass_i == 0 else 3.5
			var col := Color(0.06, 0.05, 0.08, 0.95) if pass_i == 0 else TARGET_RED.lightened(0.25)
			_c.draw_line(tip, hilt, col, w)
			_c.draw_line(hilt - (hilt - tip).normalized() * 3.0 + guard, hilt - (hilt - tip).normalized() * 3.0 - guard, col, w)


## The line being drawn, with where each squad will stand on it and which way it will
## face; then, for a moment, the line just ordered.
func _draw_line_order() -> void:
	_draw_pending()
	if _drawing and _press_squad != null:
		_draw_carry()
		return
	if _drawing:
		var b := _to_field(_drag_to)
		var only = selected_squad if sim.phase == Sim.PHASE_BATTLE else null
		var spots := sim.line_preview(Sim.PLAYER, _press_field, b, only)
		_c.draw_line(_press_field, b, Color(0, 0, 0, 0.5), 7.0)
		_c.draw_line(_press_field, b, Style.BRASS, 3.0)
		_draw_spots(spots, sim.line_face(Sim.PLAYER, _press_field, b), 1.0, true)
	elif not _line_shown.is_empty():
		var age: float = _clock - float(_line_shown["at"])
		if age > LINE_SHOWN:
			_line_shown = {}
			return
		_draw_spots(_line_shown["spots"], _line_shown["face"], 1.0 - age / LINE_SHOWN, false)


## Orders waiting for their second tap, pulsing (steady under Reduced motion): the whole
## warband's line with each company's stretch of it, or a march ring with a thread from
## the squad.
func _draw_pending() -> void:
	var k := 1.0 / maxf(0.1, field_scale)
	var pulse := 1.0 if Style.motion_reduced() else 0.7 + 0.3 * sin(_clock * 6.0)
	if not _pending_line.is_empty() and not _drawing:
		var a: Vector2 = _pending_line["a"]
		var b: Vector2 = _pending_line["b"]
		_c.draw_line(a, b, Color(0, 0, 0, 0.45), 7.0 * k)
		_c.draw_dashed_line(a, b, Color(Style.BRASS, pulse), 3.0 * k, 12.0 * k)
		_draw_spots(sim.line_preview(Sim.PLAYER, a, b, null), sim.line_face(Sim.PLAYER, a, b), 0.75 * pulse, true)
	if not _pending_march.is_empty():
		var sq = _pending_march["squad"]
		if sq == null or not sq.is_active() or sq != selected_squad:
			_pending_march = {}
			return
		var at: Vector2 = _pending_march["at"]
		_c.draw_line(sq.average_pos(), at, Color(0, 0, 0, 0.3), 5.0 * k)
		_c.draw_dashed_line(sq.average_pos(), at, Color(Style.BRASS, 0.7 * pulse), 2.5 * k, 10.0 * k)
		_c.draw_arc(at, 18.0 * k, 0.0, TAU, 32, Color(0, 0, 0, 0.5), 6.0 * k)
		_c.draw_arc(at, 18.0 * k, 0.0, TAU, 32, Color(Style.BRASS, pulse), 3.0 * k)
		_c.draw_circle(at, 4.0 * k, Color(Style.BRASS, pulse))


## A squad in the finger's hand: a thread from its men to the finger, and a ring on what
## it would go for: red round an enemy, brass on ground it can reach, grey where it can't.
func _draw_carry() -> void:
	var sq = _press_squad
	var t := _drop_target(sq, _drag_to)
	var to := _to_field(_drag_to)
	var from: Vector2 = sq.average_pos()
	var k := 1.0 / maxf(0.1, field_scale)
	var col := Style.BRASS
	if t.has("foe"):
		col = TARGET_RED
		var foe = t["foe"]
		var r: float = minf(foe.extent, 70.0) + 20.0
		_c.draw_arc(foe.average_pos(), r, 0.0, TAU, 40, Color(0, 0, 0, 0.55), 8.0 * k)
		_c.draw_arc(foe.average_pos(), r, 0.0, TAU, 40, TARGET_RED, 4.0 * k)
		_c.draw_arc(foe.average_pos(), r + 7.0 * k, 0.0, TAU, 40, Color(TARGET_RED, 0.3), 6.0 * k)
		to = foe.average_pos()
	elif not t.is_empty():
		col = Style.BRASS if bool(t["ok"]) else Style.MUTED
		_c.draw_arc(to, 18.0 * k, 0.0, TAU, 32, Color(0, 0, 0, 0.5), 6.0 * k)
		_c.draw_arc(to, 18.0 * k, 0.0, TAU, 32, col, 3.0 * k)
		if not bool(t["ok"]):
			var d := 9.0 * k
			_c.draw_line(to + Vector2(-d, -d), to + Vector2(d, d), col, 3.0 * k)
			_c.draw_line(to + Vector2(d, -d), to + Vector2(-d, d), col, 3.0 * k)
	else:
		return
	var own: float = minf(sq.extent, 70.0) + 14.0
	_c.draw_arc(from, own, 0.0, TAU, 40, Color(0, 0, 0, 0.45), 6.0 * k)
	_c.draw_arc(from, own, 0.0, TAU, 40, Style.BRASS, 3.0 * k)
	_c.draw_line(from, to, Color(0, 0, 0, 0.35), 6.0 * k)
	_c.draw_dashed_line(from, to, Color(col, 0.9), 3.0 * k, 10.0 * k)
	var dir := (to - from).normalized()
	if dir != Vector2.ZERO:
		var tip := to - dir * (26.0 * k if t.has("foe") else 22.0 * k)
		var side := dir.orthogonal() * 8.0 * k
		_c.draw_colored_polygon(PackedVector2Array([tip + dir * 10.0 * k, tip - dir * 6.0 * k + side, tip - dir * 6.0 * k - side]), col)


## The words beside the finger while a squad is carried: the matchup over an enemy, before
## the finger lifts, or what the ground would mean.
func _draw_carry_card() -> void:
	if not (_drawing and _press_squad != null):
		return
	var sq = _press_squad
	var t := _drop_target(sq, _drag_to)
	if t.is_empty():
		return
	var lines: Array = []
	if t.has("foe"):
		var foe = t["foe"]
		var m := _matchup(sq.type, foe.type)
		lines.append(["%s vs %s  %s %s" % [_name(sq.type, Sim.PLAYER, sq.roster_id), _name(foe.type, Sim.ENEMY), m[0], m[1]], m[2]])
		lines.append(["%d men against %d · their morale %d%%" % [sq.alive_count(), foe.alive_count(), maxi(0, int(foe.morale))], Style.MUTED])
	elif sim.phase == Sim.PHASE_DEPLOY:
		lines.append(["Stand here" if bool(t["ok"]) else "Not there: %s" % t["why"], Style.BRASS if bool(t["ok"]) else Style.MUTED])
	else:
		lines.append(["March here and hold" if bool(t["ok"]) else "Not there: %s" % t["why"], Style.BRASS if bool(t["ok"]) else Style.MUTED])
	# Above the finger, where the hand doesn't cover it; below it near the top of the field.
	var y := _drag_to.y - 84.0 - float(_fs(Style.SMALL) + 18) * float(lines.size() - 1)
	if y < _view.position.y + 12.0:
		y = _drag_to.y + 60.0
	var fs := _fs(Style.SMALL)
	for l in lines:
		var text: String = l[0]
		var c: Color = l[1]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 28.0
		var box := Rect2(Vector2(_drag_to.x - w * 0.5, y), Vector2(w, fs + 12.0))
		box.position.x = clampf(box.position.x, _view.position.x + 4.0, maxf(_view.position.x + 4.0, _view.end.x - w - 4.0))
		_c.draw_style_box(_chip_box(Color(Style.NIGHT, 0.88), Color(c, 0.55)), box)
		_c.draw_string(font, box.position + Vector2(14.0, (fs + 12.0) * 0.5 + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
		y += fs + 18.0


## The slow handle on the field's edge, and while it's held, the cool cast over the field
## and a badge saying time is slowed, not stopped.
func _draw_slow() -> void:
	var r := _slow_handle()
	if r.size == Vector2.ZERO:
		return
	var held := slow_held()
	if held:
		_c.draw_rect(_view, Color(0.05, 0.1, 0.3, 0.26))
		for i in 8:
			var inset := float(i) * 6.0
			_c.draw_rect(Rect2(_view.position + Vector2(inset, inset), _view.size - Vector2(inset * 2.0, inset * 2.0)),
				Color(0.4, 0.7, 1.0, 0.04), false, 2.0)
		var text := "¼ time · let go to run on"
		var fs := _fs(Style.SMALL)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 28.0
		var top := _view.position.y + 30.0 + (58.0 if objective_chip != null and objective_chip.visible else 0.0) + float(ticker.size()) * (fs + 18.0)
		var box := Rect2(Vector2(_view.get_center().x - w * 0.5, top - 6.0), Vector2(w, fs + 12.0))
		_c.draw_style_box(_chip_box(Color(Style.NIGHT, 0.88), Color(Style.PLAYER_LIGHT, 0.55)), box)
		_c.draw_string(font, box.position + Vector2(14.0, (fs + 12.0) * 0.5 + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.PLAYER_LIGHT)
	# The tab: a dark rounded edge with an hourglass, brighter while held.
	var b := StyleBoxFlat.new()
	b.bg_color = Color(Style.NIGHT, 0.85 if held else 0.6)
	b.border_color = Color(Style.PLAYER_LIGHT if held else Style.BRASS, 0.9 if held else 0.45)
	b.set_border_width_all(2 if held else 1)
	b.corner_radius_top_left = 14
	b.corner_radius_bottom_left = 14
	_c.draw_style_box(b, r)
	var c := r.get_center() + Vector2(2.0, -8.0)
	var ink := Style.PLAYER_LIGHT if held else Color(Style.TEXT, 0.75)
	var hw := 11.0
	var hh := 16.0
	_c.draw_colored_polygon(PackedVector2Array([c + Vector2(-hw, -hh), c + Vector2(hw, -hh), c + Vector2(0, 0)]), Color(ink, 0.25))
	_c.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 0), c + Vector2(hw, hh), c + Vector2(-hw, hh)]), ink)
	_c.draw_polyline(PackedVector2Array([c + Vector2(-hw, -hh), c + Vector2(hw, -hh), c + Vector2(-hw, hh), c + Vector2(hw, hh), c + Vector2(-hw, -hh)]), ink, 2.0)
	var tab_fs := _fs(Style.SMALL)
	var label := _fit("¼×" if held else "hold", tab_fs, r.size.x - 6.0)
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, tab_fs).x
	_c.draw_string(font, Vector2(r.get_center().x - lw * 0.5 + 2.0, r.end.y - 10.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, tab_fs, ink)


## Each squad's place on a line: the ground it will cover and an arrow the way it faces,
## and while drawing, a thread from where it stands now.
func _draw_spots(spots: Array, face: Vector2, alpha: float, live: bool) -> void:
	var right := Vector2(-face.y, face.x)
	for spot in spots:
		var at: Vector2 = spot["at"]
		var half: Vector2 = spot["half"]
		var sq = spot["squad"]
		if live and sq.alive_n > 0:
			_c.draw_dashed_line(sq.average_pos(), at, Color(Style.BRASS, 0.45 * alpha), 2.0, 8.0)
		var box := PackedVector2Array([at - right * half.x - face * half.y, at + right * half.x - face * half.y,
			at + right * half.x + face * half.y, at - right * half.x + face * half.y])
		_c.draw_colored_polygon(box, Color(Style.BRASS, 0.16 * alpha))
		box.append(box[0])
		_c.draw_polyline(box, Color(Style.BRASS, 0.9 * alpha), 2.0)
		var tip := at + face * (half.y + 16.0)
		_c.draw_colored_polygon(PackedVector2Array([tip, tip - face * 10.0 + right * 7.0, tip - face * 10.0 - right * 7.0]),
			Color(Style.BRASS, 0.9 * alpha))


## ▲ over an enemy your selected squad beats; ▼ over one that beats it.
func _draw_counter_hint(top: Vector2, type: String, ref_type: String) -> void:
	var c := top + Vector2(FLAG.x * 0.5, -12.0)
	if Troops.COUNTERED_BY[type] == ref_type:
		_c.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -9), c + Vector2(9, 6), c + Vector2(-9, 6)]), Style.MORALE_HIGH)
	elif Troops.COUNTERED_BY[ref_type] == type:
		_c.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 7), c + Vector2(9, -8), c + Vector2(-9, -8)]), Style.MORALE_LOW)


## A team's flag on `ci`: a swallowtail for you, square for them, with a glyph for the
## troop type.
## A squad's standard waving in the wind, as Heraldry.flag draws it with a wave of
## `_clock * 5 + id * 1.3`, but built once per look as one triangle list and waved by the
## top layer's FLAG_SHADER: one draw a flag.
func _draw_waving_flag(at: Vector2, sq, lit: bool, lean: float, edge: Color) -> void:
	var mine: bool = sq.team == Sim.PLAYER
	var grey: bool = sq.routing
	var key := "%d/%s/%d/%d/%s" % [sq.id, sq.type, int(grey), int(lit), edge.to_html()]
	var mesh: Dictionary = _flag_geo.get(key, {})
	if mesh.is_empty():
		var cloth := Style.PLAYER if mine else Style.ENEMY
		var dark := Style.PLAYER_DARK if mine else Style.ENEMY_DARK
		if grey:
			cloth = cloth.lerp(Color(0.45, 0.45, 0.45), 0.6)
			dark = dark.lerp(Color(0.2, 0.2, 0.2), 0.6)
		mesh = Heraldry.cloth_mesh(FLAG, mine, 3.0 if lit else 2.0, sq.id * 1.3, cloth, dark, edge, sq.type,
			Style.TEXT if not grey else Color(0.85, 0.85, 0.85))
		_flag_geo[key] = mesh
	_c.draw_set_transform(at, lean, Vector2.ONE)
	RenderingServer.canvas_item_add_triangle_array(_c.get_canvas_item(), mesh["indices"], mesh["points"], mesh["colors"], mesh["uvs"])
	_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_flag(ci: CanvasItem, at: Vector2, size: Vector2, team: int, type: String, grey: bool, lit: bool, lean: float, edge: Color = Heraldry.EDGE, wave: float = -1.0) -> void:
	var mine := team == Sim.PLAYER
	Heraldry.flag(ci, at, size, Style.PLAYER if mine else Style.ENEMY, Style.PLAYER_DARK if mine else Style.ENEMY_DARK,
		mine, type, grey, lit, lean, edge, wave)


func _draw_floaters() -> void:
	var still := Sound.reduced_motion
	var fs := _fs(Style.SMALL)
	for f in floaters:
		var age: float = f["age"]
		var a := clampf((float(f["life"]) - age) / 0.3, 0.0, 1.0) * clampf(age / 0.08, 0.0, 1.0)
		var color: Color = f["color"]
		var sq = f["sq"]
		if sq == null:
			# A word at a spot: rises and fades.
			var pos: Vector2 = _to_screen(f["pos"]) + Vector2(-200.0, -minf(age, 1.3) * 34.0 * field_scale)
			_c.draw_string_outline(font, pos, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 400.0, _fs(Style.BODY), 6, Color(0, 0, 0, a))
			_c.draw_string(font, pos, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 400.0, _fs(Style.BODY), Color(color, a))
			continue
		# A squad's word: a pill over its standard, led by its icon, sliding up into place.
		# Zoomed out the word goes and the icon stands alone.
		var anchor: Vector2 = Vector2(_std_tops[sq]) + Vector2(FLAG.x * 0.5, -24.0) if _std_tops.has(sq) else _to_screen(sq.average_pos()) + Vector2(0, -44.0)
		var slide := 0.0 if still else 12.0 * (1.0 - _ease_out(age / 0.15))
		var key := String(f.get("icon", ""))
		var tex: Texture2D = Widgets.icon(key) if key != "" else null
		var text := String(f["text"])
		if tex != null and cam_zoom < CALLOUT_WORDS_ZOOM:
			text = ""
		var h := float(fs) + 12.0
		var lead := h if tex != null else 22.0
		var w := lead + (font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 14.0 if text != "" else 0.0)
		var box := Rect2(anchor + Vector2(-w * 0.5, -h * 0.5 + slide), Vector2(w, h))
		box.position.x = clampf(box.position.x, _view.position.x + 4.0, maxf(_view.position.x + 4.0, _view.end.x - w - 4.0))
		_c.draw_style_box(_chip_box(Color(Style.NIGHT, 0.88 * a), Color(color, 0.55 * a)), box)
		if tex != null:
			_c.draw_texture_rect(tex, Rect2(box.position + Vector2(6.0, 6.0), Vector2(h - 12.0, h - 12.0)), false, Color(color, a))
		else:
			_c.draw_circle(box.position + Vector2(13.0, h * 0.5), 4.0, Color(color, a))
		if text != "":
			_c.draw_string(font, box.position + Vector2(lead, h * 0.5 + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(color, a))


## The one chip shape on the battle screen: a pill with the kit's radius, on any ground.
func _chip_box(bg: Color, edge: Color, width: int = 1) -> StyleBoxFlat:
	var b := Style.box(bg, edge, width, 40)
	b.content_margin_left = 14.0
	b.content_margin_right = 16.0
	b.content_margin_top = 6.0
	b.content_margin_bottom = 6.0
	return b


## A text size for the field, through the Text size setting like every label.
func _fs(base: int) -> int:
	return Style.text_size(base)


## The story so far, along the top of the field, in the same pill as every chip.
func _draw_ticker() -> void:
	var fs := _fs(Style.SMALL)
	var y := _view.position.y + 30.0 + (58.0 if objective_chip != null and objective_chip.visible else 0.0)
	if inspect_pill != null and inspect_pill.visible:
		y += inspect_pill.size.y + 8.0
	for t in ticker:
		var age: float = t["age"]
		var a := clampf(float(t["life"]) - age, 0.0, 1.0) * clampf(age / 0.2, 0.0, 1.0)
		var color: Color = t["color"]
		# a dark pill behind each line, so it reads over grass and sand alike
		var icon := Widgets.icon(String(t.get("icon", ""))) if String(t.get("icon", "")) != "" else null
		var lead := 34.0 if icon != null else 0.0
		var w := minf(font.get_string_size(t["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 28.0 + lead, _view.size.x - 16.0)
		var pill := Rect2(Vector2(_view.get_center().x - w * 0.5, y - fs - 2.0), Vector2(w, fs + 14.0))
		_c.draw_style_box(_chip_box(Color(Style.NIGHT, 0.82 * a), Color(Style.BRASS, 0.4 * a)), pill)
		if icon != null:
			var dot := Vector2(pill.position.x + 20.0, pill.get_center().y)
			_c.draw_circle(dot, 14.0, Color(Color("5a4a1a"), a))
			_c.draw_texture_rect(icon, Rect2(dot - Vector2(10, 10), Vector2(20, 20)), false, Color(Color("ffe08a"), a))
		var tx := _view.position.x + 12.0 + lead * 0.5
		_c.draw_string_outline(font, Vector2(tx, y), t["text"], HORIZONTAL_ALIGNMENT_CENTER, _view.size.x - 24.0, fs, 6, Color(0, 0, 0, 0.85 * a))
		_c.draw_string(font, Vector2(tx, y), t["text"], HORIZONTAL_ALIGNMENT_CENTER, _view.size.x - 24.0, fs, Color(color, a))
		y += fs + 18.0


# ---------------------------------------------------------------- siege marks

## Each blow of the ram on the gate: a flash and the damage, every so often.
func _watch_gate(delta: float) -> void:
	if sim.objective != Sim.OBJECTIVE_SIEGE:
		return
	if _gate_seen < 0.0:
		_gate_seen = sim.gate_hp
	if sim.gate_hp < _gate_seen:
		_gate_dmg += _gate_seen - sim.gate_hp
	_gate_seen = sim.gate_hp
	_gate_pop -= delta
	_gate_flash = maxf(0.0, _gate_flash - delta * 4.0)
	if _gate_dmg >= 1.0 and _gate_pop <= 0.0 and sim.gate_hp > 0.0:
		var out := 1.0 if sim.siege_defender == Sim.ENEMY else -1.0
		_float_text("-%d" % int(_gate_dmg), sim.gate_center + Vector2(46, out * 26.0), Color("fff3c0"), 0.9)
		_burst(sim.gate_center + Vector2(0, out * 18.0), "dust", Color("e9d3a0"), 0.5)
		_gate_dmg = 0.0
		_gate_pop = 0.9
		_gate_flash = 1.0


## A word on the field in a pill, the same size on screen however far the camera zooms.
func _field_label(text: String, at: Vector2, fg: Color, bg: Color, edge: Color) -> void:
	var k := 1.0 / maxf(0.1, field_scale)
	var fs := int(float(_fs(Style.SMALL)) * k)
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pad := 9.0 * k
	var r := Rect2(at - Vector2(ts.x * 0.5 + pad, (ts.y + pad) * 0.5), Vector2(ts.x + pad * 2.0, ts.y + pad))
	r.position.x = clampf(r.position.x, 4.0, Sim.ARENA.x - r.size.x - 4.0)
	_c.draw_style_box(Style.box(bg, edge, maxi(1, int(1.5 * k)), int(r.size.y * 0.5)), r)
	_c.draw_string(font, Vector2(r.position.x + pad, r.position.y + pad * 0.5 + font.get_ascent(fs)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)


## Planning an assault: where the garrison's bows on the wall can reach (red), the cover
## under the ram's roof (blue), and the two ladders.
func _draw_siege_reach() -> void:
	if not _deploying() or sim.siege_defender != Sim.ENEMY:
		return
	var w: float = Sim.ARENA.x
	var outside: float = sim.wall_y + Terrain.CELL * 0.5
	var below := PackedVector2Array([Vector2(0, outside), Vector2(w, outside), Vector2(w, Sim.ARENA.y), Vector2(0, Sim.ARENA.y)])
	var zone: Array = []
	var deepest := outside
	var label_x := w * 0.75
	for sq in sim.squads:
		if sq.team != Sim.ENEMY or not sq.ranged or not sq.is_active():
			continue
		var circle := PackedVector2Array()
		for i in 64:
			circle.append(sq.center + Vector2.from_angle(TAU * i / 64.0) * sq.reach)
		for piece in Geometry2D.intersect_polygons(circle, below):
			zone = _merge_zone(zone, piece)
		if sq.center.y + sq.reach > deepest:
			deepest = sq.center.y + sq.reach
			label_x = sq.center.x
	var red := Color(0.86, 0.29, 0.23)
	for poly in zone:
		if Geometry2D.is_polygon_clockwise(poly):
			continue
		_c.draw_colored_polygon(poly, Color(red, 0.16))
		var k := -Sim.ARENA.y
		while k < w:
			for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([Vector2(k, outside), Vector2(k + Sim.ARENA.y, outside + Sim.ARENA.y)]), poly):
				_c.draw_polyline(seg, Color(red, 0.32), 3.0)
			k += 20.0
		for i in poly.size():
			var a2: Vector2 = poly[i]
			var b2: Vector2 = poly[(i + 1) % poly.size()]
			if absf(a2.y - outside) < 1.0 and absf(b2.y - outside) < 1.0:
				continue
			_c.draw_dashed_line(a2, b2, Color("ff8a6a"), 2.5, 10.0)
	if not zone.is_empty():
		_field_label("Wall bows reach here", Vector2(label_x, minf(deepest + 20.0, Sim.ARENA.y - 20.0)), Color("ffb3a0"), Color(Style.NIGHT, 0.9), Color("a14a3c"))
	# The ram's roof.
	var roof := PackedVector2Array()
	for i in 48:
		roof.append(sim.gate_center + Vector2.from_angle(TAU * i / 48.0) * (Sim.GATE_REACH + 14.0))
	for piece in Geometry2D.intersect_polygons(roof, below):
		_c.draw_colored_polygon(piece, Color(0.31, 0.55, 1.0, 0.28))
		_c.draw_polyline(piece + PackedVector2Array([piece[0]]), Color("8fb8ff"), 2.0)
	_field_label("Ram roof: arrows 40%", sim.gate_center + Vector2(0, Sim.GATE_REACH + 34.0), Color("bcd4ff"), Color(Style.NIGHT, 0.9), Color("5a7fc0"))
	for lp in sim.ladder_points():
		var mid: Vector2 = lp + Vector2(0, Terrain.CELL * 0.5 + 14.0)
		_c.draw_arc(mid, 26.0, 0.0, TAU, 32, Color("ffe08a"), 2.5)
		_field_label("Ladder", mid + Vector2(0, 46.0), Color("ffe08a"), Color(Style.NIGHT, 0.9), Color("8a7a3a"))


## Holding the walls yourself, before the fight and while the gate holds: where the
## garrison's posts are. The gate tower (stones on the ram), the ladder heads, and the
## crescent behind the gate where the breach is met.
func _draw_garrison_posts() -> void:
	if sim.siege_defender != Sim.PLAYER or sim.winner != -1:
		return
	var show_all := _deploying()
	if not show_all and (selected_squad != null or sim.gate_hp <= 0.0):
		return
	var a := 1.0 if show_all else 0.45
	var tower := Vector2(sim.gate_center.x, sim.wall_y + sim.inward() * Sim.WALK_DEPTH)
	var stone := Color("e2e0dc")
	_c.draw_rect(Rect2(tower - Vector2(Sim.GATE_TOWER_HALF, 34.0), Vector2(Sim.GATE_TOWER_HALF * 2.0, 68.0)), Color(stone, 0.10 * a))
	_c.draw_rect(Rect2(tower - Vector2(Sim.GATE_TOWER_HALF, 34.0), Vector2(Sim.GATE_TOWER_HALF * 2.0, 68.0)), Color(stone, 0.6 * a), false, 2.0)
	var gold := Color("b8f5b0")
	for i in sim.ladder_points().size():
		var head: Vector2 = sim.ladder_head_post(i)
		_c.draw_arc(head, 30.0, 0.0, TAU, 32, Color(gold, 0.8 * a), 2.5)
	var red := Color("ff8a6a")
	var posts: Array = sim.breach_posts(3)
	var arc := PackedVector2Array()
	for k in 25:
		var ang := deg_to_rad(lerpf(-Sim.BREACH_SPREAD - 15.0, Sim.BREACH_SPREAD + 15.0, k / 24.0))
		arc.append(sim.gate_center + Vector2(sin(ang) * Sim.BREACH_RADIUS, cos(ang) * Sim.BREACH_RADIUS * sim.inward()))
	for k in range(0, arc.size() - 1, 2):
		_c.draw_line(arc[k], arc[k + 1], Color(red, 0.85 * a), 3.0)
	if not show_all:
		return
	_field_label("Gate tower · stones on the ram", Vector2(tower.x, sim.wall_y - sim.inward() * 44.0), stone, Color(Style.NIGHT, 0.9), Color("6a6a72"))
	for i in sim.ladder_points().size():
		_field_label("Ladder head", sim.ladder_head_post(i) + Vector2(0, sim.inward() * 44.0), gold, Color(Style.NIGHT, 0.9), Color("3c7a40"))
	_field_label("Hold the breach here", posts[0] + Vector2(0, sim.inward() * 72.0), Color("ffc0b0"), Color(Style.NIGHT, 0.9), Color("a14a3c"))


## Adds `piece` to a set of outlines, merging it with any it overlaps.
func _merge_zone(zone: Array, piece: PackedVector2Array) -> Array:
	var merged := piece
	var kept: Array = []
	for poly in zone:
		var m := Geometry2D.merge_polygons(poly, merged)
		var outer: Array = m.filter(func(q): return not Geometry2D.is_polygon_clockwise(q))
		if outer.size() == 1:
			merged = outer[0]
			for q in m:
				if Geometry2D.is_polygon_clockwise(q):
					kept.append(q)
		else:
			kept.append(poly)
	kept.append(merged)
	return kept


## The storm plan on the field: a dashed route from each company to its ladder or the ram.
func _draw_storm_plan() -> void:
	if _storm_plan.is_empty():
		return
	var foot: float = sim.wall_y + Terrain.CELL * 0.5 + 30.0
	var groups := {}
	for sq in sim.squads:
		if sq.team != Sim.PLAYER or not sq.is_active() or not _storm_plan.has(sq.id):
			continue
		var job: String = _storm_plan[sq.id]
		if job == "bows":
			continue
		var dest := Vector2(sim.gate_center.x, foot)
		var key := "ram"
		if job == "ladder":
			var best := INF
			for lp in sim.ladder_points():
				if absf(lp.x - sq.center.x) < best:
					best = absf(lp.x - sq.center.x)
					dest = Vector2(lp.x, foot)
					key = "ladder%d" % int(lp.x)
		var col := Color("ffe08a") if job == "ladder" else Color("ffc06a")
		var from: Vector2 = sq.center + (dest - sq.center).normalized() * 30.0
		_c.draw_dashed_line(from, dest, Color(0, 0, 0, 0.45), 7.0, 16.0)
		_c.draw_dashed_line(from, dest, col, 4.0, 16.0)
		var dir := (dest - from).normalized()
		_c.draw_colored_polygon(PackedVector2Array([dest + dir * 10.0, dest - dir * 10.0 + dir.orthogonal() * 9.0, dest - dir * 10.0 - dir.orthogonal() * 9.0]), col)
		if not groups.has(key):
			groups[key] = {"at": dest, "names": PackedStringArray(), "job": job}
		groups[key]["names"].append(_captain_first(sq))
	for key in groups:
		var g: Dictionary = groups[key]
		var names: PackedStringArray = g["names"]
		var at: Vector2 = Vector2(g["at"].x, g["at"].y + 30.0)
		if g["job"] == "ladder":
			_field_label("%s · ladder" % _and_list(names), at, Color("ffe08a"), Color("5a4a1a"), Color("ffe08a"))
		else:
			var who := names[0] if names.size() == 1 else "%d companies" % names.size()
			_field_label("%s · ram" % who, at, Color("ffd79a"), Color("5a3b1d"), Color("ffc06a"))


## The gate's own bar over the gatehouse, on the courtyard side, and a flash on each blow.
func _draw_gate_marker() -> void:
	if _deploying() or sim.gate_hp <= 0.0 or sim.winner != -1 or not _storm_plan.is_empty():
		return
	var cell := Terrain.CELL
	var top: float = sim.wall_row * cell
	var gate := Rect2(Sim.GATE_COLS[0] * cell, top, cell * Sim.GATE_COLS.size(), cell)
	if _gate_flash > 0.0 and not Style.motion_reduced():
		_c.draw_rect(gate.grow(3.0), Color(1.0, 0.95, 0.7, 0.55 * _gate_flash))
	var k := 1.0 / maxf(0.1, field_scale)
	var size := Vector2(128.0, 30.0) * k
	var inward := -1.0 if sim.siege_defender == Sim.ENEMY else 1.0
	var cy: float = (top - 26.0 - size.y * 0.5) if inward < 0.0 else (top + cell + 26.0 + size.y * 0.5)
	var r := Rect2(Vector2(gate.get_center().x - size.x * 0.5, cy - size.y * 0.5), size)
	_c.draw_style_box(Style.box(Color(Style.NIGHT, 0.92), Color("6d5222"), maxi(1, int(2.0 * k)), int(9.0 * k)), r)
	var tex := Widgets.icon("gate")
	if tex != null:
		_c.draw_texture_rect(tex, Rect2(r.position + Vector2(7, 5) * k, Vector2(20, 20) * k), false, Color("f3cf7a"))
	var share: float = sim.gate_hp / maxf(1.0, sim.gate_max)
	var track := Rect2(r.position + Vector2(34, 11) * k, Vector2(r.size.x - 44.0 * k, 9.0 * k))
	_c.draw_rect(track, Color("0b0f19"))
	_c.draw_rect(Rect2(track.position, Vector2(track.size.x * share, track.size.y)), Color(0.94, 0.63, 0.24).lerp(Style.ENEMY, 1.0 - share))


## The breach: a band across the field with the news in big letters, for a moment.
func _draw_banner() -> void:
	if _banner.is_empty() or not _roll.is_empty():
		return
	var age := float(_banner["age"])
	var life := float(_banner["life"])
	var a := clampf(minf(age / 0.08, (life - age) / 0.4), 0.0, 1.0)
	# It stamps down onto the field.
	var stamp := 1.0 if Sound.reduced_motion else lerpf(STAMP_SCALE, 1.0, _ease_out(age / STAMP_TIME))
	var vs := get_viewport_rect().size
	var col: Color = _banner["color"]
	var big: Font = Style.display_font()
	if big == null:
		big = font
	var title := String(_banner["title"]).to_upper()
	var icon_key := String(_banner.get("icon", ""))
	var tex := Widgets.icon(icon_key) if icon_key != "" else null
	if bool(_banner.get("big", false)):
		var cy := _view.get_center().y - 60.0
		var band := Rect2(0, cy - 86.0, vs.x, 172.0)
		_c.draw_rect(band, Color(Style.NIGHT, 0.86 * a))
		_c.draw_rect(Rect2(vs.x * 0.2, band.position.y + 4.0, vs.x * 0.6, 2.0), Color(Style.BRASS, 0.7 * a))
		_c.draw_rect(Rect2(vs.x * 0.2, band.end.y - 6.0, vs.x * 0.6, 2.0), Color(Style.BRASS, 0.7 * a))
		_c.draw_set_transform(Vector2(vs.x * 0.5, cy), 0.0, Vector2(stamp, stamp))
		if tex != null:
			_c.draw_texture_rect(tex, Rect2(Vector2(-22.0, -74.0), Vector2(44, 44)), false, Color(col, a))
		var fs := 52
		while fs > 30 and big.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > vs.x - 40.0:
			fs -= 2
		_c.draw_string_outline(big, Vector2(-vs.x * 0.5, 26.0), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, fs, 8, Color(0, 0, 0, 0.9 * a))
		_c.draw_string(big, Vector2(-vs.x * 0.5, 26.0), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, fs, Color(col, a))
		_c.draw_string(font, Vector2(-vs.x * 0.5, 68.0), String(_banner["sub"]), HORIZONTAL_ALIGNMENT_CENTER, vs.x, _fs(Style.BODY), Color(Style.TEXT, a))
		_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# A plate a quarter of the way down the field.
	var fs2 := 30
	var room := minf(vs.x - 32.0, 560.0)
	while fs2 > Style.SMALL and big.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x > room - (72.0 if tex != null else 32.0):
		fs2 -= 2
	var tw := big.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
	var w := minf(room, tw + (88.0 if tex != null else 48.0))
	var h := 88.0
	var center := Vector2(vs.x * 0.5, _view.position.y + _view.size.y * 0.24)
	_c.draw_set_transform(center, 0.0, Vector2(stamp, stamp))
	var plate := Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Style.NIGHT, 0.9 * a)
	box.border_color = Color(Style.BRASS, 0.9 * a)
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.shadow_color = Color(0, 0, 0, 0.45 * a)
	box.shadow_size = 10
	_c.draw_style_box(box, plate)
	var tx := plate.position.x + 24.0
	if tex != null:
		_c.draw_circle(Vector2(tx + 14.0, -10.0), 17.0, Color(Color("5a4a1a"), a))
		_c.draw_texture_rect(tex, Rect2(Vector2(tx + 2.0, -22.0), Vector2(24, 24)), false, Color(Color("ffe08a"), a))
		tx += 40.0
	_c.draw_string(big, Vector2(tx, -10.0 + fs2 * 0.36), title, HORIZONTAL_ALIGNMENT_LEFT, plate.end.x - tx - 16.0, fs2, Color(col, a))
	_c.draw_string(font, Vector2(plate.position.x, 30.0), String(_banner["sub"]), HORIZONTAL_ALIGNMENT_CENTER, w, _fs(Style.SMALL), Color(Style.MUTED, a))
	_c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
