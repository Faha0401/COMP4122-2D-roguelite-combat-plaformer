extends Control
## Options overlay, shared by the title screen and the pause menu.
##
## Instantiated on top of whatever screen is already showing; it emits `closed`
## instead of swapping scenes so the caller keeps its own state. Every control
## writes straight through to Global/settings.gd, which owns persistence.
##
## The controls list is built from InputMap at runtime, so it can never drift out
## of sync with project.godot the way a hand-written table would.

signal closed()

const CARD_SECTIONS := [
	["Move_Left", "MOVE LEFT"],
	["Move_Right", "MOVE RIGHT"],
	["Jump", "JUMP"],
	["Down", "DROP / DOWN"],
	["Attack", "ATTACK"],
	["Rewind", "REWIND"],
	["Pause", "PAUSE"],
]

@onready var _fullscreen_button: Button = %FullscreenButton
@onready var _vsync_button: Button = %VsyncButton
@onready var _resolution_option: OptionButton = %ResolutionOption
@onready var _master_slider: HSlider = %MasterSlider
@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _master_value: Label = %MasterValue
@onready var _music_value: Label = %MusicValue
@onready var _sfx_value: Label = %SfxValue
@onready var _controls_grid: GridContainer = %ControlsGrid
@onready var _back_button: Button = %BackButton
@onready var _reset_button: Button = %ResetButton
@onready var _root: Control = %Card

var _closing := false


func _ready() -> void:
	_build_resolutions()
	_build_controls_list()
	_sync_from_settings()

	_fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	_vsync_button.pressed.connect(_on_vsync_pressed)
	_resolution_option.item_selected.connect(_on_resolution_selected)
	_master_slider.value_changed.connect(_on_master_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_back_button.pressed.connect(request_close)
	_reset_button.pressed.connect(_on_reset_pressed)

	_root.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
	_back_button.grab_focus()


## Called by the owner (Escape, or a "back" request) — never frees itself, the
## owner decides what happens next.
func request_close() -> void:
	if _closing:
		return
	_closing = true
	Settings.save_settings()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		request_close()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _build_resolutions() -> void:
	_resolution_option.clear()
	for size in Settings.RESOLUTIONS:
		_resolution_option.add_item("%d x %d" % [size.x, size.y])


func _build_controls_list() -> void:
	for entry in CARD_SECTIONS:
		var action_name: String = entry[0]
		var label_text: String = entry[1]

		var action_label := Label.new()
		action_label.text = label_text
		action_label.theme_type_variation = &"MutedLabel"
		_controls_grid.add_child(action_label)

		var keys := _key_labels(action_name)
		var key_label := Label.new()
		key_label.text = keys
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_controls_grid.add_child(key_label)


## Human-readable key list for an action, e.g. "A" or "A / LEFT".
func _key_labels(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "--"
	var parts: PackedStringArray = []
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var code: int = event.physical_keycode
			if code == 0:
				code = event.keycode
			parts.append(OS.get_keycode_string(code))
	return " / ".join(parts) if parts.size() > 0 else "--"


# ---------------------------------------------------------------------------
# Settings -> widgets
# ---------------------------------------------------------------------------

func _sync_from_settings() -> void:
	_fullscreen_button.text = "ON" if Settings.fullscreen else "OFF"
	_vsync_button.text = "ON" if Settings.vsync else "OFF"
	_resolution_option.select(Settings.resolution_index)
	_resolution_option.disabled = Settings.fullscreen

	_master_slider.set_value_no_signal(Settings.master_volume)
	_music_slider.set_value_no_signal(Settings.music_volume)
	_sfx_slider.set_value_no_signal(Settings.sfx_volume)
	_update_value_labels()


func _update_value_labels() -> void:
	_master_value.text = "%d%%" % roundi(Settings.master_volume * 100.0)
	_music_value.text = "%d%%" % roundi(Settings.music_volume * 100.0)
	_sfx_value.text = "%d%%" % roundi(Settings.sfx_volume * 100.0)


# ---------------------------------------------------------------------------
# Widgets -> settings
# ---------------------------------------------------------------------------

func _on_fullscreen_pressed() -> void:
	Settings.set_fullscreen(not Settings.fullscreen)
	_fullscreen_button.text = "ON" if Settings.fullscreen else "OFF"
	_resolution_option.disabled = Settings.fullscreen


func _on_vsync_pressed() -> void:
	Settings.set_vsync(not Settings.vsync)
	_vsync_button.text = "ON" if Settings.vsync else "OFF"


func _on_resolution_selected(index: int) -> void:
	Settings.set_resolution_index(index)


func _on_master_changed(value: float) -> void:
	Settings.set_master_volume(value)
	_update_value_labels()


func _on_music_changed(value: float) -> void:
	Settings.set_music_volume(value)
	_update_value_labels()


func _on_sfx_changed(value: float) -> void:
	Settings.set_sfx_volume(value)
	_update_value_labels()


func _on_reset_pressed() -> void:
	Settings.reset_to_defaults()
	_sync_from_settings()
