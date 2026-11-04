class_name Chest
extends Node2D
## A chest scene.
##
## Plays an "idle" loop. When the player enters the detection Area2D it plays
## the "open" animation once (holding the final frame) and emits [signal opened].

## Emitted once the open animation has finished playing.
signal opened

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var detect_area: Area2D = $DetectArea

## If true, the chest opens as soon as the player enters the detection area.
## If false, call [method open] yourself (e.g. from an interact prompt).
@export var auto_open: bool = true
## Group used to recognise the player. Falls back to any CharacterBody2D.
@export var player_group: StringName = &"player"

## True once the chest has started opening (guards against re-opening).
var is_open: bool = false
## True while the player is inside the detection area.
var player_in_range: bool = false


func _ready() -> void:
	animated_sprite_2d.play("idle")
	detect_area.body_entered.connect(_on_detect_area_body_entered)
	detect_area.body_exited.connect(_on_detect_area_body_exited)


func _on_detect_area_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	player_in_range = true
	if auto_open:
		open()


func _on_detect_area_body_exited(body: Node2D) -> void:
	if _is_player(body):
		player_in_range = false


## Returns true if [param body] looks like the player.
func _is_player(body: Node) -> bool:
	return body.is_in_group(player_group) or body is CharacterBody2D


## Plays the open animation once and holds the final frame.
func open() -> void:
	if is_open:
		return
	is_open = true
	animated_sprite_2d.play("open")
	animated_sprite_2d.animation_finished.connect(_on_open_finished, CONNECT_ONE_SHOT)


func _on_open_finished() -> void:
	opened.emit()
