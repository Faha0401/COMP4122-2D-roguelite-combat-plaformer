extends Node2D

signal exit_requested(target_id)

@export var room_type: String = "combat"

var room_id: int = -1
var room_name: String = "Room"
var exits: Array = []          # [ {type, target}, ... ] (1 or 2 entries)

var _portals: Array = []
var _spawn: Marker2D = null
var _locked: bool = false   # true once an exit has fired; blocks further exits

func setup(id: int, type: String, rname: String, exit_list: Array) -> void:
	room_id = id
	room_type = type
	room_name = rname
	exits = exit_list
	# If already in the tree, apply immediately; otherwise _ready will.
	if is_inside_tree():
		_apply()

func _ready() -> void:
	_collect()
	_apply()
	_set_name_label()

func _set_name_label() -> void:
	var label := get_node_or_null("NameLabel")
	if label != null:
		label.text = "%s  [%s]" % [room_name, room_type]

func _collect() -> void:
	_portals.clear()
	for n in get_tree().get_nodes_in_group("portal"):
		if is_ancestor_of(n):
			_portals.append(n)
	# Sort top-to-bottom so index 0 is the upper portal.
	_portals.sort_custom(func(a, b): return a.global_position.y < b.global_position.y)
	_spawn = get_node_or_null("Spawn")

func get_spawn_position() -> Vector2:
	if _spawn != null:
		return _spawn.global_position
	return Vector2(90.0, 620.0)

func _apply() -> void:
	if _portals.is_empty():
		return

	# Work out the two portal destinations.
	var slots: Array = []
	if exits.is_empty():
		slots = []                       # boss room: leave portals as-is (closed look)
	elif exits.size() == 1:
		slots = [exits[0], exits[0]]     # single onward target -> both portals
	else:
		slots = [exits[0], exits[1]]

	for i in _portals.size():
		var portal = _portals[i]
		if i < slots.size():
			portal.setup(slots[i]["type"], slots[i]["target"], true)
			if not portal.player_entered.is_connected(_on_portal_entered):
				portal.player_entered.connect(_on_portal_entered)
		else:
			# No exit for this portal (e.g. boss room) -> close it (acts as a wall).
			portal.set_active(false)

func _on_portal_entered(target_id: int) -> void:
	# One room exit per visit: ignore any second portal that also overlapped the
	# player this frame, and lock every portal immediately.
	if _locked:
		return
	_locked = true
	for portal in _portals:
		portal.set_active(false)
	emit_signal("exit_requested", target_id)
