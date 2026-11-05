extends CanvasLayer
## In-run HUD: health, level/xp, resources, room banner, control hints and the
## rewind charge gauge.
##
## The HUD owns no state. It renders Global/run_state.gd (health, resources,
## progression) and mirrors one live value off the player (the rewind cooldown).
## Game/scene_manager.gd calls show_room() on every transition.

const PAUSE_SCENE := preload("res://UI/PauseMenu.tscn")
const GAME_OVER_SCENE := preload("res://UI/GameOver.tscn")

const GAUGE_SEGMENTS := 10
const HINTS_LINGER := 9.0

const GAUGE_FULL := Color(0.81, 0.78, 0.72, 1)
const GAUGE_EMPTY := Color(0.16, 0.1, 0.11, 1)

## Same mapping Game/portal.gd uses, so a room's banner always matches the
## colour of the portal that led into it.
const ROOM_COLORS := {
	"combat": Color(0.92, 0.22, 0.22),
	"puzzle": Color(0.96, 0.85, 0.20),
	"shop": Color(0.22, 0.90, 0.35),
	"boss": Color(0.66, 0.28, 0.96),
}

@export var heart_full: Texture2D
@export var heart_empty: Texture2D

@onready var _hearts: Array[TextureRect] = [%Heart0, %Heart1, %Heart2, %Heart3, %Heart4]
@onready var _level_label: Label = %LevelLabel
@onready var _xp_bar: ProgressBar = %XPBar
@onready var _coin_value: Label = %CoinValue
@onready var _gem_value: Label = %GemValue
@onready var _shard_value: Label = %ShardValue
@onready var _room_card: Control = %RoomCard
@onready var _room_name: Label = %RoomName
@onready var _room_type: Label = %RoomType
@onready var _room_dot: ColorRect = %RoomDot
@onready var _gauge_row: HBoxContainer = %GaugeRow
@onready var _rewind_state: Label = %RewindState
@onready var _hints: Control = %Hints
@onready var _pause_button: Button = %PauseButton

var _ramp: Array[ColorRect] = []
var _room_tween: Tween = null
var _pause_menu: Node = null
var _game_over: Node = null


func _ready() -> void:
	_build_gauge()

	RunState.health_changed.connect(_on_health_changed)
	RunState.resources_changed.connect(_on_resources_changed)
	RunState.progress_changed.connect(_on_progress_changed)
	RunState.run_ended.connect(_on_run_ended)

	_pause_button.pressed.connect(open_pause)

	_on_health_changed(RunState.hp, RunState.max_hp)
	_on_resources_changed()
	_on_progress_changed(RunState.level, RunState.xp, RunState.xp_required)

	_room_card.modulate.a = 0.0
	_fade_hints()


func _process(_delta: float) -> void:
	_update_rewind()


# ---------------------------------------------------------------------------
# Rewind gauge — the only live value pulled straight off the player
# ---------------------------------------------------------------------------

func _build_gauge() -> void:
	for i in GAUGE_SEGMENTS:
		var segment := ColorRect.new()
		segment.custom_minimum_size = Vector2(16, 26)
		segment.color = GAUGE_EMPTY
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gauge_row.add_child(segment)
		_ramp.append(segment)


func _update_rewind() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var charge := 0.0
	var readout := "--"

	if player != null:
		if player.get("Shadow") != null:
			charge = 1.0
			readout = "READY"
		else:
			var remaining := float(player.get("rewind_cooldown"))
			var total: float = maxf(float(Cooldown.rewind_cooldown), 0.001)
			charge = 1.0 - clampf(remaining / total, 0.0, 1.0)
			readout = "%.1fs" % maxf(remaining, 0.0)

	var filled := int(ceil(charge * GAUGE_SEGMENTS))
	for i in _ramp.size():
		_ramp[i].color = GAUGE_FULL if i < filled else GAUGE_EMPTY

	_rewind_state.text = readout
	_rewind_state.add_theme_color_override(
			"font_color", GAUGE_FULL if readout == "READY" else Color(0.61, 0.58, 0.54))


# ---------------------------------------------------------------------------
# Room banner
# ---------------------------------------------------------------------------

## Called by Game/scene_manager.gd each time a room becomes current.
func show_room(_display_name: String, room_type: String, index: int) -> void:
	_room_name.text = room_type.to_upper()
	_room_type.text = "ROOM %02d" % (index + 1)
	_room_dot.color = ROOM_COLORS.get(room_type, Color(0.8, 0.8, 0.8))

	if _room_tween != null and _room_tween.is_valid():
		_room_tween.kill()
	_room_card.modulate.a = 0.0
	_room_tween = create_tween()
	_room_tween.tween_property(_room_card, "modulate:a", 1.0, 0.25)
	_room_tween.tween_interval(2.4)
	_room_tween.tween_property(_room_card, "modulate:a", 0.0, 0.6)


func _fade_hints() -> void:
	var tween := create_tween()
	tween.tween_interval(HINTS_LINGER)
	tween.tween_property(_hints, "modulate:a", 0.0, 1.2)


# ---------------------------------------------------------------------------
# RunState bindings
# ---------------------------------------------------------------------------

func _on_health_changed(hp: int, max_hp: int) -> void:
	for i in _hearts.size():
		var heart := _hearts[i]
		heart.visible = i < max_hp
		if heart.visible:
			heart.texture = heart_full if i < hp else heart_empty


func _on_resources_changed() -> void:
	_coin_value.text = str(RunState.coins)
	_gem_value.text = str(RunState.gems)
	_shard_value.text = str(RunState.shards)


func _on_progress_changed(level: int, xp: int, xp_required: int) -> void:
	_level_label.text = "LV %d" % level
	_xp_bar.max_value = maxi(xp_required, 1)
	_xp_bar.value = xp


# ---------------------------------------------------------------------------
# Pause / death
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Pause") or event.is_action_pressed("ui_cancel"):
		open_pause()
		get_viewport().set_input_as_handled()


func open_pause() -> void:
	if _pause_menu != null or _game_over != null:
		return
	if not RunState.is_run_active:
		return
	_pause_menu = PAUSE_SCENE.instantiate()
	add_child(_pause_menu)
	_pause_menu.tree_exited.connect(_on_pause_closed)
	get_tree().paused = true


func _on_pause_closed() -> void:
	_pause_menu = null


func _on_run_ended() -> void:
	if _game_over != null:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		player.set_physics_process(false)
		player.set_process_input(false)

	await get_tree().create_timer(0.8).timeout
	_game_over = GAME_OVER_SCENE.instantiate()
	add_child(_game_over)
	_game_over.tree_exited.connect(_on_game_over_closed)
	get_tree().paused = true


func _on_game_over_closed() -> void:
	_game_over = null
