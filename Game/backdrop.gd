extends Node
## Room backdrop: a six-layer parallax sky plus a weather layer, chosen by the
## room's kind. One instance lives in Run.tscn and is reused for every room, so
## a transition never rebuilds textures.
##
## Everything is drawn in screen space (CanvasLayer) on purpose: the camera is
## zoomed 2x and moves inside an 864-wide room, and screen-space layers always
## cover the viewport no matter where the camera sits.
##
##   Scenery (layer -1, behind the world) : sky colour + parallax sprites
##   Weather (layer 5, in front of world) : rain / snow / leaves + lightning

## Back to front. The pack's layer 5 is the sky gradient (it is fully opaque),
## layer 1 is the nearest treeline, and the castle is a separate far silhouette.
## Small on purpose: the backdrop must not slide under the player. With these
## values the furthest layer travels ~90px across a whole room, and the painted
## sky layer never moves at all.
const LAYER_FACTORS := [0.0, 0.008, 0.02, 0.035, 0.055, 0.08]
const LAYER_DARKEN := [0.0, 0.03, 0.08, 0.14, 0.21, 0.29]
const COVER_SCALE := 1.58         # oversized so the edges never run out
const CAMERA_CENTER_X := 432.0    # rooms are 864 wide
const CAMERA_FLOOR_Y := 620.0
const FLOOR_WORLD_Y := 640.0

const SETS := {
	"normal": [
		"res://Assets/Scene/Backgrounds/Normal BG/GandalfHardcore Background layers_layer 5.png",
		"res://Assets/Scene/Backgrounds/Normal BG/Background Castle .png",
		"res://Assets/Scene/Backgrounds/Normal BG/GandalfHardcore Background layers_layer 4.png",
		"res://Assets/Scene/Backgrounds/Normal BG/GandalfHardcore Background layers_layer 3.png",
		"res://Assets/Scene/Backgrounds/Normal BG/GandalfHardcore Background layers_layer 2.png",
		"res://Assets/Scene/Backgrounds/Normal BG/GandalfHardcore Background layers_layer 1.png",
	],
	"autumn": [
		"res://Assets/Scene/Backgrounds/Autumn BG/GandalfHardcore Background layers_layer 5.png",
		"res://Assets/Scene/Backgrounds/Autumn BG/Background Castle Autumn.png",
		"res://Assets/Scene/Backgrounds/Autumn BG/GandalfHardcore Background layers_layer 4.png",
		"res://Assets/Scene/Backgrounds/Autumn BG/GandalfHardcore Background layers_layer 3.png",
		"res://Assets/Scene/Backgrounds/Autumn BG/GandalfHardcore Background layers_layer 2.png",
		"res://Assets/Scene/Backgrounds/Autumn BG/GandalfHardcore Background layers_layer 1.png",
	],
	"winter": [
		"res://Assets/Scene/Backgrounds/Winter BG/GandalfHardcore Background layers_layer 5.png",
		"res://Assets/Scene/Backgrounds/Winter BG/Background Castle  Winter.png",
		"res://Assets/Scene/Backgrounds/Winter BG/GandalfHardcore Background layers_layer 4.png",
		"res://Assets/Scene/Backgrounds/Winter BG/GandalfHardcore Background layers_layer 3.png",
		"res://Assets/Scene/Backgrounds/Winter BG/GandalfHardcore Background layers_layer 2.png",
		"res://Assets/Scene/Backgrounds/Winter BG/GandalfHardcore Background layers_layer 1.png",
	],
}

## kind -> palette + weather. Colours are the whole tone of a room type.
const PRESETS := {
	"combat": {
		"set": "normal", "sky": Color(0.03, 0.035, 0.03), "ground": Color(0.055, 0.065, 0.05),
		"tint": Color(0.30, 0.35, 0.29), "weather": "rain", "lightning": false,
	},
	"puzzle": {
		"set": "winter", "sky": Color(0.035, 0.045, 0.06), "ground": Color(0.06, 0.07, 0.09),
		"tint": Color(0.26, 0.30, 0.36), "weather": "snow", "lightning": false,
	},
	"shop": {
		"set": "autumn", "sky": Color(0.52, 0.53, 0.42), "ground": Color(0.28, 0.24, 0.17),
		"tint": Color(0.80, 0.79, 0.72), "weather": "leaves", "lightning": false,
	},
	"boss": {
		"set": "normal", "sky": Color(0.05, 0.024, 0.075), "ground": Color(0.09, 0.055, 0.115),
		"tint": Color(0.42, 0.27, 0.57), "weather": "storm", "lightning": true,
	},
	"lobby": {
		"set": "autumn", "sky": Color(0.075, 0.073, 0.042), "ground": Color(0.17, 0.135, 0.085),
		"tint": Color(0.46, 0.44, 0.28), "weather": "leaves", "lightning": false,
	},
}

