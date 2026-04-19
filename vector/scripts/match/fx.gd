class_name FX
extends Node2D
## Expanding-ring explosion FX. Spawned on melee detonation, pulse shockwave,
## base-square destruction. Lives `duration` seconds then self-frees.

var world_pos: Vector2 = Vector2.ZERO
var max_radius: float = 40.0
var duration: float = 0.5
var color: Color = Color(1, 1, 1)
var _t: float = 0.0

func setup(at: Vector2, radius: float, c: Color, dur: float = 0.5) -> void:
	world_pos = at
	max_radius = radius
	color = c
	duration = dur
	position = Pseudo3D.project(world_pos)
	var s := Pseudo3D.scale_at(world_pos.y)
	scale = Vector2.ONE * s * GameConfig.data.unit_display_scale

func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var p: float = _t / duration
	var r: float = lerpf(0.0, max_radius, p)
	var alpha: float = lerpf(0.85, 0.0, p)
	# Outer glow halo.
	var glow := color
	glow.a = alpha * 0.25
	draw_arc(Vector2.ZERO, r * 1.2, 0.0, TAU, 48, glow, 5.0, true)
	# Main stroke ring.
	var ring := color
	ring.a = alpha
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, ring, 2.0, true)
	# Inner filled flash.
	var fill := color
	fill.a = alpha * 0.3
	draw_circle(Vector2.ZERO, r * 0.5, fill)
