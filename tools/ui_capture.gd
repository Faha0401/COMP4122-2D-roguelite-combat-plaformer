extends Node
## Dev helper: renders one scene, waits, saves a PNG of the viewport.
##   godot --path . tools/ui_capture.tscn -- res://UI/Menu.tscn D:/out/menu.png 12

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: -- <scene> <out.png> [frames]")
		get_tree().quit(1)
		return

	var scene_path: String = args[0]
	var out_path: String = args[1]
	var frames: int = int(args[2]) if args.size() > 2 else 12
	var action: String = args[3] if args.size() > 3 else ""

	var packed: PackedScene = load(scene_path)
	if packed == null:
		printerr("cannot load ", scene_path)
		get_tree().quit(1)
		return

	add_child(packed.instantiate())
	for i in frames:
		await get_tree().process_frame

	# optional: drive the scene before the shot, e.g. "pause" or "options"
	if action != "":
		for node in get_tree().root.find_children("*", "", true, false):
			if node.has_method("open_" + action):
				node.call("open_" + action)
				break
		for i in 20:
			await get_tree().process_frame

	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(out_path)
	if err != OK:
		printerr("save failed: ", err)
	get_tree().quit(0)
