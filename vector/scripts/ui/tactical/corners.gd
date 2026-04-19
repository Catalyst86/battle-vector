@tool
class_name Corners
extends Control
## L-shaped corner brackets — signature motif of the tactical theme.
## Sits as a child of any panel; draws 10×10 1px cyan Ls at the chosen
## corners, no fill. Set `color` to amber for reward panels, etc.
##
## Usage in code:
##   var c := Corners.new()
##   parent.add_child(c)
##   c.set_anchors_preset(Control.PRESET_FULL_RECT)

@export var color: Color = Color("5be0ff"):
	set(v): color = v; queue_redraw()
@export_range(4.0, 30.0, 1.0) var length: float = 10.0:
	set(v): length = v; queue_redraw()
@export_range(0.5, 4.0, 0.5) var thickness: float = 1.0:
	set(v): thickness = v; queue_redraw()
## Which corners to draw. TL + BR is the canonical pattern from the handoff.
@export var top_left: bool = true:
	set(v): top_left = v; queue_redraw()
@export var top_right: bool = false:
	set(v): top_right = v; queue_redraw()
@export var bottom_left: bool = false:
	set(v): bottom_left = v; queue_redraw()
@export var bottom_right: bool = true:
	set(v): bottom_right = v; queue_redraw()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _draw() -> void:
	var t: float = thickness
	var l: float = length
	var w: float = size.x
	var h: float = size.y
	if top_left:
		draw_line(Vector2(0, 0), Vector2(l, 0), color, t, true)
		draw_line(Vector2(0, 0), Vector2(0, l), color, t, true)
	if top_right:
		draw_line(Vector2(w - l, 0), Vector2(w, 0), color, t, true)
		draw_line(Vector2(w, 0), Vector2(w, l), color, t, true)
	if bottom_left:
		draw_line(Vector2(0, h - l), Vector2(0, h), color, t, true)
		draw_line(Vector2(0, h), Vector2(l, h), color, t, true)
	if bottom_right:
		draw_line(Vector2(w - l, h), Vector2(w, h), color, t, true)
		draw_line(Vector2(w, h - l), Vector2(w, h), color, t, true)
