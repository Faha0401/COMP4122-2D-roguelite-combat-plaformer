extends Node
## Player preferences, persisted to user://settings.cfg and applied on startup.
##
## The project only ships a Master audio bus, so Music and SFX buses are created
## on demand the first time the options menu needs them. Audio buses live for the
## whole session, which is exactly the lifetime a settings singleton has.

signal changed()

const SAVE_PATH := "user://settings.cfg"
const EXTRA_BUSES: Array[String] = ["Music", "SFX"]

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var master_volume: float = 0.8
var music_volume: float = 0.7
var sfx_volume: float = 0.9
var fullscreen: bool = false
var vsync: bool = true
var resolution_index: int = 1

## False until the player has actually saved a preference. Display settings are
## only pushed to the window once that has happened, so a fresh install keeps
## whatever project.godot asks for instead of being forced into 1600x900.
var _persisted: bool = false


func _ready() -> void:
	_ensure_buses()
	_persisted = load_settings()
	apply_all()


## Window operations are meaningless (and can warn) under --headless, so they
## are skipped there. Audio and stored values still load normally.
func _windowless() -> bool:
	return DisplayServer.get_name() == "headless"


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func load_settings() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	master_volume = clampf(float(cfg.get_value("audio", "master", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	vsync = bool(cfg.get_value("display", "vsync", vsync))
	resolution_index = clampi(int(cfg.get_value("display", "resolution", resolution_index)),
			0, RESOLUTIONS.size() - 1)
	return true


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("display", "resolution", resolution_index)
	cfg.save(SAVE_PATH)
	_persisted = true


# ---------------------------------------------------------------------------
# Apply
# ---------------------------------------------------------------------------

func apply_all() -> void:
	apply_audio()
	if _persisted:
		apply_display()
	changed.emit()


func apply_audio() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)


func apply_display() -> void:
	if _windowless():
		return
	DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not fullscreen:
		DisplayServer.window_set_size(RESOLUTIONS[resolution_index])
		_centre_window()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume("Master", master_volume)


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume("Music", music_volume)


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume("SFX", sfx_volume)


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_display()


func set_vsync(value: bool) -> void:
	vsync = value
	apply_display()


func set_resolution_index(index: int) -> void:
	resolution_index = clampi(index, 0, RESOLUTIONS.size() - 1)
	apply_display()


func reset_to_defaults() -> void:
	master_volume = 0.8
	music_volume = 0.7
	sfx_volume = 0.9
	fullscreen = false
	vsync = true
	resolution_index = 1
	apply_all()
	save_settings()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _set_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(index, linear <= 0.001)


func _ensure_buses() -> void:
	for bus_name in EXTRA_BUSES:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")


func _centre_window() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_size(screen)
	var size := RESOLUTIONS[resolution_index]
	DisplayServer.window_set_position((screen_size - size) / 2)
