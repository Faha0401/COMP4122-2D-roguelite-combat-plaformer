extends CanvasLayer
## The old man's stock. Reads and writes RunState only, so the HUD behind the
## dim updates for free.
##
## While this is open the lobby pauses the tree; this layer runs with
## PROCESS_MODE_ALWAYS so its buttons keep working, and closing it restores the
## tree. It never touches the pause flag itself — the lobby owns that.

signal closed

const ITEMS := [
	{"id": "mend", "label": "MEND", "hint": "RESTORE 2 VITALITY", "cost": 10},
	{"id": "heart", "label": "IRON HEART", "hint": "+1 MAX VITALITY", "cost": 35},
	{"id": "memory", "label": "MEMORY", "hint": "+50 EXPERIENCE", "cost": 20},
]

@onready var _items_box: VBoxContainer = %Items
@onready var _status: Label = %Status
@onready var _coins: Label = %CoinsLabel
@onready var _leave: Button = %LeaveButton

var _buttons: Array[Button] = []


func _ready() -> void:
	for item in ITEMS:
		var button := Button.new()
		button.text = "%s   %d" % [item["label"], item["cost"]]
		button.tooltip_text = item["hint"]
		button.custom_minimum_size = Vector2(360, 52)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_buy.bind(item))
		_items_box.add_child(button)
		_buttons.append(button)

	_leave.pressed.connect(_close)
	RunState.resources_changed.connect(_refresh)
	RunState.progress_changed.connect(func(_a, _b, _c) -> void: _refresh())

	_status.text = "WHAT'LL IT BE, WANDERER?"
	_refresh()
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _buy(item: Dictionary) -> void:
	var cost: int = item["cost"]
	if RunState.coins < cost:
		_status.text = "NOT ENOUGH COINS"
		return

	RunState.add_coins(-cost)
	match item["id"]:
		"mend":
			RunState.heal(2)
			_status.text = "THE OLD MAN PATCHES YOU UP"
		"heart":
			RunState.set_max_health(RunState.max_hp + 1)
			RunState.heal(1)
			_status.text = "A LITTLE MORE ROOM FOR PAIN"
		"memory":
			RunState.add_xp(50)
			_status.text = "THE PAST SHARPENS"
	_refresh()


func _refresh() -> void:
	_coins.text = "COINS  %d" % RunState.coins
	for i in ITEMS.size():
		if i < _buttons.size():
			_buttons[i].disabled = RunState.coins < int(ITEMS[i]["cost"])


func _close() -> void:
	closed.emit()
