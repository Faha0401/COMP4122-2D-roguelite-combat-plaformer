extends Control
func _ready() -> void:
	$HUD/Root/TopRight/TextureButton.pressed.connect(_on_play_pressed)
func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://Game/Run.tscn")
