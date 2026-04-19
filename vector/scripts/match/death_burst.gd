class_name DeathBurst
extends Node2D
## Short-lived particle burst spawned when a unit dies. 8 fragments radiate
## outward, fading over 0.4s. Projected once at spawn then drawn in local
## space — cheap and readable on the mobile compat renderer.

const FRAGMENT_COUNT := 8
const LIFE: float = 0.45
const SPEED_MIN: float = 30.0
const SPEED_MAX: float = 90.0

var world_pos: Vector2
var color: Color = Color(1, 1, 1)
var _t: float = 0.0
var _dirs: PackedVector2Array = PackedVector2Array()
var _speeds: PackedFloat32Array = PackedFloat32Array()

func setup(at: Vector2, c: Color) -> void:
	world_pos = at
	color = c
	_dirs.clear()
	_speeds.clear()
	for i in FRAGMENT_COUNT:
		var angle: float = randf() * TAU
		_dirs.append(Vector2(cos(angle), sin(angle)))
		_speeds.append(randf_range(SPEED_MIN, SPEED_MAX))
	position = Pseudo3D.project(world_pos)
	var s := Pseudo3D.scale_at(world_pos.y)
	scale = Vector2.ONE * s * GameConfig.data.unit_display_scale

func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var progress: float = _t / LIFE
	var alpha: float = 1.0 - progress
	var ease: float = 1.0 - pow(1.0 - progress, 2.0)  # ease-out
	var radius: float = 2.2 * (1.0 - progress * 0.5)
	for i in _dirs.size():
		var offset: Vector2 = _dirs[i] * (_speeds[i] * ease * LIFE)
		var c: Color = color
		c.a = alpha
		draw_circle(offset, radius, c)
		# Faint leading streak
		var tail: Color = color
		tail.a = alpha * 0.25
		draw_line(offset * 0.5, offset, tail, 1.2, true)
