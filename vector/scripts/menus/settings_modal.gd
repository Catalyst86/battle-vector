extends Control
## Settings bottom-sheet modal. Slides up from the bottom; backdrop dim +
## close on tap. AUDIO / GRAPHICS / ACCOUNT sections match the design handoff.

@onready var backdrop: ColorRect = $Backdrop
@onready var sheet: PanelContainer = %Sheet

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close())
	# Sheet styling
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.UI_BG_1
	sb.border_color = Palette.UI_CYAN
	sb.border_width_top = 1; sb.border_width_left = 1; sb.border_width_right = 1
	sheet.add_theme_stylebox_override("panel", sb)
	# Corner brackets on the top
	var corners := Corners.new()
	corners.top_left = true
	corners.top_right = true
	corners.bottom_left = false
	corners.bottom_right = false
	corners.color = Palette.UI_CYAN
	sheet.add_child(corners)
	# Build content
	var m: MarginContainer = TabHelpers.margin(16, 16, 16, 16)
	sheet.add_child(m)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	m.add_child(sc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	sc.add_child(col)
	col.add_child(_build_header())
	col.add_child(_build_audio_section())
	col.add_child(_build_graphics_section())
	col.add_child(_build_account_section())
	var logout_btn: Button = TabHelpers.ghost_button("LOG OUT", func():
		SfxBank.play_ui(&"ui_back"), Palette.UI_RED)
	logout_btn.add_theme_color_override("font_color", Palette.UI_RED)
	col.add_child(logout_btn)

	# Slide-in tween
	var start_y: float = sheet.offset_top
	sheet.offset_top = 200.0
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(sheet, "offset_top", start_y, 0.25)

func _close() -> void:
	SfxBank.play_ui(&"ui_back")
	var tween := create_tween().set_ease(Tween.EASE_IN)
	tween.tween_property(sheet, "offset_top", 200.0, 0.18)
	tween.parallel().tween_property(backdrop, "modulate:a", 0.0, 0.18)
	tween.finished.connect(func(): queue_free())

func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	col.add_child(TabHelpers.label("SYS_MENU", 9, Palette.UI_TEXT_3))
	col.add_child(TabHelpers.label("SETTINGS", 18, Palette.UI_CYAN))
	row.add_child(col)
	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.flat = true
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.add_theme_font_override("font", Palette.FONT_MONO)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.add_theme_color_override("font_color", Palette.UI_TEXT_1)
	close_btn.add_theme_color_override("font_hover_color", Palette.UI_CYAN)
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0, 0, 0, 0)
	csb.border_color = Palette.UI_LINE_2
	csb.border_width_top = 1; csb.border_width_bottom = 1
	csb.border_width_left = 1; csb.border_width_right = 1
	for sn in ["normal", "hover", "pressed"]:
		close_btn.add_theme_stylebox_override(sn, csb)
	close_btn.pressed.connect(_close)
	row.add_child(close_btn)
	return row

func _build_audio_section() -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.add_child(TabHelpers.label("▸ AUDIO", 10, Palette.UI_TEXT_3))
	vb.add_child(_build_slider_row("MUSIC",
		PlayerProfile.data.music_volume if PlayerProfile != null else 0.7,
		func(v): PlayerProfile.set_music_volume(v)))
	vb.add_child(_build_slider_row("SFX",
		PlayerProfile.data.sfx_volume if PlayerProfile != null else 0.9,
		func(v):
			PlayerProfile.set_sfx_volume(v)
			SfxBank.play(&"ui_click")))
	vb.add_child(_build_toggle_row("MUTE ALL",
		PlayerProfile.data.audio_muted if PlayerProfile != null else false,
		func(b): PlayerProfile.set_audio_muted(b)))
	return vb