@onready var _sky: ColorRect = $Scenery/Root/Sky
@onready var _ground: Sprite2D = $Scenery/Root/GroundFill
@onready var _layers: Node2D = $Scenery/Root/Layers
@onready var _rain: CPUParticles2D = $Weather/Root/Rain
@onready var _snow: CPUParticles2D = $Weather/Root/Snow
@onready var _leaves: CPUParticles2D = $Weather/Root/Leaves
@onready var _flash: ColorRect = $Weather/Root/Flash

var _sprites: Array[Sprite2D] = []
var _kind := ""
var _pending := ""   # setup() can arrive before _ready; apply it there
var _lightning := false
var _next_flash := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_build_layers()
	_apply_weather("")
	if _pending != "":
		var kind := _pending
		_pending = ""
		setup(kind)


func _build_layers() -> void:
	for path in SETS["normal"]:
		var sprite := Sprite2D.new()
		sprite.centered = true
		_layers.add_child(sprite)
		_sprites.append(sprite)


## Re-point the backdrop at a room kind. Safe to call repeatedly.
func setup(kind: String) -> void:
	if not is_node_ready():
		_pending = kind
		return
	if kind == _kind:
		return
	var preset: Dictionary = PRESETS.get(kind, PRESETS["lobby"])
	_kind = kind

	_sky.color = preset["sky"]
	_ground.modulate = preset["ground"]
	_lightning = preset["lightning"]

	var paths: Array = SETS[preset["set"]]
	var tint: Color = preset["tint"]
	for i in _sprites.size():
		var sprite := _sprites[i]
		sprite.texture = load(paths[i])
		var darken: float = LAYER_DARKEN[i]
		sprite.modulate = Color(
			tint.r * (1.0 - darken),
			tint.g * (1.0 - darken),
			tint.b * (1.0 - darken),
			1.0)
		sprite.scale = Vector2(COVER_SCALE, COVER_SCALE)
		sprite.z_index = i

	# The back layer is a painted sky gradient. Sampling its top row means the
	# flat colour above the art continues it without a seam.
	_sky.color = _sample_top(_sprites[0])

	_apply_weather(preset["weather"])
	_next_flash = _rng.randf_range(2.0, 6.0)


## Colour of the top-centre pixel of a sprite's texture, already tinted.
func _sample_top(sprite: Sprite2D) -> Color:
	if sprite.texture == null:
		return Color.BLACK
	var image: Image = sprite.texture.get_image()
	if image == null or image.is_empty():
		return Color.BLACK
	var top: Color = image.get_pixel(image.get_width() / 2, 0)
	var m: Color = sprite.modulate
	return Color(top.r * m.r, top.g * m.g, top.b * m.b, 1.0)


func _apply_weather(kind: String) -> void:
	# Set the emission volume here rather than trusting the scene file: a box
	# that silently stays a point turns a rainstorm into a single column.
	for emitter in [_rain, _snow, _leaves]:
		emitter.emission_shape = 3   # EMISSION_SHAPE_BOX
	_rain.emission_rect_extents = Vector2(800, 40)
	_snow.emission_rect_extents = Vector2(640, 340)
	_leaves.emission_rect_extents = Vector2(660, 330)

	var storm := kind == "storm"
	_rain.emitting = kind == "rain" or storm
	_snow.emitting = kind == "snow"
	_leaves.emitting = kind == "leaves"
	_rain.amount = 320 if storm else 200
	_flash.color = Color(0.92, 0.9, 1.0, 0.0)


func _process(delta: float) -> void:
	_update_parallax()

	if _lightning and _sprites.size() > 0:
		_next_flash -= delta
		if _next_flash <= 0.0:
			_next_flash = _rng.randf_range(3.5, 9.0)
			_strike()


func _update_parallax() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var view := get_viewport().get_visible_rect().size
	# The screen centre, not the node position: this is the camera after its
	# limits clamp, so a clamped camera leaves the backdrop perfectly still.
	var centre := camera.get_screen_center_position()
	var zoom := camera.zoom.y
	# Sit the art on the bottom edge so the sky above it stays open.
	var frame_height := 346.0 * COVER_SCALE
	var base := Vector2(view.x * 0.5, view.y + 132.0 - frame_height * 0.5)
	var dx := (centre.x - CAMERA_CENTER_X) * zoom
	var dy := (centre.y - FLOOR_WORLD_Y) * zoom

	for i in _sprites.size():
		var factor: float = LAYER_FACTORS[i]
		_sprites[i].position = base + Vector2(-dx * factor, -dy * factor * 0.5)

	# Solid ground from the floor line down, so no room shows a void under it.
	var floor_y := (FLOOR_WORLD_Y - centre.y) * zoom + view.y * 0.5
	_ground.position = Vector2(0.0, floor_y)
	_ground.scale = Vector2(view.x, maxf(0.0, view.y - floor_y))


## Double-flicker so it reads as lightning rather than a fade.
func _strike() -> void:
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.42, 0.05)
	tween.tween_property(_flash, "color:a", 0.05, 0.09)
	tween.tween_property(_flash, "color:a", 0.30, 0.05)
	tween.tween_property(_flash, "color:a", 0.0, 0.28)
