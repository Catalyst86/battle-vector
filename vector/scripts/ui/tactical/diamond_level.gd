@tool
class_name DiamondLevel
extends Control
## Rotated-square level indicator. 22×22 rotated 45° with a level number
## drawn upright in the center. Used in the player header next to "LVL" label.

@export_range(1, 99) var level: int = 2:
	set(v): level = v; queue_redraw()
@export var color: Color = Color("5be0ff"):
	set(v): color = v; queue_redraw()
@export_range(12.0, 40.0, 1.0) var box_size: float = 22.0:
	set(v): box_size = v; custom_minimum_size = Vector2(v, v); queue_redraw()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(box_size, box_size)

func _draw() -> void:
	var cx: float = size.x * 0.5
	var cy: float = size.y * 0.5
	var r: float = box_size * 0.5
	# Diamond polygon
	var pts := PackedVector2Array([
		Vector2(cx, cy - r),
		Vector2(cx + r, cy),
		Vector2(cx, cy + r),
		Vector2(cx - r, cy),
	])
	# Fill (dim tinted)
	var fill := color
	fill.a = 0.08
	draw_colored_polygon(pts, fill)
	# Border
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, color, 1.0, true)
	# Number (upright, centered)
	var font: Font = Palette.FONT_MONO_BOLD
	var fs: int = clampi(int(box_size * 0.5), 9, 20)
	var txt: String = str(level)
	var txt_size: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string(font, Vector2(cx - txt_size.x * 0.5, cy + txt_size.y * 0.32),
		txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, color)
