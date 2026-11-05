extends CanvasLayer
## Pause overlay. Runs with PROCESS_MODE_ALWAYS so it keeps responding while the
## tree is paused, and it owns the pause flag: resuming and quitting both clear
## `get_tree().paused` before anything else happens.

const OPTIONS_SCENE := preload("res://UI/OptionsMenu.tscn")
const MENU_SCENE := "res://UI/Menu.tscn"

@onready var _resume_button: Button = %ResumeButton
@onready var _options_button: Button = %OptionsButton
@onready var _quit_button: Button = %QuitButton
@onready var _stats_label: Label = %StatsLabel
@onready var _card: Control = %Card
@onready var _overlay: Control = %Overlay

var _options_screen: Control = null


func _ready() -> void:
	_resume_button.pressed.connect(resume_game)
	_options_button.pressed.connect(_open_options)
	_quit_button.pressed.connect(_quit_to_title)

	_stats_label.text = "ROOMS  %02d      COINS  %d      LEVEL  %d" % [
		RunState.rooms_entered, RunState.coins, RunState.level,
	]

	_card.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_card, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
	_resume_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _options_screen != null:
		return
	if event.is_action_pressed("Pause") or event.is_action_pressed("ui_cancel"):
		resume_game()
		get_viewport().set_input_as_handled()


func resume_game() -> void:
	if _options_screen != null:
		return
	get_tree().paused = false
	queue_free()


func _open_options() -> void:
	if _options_screen != null:
		return
	_options_screen = OPTIONS_SCENE.instantiate()
	_overlay.add_child(_options_screen)
	_options_screen.closed.connect(_on_options_closed)


func _on_options_closed() -> void:
	if _options_screen == null:
		return
	_options_screen.queue_free()
	_options_screen = null
	_options_button.grab_focus()


func _quit_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
