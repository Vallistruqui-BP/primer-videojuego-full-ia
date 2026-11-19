extends CharacterBody2D


@export var move_speed: float = 240.0
@export var jump_velocity: float = -360.0
@export var gravity: float = 980.0
@export var shot_scene: PackedScene
@export var move_left_action: StringName = &"move_left"
@export var move_right_action: StringName = &"move_right"
@export var jump_action: StringName = &"jump"
@export var shoot_action: StringName = &"shoot"
@export var aim_up_action: StringName = &"aim_up"
@export var aim_down_action: StringName = &"aim_down"
@export var facing: int = 1
@export var max_health: int = 1
@export var respawn_delay: float = 1.25

var _shot_cooldown := 0.0
var _health := 1
var _spawn_position := Vector2.ZERO
var _respawn_timer := 0.0


func _ready() -> void:
    _spawn_position = global_position
    _health = max_health


func _physics_process(delta: float) -> void:
    if _respawn_timer > 0.0:
        _respawn_timer -= delta
        if _respawn_timer <= 0.0:
            respawn()
        return

    _shot_cooldown = maxf(_shot_cooldown - delta, 0.0)

    if not is_on_floor():
        velocity.y += gravity * delta

    var direction := Input.get_axis(move_left_action, move_right_action)
    velocity.x = direction * move_speed
    if direction != 0.0:
        facing = int(sign(direction))

    if Input.is_action_just_pressed(jump_action) and is_on_floor():
        velocity.y = jump_velocity

    if Input.is_action_just_pressed(shoot_action) and _shot_cooldown <= 0.0:
        shoot()
        _shot_cooldown = 0.2

    move_and_slide()


func shoot() -> void:
    if shot_scene == null:
        return

    var arrow := shot_scene.instantiate()
    if arrow is Node2D:
        arrow.global_position = global_position + Vector2(facing * 12, -4)
        if arrow.has_method("launch"):
            var aim := Vector2(facing, 0)
            if Input.is_action_pressed(aim_up_action):
                aim = Vector2(facing, -0.35).normalized()
            elif Input.is_action_pressed(aim_down_action):
                aim = Vector2(facing, 0.35).normalized()
            arrow.call("launch", aim, self)
        get_tree().current_scene.add_child(arrow)


func take_hit(amount: int, knockback: Vector2) -> void:
    _health -= amount
    velocity = knockback
    if _health <= 0:
        die()


func die() -> void:
    hide()
    set_physics_process(false)
    _respawn_timer = respawn_delay


func respawn() -> void:
    global_position = _spawn_position
    velocity = Vector2.ZERO
    _health = max_health
    show()
    set_physics_process(true)
