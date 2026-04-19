class_name ShapeRenderer
extends RefCounted
## Pure draw helpers for the 8 vector shapes. Called from any CanvasItem's
## _draw(). `draw()` is the legacy single-pass entry; `draw_with_glow()` does
## three passes (soft halo → mid ring → crisp core) to fake bloom without
## requiring a post-process shader — works on the mobile compat renderer.

static func draw(ci: CanvasItem, shape: int, color: Color, size: float, rot: float = 0.0) -> void:
	_stroke(ci, shape, color, size, maxf(1.4, size * 0.12), rot)

## Preferred renderer for units / projectiles / preview — visibly neon.
static func draw_with_glow(ci: CanvasItem, shape: int, color: Color, size: float, rot: float = 0.0, intensity: float = 1.0) -> void:
	var core_w: float = maxf(1.4, size * 0.12)
	# Outer soft halo.
	var halo := color
	halo.a = 0.12 * intensity
	_stroke(ci, shape, halo, size, core_w * 3.0, rot)
	# Mid ring.
	var mid := color
	mid.a = 0.30 * intensity
	_stroke(ci, shape, mid, size, core_w * 1.8, rot)
	# Crisp core.
	_stroke(ci, shape, color, size, core_w, rot)

static func _stroke(ci: CanvasItem, shape: int, color: Color, size: float, stroke_w: float, rot: float) -> void:
	var t := Transform2D().rotated(rot)
	match shape:
		CardData.Shape.TRIANGLE:
			_poly(ci, t, [Vector2(0, -size), Vector2(size * 0.9, size * 0.7), Vector2(-size * 0.9, size * 0.7)], color, stroke_w, true)
		CardData.Shape.SQUARE:
			var r := size * 0.8
			_poly(ci, t, [Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)], color, stroke_w, true)
		CardData.Shape.DIAMOND:
			_poly(ci, t, [Vector2(0, -size), Vector2(size * 0.7, 0), Vector2(0, size), Vector2(-size * 0.7, 0)], color, stroke_w, true)
		CardData.Shape.CIRCLE:
			ci.draw_arc(Vector2.ZERO, size * 0.85, 0.0, TAU, 48, color, stroke_w, true)
		CardData.Shape.RING:
			ci.draw_arc(Vector2.ZERO, size * 0.85, 0.0, TAU, 48, color, stroke_w, true)
			var faded := color
			faded.a *= 0.6
			ci.draw_arc(Vector2.ZERO, size * 0.45, 0.0, TAU, 32, faded, stroke_w, true)
		CardData.Shape.STAR:
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(10):
				var r := size if (i % 2 == 0) else size * 0.45
				var a := i * PI / 5.0 - PI * 0.5
				pts.append(Vector2(cos(a) * r, sin(a) * r))
			_poly(ci, t, pts, color, stroke_w, true)
		CardData.Shape.CHEVRON:
			_polyline(ci, t, [Vector2(-size * 0.8, -size * 0.3), Vector2(0, size * 0.5), Vector2(size * 0.8, -size * 0.3)], color, stroke_w)
		CardData.Shape.SPIRAL:
			var sp: PackedVector2Array = PackedVector2Array()
			for i in range(40):
				var a := i * 0.35
				var r := (float(i) / 40.0) * size
				sp.append(Vector2(cos(a) * r, sin(a) * r))
			_polyline(ci, t, sp, color, stroke_w)

static func _poly(ci: CanvasItem, t: Transform2D, points, color: Color, sw: float, close: bool) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for p in points:
		pts.append(t * p)
	if close:
		pts.append(pts[0])
	ci.draw_polyline(pts, color, sw, true)

static func _polyline(ci: CanvasItem, t: Transform2D, points, color: Color, sw: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for p in points:
		pts.append(t * p)
	ci.draw_polyline(pts, color, sw, true)
