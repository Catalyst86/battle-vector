class_name Silhouettes
extends RefCounted
## Procedural vector silhouette library for Vector Battles "pieces" — every
## placeable mob and stationary tower. A card opts into a silhouette via
## `CardData.silhouette_id`; when set, `Unit._draw()` routes rendering here
## instead of the generic primitive shape. When not set the piece falls back
## to the original `ShapeRenderer` behaviour — rollout is card-by-card.
##
## ## Why a library, not per-card scripts
##
## Data-driven editability: new pieces are added by (a) writing a
## `_draw_<id>` function here, (b) adding the id to `IDS`, (c) setting
## `silhouette_id` on the card's .tres. No scene edits, no subclassing.
##
## ## Style vocabulary (keep silhouettes coherent across the 29 pieces)
##
##   - Three stroke weights only: **1.8 px primary / 1.2 px secondary /
##     0.8 px detail**. Don't invent intermediate widths; the rhythm breaks
##     if every piece has its own scale.
##   - Max ~6-8 drawn elements. Past that it reads busy at 24 px.
##   - Fit inside a `size * 2` bounding box — matches the existing collision
##     radius so the silhouette always stays within the card's footprint.
##   - One procedural motion at **3-8 Hz** per piece (wings flap, turbines
##     spin, exhaust pulse). Faster than 10 Hz reads as jitter on mobile.
##   - Build in asymmetry on purpose — a wing 5 % longer, a fin offset by
##     one pixel. That's what sells "designed" over "generated."
##
## ## Animation model
##
## Each silhouette function takes a `t` param (the unit's age in seconds).
## All motion is derived from `t` via sin/cos — no tweens, no state. A
## given (id, t, size) always produces the same frame so screenshots and
## replays are deterministic.
##
## ## Fake bloom
##
## The dispatcher calls the silhouette three times — halo → mid → core —
## with widening strokes and lower alpha, same pattern as
## `ShapeRenderer.draw_with_glow`. Individual silhouettes accept a
## `stroke_mult` param and scale their line widths accordingly so the
## bloom is automatic.

## Canonical list of registered silhouette ids — `has()` checks against
## this and `_dispatch()` matches on it. Add to this array when you land a
## new silhouette.
const IDS: Array[StringName] = [
	&"dart",
]

static func has(id: StringName) -> bool:
	return IDS.has(id)

## Draws the silhouette with the triple-pass fake-bloom wrapper. `facing`
## (radians) rotates the whole silhouette — use it so enemy-side pieces
## point at their destination. `t` drives procedural animation.
static func draw(ci: CanvasItem, id: StringName, color: Color, size: float, t: float, facing: float = 0.0) -> void:
	if not IDS.has(id):
		return
	ci.draw_set_transform(Vector2.ZERO, facing, Vector2.ONE)
	_dispatch(ci, id, _with_alpha(color, 0.12), size, t, 3.0)
	_dispatch(ci, id, _with_alpha(color, 0.30), size, t, 1.8)
	_dispatch(ci, id, color, size, t, 1.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _with_alpha(c: Color, mult: float) -> Color:
	var out := c
	out.a *= mult
	return out

static func _dispatch(ci: CanvasItem, id: StringName, color: Color, size: float, t: float, stroke_mult: float) -> void:
	match id:
		&"dart": _draw_dart(ci, color, size, t, stroke_mult)

# ─── Silhouettes ──────────────────────────────────────────────────────────

## DART — sleek interceptor jet. Nose-up in local space, swept delta wings,
## pulsing afterburner. Subtle wing flap + slight asymmetric bank sell the
## "in flight" read. Designed to be recognisable at 20 px.
static func _draw_dart(ci: CanvasItem, color: Color, size: float, t: float, sw: float) -> void:
	var flap: float = sin(t * 7.0) * size * 0.035
	var burn: float = 0.55 + 0.45 * sin(t * 18.0)

	# Fuselage spine — primary stroke, nose to tail.
	ci.draw_line(
		Vector2(0, -size * 0.95),
		Vector2(0,  size * 0.70),
		color, 1.8 * sw, true)

	# Cockpit canopy — small diamond detail near the nose.
	var cp: PackedVector2Array = PackedVector2Array([
		Vector2(0,            -size * 0.70),
		Vector2(size * 0.08,  -size * 0.55),
		Vector2(0,            -size * 0.40),
		Vector2(-size * 0.08, -size * 0.55),
		Vector2(0,            -size * 0.70),
	])
	ci.draw_polyline(cp, color, 0.8 * sw, true)

	# Swept wings — secondary stroke. Right wing +3 % length and −0.02 flap
	# offset so the jet banks slightly. Reads as intentional, not accidental.
	var wing_root: Vector2 = Vector2(0, -size * 0.02)
	ci.draw_line(wing_root, Vector2(-size * 0.72,  size * 0.25 + flap),      color, 1.4 * sw, true)
	ci.draw_line(wing_root, Vector2( size * 0.78,  size * 0.23 - flap * 0.9), color, 1.4 * sw, true)

	# Tail fins — small rearward V in secondary stroke.
	ci.draw_line(Vector2(0, size * 0.50), Vector2(-size * 0.20, size * 0.70), color, 1.2 * sw, true)
	ci.draw_line(Vector2(0, size * 0.50), Vector2( size * 0.20, size * 0.70), color, 1.2 * sw, true)

	# Afterburner — pulsing core + halo circle behind the tail. The halo
	# extends slightly past the fuselage tip so the jet feels like it's
	# leaving exhaust behind it, not dragging it.
	var flare := color
	flare.a = color.a * burn
	ci.draw_circle(Vector2(0, size * 0.88), 2.4 * sw, flare)
	var halo := color
	halo.a = color.a * burn * 0.35
	ci.draw_circle(Vector2(0, size * 0.94), 4.2 * sw, halo)
