@tool
class_name GridBg
extends Control
## 24px technical-drawing grid background — 1px hairlines at very low opacity.
## Add as a child of any panel, anchors-preset full, mouse_filter ignore. The
## 8px fine variant is for the header where a denser feel is wanted.

@export_range(4.0, 64.0, 1.0) var spacing: float = 24.0:
	set(v): spacing = maxf(4.0, v); queue_redraw()
@export var color: Color = Color(0.47, 0.588, 0.706, 0.08):
	set(v): color = v; queue_redraw()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var x: float = 0.0
	while x <= w:
		draw_line(Vector2(x, 0), Vector2(x, h), color, 1.0, false)
		x += spacing
	var y: float = 0.0
	while y <= h:
		draw_line(Vector2(0, y), Vector2(w, y), color, 1.0, false)
		y += spacing
