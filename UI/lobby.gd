extends Node2D
## The waystation hub: one walkable room between runs.
##
## There is no "PLAY" button here. The shop and the chest are interacted with
## in the world, and the run starts by walking into the arrow at the far right.
## Everything the HUD shows (coins, hearts) comes from RunState, so the shop and
## the chest only need to call RunState methods.

const RUN_SCENE := "res://Game/Run.tscn"
const SHOP_SCENE := preload("res://UI/ShopUI.tscn")
## The pack ships the campfire as a 12-frame strip (64x64 each).
const CAMPFIRE_SHEET := preload("res://Assets/Scene/Backgrounds/Cooking area.png")
const CAMPFIRE_FRAMES := 12
const CAMPFIRE_SIZE := 64
const CHEST_REWARD := 25
const FADE_TIME := 0.45
const BANNER_HOLD := 2.6

@onready var _player: CharacterBody2D = $Player
@onready var _shop_area: Area2D = $Shop/ShopArea
@onready var _exit_area: Area2D = $ExitArea
@onready var _chest: Chest = $Chest
@onready var _rest_area: Area2D = $RestArea
@onready var _campfire: AnimatedSprite2D = $Campfire
@onready var _fire_glow: Sprite2D = $FireGlow
@onready var _lanterns: Array[Sprite2D] = [$Shop/LanternLeft, $Shop/LanternRight]
@onready var _banner: Control = $Banner/Root/Card
@onready var _prompt: Label = $Prompt/Root/Label
@onready var _fade: ColorRect = $Fade/FadeRect
@onready var _hud: CanvasLayer = $HUD

var _shop_screen: CanvasLayer = null
var _near_shop := false
var _near_rest := false
var _flicker := 0.0
var _leaving := false
var _prompt_tween: Tween = null


func _ready() -> void:
	# A hub visit is a fresh, healthy body; coins survive because they are the
	# shop's currency, not a per-run score.
	RunState.start_run()
	$Backdrop.setup("lobby")
	# The interact areas filter on this group; scene_manager does the same for
	# players it spawns, but the hub instances its player directly.
	_player.add_to_group("player")

	_build_campfire()
	_shop_area.body_entered.connect(_on_shop_entered)
	_shop_area.body_exited.connect(_on_shop_exited)
	_rest_area.body_entered.connect(_on_rest_entered)
	_rest_area.body_exited.connect(_on_rest_exited)
	_exit_area.body_entered.connect(_on_exit_entered)
	_chest.opened.connect(_on_chest_opened)

	_prompt.text = ""
	_hide_run_only_ui()
	_fade.color = Color(0, 0, 0, 1)
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, FADE_TIME).set_trans(Tween.TRANS_SINE)

	_announce()


## The hub is not a run: the control hints and the shadow's debug marker would
## only be noise here. Both live in scenes owned by the player workstream, so
## they are hidden rather than edited.
func _hide_run_only_ui() -> void:
	var hints := _hud.get_node_or_null("Root/Hints")
	if hints != null:
		hints.visible = false
	var gauge := _hud.get_node_or_null("Root/Gauge")
	if gauge != null:
		gauge.visible = false
	var shadow := _player.get_node_or_null("Shadow")
	if shadow != null:
		var marker := shadow.get_node_or_null("ColorRect")
		if marker != null:
			marker.visible = false


## Small sign on arrival, the hub's version of the in-run room banner.
func _announce() -> void:
	_banner.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_banner, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(BANNER_HOLD)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.7)


func _process(delta: float) -> void:
	_flicker += delta
	var pulse := 0.82 + 0.18 * sin(_flicker * 7.3) * sin(_flicker * 3.1)
	_fire_glow.modulate.a = 0.6 * pulse
	for i in _lanterns.size():
		var phase := _flicker * 2.2 + i * 1.7
		_lanterns[i].modulate.a = 0.55 * (0.95 + 0.05 * sin(phase))
	if _shop_screen != null or _leaving:
		_prompt.text = ""
		return
	if _near_shop:
		_set_prompt("[E]   TRADE")
	elif _near_rest:
		_set_prompt("[E]   REST")
	elif _chest != null and _chest.player_in_range and not _chest.is_open:
		_set_prompt("[E]   OPEN CHEST")
	else:
		_set_prompt("")


func _set_prompt(text: String) -> void:
	if _prompt.text == text:
		return
	_prompt.text = text


func _unhandled_input(event: InputEvent) -> void:
	if _shop_screen != null or _leaving:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_interact()
		get_viewport().set_input_as_handled()


func _interact() -> void:
	if _near_shop:
		open_shop()
	elif _near_rest:
		_rest()
	elif _chest != null and _chest.player_in_range and not _chest.is_open:
		_chest.open()


## Slice the pack's campfire strip into frames rather than baking twelve
## AtlasTextures into the scene file.
func _build_campfire() -> void:
	var frames := SpriteFrames.new()
	for i in CAMPFIRE_FRAMES:
		var slice := AtlasTexture.new()
		slice.atlas = CAMPFIRE_SHEET
		slice.region = Rect2(i * CAMPFIRE_SIZE, 0, CAMPFIRE_SIZE, CAMPFIRE_SIZE)
		frames.add_frame("default", slice)
	frames.set_animation_speed("default", 9.0)
	frames.set_animation_loop("default", true)
	_campfire.sprite_frames = frames
	_campfire.play("default")


# ---------------------------------------------------------------------------
# Rest tent
# ---------------------------------------------------------------------------

func _on_rest_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near_rest = true


func _on_rest_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near_rest = false


func _rest() -> void:
	if RunState.hp >= RunState.max_hp:
		_toast("YOU ARE ALREADY WHOLE")
		return
	RunState.heal(RunState.max_hp)
	_toast("YOU REST A WHILE")


# ---------------------------------------------------------------------------
# Shop
# ---------------------------------------------------------------------------

func _on_shop_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near_shop = true


func _on_shop_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near_shop = false


func open_shop() -> void:
	if _shop_screen != null:
		return
	_shop_screen = SHOP_SCENE.instantiate()
	add_child(_shop_screen)
	_shop_screen.closed.connect(_on_shop_closed)
	# The shop owns the pause while it is open; its nodes run with ALWAYS.
	get_tree().paused = true


func _on_shop_closed() -> void:
	if _shop_screen == null:
		return
	get_tree().paused = false
	_shop_screen.queue_free()
	_shop_screen = null


# ---------------------------------------------------------------------------
# Chest
# ---------------------------------------------------------------------------

func _on_chest_opened() -> void:
	RunState.add_coins(CHEST_REWARD)
	_toast("+%d COINS" % CHEST_REWARD)


func _toast(text: String) -> void:
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	_prompt.text = text
	_prompt.modulate.a = 1.0
	_prompt_tween = create_tween()
	_prompt_tween.tween_interval(1.2)
	_prompt_tween.tween_property(_prompt, "modulate:a", 0.0, 0.4)
	_prompt_tween.tween_callback(func() -> void: _prompt.text = "")


# ---------------------------------------------------------------------------
# Leaving for stage one
# ---------------------------------------------------------------------------

func _on_exit_entered(body: Node2D) -> void:
	if _leaving or not body.is_in_group("player"):
		return
	_leaving = true
	_prompt.text = ""
	_player.set_physics_process(false)
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_TIME).set_trans(Tween.TRANS_SINE)
	await tween.finished
	get_tree().change_scene_to_file(RUN_SCENE)
