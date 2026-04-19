class_name TacticalTabBar
extends Control
## 5-tab bar with cyan underline + glow on the active tab. Emits
## `tab_selected(id)` and exposes `select(id)` for programmatic swaps.

signal tab_selected(id: StringName)

const TABS: Array = [
	{ "id": &"home",       "label": "HOME" },
	{ "id": &"collection", "label": "COLLECTION" },
	{ "id": &"deck",       "label": "DECK" },
	{ "id": &"ladder",     "label": "LADDER" },
	{ "id": &"shop",       "label": "SHOP" },
]

var _active: StringName = &"home"
var _buttons: Array[Button] = []

func _ready() -> void:
	custom_minimum_size = Vector2(0, 44)
	_build()
	select(_active)

func _build() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	add_child(row)
	for t in TABS:
		var b := Button.new()
		b.text = t.label
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_size_override("font_size", Palette.FS_BUTTON)
		b.add_theme_color_override("font_color", Palette.UI_TEXT_2)
		b.add_theme_color_override("font_hover_color", Palette.UI_TEXT_0)
		b.add_theme_color_override("font_pressed_color", Palette.UI_CYAN)
		var id: StringName = t.id
		b.pressed.connect(func():
			SfxBank.play_ui(&"ui_click")
			select(id)
			tab_selected.emit(id))
		row.add_child(b)
		_buttons.append(b)
	queue_redraw()

func select(id: StringName) -> void:
	_active = id
	for i in TABS.size():
		var active: bool = TABS[i].id == id
		var btn: Button = _buttons[i]
		btn.add_theme_color_override("font_color", Palette.UI_CYAN if active else Palette.UI_TEXT_2)
	queue_redraw()

func _draw() -> void:
	# Base border along full width
	draw_line(Vector2(0, size.y - 1), Vector2(size.x, size.y - 1), Palette.UI_LINE_2, 1.0, false)
	# Cyan underline + soft halo under active tab
	var idx: int = 0
	for i in TABS.size():
		if TABS[i].id == _active:
			idx = i
			break
	var seg_w: float = size.x / float(TABS.size())
	var x: float = seg_w * float(idx)
	var glow_color := Palette.UI_CYAN
	glow_color.a = 0.25
	draw_rect(Rect2(x, size.y - 6, seg_w, 4), glow_color, true)
	draw_line(Vector2(x + 2, size.y - 1), Vector2(x + seg_w - 2, size.y - 1), Palette.UI_CYAN, 2.0, false)
