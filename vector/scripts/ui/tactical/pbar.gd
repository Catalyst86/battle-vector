@tool
class_name PBar
extends Control
## Progress bar with a gradient fill, subtle glow, and a 7px-period vertical
## hash overlay that sells the "technical readout" feel. Used for XP, trophy
## progress, chest countdown, season track fill.

@export_range(0.0, 1.0, 0.001) var progress: float = 0.5:
	set(v): progress = clampf(v, 0.0, 1.0); queue_redraw()
@export var color: Color = Color("5be0ff"):
	set(v): color = v; queue_redraw()
@export var color_dim: Color = Color("2a7a94"):
	set(v): color_dim = v; queue_redraw()
@export var bg: Color = Color("151e2b"):
	set(v): bg = v; queue_redraw()
@export var show_hash: bool = true:
	set(v): show_hash = v; queue_redraw()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 4)

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	# Track
	draw_rect(Rect2(0, 0, w, h), bg, true)
	# Fill (gradient via per-pixel-column shade)
	var fill_w: float = w * progress
	if fill_w > 0.0:
		# Approximate gradient with 2 rects (dim → bright).
		draw_rect(Rect2(0, 0, fill_w * 0.5, h), color_dim, true)
		draw_rect(Rect2(fill_w * 0.5, 0, fill_w * 0.5, h), color, true)
		# Soft glow under fill
		var g := color
		g.a = 0.25
		draw_rect(Rect2(-1, -1, fill_w + 2, h + 2), g, false, 1.0)
	# Hash overlay
	if show_hash:
		var hash_color := Color(0, 0, 0, 0.4)
		var x: float = 7.0
		while x < w:
			draw_line(Vector2(x, 0), Vector2(x, h), hash_color, 1.0, false)
			x += 8.0
