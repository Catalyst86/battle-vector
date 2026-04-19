@tool
class_name Scanlines
extends Control
## Faint horizontal scanline overlay — 1px cyan line every 3px at 1.5% alpha.
## Sits on top of everything via `z_index`; mouse_filter ignore. Lends the
## CRT/terminal patina without any shader cost.

@export var color: Color = Color(0.357, 0.878, 1.0, 0.025):
	set(v): color = v; queue_redraw()
@export_range(2.0, 8.0, 1.0) var period: float = 3.0:
	set(v): period = maxf(2.0, v); queue_redraw()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 1
	if PlayerProfile != null and not PlayerProfile.changed.is_connected(_sync_visibility):
		PlayerProfile.changed.connect(_sync_visibility)
	_sync_visibility()

func _sync_visibility() -> void:
	visible = PlayerProfile == null or PlayerProfile.data == null or PlayerProfile.data.scanlines_enabled

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var y: float = 0.0
	while y <= h:
		draw_line(Vector2(0, y), Vector2(w, y), color, 1.0, false)
		y += period
