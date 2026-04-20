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
	&"bomb",
	&"spiral",
	&"burst",
	&"lance",
	&"orb",
	&"scout",
	&"pulse",
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
		&"dart":   _draw_dart(ci, color, size, t, stroke_mult)
		&"bomb":   _draw_bomb(ci, color, size, t, stroke_mult)
		&"spiral": _draw_spiral(ci, color, size, t, stroke_mult)
		&"burst":  _draw_burst(ci, color, size, t, stroke_mult)
		&"lance":  _draw_lance(ci, color, size, t, stroke_mult)
		&"orb":    _draw_orb(ci, color, size, t, stroke_mult)
		&"scout":  _draw_scout(ci, color, size, t, stroke_mult)
		&"pulse":  _draw_pulse(ci, color, size, t, stroke_mult)

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

## BOMB — warhead rocket. Tapered nose, body with a midsection seam band,
## tail fins, flickering exhaust flame. Biggest default-deck piece (size
## 20) so an extra detail (the seam) is affordable without crowding.
static func _draw_bomb(ci: CanvasItem, color: Color, size: float, t: float, sw: float) -> void:
	var flame: float = 0.7 + 0.3 * sin(t * 22.0 + cos(t * 7.0))
	var wobble: float = sin(t * 2.5) * size * 0.02
	var w: float = size * 0.28

	# Nose cone — triangle from shoulders to tip.
	var nose: PackedVector2Array = PackedVector2Array([
		Vector2(-w + wobble, -size * 0.45),
		Vector2(wobble,      -size * 0.95),
		Vector2(w + wobble,  -size * 0.45),
	])
	ci.draw_polyline(nose, color, 1.8 * sw, true)

	# Body — rectangle outline, primary stroke.
	var body: PackedVector2Array = PackedVector2Array([
		Vector2(-w + wobble, -size * 0.45),
		Vector2(w + wobble,  -size * 0.45),
		Vector2(w + wobble,   size * 0.35),
		Vector2(-w + wobble,  size * 0.35),
		Vector2(-w + wobble, -size * 0.45),
	])
	ci.draw_polyline(body, color, 1.8 * sw, true)

	# Seam band — short horizontal line mid-body, detail stroke.
	ci.draw_line(
		Vector2(-w + wobble, -size * 0.05),
		Vector2( w + wobble, -size * 0.05),
		color, 0.8 * sw, true)

	# Tail fins — two outer right-angle fins in secondary stroke.
	ci.draw_line(Vector2(-w, size * 0.35),       Vector2(-w * 1.9, size * 0.62), color, 1.2 * sw, true)
	ci.draw_line(Vector2(-w * 1.9, size * 0.62), Vector2(-w,       size * 0.62), color, 1.2 * sw, true)
	ci.draw_line(Vector2( w, size * 0.35),       Vector2( w * 1.9, size * 0.62), color, 1.2 * sw, true)
	ci.draw_line(Vector2( w * 1.9, size * 0.62), Vector2( w,       size * 0.62), color, 1.2 * sw, true)

	# Flame — flickering triangle below the fins, pulsing alpha.
	var flame_c := color
	flame_c.a = color.a * flame
	var flame_tip: float = size * (0.88 + 0.08 * sin(t * 26.0))
	var flame_pts: PackedVector2Array = PackedVector2Array([
		Vector2(-w * 0.7, size * 0.62),
		Vector2( 0,        flame_tip),
		Vector2( w * 0.7, size * 0.62),
	])
	ci.draw_polyline(flame_pts, flame_c, 1.4 * sw, true)
	var flame_halo := color
	flame_halo.a = color.a * flame * 0.3
	ci.draw_circle(Vector2(0, size * 0.78), 3.2 * sw, flame_halo)

## SPIRAL — drill. Vertical cone with helical stripes that scroll along
## the body, fake-rotation from 2D. Tip spark reads as friction sparks on
## contact with walls.
static func _draw_spiral(ci: CanvasItem, color: Color, size: float, t: float, sw: float) -> void:
	var spin: float = fmod(t * 0.9, 1.0)

	# Cone body — triangle outline, primary stroke.
	var cone: PackedVector2Array = PackedVector2Array([
		Vector2(-size * 0.5,  size * 0.6),
		Vector2( 0,          -size * 0.9),
		Vector2( size * 0.5,  size * 0.6),
		Vector2(-size * 0.5,  size * 0.6),
	])
	ci.draw_polyline(cone, color, 1.8 * sw, true)

	# Helical stripes — 3 short diagonals that slide up the cone with spin.
	# Each stripe narrows as it climbs (cone tapers) so the drill reads as
	# actually spinning, not as three static bars.
	for i in 3:
		var offset: float = fmod(spin + float(i) * 0.33, 1.0)
		var y: float = lerpf(size * 0.55, -size * 0.78, offset)
		var w: float = lerpf(size * 0.42, size * 0.06, offset)
		ci.draw_line(
			Vector2(-w,         y),
			Vector2( w * 0.85,  y - size * 0.08),
			color, 0.8 * sw, true)

	# Base ring — short horizontal accent at the bottom.
	ci.draw_line(
		Vector2(-size * 0.55, size * 0.6),
		Vector2( size * 0.55, size * 0.6),
		color, 1.2 * sw, true)

	# Tip sparks — flashing dot.
	var spark := color
	spark.a = color.a * (0.3 + 0.5 * abs(sin(t * 13.0)))
	ci.draw_circle(Vector2(0, -size * 0.93), 1.4 * sw, spark)

