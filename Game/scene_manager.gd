extends Node2D
## Run orchestrator: owns the live room, the player and the fade transition.
##
## Room generation lives in run_generator.gd and knows nothing about the tree;
## this script only turns a generated graph into rooms and walks the player
## through it. Portal colours, exit rules and the run grammar are documented
## there, next to the code that enforces them.

const RunGenerator := preload("res://Game/run_generator.gd")
const PlayerScene := preload("res://Entity/Player.tscn")
const FADE_TIME := 0.25

## Room graph: id -> { type, name, scene, children }. Read-only after _ready.
var graph: Dictionary = {}

var current_room: Node2D = null
var player: CharacterBody2D = null

## True from the moment a transition is accepted until its final fade ends.
var _transition_pending := false

## One exit may arrive while a transition is still running; keep it rather than
## dropping it, since the room that emitted it has already locked itself.
const NO_EXIT := -1
var _queued_exit := NO_EXIT
var _draining := false

@onready var _fade_rect: ColorRect = $Fade/FadeRect
@onready var _hud: CanvasLayer = $HUD


func _ready() -> void:
	# A run owns exactly one reset point, here, so RETRY and PLAY cannot drift
	# apart in what they reset.
	RunState.start_run()

	var generator := RunGenerator.new()
	graph = generator.build()
	_queued_exit = generator.start_id
	_drain_exits()


# ---------------------------------------------------------------------------
# Transitions
# ---------------------------------------------------------------------------

## Fade out, swap the room while the screen is black, fade in.
func _enter_room(node_id: int) -> void:
	_transition_pending = true

	_set_player_frozen(true)
	await _fade_to(1.0)

	_swap_room(node_id)
	_set_player_frozen(true)   # the swap may have produced a fresh player

	await _fade_to(0.0)
	_set_player_frozen(false)

	_transition_pending = false


func _swap_room(node_id: int) -> void:
	_clear_current_room()

	var room_data: Dictionary = graph[node_id]
	var packed: PackedScene = load(room_data["scene"])
	var room = packed.instantiate()

	# Configure before adding to the tree so the room applies its exits the
	# first time it readies, instead of briefly existing with none.
	room.setup(node_id, room_data["type"], room_data["name"], _exits_for(node_id))
	add_child(room)
	current_room = room
	room.exit_requested.connect(_on_exit_requested)

	_ensure_player()
	room.add_child(player)
	player.global_position = room.get_spawn_position()
	player.velocity = Vector2.ZERO

	RunState.enter_room()
	if _hud != null and _hud.has_method("show_room"):
		_hud.show_room(room_data["name"], room_data["type"], RunState.rooms_entered - 1)


func _clear_current_room() -> void:
	if current_room == null:
		return
	if player != null and player.get_parent() == current_room:
		current_room.remove_child(player)
	current_room.queue_free()
	current_room = null


func _exits_for(node_id: int) -> Array:
	var exits: Array = []
	for child_id in graph[node_id]["children"]:
		exits.append({
			"type": graph[child_id]["type"],
			"target": child_id,
		})
	return exits


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", alpha, FADE_TIME)
	await tween.finished


func _set_player_frozen(frozen: bool) -> void:
	if player == null:
		return
	# Freeze movement, input and momentum together: stopping only the physics
	# tick would still let an attack queue up behind the fade.
	player.set_physics_process(not frozen)
	player.set_process_input(not frozen)
	player.velocity = Vector2.ZERO


func _ensure_player() -> void:
	if player != null:
		return
	player = PlayerScene.instantiate()
	player.add_to_group("player")


func _on_exit_requested(target_id: int) -> void:
	_queued_exit = target_id
	_drain_exits.call_deferred()


## Play out queued exits one at a time. A request that lands mid-fade is honoured
## after the current transition instead of being thrown away and stranding the
## player in a room whose portals have all closed.
func _drain_exits() -> void:
	if _draining:
		return
	_draining = true
	while _queued_exit != NO_EXIT:
		var target := _queued_exit
		_queued_exit = NO_EXIT
		await _enter_room(target)
	_draining = false
