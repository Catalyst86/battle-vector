class_name TutorialCoach
extends Control
## Full-screen overlay that highlights whatever the tutorial wants the player
## to tap next and (optionally) shows a tactical message bubble near it.
##
## Driven by `point_at(target, message)` / `point_at_rect(rect, message)` /
## `hide_coach()` from match.gd. The bubble auto-places itself above or below
## the highlighted element depending on which half of the screen it's in.

var target: Control = null
var target_rect_override: Rect2 = Rect2()
var _use_rect: bool = false
var _time: float = 0.0
var _message: String = ""
var _bubble: PanelContainer
var _bubble_label: Label
var _bubble_arrow: Control

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false
	set_process(true)
	_build_bubble()

func _build_bubble() -> void:
	_bubble = PanelContainer.new()
	_bubble.mouse_filter = MOUSE_FILTER_IGNORE
	_bubble.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.016, 0.027, 0.047, 0.92)
	sb.border_color = Palette.UI_CYAN
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_width_left = 1; sb.border_width_right = 1
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	_bubble.add_theme_stylebox_override("panel", sb)
	add_child(_bubble)
	_bubble_label = Label.new()
	_bubble_label.add_theme_font_override("font", Palette.FONT_DISPLAY_BOLD)
	_bubble_label.add_theme_font_size_override("font_size", 11)
	_bubble_label.add_theme_color_override("font_color", Palette.UI_CYAN)
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.custom_minimum_size = Vector2(240, 0)
	_bubble.add_child(_bubble_label)
	_bubble_arrow = Control.new()
	_bubble_arrow.custom_minimum_size = Vector2(12, 8)
	_bubble_arrow.mouse_filter = MOUSE_FILTER_IGNORE
	_bubble_arrow.visible = false
	_bubble_arrow.draw.connect(_draw_arrow)
	add_child(_bubble_arrow)

var _arrow_points_up: bool = false

func _draw_arrow() -> void:
	# Cyan triangle pointing TOWARD the target. When bubble is below target,
	# arrow points up; when above, arrow points down.
	var pts: PackedVector2Array
	if _arrow_points_up:
		pts = PackedVector2Array([Vector2(6, 0), Vector2(12, 8), Vector2(0, 8)])
	else:
		pts = PackedVector2Array([Vector2(0, 0), Vector2(12, 0), Vector2(6, 8)])
	_bubble_arrow.draw_colored_polygon(pts, Palette.UI_CYAN)

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_reposition_bubble()
	queue_redraw()

func point_at(t: Control, message: String = "") -> void:
	if t == null:
		hide_coach()
		return
	target = t
	_use_rect = false
	_message = message
	_refresh_bubble()
	visible = true
	queue_redraw()

func point_at_rect(r: Rect2, message: String = "") -> void:
	target = null
	target_rect_override = r
	_use_rect = true
	_message = message
	_refresh_bubble()
	visible = true
	queue_redraw()

func hide_coach() -> void:
	target = null
	_use_rect = false
	visible = false
	if _bubble: _bubble.visible = false
	if _bubble_arrow: _bubble_arrow.visible = false

func _refresh_bubble() -> void:
	if _bubble == null:
		return
	if _message == "":
		_bubble.visible = false
		_bubble_arrow.visible = false
		return
	_bubble_label.text = _message
	_bubble.visible = true
	_bubble_arrow.visible = true
	_reposition_bubble()

func _reposition_bubble() -> void:
	if _bubble == null or not _bubble.visible:
		return
	var rect: Rect2 = _get_rect()
	if rect.size == Vector2.ZERO:
		return
	var viewport_size: Vector2 = size
	# Wait for bubble to have a real size after relayout.
	var bubble_size: Vector2 = _bubble.get_combined_minimum_size()
	# Place bubble either above or below target depending on vertical half.
	var target_center_y: float = rect.position.y + rect.size.y * 0.5
	var below: bool = target_center_y < viewport_size.y * 0.5
	_arrow_points_up = below
	var margin: float = 18.0
	var y: float
	var arrow_y: float
	if below:
		y = rect.position.y + rect.size.y + margin
		arrow_y = y - 8.0
	else:
		y = rect.position.y - margin - bubble_size.y
		arrow_y = y + bubble_size.y
	# Clamp horizontally so the bubble doesn't leave the viewport.
	var x: float = rect.position.x + rect.size.x * 0.5 - bubble_size.x * 0.5
	x = clampf(x, 8.0, viewport_size.x - bubble_size.x - 8.0)
	_bubble.position = Vector2(x, y)
	# Arrow aligned to the target's horizontal center.
	var arrow_x: float = clampf(rect.position.x + rect.size.x * 0.5 - 6.0, 4.0, viewport_size.x - 16.0)
	_bubble_arrow.position = Vector2(arrow_x, arrow_y)
	_bubble_arrow.queue_redraw()

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
	var base := Palette.UI_CYAN
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
