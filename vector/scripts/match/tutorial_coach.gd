class_name TutorialCoach
extends Control
## Full-screen overlay that draws a pulsing highlight around whatever the
## tutorial wants the player to tap next. Driven entirely by `point_at()` /
## `point_at_rect()` / `hide_coach()` from match.gd — no state of its own
## beyond the current target.

var target: Control = null
var target_rect_override: Rect2 = Rect2()
var _use_rect: bool = false
var _time: float = 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false
	set_process(true)

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	queue_redraw()

func point_at(t: Control) -> void:
	if t == null:
		hide_coach()
		return
	target = t
	_use_rect = false
	visible = true
	queue_redraw()

func point_at_rect(r: Rect2) -> void:
	target = null
	target_rect_override = r
	_use_rect = true
	visible = true
	queue_redraw()

func hide_coach() -> void:
	target = null
	_use_rect = false
	visible = false

func _get_rect() -> Rect2:
	if target != null and is_instance_valid(target):
		return target.get_global_rect()
	if _use_rect:
		return target_rect_override
	return Rect2()

func _draw() -> void:
	var rect: Rect2 = _get_rect()
	if rect.size == Vector2.ZERO:
		return
	var pulse: float = 0.5 + 0.5 * sin(_time * 5.0)
	var base := Color(0.404, 0.910, 0.976, 1.0)  # cyan accent
	var pad: float = 6.0 + 4.0 * pulse
	# Outer soft halo
	var outer := base
	outer.a = 0.18 * (0.6 + 0.4 * pulse)
	draw_rect(rect.grow(pad + 6.0), outer, false, 6.0, true)
	# Main pulsing ring
	var ring := base
	ring.a = 0.55 + 0.45 * pulse
	draw_rect(rect.grow(pad), ring, false, 2.5, true)
	# Interior tint wash — very subtle so the target stays readable
	var tint := base
	tint.a = 0.08 * pulse
	draw_rect(rect, tint, true)
