extends CharacterBody2D

enum State { PATROL, CHASE, ATTACK }
var current_state: State = State.PATROL

@export var speed: float = 50.0
@export var chase_speed: float = 80.0
@export var gravity: float = 980.0

var player: Node2D = null
var direction: int = 1

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray_cast: RayCast2D = $RayCast2D
@onready var detection_zone: Area2D = $DetectionZone
@onready var attack_zone: Area2D = $AttackZone

func _ready() -> void:
	# Automatically connect signals from the Area2Ds
	detection_zone.body_entered.connect(_on_detection_zone_body_entered)
	detection_zone.body_exited.connect(_on_detection_zone_body_exited)
	
	attack_zone.body_entered.connect(_on_attack_zone_body_entered)
	attack_zone.body_exited.connect(_on_attack_zone_body_exited)

func _physics_process(delta: float) -> void:
	# 1. Apply Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# 2. State Machine Logic
	match current_state:
		State.PATROL:
			_handle_patrol()
		State.CHASE:
			_handle_chase()
		State.ATTACK:
			_handle_attack()

	# 3. Move
	move_and_slide()

# --- STATE HANDLERS ---

func _handle_patrol() -> void:
	# Flip direction if hitting a wall or edge
	if is_on_wall() or not ray_cast.is_colliding():
		direction *= -1
		ray_cast.position.x *= -1
		_update_facing()

	velocity.x = direction * speed
	_play_animation("walk")

func _handle_chase() -> void:
	if player:
		var dir_to_player = player.global_position.x - global_position.x
		direction = 1 if dir_to_player > 0 else -1
		_update_facing()
		
		velocity.x = direction * chase_speed
		_play_animation("walk")

func _handle_attack() -> void:
	velocity.x = 0 # Stop movement while swinging
	_play_animation("attack")

# --- HELPERS ---

func _update_facing() -> void:
	# Flips sprite and attack zone based on facing direction
	animated_sprite.flip_h = (direction < 0)
	attack_zone.scale.x = -1 if direction < 0 else 1

func _play_animation(anim_name: String) -> void:
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)

# --- SIGNALS ---

func _on_detection_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		if current_state != State.ATTACK:
			current_state = State.CHASE

func _on_detection_zone_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
		current_state = State.PATROL

func _on_attack_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		current_state = State.ATTACK

func _on_attack_zone_body_exited(body: Node2D) -> void:
	if body == player:
		# If player exits attack zone but remains in detection zone
		current_state = State.CHASE if player else State.PATROL
