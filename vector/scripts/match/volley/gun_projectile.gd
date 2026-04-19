class_name GunProjectile
extends Node2D
## Short-life bolt fired by a Gun. Travels in a straight line until it hits
## a Square or expires. Kept simple for MVP — no piercing, no AoE yet.

var velocity: Vector2 = Vector2.ZERO
var damage: float = 2.0
var color: Color = Color("5be0ff")
var origin_is_enemy: bool = false

const LIFE_MAX: float = 1.6
var _life: float = LIFE_MAX

func _ready() -> void:
	add_to_group("volley_bolts")

func _process(delta: float) -> void:
	position += velocity * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	_check_hit()
	queue_redraw()

func _check_hit() -> void:
	var body_r: float = 10.0
	for n in get_tree().get_nodes_in_group("volley_squares"):
		var sq := n as Square
		if sq == null or not is_instance_valid(sq) or sq.hp <= 0.0:
			continue
		if global_position.distance_to(sq.global_position) <= body_r:
			sq.take_damage(damage, origin_is_enemy)
			queue_free()
			return

func _draw() -> void:
	# Head + trail streak opposite velocity.
	var glow := color
	glow.a = 0.35
	draw_circle(Vector2.ZERO, 4.0, glow)
	draw_circle(Vector2.ZERO, 2.0, color)
	if velocity.length_squared() > 0.01:
		var tail: Vector2 = -velocity.normalized() * 10.0
		var trail := color
		trail.a = 0.45
		draw_line(Vector2.ZERO, tail, trail, 2.0, true)
