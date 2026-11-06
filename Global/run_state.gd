extends Node
## Single source of truth for every number the in-run HUD displays.
##
## The UI layer never owns gameplay values: the HUD only listens to the signals
## below, so gameplay code (combat, pickups, the run generator) can change these
## numbers without knowing the HUD exists. Reset happens once per run from
## Game/scene_manager.gd, which is the only place a run actually starts.
##
## Hooks that exist today:
##   * Entity/enemy.gd calls damage() when its attack zone touches the player.
##   * Game/scene_manager.gd calls enter_room() for every room transition.
## Everything else (coins, gems, shards, xp) is exposed for the shop / chest /
## enemy drops that are still on the roadmap — nothing needs to change in the
## HUD to start feeding it.

signal health_changed(hp: int, max_hp: int)
signal resources_changed()
signal progress_changed(level: int, xp: int, xp_required: int)
signal run_started()
signal run_ended()

const MAX_HEALTH := 5
const XP_PER_LEVEL := 100
## Seconds of invulnerability after a hit, so one touch never drains the bar.
const IFRAME_TIME := 0.9

var max_hp: int = MAX_HEALTH
var hp: int = MAX_HEALTH
var coins: int = 0
var gems: int = 0
var shards: int = 0
var level: int = 1
var xp: int = 0
var xp_required: int = XP_PER_LEVEL
var rooms_entered: int = 0

var is_run_active: bool = false

var _iframe: float = 0.0


func _process(delta: float) -> void:
	if _iframe > 0.0:
		_iframe = maxf(0.0, _iframe - delta)


# ---------------------------------------------------------------------------
# Run lifecycle
# ---------------------------------------------------------------------------

func start_run() -> void:
	is_run_active = true
	max_hp = MAX_HEALTH
	hp = max_hp
	coins = 0
	gems = 0
	shards = 0
	level = 1
	xp = 0
	xp_required = XP_PER_LEVEL
	rooms_entered = 0
	_iframe = 0.0
	_emit_all()
	run_started.emit()


func end_run() -> void:
	if not is_run_active:
		return
	is_run_active = false
	run_ended.emit()


func enter_room() -> void:
	rooms_entered += 1


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

## Returns true when the hit landed. False during i-frames, after death, or
## while no run is active.
func damage(amount: int = 1) -> bool:
	if amount <= 0 or not is_run_active or hp <= 0:
		return false
	if _iframe > 0.0:
		return false
	_iframe = IFRAME_TIME
	hp = clampi(hp - amount, 0, max_hp)
	health_changed.emit(hp, max_hp)
	if hp == 0:
		end_run()
	return true


func heal(amount: int = 1) -> void:
	if amount <= 0 or hp <= 0:
		return
	hp = clampi(hp + amount, 0, max_hp)
	health_changed.emit(hp, max_hp)


func set_max_health(value: int) -> void:
	max_hp = maxi(1, value)
	hp = mini(hp, max_hp)
	health_changed.emit(hp, max_hp)


# ---------------------------------------------------------------------------
# Resources
# ---------------------------------------------------------------------------

func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	resources_changed.emit()


func add_gems(amount: int) -> void:
	gems = maxi(0, gems + amount)
	resources_changed.emit()


func add_shards(amount: int) -> void:
	shards = maxi(0, shards + amount)
	resources_changed.emit()


# ---------------------------------------------------------------------------
# Progression
# ---------------------------------------------------------------------------

func add_xp(amount: int) -> void:
	xp += maxi(0, amount)
	while xp >= xp_required:
		xp -= xp_required
		level += 1
		xp_required = XP_PER_LEVEL + (level - 1) * 25
	progress_changed.emit(level, xp, xp_required)


func _emit_all() -> void:
	health_changed.emit(hp, max_hp)
	resources_changed.emit()
	progress_changed.emit(level, xp, xp_required)