## BURST — lean chaser. Spearhead body, twin side thrusters with pulsing
## flare tails. Shorter nose than the dart so it reads "aggressor" rather
## than "patrol."
static func _draw_burst(ci: CanvasItem, color: Color, size: float, t: float, sw: float) -> void:
	var boost: float = 0.5 + 0.5 * sin(t * 12.0)

	# Spearhead body — elongated diamond.
	var spear: PackedVector2Array = PackedVector2Array([
		Vector2( 0,            -size * 0.95),
		Vector2( size * 0.4,    0),
		Vector2( 0,             size * 0.4),
		Vector2(-size * 0.4,    0),
		Vector2( 0,            -size * 0.95),
	])
	ci.draw_polyline(spear, color, 1.8 * sw, true)

	# Twin outboard thrusters — short vertical rails flanking the body.
	ci.draw_line(Vector2(-size * 0.5, -size * 0.05), Vector2(-size * 0.5, size * 0.3), color, 1.2 * sw, true)
	ci.draw_line(Vector2( size * 0.5, -size * 0.05), Vector2( size * 0.5, size * 0.3), color, 1.2 * sw, true)

	# Core dot.
	ci.draw_circle(Vector2(0, -size * 0.2), 1.1 * sw, color)

	# Thruster flares — pulsing dots trailing each thruster.
	var flare := color
	flare.a = color.a * boost
	ci.draw_circle(Vector2(-size * 0.5, size * 0.45), 1.8 * sw, flare)
	ci.draw_circle(Vector2( size * 0.5, size * 0.45), 1.8 * sw, flare)

## LANCE — stationary rail-gun tower. Wide base, support column, long
## barrel, two rail coils, charge glow at the muzzle. The silhouette
## reads "tower" in contrast to the mobile jet/chaser pieces.
static func _draw_lance(ci: CanvasItem, color: Color, size: float, t: float, sw: float) -> void:
	var charge: float = 0.4 + 0.6 * abs(sin(t * 2.8))

	# Base plate — double horizontal rail for depth.
	ci.draw_line(Vector2(-size * 0.6,  size * 0.6 ), Vector2( size * 0.6,  size * 0.6 ), color, 1.8 * sw, true)
	ci.draw_line(Vector2(-size * 0.45, size * 0.42), Vector2( size * 0.45, size * 0.42), color, 1.4 * sw, true)

	# Column supports — two verticals rising to the barrel root.
	ci.draw_line(Vector2(-size * 0.12, size * 0.42), Vector2(-size * 0.12, size * 0.05), color, 1.2 * sw, true)
	ci.draw_line(Vector2( size * 0.12, size * 0.42), Vector2( size * 0.12, size * 0.05), color, 1.2 * sw, true)

	# Barrel — long spine pointing forward, primary stroke.
	ci.draw_line(Vector2(0, size * 0.1), Vector2(0, -size * 0.95), color, 1.8 * sw, true)

	# Rail coils — two short horizontal accents along the barrel, detail
	# stroke, alpha oscillates with the charge cycle.
	var coil := color
	coil.a = color.a * (0.5 + 0.5 * charge)
	ci.draw_line(Vector2(-size * 0.16, -size * 0.25), Vector2(size * 0.16, -size * 0.25), coil, 0.8 * sw, true)
	ci.draw_line(Vector2(-size * 0.16, -size * 0.55), Vector2(size * 0.16, -size * 0.55), coil, 0.8 * sw, true)

	# Muzzle charge glow — core + halo.
	var tip := color
	tip.a = color.a * charge
	ci.draw_circle(Vector2(0, -size * 0.95), 1.8 * sw, tip)
	var halo := color
	halo.a = color.a * charge * 0.4
	ci.draw_circle(Vector2(0, -size * 0.95), 3.6 * sw, halo)

