class_name OvertimeRift
extends Node2D
## Midline capture objective that appears during VOLLEY overtime. Player
## or enemy units entering the capture radius fill a signed progress
## meter; when one side reaches ±1.0 they capture it and the match
## controller grants that team a temporary buff (mana regen boost).
## After the buff ends the rift resets and another capture can fire.
##
## Designed as the natural comeback lever — the trailing side has the
## same mechanical access to the rift as the leader, so even a 40-kill
## deficit at the 2:00 mark is recoverable.

signal captured(capturing_is_enemy: bool)

const CAPTURE_RADIUS: float = 70.0
## Seconds of uncontested presence to complete a capture. A contested
## zone (both sides inside) freezes the meter; whoever clears their side
## of the rift pushes the meter their way.
const CAPTURE_DURATION: float = 3.5

## −1.0 → enemy fully captured. +1.0 → player fully captured. 0.0 → neutral.
## Decays toward 0 when nobody is inside to prevent stale half-captures.
var _capture_progress: float = 0.0
var _locked: bool = false  # true after capture fires, reset externally
var _age: float = 0.0

func _process(delta: float) -> void:
	_age += delta
	if _locked:
		queue_redraw()
		return
	var player_in: int = 0
	var enemy_in: int = 0
	if UnitRegistry != null:
		for u in UnitRegistry.player_team:
			if is_instance_valid(u) and u.world_pos.distance_to(position) <= CAPTURE_RADIUS:
				player_in += 1
		for u in UnitRegistry.enemy_team:
			if is_instance_valid(u) and u.world_pos.distance_to(position) <= CAPTURE_RADIUS:
				enemy_in += 1
	if player_in > 0 and enemy_in == 0:
		_capture_progress = minf(1.0, _capture_progress + delta / CAPTURE_DURATION)
	elif enemy_in > 0 and player_in == 0:
		_capture_progress = maxf(-1.0, _capture_progress - delta / CAPTURE_DURATION)
	elif player_in == 0 and enemy_in == 0:
		# Slow neutral decay — stops one unit from locking in a half-capture
		# by walking away.
		_capture_progress = move_toward(_capture_progress, 0.0, delta * 0.25)
	# Contested (both sides present) → meter frozen.
	if _capture_progress >= 1.0:
		_locked = true
		captured.emit(false)
	elif _capture_progress <= -1.0:
		_locked = true
		captured.emit(true)
	queue_redraw()

## Match controller calls this when the buff ends so the rift can be
## captured again. Resets progress + unlocks.
func reset() -> void:
	_capture_progress = 0.0
	_locked = false
	queue_redraw()

func _draw() -> void:
	var pulse: float = 0.6 + 0.4 * sin(_age * 4.0)
	# Capture zone — faint outer ring.
	var zone := Palette.UI_AMBER
	zone.a = 0.10 + 0.05 * pulse
	draw_arc(Vector2.ZERO, CAPTURE_RADIUS, 0.0, TAU, 64, zone, 1.0, true)
	# Inner diamond body — gold-amber when neutral, team-tinted when being
	# captured so the player reads who's winning the zone at a glance.
	var body_color: Color = Palette.UI_AMBER
	if _capture_progress > 0.02:
		body_color = Palette.UI_CYAN
	elif _capture_progress < -0.02:
		body_color = Palette.UI_RED
	body_color.a = pulse
	var d: float = 20.0
	var diamond: PackedVector2Array = PackedVector2Array([
		Vector2(0, -d), Vector2(d, 0), Vector2(0, d), Vector2(-d, 0), Vector2(0, -d),
	])
	draw_polyline(diamond, body_color, 2.0 * (1.0 + pulse * 0.3), true)
	# Inner core dot.
	var core := body_color
	core.a = pulse * 0.8
	draw_circle(Vector2.ZERO, 4.0, core)
	# Capture progress ring — fills clockwise from top.
	var frac: float = absf(_capture_progress)
	if frac > 0.02:
		var ring_color: Color = Palette.UI_CYAN if _capture_progress > 0.0 else Palette.UI_RED
		ring_color.a = 0.7
		draw_arc(Vector2.ZERO, CAPTURE_RADIUS * 0.75,
			-PI * 0.5, -PI * 0.5 + frac * TAU,
			48, ring_color, 3.0, true)
	# Lock flash — filled ring for one frame after capture.
	if _locked:
		var lock_color: Color = Palette.UI_CYAN if _capture_progress > 0.0 else Palette.UI_RED
		lock_color.a = 0.4 * pulse
		draw_arc(Vector2.ZERO, CAPTURE_RADIUS * 0.75, 0.0, TAU, 48, lock_color, 5.0, true)