func _build_graphics_section() -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.add_child(TabHelpers.label("▸ GRAPHICS", 10, Palette.UI_TEXT_3))
	var shake_on: bool = PlayerProfile.data.screen_shake_enabled if PlayerProfile != null else true
	vb.add_child(_build_toggle_row("SCREEN SHAKE", shake_on,
		func(b): PlayerProfile.set_screen_shake_enabled(b)))
	var scan_on: bool = PlayerProfile.data.scanlines_enabled if PlayerProfile != null else true
	vb.add_child(_build_toggle_row("SCANLINES", scan_on,
		func(b): PlayerProfile.set_scanlines_enabled(b)))
	var haptic_on: bool = PlayerProfile.data.haptic_enabled if PlayerProfile != null else true
	vb.add_child(_build_toggle_row("HAPTIC FEEDBACK", haptic_on,
		func(b):
			PlayerProfile.set_haptic_enabled(b)
			if b: PlayerProfile.buzz(30)))  # preview buzz on enable
	return vb

func _build_account_section() -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.add_child(TabHelpers.label("▸ ACCOUNT", 10, Palette.UI_TEXT_3))
	vb.add_child(_build_name_edit_row())
	vb.add_child(_build_text_row("REGION", "NA-WEST"))
	return vb

## Player-name row — editable LineEdit that writes back through
## PlayerProfile.set_player_name on focus-exit or Enter.
func _build_name_edit_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 36)
	var lbl: Label = TabHelpers.mono("PLAYER ID", 10, Palette.UI_TEXT_1)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var le := LineEdit.new()
	le.text = PlayerProfile.data.player_name if PlayerProfile != null else "VEC.BLUE"
	le.max_length = 16
	le.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	le.custom_minimum_size = Vector2(140, 28)
	le.add_theme_font_override("font", Palette.FONT_MONO_BOLD)
	le.add_theme_font_size_override("font_size", 11)
	le.add_theme_color_override("font_color", Palette.UI_CYAN)
	le.add_theme_color_override("caret_color", Palette.UI_CYAN)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.047, 0.055, 0.071, 0.5)
	sb.border_color = Palette.UI_LINE_2
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_width_left = 1; sb.border_width_right = 1
	sb.content_margin_left = 6; sb.content_margin_right = 6
	le.add_theme_stylebox_override("normal", sb)
	le.add_theme_stylebox_override("focus", sb.duplicate())
	le.text_submitted.connect(func(new_text: String):
		PlayerProfile.set_player_name(new_text))
	le.focus_exited.connect(func():
		PlayerProfile.set_player_name(le.text))
	row.add_child(le)
	var div := _row_divider(); div.add_child(row); return div

# ─── Row builders ──────────────────────────────────────────────────────────

func _build_slider_row(label: String, initial: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 40)
	var lbl: Label = TabHelpers.mono(label, 10, Palette.UI_TEXT_1)
	lbl.custom_minimum_size = Vector2(100, 0)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 28)
	slider.focus_mode = Control.FOCUS_NONE
	var value_lbl: Label = TabHelpers.mono("%d" % int(round(initial * 100.0)), 10, Palette.UI_TEXT_0)
	value_lbl.custom_minimum_size = Vector2(34, 0)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(v: float):
		value_lbl.text = "%d" % int(round(v * 100.0))
		on_change.call(v))
	row.add_child(slider)
	row.add_child(value_lbl)
	var div := _row_divider(); div.add_child(row); return div

func _build_toggle_row(label: String, initial: bool, on_toggle: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 36)
	var lbl: Label = TabHelpers.mono(label, 10, Palette.UI_TEXT_1)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var cb := CheckButton.new()
	cb.button_pressed = initial
	cb.toggled.connect(func(b: bool):
		SfxBank.play_ui(&"ui_click")
		on_toggle.call(b))
	row.add_child(cb)
	var div := _row_divider(); div.add_child(row); return div

func _build_text_row(label: String, value: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 36)
	var lbl: Label = TabHelpers.mono(label, 10, Palette.UI_TEXT_1)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	row.add_child(TabHelpers.mono(value, 11, Palette.UI_CYAN))
	var div := _row_divider(); div.add_child(row); return div

func _row_divider() -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	var div := ColorRect.new()
	div.color = Palette.UI_LINE_1
	div.custom_minimum_size = Vector2(0, 1)
	vb.add_child(div)
	return vb
