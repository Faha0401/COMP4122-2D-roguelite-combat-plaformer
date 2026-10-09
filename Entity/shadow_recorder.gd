extends Node

const INTERVAL: float = 1.0/30.0
const DELAY: float = 3.0
var size : int = 90 # 3s = INTERVAL*3 = 90
var snapshots :Array = []
var timer : float = 0.0

@onready var animated_sprite_2d: AnimatedSprite2D = $"../AnimatedSprite2D"
@onready var player: CharacterBody2D 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player = get_parent()
	snapshots.resize(size) 

	snapshots[0] = {
		"position": player.global_position,
		"animation": animated_sprite_2d.animation,
		"flip_h": animated_sprite_2d.flip_h
	}


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	timer += delta
	if timer < INTERVAL: # Not yet enough frame before a snapshot
		return
	timer = 0.0
	_record()

func _record():
	snapshots.append({
		"position": player.position,
		"animation": animated_sprite_2d.animation,
		"flip_h": animated_sprite_2d.flip_h
	})
	if snapshots.size() > size:
		snapshots.pop_front()
