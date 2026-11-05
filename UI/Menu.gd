extends Control
## Title screen: PLAY / OPTIONS / QUIT over the parallax backdrop.
##
## PLAY hands control to Game/Run.tscn. OPTIONS is opened as an overlay instead
## of a scene swap, so the backdrop (and the music) never stop; the same overlay
## is reused by the pause menu, which is why UI/OptionsMenu.tscn is a Control
## with a `closed` signal rather than a full screen scene.

const RUN_SCENE := "res://Game/Run.tscn"
const OPTIONS_SCENE := preload("res://UI/OptionsMenu.tscn")
const FADE_OUT_TIME := 0.4
const TITLE_FADE_TIME := 0.7

@onready var _title_art: TextureRect = %TitleArt
@onready var _play_button: Button = %PlayButton
@onready var _options_button: Button = %OptionsButton
@onready var _quit_button: Button = %QuitButton
@onready var _overlay: Control = %Overlay
@onready var _fade: ColorRect = %Fade

## Non-null while the options overlay exists, so a double click cannot stack two.
var _options_screen: Control = null
var _leaving := false


func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

	_play_button.grab_focus()
	# Coming back from a paused run must never land on a paused title screen.
	get_tree().paused = false

	_fade_in()
	_breath()


## Fade the black cover out and lift the logo in.
func _fade_in() -> void:
	_fade.color = Color(0, 0, 0, 1)
	_title_art.modulate = Color(1, 1, 1, 0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_fade, "color:a", 0.0, TITLE_FADE_TIME).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_title_art, "modulate:a", 1.0, TITLE_FADE_TIME + 0.25).set_trans(Tween.TRANS_SINE)


## Candle-light flicker on the logo. `modulate` is used rather than position
## because the logo lives in a container that owns its transform.
func _breath() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_title_art, "self_modulate", Color(0.83, 0.8, 0.78, 1), 2.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_title_art, "self_modulate", Color(1.0, 1.0, 1.0, 1), 2.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ---------------------------------------------------------------------------
# Buttons
# ---------------------------------------------------------------------------

func _on_play_pressed() -> void:
	_leave_to(RUN_SCENE)


func _on_options_pressed() -> void:
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


func _on_quit_pressed() -> void:
	_set_buttons_enabled(false)
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_OUT_TIME).set_trans(Tween.TRANS_SINE)
	await tween.finished
	get_tree().quit()


func _leave_to(scene_path: String) -> void:
	if _leaving:
		return
	_leaving = true
	_set_buttons_enabled(false)
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_OUT_TIME).set_trans(Tween.TRANS_SINE)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)


func _set_buttons_enabled(enabled: bool) -> void:
	for button in [_play_button, _options_button, _quit_button]:
		button.disabled = not enabled
