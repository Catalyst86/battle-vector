class_name Square
extends Node2D
## Target unit for VOLLEY mode. Spawns at the midline and descends toward
## one of the two guns. Destroyed by gun bolts or units; credits kills to
## the shooter. If it reaches the far edge on the destined player's side,
## the OTHER player gets a "defense miss" kill credit — creates lane-
## pressure tension.
##
## MVP: Standard tier only. Fast / Armored / Elite / Boss come later (same
## script, different HP + speed + score).

signal destroyed(killer_is_enemy: bool, score: int)
signal escaped(to_side_is_enemy: bool, score: int)

enum Tier { STANDARD, FAST, ARMORED, ELITE, BOSS }

const STATS: Dictionary = {
	Tier.STANDARD: {"hp": 4.0,   "speed": 1.0, "score": 1,  "size": 10.0, "color": Color("5be0ff")},
	Tier.FAST:     {"hp": 2.0,   "speed": 1.8, "score": 2,  "size": 8.0,  "color": Color("4dffa8")},
	Tier.ARMORED:  {"hp": 12.0,  "speed": 0.7, "score": 3,  "size": 12.0, "color": Color("b8c7d6")},
	Tier.ELITE:    {"hp": 40.0,  "speed": 0.5, "score": 5,  "size": 14.0, "color": Color("b56cff")},
	Tier.BOSS:     {"hp": 120.0, "speed": 0.3, "score": 10, "size": 18.0, "color": Color("ff4d8d")},
}

@export var tier: Tier = Tier.STANDARD
## Which side this square is heading to; controls descent direction +
## determines who owns a "defense miss" if it escapes.
@export var bound_for_enemy: bool = false
## Base descent speed (px/sec). Multiplied by tier speed factor.
@export var base_speed: float = 70.0

var hp: float = 4.0
var _score: int = 1
var _size: float = 10.0
var _color: Color = Color("5be0ff")
var _velocity: Vector2 = Vector2(0, 1)
var _max_hp: float = 4.0
var _hit_flash: float = 0.0
var _age: float = 0.0

func _ready() -> void:
	add_to_group("volley_squares")
	var s: Dictionary = STATS[tier]
	hp = float(s.hp)
	_max_hp = hp
	_score = int(s.score)
	_size = float(s.size)
	_color = s.color
	_velocity = Vector2(0, (1.0 if bound_for_enemy == false else -1.0) * base_speed * float(s.speed))

func take_damage(amount: float, from_enemy: bool) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	_hit_flash = 1.0
	if hp <= 0.0:
		destroyed.emit(from_enemy, _score)
		queue_free()

func _process(delta: float) -> void:
	_age += delta
	_hit_flash = maxf(0.0, _hit_flash - delta * 8.0)
	position += _velocity * delta
	queue_redraw()

## Called by the match coordinator when we've crossed the far edge on the
## side we were heading to. Credits the opposite player ("you failed to
## defend; opponent gets the miss-bonus").
func trigger_escape() -> void:
	if hp <= 0.0:
		return
	escaped.emit(bound_for_enemy, _score)
	queue_free()

func _draw() -> void:
	var body := _color
	var flash: float = _hit_flash
	var fill := body
	fill.a = 0.16 + 0.25 * flash
	var border := body
	border.a = 0.85 + 0.15 * flash
	if flash > 0.2:
		border = border.lerp(Color(1, 1, 1, 1), flash * 0.7)
	# Body — square rotated 0 or 45° depending on tier, so elites stand out.
	var pts: PackedVector2Array
	if tier == Tier.ELITE or tier == Tier.BOSS:
		# Diamond for prestige
		pts = PackedVector2Array([
			Vector2(0, -_size), Vector2(_size, 0), Vector2(0, _size), Vector2(-_size, 0)
		])
	else:
		pts = PackedVector2Array([
			Vector2(-_size, -_size), Vector2(_size, -_size),
			Vector2(_size, _size), Vector2(-_size, _size)
		])
	var loop := pts.duplicate(); loop.append(pts[0])
	draw_colored_polygon(pts, fill)
	draw_polyline(loop, border, 1.5, true)
	# Armored / elite / boss get a second inner outline
	if tier == Tier.ARMORED or tier == Tier.ELITE or tier == Tier.BOSS:
		var inner := pts.duplicate()
		for i in inner.size():
			inner[i] *= 0.55
		inner.append(inner[0])
		draw_polyline(inner, border, 1.0, true)
	# HP bar (only if damaged)
	if hp < _max_hp and _max_hp > 0.0:
		var w: float = _size * 2.0
		var y: float = _size + 4.0
		var frac: float = clampf(hp / _max_hp, 0.0, 1.0)
		draw_rect(Rect2(-w * 0.5, y, w, 2), Color(0, 0, 0, 0.5), true)
		draw_rect(Rect2(-w * 0.5, y, w * frac, 2), body, true)
