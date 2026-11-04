extends SceneTree
## Headless smoke test. Each step it fires EVERY portal's body-entered handler
## with the player, simulating the worst case where the player overlaps both
## stacked portals on the same frame. The double-entry guards must ensure only
## ONE room transition happens per step.

var _frames := 0
var _current_run: Node = null
var _max_steps := 600
var _last_room = null

func _initialize() -> void:
	var packed: PackedScene = load("res://Game/Run.tscn")
	_current_run = packed.instantiate()
	root.add_child(_current_run)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	if _max_steps <= 0:
		quit()
		return true
	_max_steps -= 1

	var room = _current_run.get("current_room")
	var player = _current_run.get("player")
	if room == null or player == null:
		return false

	if room != _last_room:
		_last_room = room
		print("[test] entered room: %s [%s]" % [room.room_name, room.room_type])

	var portals = []
	for n in room.get_children():
		if n.is_in_group("portal"):
			portals.append(n)
	if portals.is_empty():
		print("[test] reached a room with no portals (boss) -> done")
		quit()
		return true

	# Fire ALL portals this frame (worst case). Only one should take effect.
	for p in portals:
		p._on_body_entered(player)
	return false
