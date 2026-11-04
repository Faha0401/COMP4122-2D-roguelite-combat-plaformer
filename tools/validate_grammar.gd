extends SceneTree
## Structural validator: builds a run graph (no tree, no rooms) and checks the
## grammar invariants, printing a PASS/FAIL report per rule.

func _initialize() -> void:
	var generator = load("res://Game/run_generator.gd").new()
	var graph: Dictionary = generator.build()
	_validate(graph, generator.start_id)
	generator = null
	quit()


func _validate(graph: Dictionary, start_id: int) -> void:
	print("=== GRAPH VALIDATION ===")

	var counts := {"combat": 0, "puzzle": 0, "shop": 0, "boss": 0}
	var bosses: Array = []
	for id in graph.keys():
		var kind: String = graph[id]["type"]
		counts[kind] = counts.get(kind, 0) + 1
		if kind == "boss":
			bosses.append(id)

	print("counts: combat=%d puzzle=%d shop=%d boss=%d (nodes=%d)" % [
		counts["combat"], counts["puzzle"], counts["shop"], counts["boss"], graph.size()
	])

	# INVARIANT 1: exactly one boss.
	if bosses.size() != 1:
		print("FAIL: expected exactly 1 boss, got %d" % bosses.size())
		return
	print("PASS: exactly one boss room")

	var boss_id: int = bosses[0]

	# INVARIANT 2: boss is terminal.
	if graph[boss_id]["children"].is_empty():
		print("PASS: boss is terminal (no exits)")
	else:
		print("FAIL: boss has children %s" % [graph[boss_id]["children"]])

	# INVARIANT 3: every non-boss room has exactly 2 exits.
	var bad_exits := 0
	for id in graph.keys():
		if id == boss_id:
			continue
		if graph[id]["children"].size() != 2:
			bad_exits += 1
	if bad_exits == 0:
		print("PASS: all non-boss rooms expose exactly 2 exits")
	else:
		print("FAIL: %d rooms do not have 2 exits" % bad_exits)

	# INVARIANT 4: some room offers {shop, puzzle} as its two choices.
	var gate_ok := false
	for id in graph.keys():
		var kinds := []
		for child in graph[id]["children"]:
			kinds.append(graph[child]["type"])
		if kinds.has("shop") and kinds.has("puzzle"):
			gate_ok = true
			break
	if gate_ok:
		print("PASS: found a gate offering {shop, puzzle} as the two exits")
	else:
		print("FAIL: no room offers a shop+puzzle choice")

	# INVARIANT 5: no combat room leads into the same combat scene.
	# Repeats in smaller pools (puzzle holds 2 scenes) are reported, not failed:
	# two distinct puzzle parents can make a repeat unavoidable.
	var same_combat := 0
	var soft_repeats := 0
	for id in graph.keys():
		for child in graph[id]["children"]:
			if graph[child]["type"] != graph[id]["type"]:
				continue
			if graph[child]["scene"] != graph[id]["scene"]:
				continue
			if graph[id]["type"] == "combat":
				same_combat += 1
			else:
				soft_repeats += 1
	if same_combat == 0:
		print("PASS: no combat edge reuses the same combat scene")
	else:
		print("FAIL: %d combat edges reuse the same scene" % same_combat)
	if soft_repeats > 0:
		print("INFO: %d repeated non-combat edges (pool smaller than branching)" % soft_repeats)

	# INVARIANT 6: every generated room is reachable from the entrance, so no
	# room is paid for and never visited.
	var reachable := {}
	var queue: Array = [start_id]
	while not queue.is_empty():
		var id: int = queue.pop_front()
		if reachable.has(id):
			continue
		reachable[id] = true
		queue.append_array(graph[id]["children"])
	var orphans: Array = []
	for id in graph.keys():
		if not reachable.has(id):
			orphans.append(id)
	if orphans.is_empty():
		print("PASS: all %d rooms reachable from the entrance" % graph.size())
	else:
		print("FAIL: %d unreachable rooms: %s" % [orphans.size(), orphans])

	# INVARIANT 7: the run starts in a combat room.
	if graph[start_id]["type"] == "combat":
		print("PASS: run starts in a combat room (%s)" % graph[start_id]["name"])
	else:
		print("FAIL: run starts in a %s room" % graph[start_id]["type"])

	print("=== DONE ===")
