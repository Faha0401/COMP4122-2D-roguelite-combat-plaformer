extends CharacterBody2D

enum ComboState { NONE, SLASH_1, SLASH_2, DASH }
var combo_state: ComboState = ComboState.NONE
var combo_window_open: bool = false
var combo_queued: bool = false 
var direction: int = 1
var Speed: float = 300
var Jump_velocity: float = -400
var Gravity: float = 1000
var Acceleration: float = 1000
var Friction: float = 2
var Lurch_timer: float = 0
var Lurch_speed: float = 0
const LURCH_DURATION: float = 0.08
var _delta: float = 0
var face = 1

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var Slash_area: CollisionPolygon2D = $SlashArea/CollisionPolygon2D
@onready var Dash_area: CollisionPolygon2D = $DashArea/CollisionPolygon2D


func _physics_process(delta: float) -> void:
	_delta = delta
	_movement(delta)
	move_and_slide()
	_update_animation()
	
func _input(event):
	if event.is_action_pressed("Attack"):
		_try_queue_attack()
	
func _movement(delta):
	direction = Input.get_axis("Move_Left", "Move_Right")
	if !is_on_floor():
		velocity.y += Gravity * delta
	else:
		if Input.is_action_just_pressed("Jump"):
			velocity.y = Jump_velocity
		else: 
			velocity.y  = 0
	
	if Lurch_timer > 0.0:
		Lurch_timer -= _delta
		velocity.x = Lurch_speed
		return # Just skip the movement on attack
	
	if Lurch_timer <= 0.0 && combo_state != ComboState.NONE:
		velocity.x = 0
	
	if combo_state == ComboState.NONE:
		if direction != 0:
			_flip_player()
			velocity.x = move_toward(velocity.x, direction * Speed, Acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, Acceleration * Friction * delta)
			
func _try_queue_attack():
# Case 1: Not in a combo — start the first slash immediately
	if combo_state == ComboState.NONE:
		_start_combo()
		return

	# Case 2: In a combo — only accept if:
	#   - the combo window is open (startup frames are over)
	#   - the buffer is empty (prevents spam accumulation)
	if combo_window_open:
		combo_queued = true

# Anything else: input is ignored. No queue, no animation_playeration, no effect.
func _start_combo():
	_lurch()
	combo_state = ComboState.SLASH_1
	combo_queued = false
	animation_player.play("Slash1")

# --- Called by animation_playerationPlayer method tracks
func open_combo_window():
# Placed AFTER the startup frames in the timeline.
# Before this fires, combo_window_open is false, so input is rejected.
	combo_window_open = true

func close_combo_window():
	combo_window_open = false

func on_combo_animation_playeration_finished():
	
	combo_window_open = false

	if combo_queued:
		combo_queued = false  # consume the buffer exactly once
		_advance_combo()
	else:
		combo_state = ComboState.NONE
		combo_window_open = false
		combo_queued = false
		animated_sprite_2d.play("Idle")
	
# Priority Jump > Run > Idle
func _update_animation():
	if combo_state == ComboState.NONE: #make sure attack animation plays when no attack
		if is_on_floor():
			if (abs(velocity.x) > Friction): # So the animation keeps playing and stop at the stop friction 
				animated_sprite_2d.play("Run")
			else :
				animated_sprite_2d.play("Idle")
		else:
			animated_sprite_2d.play("Jump")

func _advance_combo():
	_lurch()
	match combo_state:
		ComboState.SLASH_1:
			combo_state = ComboState.SLASH_2
			animation_player.play("Slash2")
			animated_sprite_2d.play("Slash2")
		ComboState.SLASH_2:
			combo_state = ComboState.DASH
			animation_player.play("Dash")
			animated_sprite_2d.play("Dash")
		ComboState.DASH:	
			combo_state = ComboState.NONE
			combo_window_open = false
			combo_queued = false
			animated_sprite_2d.play("Idle")

	
func _flip_player():
	animated_sprite_2d.flip_h = direction < 0	 #If left so direction = -1 <0 then flip_h = true
	Slash_area.scale.x = direction
	Dash_area.scale.x = direction
	face = direction

func _Toggle_slash_collision():
	match combo_state:
		ComboState.SLASH_1:
			Slash_area.disabled = !Slash_area.disabled
			print("Toggled! ", Slash_area.disabled)
		ComboState.SLASH_2:
			Slash_area.disabled = !Slash_area.disabled
			print("Toggled! ", Slash_area.disabled)
		ComboState.DASH:
			Dash_area.disabled = !Dash_area.disabled
			print("Toggled! ", Dash_area.disabled)
		
func _lurch():
	Lurch_speed = 300 * face
	Lurch_timer = LURCH_DURATION
	
