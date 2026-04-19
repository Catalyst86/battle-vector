class_name TabHelpers
extends RefCounted
## Shared builders used by all tactical tab scripts. Kept as static helpers so
## each tab script can pull what it needs without a mixin inheritance graph.
## The point is to make tabs read as compositions of tokens — not a tangle of
## add_theme_color_override calls.

# ─── Text factories ─────────────────────────────────────────────────────────

static func label(text: String, fs: int = 11, color: Color = Palette.UI_TEXT_1) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", Palette.FONT_DISPLAY)
	return l

static func mono(text: String, fs: int = 10, color: Color = Palette.UI_TEXT_2) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", Palette.FONT_MONO)
	return l

static func hero_number(text: String, fs: int = 22, color: Color = Palette.UI_AMBER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", Palette.FONT_MONO_BLACK)
	return l

static func kicker(text: String, color: Color = Palette.UI_TEXT_3) -> Label:
	## Section-kicker style: "▸ SOMETHING" tiny gold-ish label.
	return label(text, Palette.FS_TINY, color)

# ─── Panels / surfaces ──────────────────────────────────────────────────────

static func panel_style(bg: Color = Palette.UI_BG_1, border: Color = Palette.UI_LINE_2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_width_left = 1
	sb.border_width_right = 1
	return sb

static func make_panel(bg: Color = Palette.UI_BG_1, border: Color = Palette.UI_LINE_2, _corners_color: Color = Color(0,0,0,0)) -> PanelContainer:
	## Corners used to be an inline child here, but PanelContainer treats all
	## children as Container-managed layout slots — the bracket node was getting
	## positioned ABOVE the real content instead of overlaying it. Callers that
	## want brackets should now wrap the returned panel with `with_corners()`.
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(bg, border))
	return p

## Wraps any Control in an overlay that draws L-shaped corner brackets on top.
## Use this when a panel needs the "operations briefing" look — do NOT nest
## Corners directly into a PanelContainer or any Container (their layout
## engines override anchors).
static func with_corners(content: Control, color: Color = Palette.UI_CYAN) -> Control:
	var root := Control.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.custom_minimum_size = content.custom_minimum_size
	# Content fills the wrapper.
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(content)
	# Corners overlay, also fills — they'll self-anchor in _ready.
	var c := Corners.new()
	c.color = color
	root.add_child(c)
	return root

static func margin(left: int = 12, top: int = 12, right: int = 12, bottom: int = 12) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_bottom", bottom)
	return m

static func divider(color: Color = Palette.UI_LINE_1, height: int = 1) -> ColorRect:
	var d := ColorRect.new()
	d.color = color
	d.custom_minimum_size = Vector2(0, height)
	return d

static func spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s

# ─── Chips / buttons ────────────────────────────────────────────────────────

static func chip(text: String, color: Color = Palette.UI_TEXT_2, border: Color = Palette.UI_LINE_2) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.047, 0.055, 0.071, 0.5)
	sb.border_color = border
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_width_left = 1; sb.border_width_right = 1
	p.add_theme_stylebox_override("panel", sb)
	var m := margin(8, 4, 8, 4)
	p.add_child(m)
	var l := mono(text, 10, color)
	m.add_child(l)
	return p

static func ghost_button(text: String, on_pressed: Callable, color: Color = Palette.UI_TEXT_1) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = false
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", Palette.FONT_DISPLAY)
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", Palette.UI_TEXT_0)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0,0,0,0)
	normal.border_color = Palette.UI_LINE_2
	normal.border_width_top = 1; normal.border_width_bottom = 1
	normal.border_width_left = 1; normal.border_width_right = 1
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Palette.UI_LINE_3
	for sn in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(sn, normal if sn != "hover" else hover)
	b.custom_minimum_size = Vector2(0, 36)
	b.pressed.connect(func():
		SfxBank.play_ui(&"ui_click")
		on_pressed.call())
	return b

static func primary_button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = false
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", Palette.FONT_DISPLAY)
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", Palette.UI_CYAN)
	b.add_theme_color_override("font_hover_color", Palette.UI_CYAN)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("0e2533")
	normal.border_color = Palette.UI_CYAN
	normal.border_width_top = 1; normal.border_width_bottom = 1
	normal.border_width_left = 1; normal.border_width_right = 1
	normal.shadow_color = Palette.UI_CYAN_GLOW
	normal.shadow_size = 8
	for sn in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(sn, normal)
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(func():
		SfxBank.play_ui(&"ui_confirm")
		on_pressed.call())
	return b

# ─── Tab frame ─────────────────────────────────────────────────────────────

static func tab_scroll() -> ScrollContainer:
	## Standard tab-content scroll container. Each tab root should be this.
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	return sc

static func tab_column() -> VBoxContainer:
	## Root vertical column for tab content. Handles gutter margins.
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return vb
