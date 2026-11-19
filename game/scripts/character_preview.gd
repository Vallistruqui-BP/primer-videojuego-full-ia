extends Control

# Reuse the player's pixel drawing, but disable all simulation and collisions.
var avatar = preload("res://scripts/office_player.gd").new()

func _ready() -> void:
 name = "CharacterPreview"
 custom_minimum_size = Vector2(0,170)
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 clip_contents = true
 add_child(avatar)
 avatar.set_physics_process(false)
 avatar.set_process_input(false)
 avatar.keyboard_enabled = false
 avatar.collision_layer = 0
 avatar.collision_mask = 0
 avatar.scale = Vector2(3,3)
 resized.connect(recenter)
 recenter()

func recenter() -> void:
 avatar.position = Vector2(floor(size.x/2),145)

func update_profile(value: Dictionary) -> void:
 avatar.profile = value.duplicate(true)
 avatar.queue_redraw()
