@tool
class_name CornerWrap
extends Control
## Wraps a single Control with an L-shaped corner bracket overlay without
## going through a Container node (Container layout managers override the
## Corners child's anchors and shove it to the wrong spot).
##
## Critical: overrides _get_minimum_size() to forward the inner content's
## size up to its VBoxContainer parent — otherwise the wrapper reports 0×0
## and subsequent siblings stack on top of it.

var _content: Control
var _corners: Corners
@export var bracket_color: Color = Color("5be0ff"):
	set(v):
		bracket_color = v
		if _corners:
			_corners.color = v

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = MOUSE_FILTER_PASS

## One-shot setup called by TabHelpers.with_corners. Adds the content as a
## full-rect child, then the Corners as a full-rect overlay on top.
func set_content(content: Control, color: Color = Color("5be0ff")) -> void:
	_content = content
	bracket_color = color
	add_child(_content)
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_corners = Corners.new()
	_corners.color = color
	add_child(_corners)
	# Re-query minimum size whenever the content's own min size changes
	# (e.g. a ScrollContainer resolving its inner list's height).
	if _content.has_signal("minimum_size_changed"):
		if not _content.minimum_size_changed.is_connected(update_minimum_size):
			_content.minimum_size_changed.connect(update_minimum_size)
	update_minimum_size()

func _get_minimum_size() -> Vector2:
	if _content and is_instance_valid(_content):
		return _content.get_combined_minimum_size()
	return Vector2.ZERO
