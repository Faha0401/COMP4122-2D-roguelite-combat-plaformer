extends Node2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var blast: Area2D = $Blast

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# A little fate in transition
	var tween = create_tween()
	modulate.a = 0
	tween.tween_property(self, "modulate:a", 0.3, 1.0)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	
func _copy(dict: Dictionary):
	# We dont copy nth
	if dict.is_empty():
		return
	
	position = dict["position"]
	if animated_sprite_2d != null : # It will be null if the sprite has not spawn but the script is running
		if animated_sprite_2d.animation != dict["animation"]:
			animated_sprite_2d.animation = dict["animation"] # Prevent the animation replaying, prob dont need this if frame is used instead of just animation
		animated_sprite_2d.flip_h = dict["flip_h"]
	print("cur = ", position, " shadow = ", dict["position"])
	
func _blast():
	 # Prob also group the blast collision into damage_area act exactly like normal attacks
	pass
	
# For the damage in the return path, prob gonna draw a collision shadow or just draw a line on top and bot of the shadow and player, i will figure out how does the collision polyu works in changing the global points
