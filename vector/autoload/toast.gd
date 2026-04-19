extends CanvasLayer
## Global toast notification. Call `Toast.show("MESSAGE")` from anywhere.
## Appears as a centred cyan bracketed chip near the top of the screen, fades
## out after ~1.6s. Stacks by cancelling previous toast if one is active.

const DEFAULT_DURATION: float = 1.8
const FADE: float = 0.22

var _panel: PanelContainer
var _label: Label
var _tween: Tween

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.modulate = Color(1, 1, 1, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.016, 0.027, 0.047, 0.92)
	sb.border_color = Palette.UI_CYAN
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_width_left = 1; sb.border_width_right = 1
	_panel.add_theme_stylebox_override("panel", sb)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(m)
	_label = Label.new()
	_label.add_theme_font_override("font", Palette.FONT_DISPLAY_BOLD)
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", Palette.UI_CYAN)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.add_child(_label)
	add_child(_panel)
	# Anchor near top-center.
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_top = 60
	_panel.offset_bottom = 60
	_panel.offset_left = -120
	_panel.offset_right = 120

func notify(message: String, duration: float = DEFAULT_DURATION) -> void:
	_label.text = message
	_panel.visible = true
	if _tween and _tween.is_valid():
		_tween.kill()
	_panel.modulate.a = 0.0
	_tween = create_tween().set_ease(Tween.EASE_OUT)
	_tween.tween_property(_panel, "modulate:a", 1.0, FADE)
	_tween.tween_interval(duration)
	_tween.tween_property(_panel, "modulate:a", 0.0, FADE)

## Special-purpose shortcut — the "coming soon" label used by every stubbed
## storefront widget. Kept as its own call so the message text is consistent.
func coming_soon() -> void:
	notify("// COMING SOON //", 1.6)
