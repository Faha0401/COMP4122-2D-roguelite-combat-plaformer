extends RefCounted
## Pure generator for one run's room graph.
##
## Grammar:
##   START -> SEGMENT1 (2-3 layers of 2-3 rooms) -> GATE {Shop | Puzzle}
##         -> SEGMENT2 (2-3 layers of 2-3 rooms) -> SHOP2 -> BOSS
##
## Each layer is a set of rooms the player chooses between; layers are chained,
## so a run is a short branching sequence and every room is a real scene.
##
## Rules:
##   - Every non-boss room has exactly two exits. A room with a single onward
##     target lists it twice so both portals point there.
##   - A combat room never leads into the same combat scene back-to-back. The
##     ban is best-effort for other kinds: two distinct puzzle parents can force
##     a repeat because the puzzle pool only holds two scenes.
##   - Every room is reachable from START; exits are allocated with coverage.
##   - The gate room always offers {shop, puzzle} as its two options.
##
## Nothing here touches the scene tree or awaits: build() is a pure function of
## the RNG, so it can be exercised headlessly (see tools/validate_grammar.gd).
##
## Output is Dictionary[int, Dictionary] where each room is
##   { type: String, name: String, scene: String, children: Array[int] }

const MIN_SEGMENT_LAYERS := 2
const MAX_SEGMENT_LAYERS := 3
const MIN_LAYER_ROOMS := 2
const MAX_LAYER_ROOMS := 3
const COMBAT_CHANCE := 0.6
const EXITS_PER_ROOM := 2

const ROOM_POOLS := {
	"combat": [
		"res://Levels/Combat/Combat1.tscn",
		"res://Levels/Combat/Combat2.tscn",
		"res://Levels/Combat/Combat3.tscn",
		"res://Levels/Combat/Combat4.tscn",
	],
	"puzzle": [
		"res://Levels/Puzzle/Puzzle1.tscn",
		"res://Levels/Puzzle/Puzzle2.tscn",
	],
	"shop": [
		"res://Levels/Shop/Shop1.tscn",
		"res://Levels/Shop/Shop2.tscn",
	],
	"boss": [
		"res://Levels/Boss/BossRoom.tscn",
	],
}

## Id of the room the player starts in. Valid only after build().
var start_id: int = -1

var _graph: Dictionary = {}
var _next_id: int = 0


func build() -> Dictionary:
	_graph = {}
	_next_id = 0

	var start := _make_room("combat")

	# Each entry of `layers` is a set of rooms the player picks between; the
	# layers are chained, so a segment is a short branching sequence.
	var layers: Array = []
	layers.append([start])
	# START only has two exits, so the layer it feeds may not be wider than two.
	layers.append_array(_make_segment(EXITS_PER_ROOM))
	var gate_index := layers.size()
	layers.append([_make_room("shop"), _make_room("puzzle")])
	layers.append_array(_make_segment())
	layers.append([_make_room("shop")])
	layers.append([_make_room("boss")])

	for i in layers.size() - 1:
		if i + 1 == gate_index:
			# The gate exists as a choice, so every room leading into it must
			# offer both options rather than half of them.
			_connect_exhaustive(layers[i], layers[i + 1])
		else:
			_connect_layers(layers[i], layers[i + 1])

	_assign_scenes(start)

	start_id = start
	return _graph


# ---------------------------------------------------------------------------
# Graph construction
# ---------------------------------------------------------------------------

## A segment is 2-3 layers of 2-3 rooms. `max_first_layer` caps the first layer
## when a narrow predecessor (the entrance, with two exits) feeds it.
func _make_segment(max_first_layer: int = MAX_LAYER_ROOMS) -> Array:
	var layers: Array = []
	for layer_index in randi_range(MIN_SEGMENT_LAYERS, MAX_SEGMENT_LAYERS):
		var width := MAX_LAYER_ROOMS if layer_index > 0 else max_first_layer
		var rooms: Array = []
		for _room in randi_range(MIN_LAYER_ROOMS, width):
			var kind: String = "combat" if randf() < COMBAT_CHANCE else "puzzle"
			rooms.append(_make_room(kind))
		layers.append(rooms)
	return layers


func _make_room(kind: String) -> int:
	var id := _next_id
	_next_id += 1
	# Scene and name stay empty until _assign_scenes(), which needs the finished
	# graph: the scene of a room depends on the scenes of its parents.
	_graph[id] = {
		"type": kind,
		"name": "",
		"scene": "",
		"children": [],
	}
	return id


func _connect_layers(parents: Array, children: Array) -> void:
	# First pass: give every child at least one parent so no room is orphaned.
	# A parent holds at most two exits, so coverage can fall short when a layer
	# is wider than twice the layer feeding it.
	for i in children.size():
		_append_exit(parents[i % parents.size()], children[i])

	# Second pass: top every parent up to exactly two exits.
	for parent in parents:
		var exits: Array = _graph[parent]["children"]
		while exits.size() < EXITS_PER_ROOM:
			exits.append(children.pick_random())


## Give every parent the complete set of children, shuffled. Used where the
## choice itself is the design (the gate must always offer shop *and* puzzle).
func _connect_exhaustive(parents: Array, children: Array) -> void:
	for parent in parents:
		var exits: Array = children.duplicate()
		exits.shuffle()
		_graph[parent]["children"] = exits


func _append_exit(parent: int, child: int) -> void:
	var exits: Array = _graph[parent]["children"]
	if exits.size() >= EXITS_PER_ROOM:
		return
	if exits.is_empty():
		exits.append(child)
	else:
		# Either slot may hold it; the upper portal is not privileged.
		exits.insert(randi_range(0, 1), child)


# ---------------------------------------------------------------------------
# Scene assignment
# ---------------------------------------------------------------------------

func _assign_scenes(start: int) -> void:
	var parents := _parent_map()
	# Breadth-first from the entrance so a parent's scene is always known
	# before its children pick theirs.
	for id in _breadth_first(start):
		var kind: String = _graph[id]["type"]
		var banned := _banned_scenes(parents.get(id, []), kind)
		var scene := _pick_scene(kind, banned)
		_graph[id]["scene"] = scene
		_graph[id]["name"] = "Boss" if kind == "boss" else _scene_label(scene)


func _parent_map() -> Dictionary:
	var parents := {}
	for id in _graph.keys():
		for child in _graph[id]["children"]:
			if not parents.has(child):
				parents[child] = []
			parents[child].append(id)
	return parents


func _breadth_first(start: int) -> Array:
	var order: Array = []
	var seen := {}
	var queue: Array = [start]
	while not queue.is_empty():
		var id: int = queue.pop_front()
		if seen.has(id):
			continue
		seen[id] = true
		order.append(id)
		queue.append_array(_graph[id]["children"])
	return order


func _banned_scenes(parent_ids: Array, kind: String) -> Dictionary:
	var banned := {}
	for parent in parent_ids:
		if _graph[parent]["type"] == kind:
			banned[_graph[parent]["scene"]] = true
	return banned


func _pick_scene(kind: String, banned: Dictionary) -> String:
	var pool: Array = ROOM_POOLS[kind]
	if pool.size() > 1:
		var allowed := pool.filter(func(scene): return not banned.has(scene))
		if not allowed.is_empty():
			pool = allowed
	return pool.pick_random()


func _scene_label(scene: String) -> String:
	return String(scene).get_file().get_basename()
