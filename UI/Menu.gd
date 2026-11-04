extends Control

func _ready() -> void:
	$CanvasLayer/CenterRow/MainContainer/TextureButton.pressed.connect(_on_start_pressed)
	$CanvasLayer/CenterRow/MainContainer/TextureButton2.pressed.connect(_on_option_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://UI/Lobby.tscn")

func _on_option_pressed() -> void:
	get_tree().change_scene_to_file("res://UI/OptionsMenu.tscn")
