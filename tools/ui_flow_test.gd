extends Node
## Headless smoke test for the UI layer.
##
##   godot --headless --path . tools/ui_flow_test.tscn
##
## Exercises the paths a player actually walks — run -> pause -> resume -> death
## -> game over — instead of only loading the scenes, so a broken signal
## connection or a missing unique node fails here rather than in a demo.

const MENU_SCENE := "res://UI/Menu.tscn"
const RUN_SCENE := "res://Game/Run.tscn"
const LOBBY_SCENE := "res://UI/Lobby.tscn"

var _failures := 0


func _ready() -> void:
	await _test_scenes_load()
	await _test_run_and_pause()
	await _test_death_and_game_over()
	await _test_lobby_and_shop()
	await _test_menu_to_lobby()

	if _failures == 0:
		print("UI FLOW TEST: OK")
	else:
		printerr("UI FLOW TEST: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok    ", what)
	else:
		_failures += 1
		printerr("  FAIL  ", what)


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _test_scenes_load() -> void:
	print("scenes load:")
	for path in [MENU_SCENE, "res://UI/OptionsMenu.tscn", "res://UI/HUD.tscn",
			"res://UI/PauseMenu.tscn", "res://UI/GameOver.tscn",
			LOBBY_SCENE, "res://UI/ShopUI.tscn"]:
		var packed: PackedScene = load(path)
		_check(packed != null, path)
		if packed == null:
			continue
		var inst := packed.instantiate()
		_check(inst != null, path + " instantiates")
		if inst != null:
			inst.free()

	_check(load("res://UI/theme/chrono_blade_theme.tres") is Theme, "theme resource")
	_check(InputMap.has_action("Pause"), "Pause input action exists")


## The waystation: chest pays out, the shop pauses the tree and releases it.
func _test_lobby_and_shop() -> void:
	print("lobby + shop:")
	var lobby: Node = load(LOBBY_SCENE).instantiate()
	add_child(lobby)
	await _wait(10)

	_check(lobby.get("player") != null or lobby.get_node_or_null("Player") != null,
			"lobby spawns the player")
	var coins_before := RunState.coins
	lobby.call("_on_chest_opened")
	_check(RunState.coins == coins_before + 25, "chest pays 25 coins")

	lobby.call("open_shop")
	await _wait(3)
	_check(get_tree().paused, "shop pauses the tree")

	var shop: Node = null
	for child in lobby.get_children():
		if child.name.begins_with("ShopUI"):
			shop = child
	_check(shop != null, "shop overlay added")
	if shop != null:
		shop.call("_close")
		await _wait(3)
	_check(not get_tree().paused, "closing the shop unpauses")

	lobby.queue_free()
	await _wait(3)


## The one path a player is guaranteed to take: pressing PLAY on the title
## screen. It is checked last, because it frees everything before it.
func _test_menu_to_lobby() -> void:
	print("menu -> lobby:")
	var menu: Control = load(MENU_SCENE).instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await _wait(10)

	var play: Button = menu.get_node_or_null("Content/Buttons/PlayButton")
	_check(play != null, "PLAY button found")
	if play == null:
		return

	play.pressed.emit()
	# 0.4s fade, then the scene swap
	await get_tree().create_timer(0.9).timeout
	await _wait(10)

	var current := get_tree().current_scene
	_check(current != null and current.name == "Lobby", "PLAY loads the hub, not the run")

	# the menu is freed by the swap; do not touch `menu` below this line
	if current != null:
		current.queue_free()


func _test_run_and_pause() -> void:
	print("run + pause:")
	var run: Node = load(RUN_SCENE).instantiate()
	add_child(run)
	await _wait(45)

	_check(RunState.is_run_active, "run started")
	_check(RunState.rooms_entered >= 1, "entered at least one room")

	var hud: CanvasLayer = run.get_node_or_null("HUD")
	_check(hud != null, "HUD instanced inside Run")
	_check(hud != null and RunState.hp == RunState.max_hp, "HUD reads full health")

	if hud == null:
		run.queue_free()
		return

	var room_label: Label = hud.get_node_or_null("Root/RoomCard/Row/Text/RoomName")
	_check(room_label != null and room_label.text != "ROOM", "room banner filled in")

	var gauge: HBoxContainer = hud.get_node_or_null("Root/Gauge/GaugeRow")
	_check(gauge != null and gauge.get_child_count() > 0, "rewind gauge built")

	hud.open_pause()
	await _wait(3)
	_check(get_tree().paused, "pausing stops the tree")

	var pause_menu: Node = null
	for child in hud.get_children():
		if child.name.begins_with("PauseMenu"):
			pause_menu = child
	_check(pause_menu != null, "pause menu added")

	if pause_menu != null:
		pause_menu.resume_game()
		await _wait(3)
	_check(not get_tree().paused, "resume clears the pause flag")

	run.queue_free()
	await _wait(3)


func _test_death_and_game_over() -> void:
	print("death + game over:")
	var run: Node = load(RUN_SCENE).instantiate()
	add_child(run)
	await _wait(45)

	var hud: CanvasLayer = run.get_node_or_null("HUD")
	if hud == null:
		_check(false, "HUD for death test")
		return

	# drain the bar, clearing i-frames between hits so this is deterministic
	for i in RunState.max_hp:
		RunState.damage(1)
		RunState.set("_iframe", 0.0)

	_check(RunState.hp == 0, "health reaches zero")
	_check(not RunState.is_run_active, "run deactivated on death")

	# the HUD delays the summary by 0.8s
	await get_tree().create_timer(1.4).timeout
	await _wait(3)

	_check(get_tree().paused, "game over pauses the tree")

	var game_over: Node = null
	for child in hud.get_children():
		if child.name.begins_with("GameOver"):
			game_over = child
	_check(game_over != null, "game over screen shown")
	if game_over != null:
		var rooms: Label = game_over.get_node_or_null("Root/Center/Card/Body/Stats/RoomsValue")
		_check(rooms != null and rooms.text != "", "summary filled in")

	get_tree().paused = false
	run.queue_free()
	await _wait(3)
