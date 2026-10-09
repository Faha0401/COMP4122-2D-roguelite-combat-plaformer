extends CharacterBody2D

#Player var######################################################
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
var rewind_cooldown = 0

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var Slash_area: CollisionPolygon2D = $SlashArea/CollisionPolygon2D
@onready var Dash_area: CollisionPolygon2D = $DashArea/CollisionPolygon2D
@onready var Rewind_particle: CPUParticles2D = $CPUParticles2D
@onready var Explosion_particle: CPUParticles2D = $CPUParticles2D2

#Shadow var######################################################
var Shadow: Node2D
var record_timer: float = 0.0
@onready var recorder: Node2D = $Recorder

#Player func######################################################
func _ready() -> void:
	_spawn_shadow()
	
	
func _physics_process(delta: float) -> void:
	_delta = delta
	_movement(delta)
	move_and_slide()
	_update_animation()
	_snapshot()
	_rewind()
	Shadow_cooldown()
	
func _input(event):
	if event.is_action_pressed("Attack"):
		_try_queue_attack()
	
func _movement(delta):
	direction = int(Input.get_axis("Move_Left", "Move_Right"))
	
	# Priority: Gravity > Jump = Standing > Lurch > Normal movement
	if !is_on_floor():
		velocity.y += Gravity * delta
	else:
		if Input.is_action_just_pressed("Jump"):
			velocity.y = Jump_velocity
		else: 
			velocity.y  = 0
	
	# Used delta for timer {delta = 1s/fps}
	if Lurch_timer > 0.0:
		Lurch_timer -= _delta
		velocity.x = Lurch_speed
		return # Just skip the movement on attack
	
	# So there is a short duration between the end of combo and end of lurch, it's cooler to make player static in that period
	if Lurch_timer <= 0.0 && combo_state != ComboState.NONE:
		velocity.x = 0
	
	if combo_state == ComboState.NONE:
		if direction != 0:
			_flip_player()
			velocity.x = move_toward(velocity.x, direction * Speed, Acceleration * delta)
		else:
			# I didnt allow the player to switch direction during combo
			velocity.x = move_toward(velocity.x, 0.0, Acceleration * Friction * delta)

			
func _try_queue_attack():
	# Case 1: Not in a combo — start the first slash immediately
	if combo_state == ComboState.NONE:
		_start_combo()
		return

	# Case 2: In a combo, only accept 1 combo
	if combo_window_open:
		combo_queued = true
	# Anything else: input is ignored. No queue, no animation_playeration.

func _start_combo():
	# Disable every combo_queue until the animationplayer called open combo window
	combo_queued = false
	_lurch()
	combo_state = ComboState.SLASH_1
	animation_player.play("Slash1")

# Called by animation_playerationPlayer method tracks
func open_combo_window():
# Placed AFTER the startup frames in the timeline.
	combo_window_open = true

func close_combo_window():
	combo_window_open = false

func on_combo_animation_playeration_finished():
	
	combo_window_open = false

	if combo_queued:
		combo_queued = false  # consume the buffer exactly once
		_advance_combo()
	else:
		# So there is no more combo or the under didnt input any attacks
		combo_state = ComboState.NONE
		combo_window_open = false
		combo_queued = false
		animated_sprite_2d.play("Idle")
	
# Priority Jump > Run > Idle
func _update_animation():
	if combo_state == ComboState.NONE: # Make sure attack animation plays when no attack
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
	animated_sprite_2d.flip_h = direction < 0	 # If left so direction = -1 <0 then flip_h = true
	Slash_area.scale.x = direction
	Dash_area.scale.x = direction
	face = direction # Prob gonna fix this line, could use face in general

func _Toggle_slash_collision(): # Not too sure abt this, I feel like it more convinient to use toggle but it's could break code in future
	match combo_state:
		ComboState.SLASH_1:
			Slash_area.disabled = !Slash_area.disabled
		ComboState.SLASH_2:
			Slash_area.disabled = !Slash_area.disabled
		ComboState.DASH:
			Dash_area.disabled = !Dash_area.disabled
		
func _lurch(): 
	# Init the lurch_timer 
	Lurch_speed = 300 * face
	Lurch_timer = LURCH_DURATION

func _rewind():
	if Input.is_action_just_pressed("Rewind") && Shadow!= null:
		position = Shadow.position
		animated_sprite_2d.flip_h = Shadow.animated_sprite_2d.flip_h
		animated_sprite_2d.animation = Shadow.animated_sprite_2d.animation
		Rewind_particle.emitting = true
		Explosion_particle.emitting = true
		_kill_shadow()
	
#Shadow func######################################################
func _spawn_shadow():
	recorder.init()
	Shadow = preload("res://Entity/Shadow.tscn").instantiate()
	Shadow._copy(recorder.snapshots[0])
	add_child(Shadow)
	Shadow.visible = true
	Shadow.top_level = true # !!!! Make it top level so it's a canvas item but not following the child
	rewind_cooldown = Cooldown.rewind_cooldown
	
func _kill_shadow():
	Shadow.queue_free()
	recorder._clear_cache()
	
func _snapshot():
	if Shadow != null: # Only take snapshot if not 
		# For each INTERVAL i.e. 1/30 s take a snapshot, so it's 30 fps rn, half of the default fps(60)
		# Im not sure abt the performance if i take 60 snapshot /s, i feel like as the shadow it doesnt need to be that smooth
		if record_timer < recorder.INTERVAL:
			record_timer += _delta
		record_timer = 0.0
		# Snapshot ; [{init},{null},{null},(append here)] so the shadow copies the init status on spawn, then just ignore every snapshot until the delay had passed
		
		if (recorder.snapshots[0] != null): # It's possible for the dictionary to not spawn or not init before this function calls, scheduling problem
			print("recording!", recorder.snapshots)
			Shadow._copy(recorder.snapshots[0])

func Shadow_cooldown():
	# Just a simple delta timer
	if Shadow == null:
		print("Shadow cooldown = ", rewind_cooldown)
		if rewind_cooldown > 0:
			rewind_cooldown -= _delta
			return
		print("spawned")
		_spawn_shadow()
