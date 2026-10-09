extends Node2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var blast: Area2D = $Blast

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func _copy(dict: Dictionary):
	if dict.is_empty():
		return
	position = dict["position"]
	if animated_sprite_2d != null : #it will be null for some reason
		if animated_sprite_2d.animation != dict["animation"]:
			animated_sprite_2d.animation = dict["animation"] #prevent the animation replaying
		animated_sprite_2d.flip_h = dict["flip_h"]
	print("cur = ", position, "dict = ", dict["position"])
	
func _blast():
	var blast = "Blast!"
	pass
	
