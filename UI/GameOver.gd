extends CanvasLayer
## Run summary shown when RunState reports the player died.
##
## Both buttons clear `paused` before touching the tree, because the HUD pauses
## the game the moment this screen appears.

const MENU_SCENE := "res://UI/Menu.tscn"
const RUN_SCENE := "res://Game/Run.tscn"

@onready var _retry_button: Button = %RetryButton
@onready var _title_button: Button = %TitleButton
@onready var _rooms_value: Label = %RoomsValue
@onready var _coins_value: Label = %CoinsValue
@onready var _level_value: Label = %LevelValue
@onready var _card: Control = %Card


func _ready() -> void:
	_retry_button.pressed.connect(_retry_run)
	_title_button.pressed.connect(_quit_to_title)

	_rooms_value.text = "%02d" % RunState.rooms_entered
	_coins_value.text = str(RunState.coins)
	_level_value.text = str(RunState.level)

	_card.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_card, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	_retry_button.grab_focus()


func _retry_run() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(RUN_SCENE)


func _quit_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
