extends Node2D
## Reusable portal component (see res://Game/Portal.tscn).
## Two states:
##   ACTIVE  -> pass-through trigger (Area2D). Player walking in emits `player_entered`.
##   CLOSED  -> solid wall (StaticBody2D). Passive, blocks the player, no action.
## Colour scheme is derived from the DESTINATION room type so one asset is reused:
##   combat = red, puzzle = yellow, shop = green, boss = purple.

signal player_entered(target_id)

const ARM_DELAY: float = 0.15   # seconds a freshly set-up portal ignores enters

var target_room_id: int = -1
var color_type: String = "combat"
var is_active: bool = false
var _consumed: bool = false   # guards against emitting player_entered more than once
var _armed: bool = false      # false briefly after (re)setup: ignore spurious enters
var _arm_timer: float = 0.0

@onready var _glow: ColorRect = $Glow
@onready var _core: ColorRect = $Core
@onready var _wall_shape: CollisionShape2D = $Wall/WallShape
@onready var _trigger: Area2D = $Trigger

func _ready() -> void:
	_trigger.body_entered.connect(_on_body_entered)
	_apply_color()
	set_active(is_active)

func setup(type: String, target: int, active: bool) -> void:
	color_type = type
	target_room_id = target
	_consumed = false
	# The player is placed into a room just after it loads, and its body can still
	# overlap this trigger for a frame (the new room's portal sits at the same
	# spot as the one we left). Stay disarmed briefly so that is not a real entry.
	_armed = false
	_arm_timer = ARM_DELAY
	_apply_color()
	set_active(active)

func _process(delta: float) -> void:
	if not _armed:
		_arm_timer -= delta
		if _arm_timer <= 0.0:
			_armed = true

func set_active(active: bool) -> void:
	is_active = active
	# `set_active` may be called from an area/body signal handler, where changing
	# monitoring/disabled directly is blocked. Always change physical state deferred.
	if _wall_shape != null:
		_wall_shape.set_deferred("disabled", active)   # active -> the wall is gone
	if _trigger != null:
		_trigger.set_deferred("monitoring", active)    # only listen when active
	if _glow != null:
		_glow.visible = active
	modulate = Color(1, 1, 1, 1.0) if active else Color(0.55, 0.55, 0.55, 0.85)

func _apply_color() -> void:
	var c := _type_color(color_type)
	if _core != null:
		_core.color = c
	if _glow != null:
		_glow.color = Color(c.r, c.g, c.b, 0.30)

func _type_color(t: String) -> Color:
	match t:
		"combat":
			return Color(0.92, 0.22, 0.22)   # red
		"puzzle":
			return Color(0.96, 0.85, 0.20)   # yellow
		"shop":
			return Color(0.22, 0.90, 0.35)   # green
		"boss":
			return Color(0.66, 0.28, 0.96)   # purple
	return Color.WHITE

func _on_body_entered(body: Node2D) -> void:
	if not _armed or not is_active or _consumed:
		return
	if body.is_in_group("player"):
		# Mark consumed synchronously so a second body (or a second portal that
		# also overlaps the player this frame) cannot emit again. Disabling the
		# collision shape itself must be deferred (physics callback safety).
		_consumed = true
		set_active.call_deferred(false)
		emit_signal("player_entered", target_room_id)