## ORB — orbital satellite. Central body with two half-ring arcs whose Y
## scales oscillate out of phase — fakes 3D rotation from 2D primitives.
## Rotationally symmetric so the is_enemy flip doesn't change appearance.
static func _draw_orb(ci: CanvasItem, color: Color, size: float, t: float, sw: float) -> void:
	var spin: float = t * 2.8
	var pulse: float = 0.6 + 0.4 * sin(t * 5.0)

	# Central body — circle outline.
	ci.draw_arc(Vector2.ZERO, size * 0.36, 0.0, TAU, 24, color, 1.8 * sw, true)

	# Inner core — pulsing filled dot.
	var core := color
	core.a = color.a * pulse
	ci.draw_circle(Vector2.ZERO, size * 0.16, core)

	# Orbital ring A — upper half-arc, Y-squashed by |sin(spin)| to fake
	# the ring tilting toward the viewer.
	var tilt_a: float = abs(sin(spin)) * 0.65 + 0.12
	_draw_squashed_half_ring(ci, size * 0.72, tilt_a, false, color, 1.2 * sw)

	# Orbital ring B — lower half-arc, opposite phase.
	var tilt_b: float = abs(cos(spin)) * 0.55 + 0.1
	_draw_squashed_half_ring(ci, size * 0.58, tilt_b, true, color, 1.2 * sw)

## Helper: renders half of an ellipse (top or bottom). `flip` chooses
## which half, `tilt` is the Y-axis squash factor (0 = flat line, 1 =
## full circle). Used by the Orb silhouette to sell rotating orbital rings.
static func _draw_squashed_half_ring(ci: CanvasItem, radius: float, tilt: float, flip: bool, color: Color, stroke: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	var sign: float = 1.0 if flip else -1.0
	for i in 17:
		var a: float = lerpf(0.0, PI, float(i) / 16.0)
		pts.append(Vector2(cos(a) * radius, sign * sin(a) * radius * tilt))
	# Second pass reverses the sign so the flip argument controls top vs
	# bottom. Polyline is open (doesn't close into full ellipse).
	if flip:
		pts.reverse()
	ci.draw_polyline(pts, color, stroke, true)

## SCOUT — tiny formation ship spawned in groups of 3 by the Chevron
## SWARM card. At size 12 the silhouette is aggressively simplified — one
## arrowhead stroke + fuselage + thruster dot is all that reads at that
## scale. Three scouts in loose formation = "three little ships" in flight.
static func _draw_scout(ci: CanvasItem, color: Color, size: float, t: float, sw: float) -> void:
	var burn: float = 0.6 + 0.4 * sin(t * 14.0)

	# Arrowhead wing — single V pointing forward.
	var v: PackedVector2Array = PackedVector2Array([
		Vector2(-size * 0.7, size * 0.3),
		Vector2( 0,         -size * 0.9),
		Vector2( size * 0.7, size * 0.3),
	])
	ci.draw_polyline(v, color, 1.4 * sw, true)

	# Short fuselage — spine from cockpit to tail.
	ci.draw_line(Vector2(0, -size * 0.5), Vector2(0, size * 0.45), color, 1.2 * sw, true)

	# Tail thruster — pulsing dot.
	var flare := color
	flare.a = color.a * burn
	ci.draw_circle(Vector2(0, size * 0.6), 1.5 * sw, flare)

## PULSE — shockwave hunter. Diamond body with an inner diamond detail,
## plus an expanding ring that cycles outward (telegraphs the on-death
## shockwave). Twin back-thrusters anchor the "interceptor" role. Largest
## default-deck piece (size 22).
static func _draw_pulse(ci: CanvasItem, color: Color, size: float, t: float, sw: float) -> void:
	var phase: float = fmod(t * 1.5, 1.0)
	var expand_fade: float = 1.0 - phase
	var thrust: float = 0.5 + 0.5 * sin(t * 9.0)

	# Outer body — diamond outline.
	var body: PackedVector2Array = PackedVector2Array([
		Vector2( 0,           -size * 0.55),
		Vector2( size * 0.4,   0),
		Vector2( 0,            size * 0.55),
		Vector2(-size * 0.4,   0),
		Vector2( 0,           -size * 0.55),
	])
	ci.draw_polyline(body, color, 1.8 * sw, true)

	# Inner diamond detail.
	var inner: PackedVector2Array = PackedVector2Array([
		Vector2( 0,           -size * 0.22),
		Vector2( size * 0.18,  0),
		Vector2( 0,            size * 0.22),
		Vector2(-size * 0.18,  0),
		Vector2( 0,           -size * 0.22),
	])
	ci.draw_polyline(inner, color, 0.8 * sw, true)

	# Expanding shockwave ring — radius grows with phase, alpha fades out.
	var ring := color
	ring.a = color.a * expand_fade * 0.55
	ci.draw_arc(Vector2.ZERO, size * (0.55 + phase * 0.65), 0.0, TAU, 36, ring, 1.0 * sw, true)

	# Twin thruster flares at the rear.
	var flare := color
	flare.a = color.a * thrust
	ci.draw_circle(Vector2(-size * 0.28, size * 0.62), 1.5 * sw, flare)
	ci.draw_circle(Vector2( size * 0.28, size * 0.62), 1.5 * sw, flare)
