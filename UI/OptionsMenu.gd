extends CanvasLayer
func _ready() -> void:
	$MainPanel/MarginContainer/VBoxContainer/BackButton.pressed.connect(_on_back_pressed)
func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://UI/Menu.tscn")
