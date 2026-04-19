@tool
class_name SegBar
extends Control
## Segmented progress bar — discrete cells instead of a smooth fill.
## Reads as "3 of 10 charges" rather than "30%". Used for XP, mana, season
## pass tiers, arena progression.

@export_range(1, 30) var segments: int = 10:
	set(v): segments = maxi(1, v); queue_redraw()
## value in 0..segments. Partial fills render the leading cell at 40%.
@export_range(0.0, 30.0, 0.01) var value: float = 3.0:
	set(v): value = clampf(v, 0.0, float(segments)); queue_redraw()
@export var color_on: Color = Color("5be0ff"):
	set(v): color_on = v; queue_redraw()
@export var color_off: Color = Color(0.47, 0.588, 0.706, 0.12):
	set(v): color_off = v; queue_redraw()
@export_range(1.0, 6.0) var gap: float = 2.0:
	set(v): gap = v; queue_redraw()
@export var glow: bool = true:
	set(v): glow = v; queue_redraw()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 8)

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var n: int = segments
	var seg_w: float = (w - gap * float(n - 1)) / float(n)
	if seg_w <= 0.0:
		return
	var full_segs: int = int(floor(value))
	var partial: float = value - float(full_segs)
	for i in n:
		var x: float = float(i) * (seg_w + gap)
		var rect := Rect2(x, 0.0, seg_w, h)
		if i < full_segs:
			draw_rect(rect, color_on, true)
			if glow:
				var g := color_on
				g.a *= 0.35
				draw_rect(Rect2(x - 0.5, -0.5, seg_w + 1.0, h + 1.0), g, false, 1.0)
		elif i == full_segs and partial > 0.0:
			# Partial fill at the leading cell.
			draw_rect(Rect2(x, 0.0, seg_w * partial, h), color_on, true)
			draw_rect(Rect2(x + seg_w * partial, 0.0, seg_w * (1.0 - partial), h), color_off, true)
		else:
			draw_rect(rect, color_off, true)
