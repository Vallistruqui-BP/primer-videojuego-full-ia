extends Area2D


@export var speed: float = 520.0
@export var lifetime: float = 3.0
@export var damage: int = 1

var _velocity := Vector2.ZERO
var _owner: Node = null
var _stuck := false


func launch(direction: Vector2, owner: Node) -> void:
    _velocity = direction.normalized() * speed
    _owner = owner


func _ready() -> void:
    body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
    if _stuck:
        return
    position += _velocity * delta
    lifetime -= delta
    if lifetime <= 0.0:
        queue_free()


func _on_body_entered(body: Node) -> void:
    if body == _owner:
        return
    if body.has_method("take_hit"):
        body.call("take_hit", damage, _velocity * 0.35)
    _stuck = true
    _velocity = Vector2.ZERO
    set_deferred("monitoring", false)
    set_deferred("monitorable", false)
