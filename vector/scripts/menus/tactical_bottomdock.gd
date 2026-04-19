class_name TacticalBottomDock
extends Control
## Persistent bottom dock — tutorial (ghost) + 1V1 (primary glowing) + VOLLEY +
## 2V2. Emits `mode_selected(mode)` for 1v1/2v2/volley and `tutorial_pressed`.
## Pulses the primary via corner brackets + cyan border.

signal mode_selected(mode: StringName)
signal tutorial_pressed

var _tutorial_btn: Button
var _1v1_btn: Button
var _2v2_btn: Button
var _volley_btn: Button
var _pulse_t: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(0, 82)
	_build()
	set_process(true)

func _build() -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.offset_left = 10; grid.offset_right = -10
	grid.offset_top = 12; grid.offset_bottom = -16
	add_child(grid)
	# Column stretch — 1V1 still the primary (fat middle); VOLLEY gets
	# a highlight secondary, TUTORIAL + 2V2 stay compact.
	_tutorial_btn = _make_dock_button(false, "TRAIN", "TUTORIAL", 1.0)
	_1v1_btn = _make_dock_button(true, "1V1", "2m · VS", 1.3)
	_volley_btn = _make_dock_button(false, "VOLLEY", "2m · RAIN", 1.2)
	_2v2_btn = _make_dock_button(false, "2V2", "3m · DUO", 1.0)
	grid.add_child(_tutorial_btn)
	grid.add_child(_1v1_btn)
	grid.add_child(_volley_btn)
	grid.add_child(_2v2_btn)
	_tutorial_btn.pressed.connect(func():
		SfxBank.play_ui(&"ui_click")
		tutorial_pressed.emit())
	_1v1_btn.pressed.connect(func():
		SfxBank.play_ui(&"ui_confirm")
		mode_selected.emit(&"1v1"))
	_2v2_btn.pressed.connect(func():
		SfxBank.play_ui(&"ui_confirm")
		mode_selected.emit(&"2v2"))
	_volley_btn.pressed.connect(func():
		SfxBank.play_ui(&"ui_confirm")
		mode_selected.emit(&"volley"))

func _make_dock_button(primary: bool, label: String, subtitle: String, stretch: float) -> Button:
	var b := Button.new()
	b.flat = false
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_stretch_ratio = stretch
	b.custom_minimum_size = Vector2(0, 54)
	b.text = label + "\n" + subtitle
	b.clip_text = false
	b.autowrap_mode = TextServer.AUTOWRAP_OFF
	b.add_theme_font_size_override("font_size", 16 if primary else 11)
	b.add_theme_color_override("font_color", Palette.UI_CYAN if primary else Palette.UI_TEXT_0)
	b.add_theme_color_override("font_hover_color", Palette.UI_CYAN if primary else Palette.UI_TEXT_0)
	# Custom StyleBox per state
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("0e2533") if primary else Color("0a1018")
	normal.border_color = Palette.UI_CYAN if primary else Palette.UI_LINE_3
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	if primary:
		normal.shadow_color = Palette.UI_CYAN_GLOW
		normal.shadow_size = 12
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", normal)
	b.add_theme_stylebox_override("focus", normal)
	# Corner brackets as decoration
	var corners := Corners.new()
	corners.color = Palette.UI_CYAN if primary else Palette.UI_TEXT_2
	corners.top_left = true
	corners.top_right = true
	corners.bottom_left = true
	corners.bottom_right = true
	corners.length = 8.0
	b.add_child(corners)
	return b

func _process(delta: float) -> void:
	_pulse_t += delta
	# Pulse the primary button's shadow to draw the eye.
	if _1v1_btn == null:
		return
	var sb: StyleBox = _1v1_btn.get_theme_stylebox("normal")
	if sb is StyleBoxFlat:
		var pulse: float = 0.5 + 0.5 * sin(_pulse_t * TAU / 2.2)
		(sb as StyleBoxFlat).shadow_size = 8 + int(6 * pulse)
