class_name LinkBeam
extends Node2D
## Short-lived beam VFX drawn between two fusing units the moment Vector
## Link fires. Grows in the first half of its life, fades in the second,
## with a bright midpoint burst that sells the "the two became one" beat.
## Self-frees when finished — no pool needed since links are rare.

const DURATION: float = 0.40

var _from: Vector2
var _to: Vector2
var _color: Color
var _t: float = 0.0

func setup(from: Vector2, to: Vector2, color: Color) -> void:
	_from = from
	_to = to
	_color = color
	_t = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var frac: float = _t / DURATION
	# Grow curve (first 50%) × fade curve (last 50%) → bell that peaks midway.
	var in_frac: float = clampf(frac * 2.0, 0.0, 1.0)
	var out_frac: float = clampf((frac - 0.5) * 2.0, 0.0, 1.0)
	var intensity: float = in_frac * (1.0 - out_frac)
	# Core beam.
	var core := _color
	core.a = intensity
	draw_line(_from, _to, core, 2.0 + 3.0 * intensity, true)
	# Halo beam (wider, fainter).
	var halo := _color
	halo.a = intensity * 0.35
	draw_line(_from, _to, halo, 6.0 + 8.0 * intensity, true)
	# Midpoint burst — bright pop at the fusion centre.
	var mid: Vector2 = (_from + _to) * 0.5
	var burst := _color
	burst.a = intensity
	draw_circle(mid, 4.0 + 8.0 * intensity, burst)
	var burst_halo := _color
	burst_halo.a = intensity * 0.3
	draw_circle(mid, 16.0 * intensity, burst_halo)
