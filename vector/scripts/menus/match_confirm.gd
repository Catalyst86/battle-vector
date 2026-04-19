extends Control
## Pre-match "deploy briefing" modal. Shown after the player taps 1V1 / 2V2
## in the bottom dock — before the queue radar. Confirms the mode, shows the
## opponent persona, the player's loadout, the rewards table, and the
## build/match timings. CANCEL dismisses; DEPLOY kicks off the match flow.

signal confirmed(mode: StringName)

var mode: StringName = &"1v1"
## For Volley entries — tracks whether the user picked the 2V2 variant.
## Default 1v1 (volley). Toggled via a chip in the body.
var _volley_is_2v2: bool = false

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
	# Top corner brackets
	var corners := Corners.new()
	corners.top_left = true
	corners.top_right = true
	corners.bottom_left = false
	corners.bottom_right = false
	corners.color = Palette.UI_CYAN
	sheet.add_child(corners)
	# Content
	var m: MarginContainer = TabHelpers.margin(18, 18, 18, 18)
	sheet.add_child(m)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	m.add_child(sc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(col)
	col.add_child(_build_header())
	if mode == &"volley":
		col.add_child(_build_volley_team_toggle())
	col.add_child(_build_opponent())
	col.add_child(_build_loadout())
	col.add_child(_build_rewards())
	col.add_child(_build_timing())
	col.add_child(_build_buttons())
	# Slide-in tween
	var start_y: float = sheet.offset_top
	sheet.offset_top = 260.0
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(sheet, "offset_top", start_y, 0.25)

func _close() -> void:
	SfxBank.play_ui(&"ui_back")
	var tween := create_tween().set_ease(Tween.EASE_IN)
	tween.tween_property(sheet, "offset_top", 260.0, 0.18)
	tween.parallel().tween_property(backdrop, "modulate:a", 0.0, 0.18)
	tween.finished.connect(func(): queue_free())

func _confirm() -> void:
	SfxBank.play_ui(&"ui_confirm")
	var emit_mode: StringName = mode
	if mode == &"volley" and _volley_is_2v2:
		emit_mode = &"volley_2v2"
	confirmed.emit(emit_mode)
	# Close quickly; parent will spawn the queue overlay.
	queue_free()

## Team-size chip row shown only when the parent opened this confirm with
## mode=volley. The player picks SOLO (1V1) or DUO (2V2) before DEPLOY.
func _build_volley_team_toggle() -> Control:
	var panel: PanelContainer = TabHelpers.make_panel(Palette.UI_BG_1, Palette.UI_LINE_2)
	var m: MarginContainer = TabHelpers.margin(12, 8, 12, 8)
	panel.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	m.add_child(vb)
	vb.add_child(TabHelpers.label("▸ TEAM SIZE", 9, Palette.UI_TEXT_3))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vb.add_child(row)
	var solo := _team_chip("SOLO · 1V1", not _volley_is_2v2)
	solo.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_volley_is_2v2 = false
			SfxBank.play_ui(&"ui_click")
			_refresh_volley_chips(row))
	var duo := _team_chip("DUO · 2V2", _volley_is_2v2)
	duo.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_volley_is_2v2 = true
			SfxBank.play_ui(&"ui_click")
			_refresh_volley_chips(row))
	row.add_child(solo)
	row.add_child(duo)
	return panel

func _team_chip(label: String, active: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 36)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.357, 0.878, 1.0, 0.08) if active else Color(0, 0, 0, 0)
	sb.border_color = Palette.UI_CYAN if active else Palette.UI_LINE_2
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_width_left = 1; sb.border_width_right = 1
	p.add_theme_stylebox_override("panel", sb)
	var lbl: Label = TabHelpers.label(label, 11, Palette.UI_CYAN if active else Palette.UI_TEXT_2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", Palette.FONT_DISPLAY_BOLD)
	var m := TabHelpers.margin(6, 6, 6, 6)
	p.add_child(m)
	m.add_child(lbl)
	return p

func _refresh_volley_chips(row: HBoxContainer) -> void:
	for c in row.get_children():
		c.queue_free()
	var solo := _team_chip("SOLO · 1V1", not _volley_is_2v2)
	solo.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_volley_is_2v2 = false
			SfxBank.play_ui(&"ui_click")
			_refresh_volley_chips(row))
	var duo := _team_chip("DUO · 2V2", _volley_is_2v2)
	duo.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_volley_is_2v2 = true
			SfxBank.play_ui(&"ui_click")
			_refresh_volley_chips(row))
	row.add_child(solo)
	row.add_child(duo)

# ─── Sections ──────────────────────────────────────────────────────────────

func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	col.add_child(TabHelpers.label("▸ DEPLOY BRIEFING", 9, Palette.UI_TEXT_3))
	var title := "SOLO · 1V1" if mode == &"1v1" else "DUO · 2V2"
	col.add_child(TabHelpers.label(title, 18, Palette.UI_CYAN))
	row.add_child(col)
	var x_btn := Button.new()
	x_btn.text = "×"
	x_btn.flat = true
	x_btn.focus_mode = Control.FOCUS_NONE
	x_btn.custom_minimum_size = Vector2(36, 36)
	x_btn.add_theme_font_override("font", Palette.FONT_MONO)
	x_btn.add_theme_font_size_override("font_size", 20)
	x_btn.add_theme_color_override("font_color", Palette.UI_TEXT_1)
	x_btn.add_theme_color_override("font_hover_color", Palette.UI_CYAN)
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0, 0, 0, 0)
	csb.border_color = Palette.UI_LINE_2
	csb.border_width_top = 1; csb.border_width_bottom = 1
	csb.border_width_left = 1; csb.border_width_right = 1
	for sn in ["normal", "hover", "pressed"]:
		x_btn.add_theme_stylebox_override(sn, csb)
	x_btn.pressed.connect(_close)
	row.add_child(x_btn)
	return row

func _build_opponent() -> Control:
	var panel: PanelContainer = TabHelpers.make_panel(Palette.UI_BG_1, Palette.UI_LINE_2)
	var m: MarginContainer = TabHelpers.margin(12, 10, 12, 10)
	panel.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	m.add_child(vb)
	vb.add_child(TabHelpers.label("▸ OPPONENT", 9, Palette.UI_TEXT_3))
	var arena_idx: int = PlayerProfile.arena_index() if PlayerProfile != null else 0
	var persona: Dictionary = BotPersonas.for_arena(arena_idx) if BotPersonas != null else {}
	var name: String = String(persona.get("name", "BOT"))
	var aggression: float = float(persona.get("aggression", 0.75))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	var dot := StatusDot.new()
	dot.color = Palette.UI_RED
	dot.radius = 4.0
	dot.mode = StatusDot.Mode.PULSE
	row.add_child(dot)
	var name_lbl: Label = TabHelpers.label(name, 14, Palette.UI_RED)
	name_lbl.add_theme_font_override("font", Palette.FONT_DISPLAY_BOLD)
	row.add_child(name_lbl)
	row.add_child(TabHelpers.spacer(0))
	row.get_child(row.get_child_count() - 1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var aggro_label: String = "AGGRESSIVE" if aggression >= 0.85 else ("BALANCED" if aggression >= 0.7 else "DEFENSIVE")
	row.add_child(TabHelpers.mono(aggro_label, 9, Palette.UI_AMBER))
	var arena_name: String = PlayerProfile.arena_name() if PlayerProfile != null else "GROUND ZERO"
	vb.add_child(TabHelpers.mono("ARENA %02d · %s" % [arena_idx + 1, arena_name], 10, Palette.UI_TEXT_2))
	return panel

func _build_loadout() -> Control:
	var panel: PanelContainer = TabHelpers.make_panel(Palette.UI_BG_1, Palette.UI_LINE_2)
	var m: MarginContainer = TabHelpers.margin(12, 10, 12, 10)
	panel.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	m.add_child(vb)
	vb.add_child(TabHelpers.label("▸ YOUR LOADOUT", 9, Palette.UI_TEXT_3))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	vb.add_child(grid)
	var deck: Array = PlayerDeck.cards if PlayerDeck != null else []
	for c in deck:
		grid.add_child(_build_deck_chip(c))
	return panel

func _build_deck_chip(c: CardData) -> Control:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(0, 52)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.047, 0.055, 0.071, 0.7)
	sb.border_color = Palette.UI_LINE_2
	sb.border_width_top = 2
	sb.border_width_bottom = 1
	sb.border_width_left = 1
	sb.border_width_right = 1
	# Role stripe via top border color
	sb.border_color = c.color
	# Restore other borders as faint lines — use a composite visual via
	# bg + inner bg trick: simpler to accept the full border is the role color.
	chip.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	chip.add_child(vb)
	var icon := ShapeIcon.new()
	icon.shape = c.shape
	icon.color = c.color
	icon.icon_size = 10.0
	icon.custom_minimum_size = Vector2(0, 28)
	vb.add_child(icon)
	var name_lbl: Label = TabHelpers.label(c.display_name.to_upper(), 8, Palette.UI_TEXT_0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", Palette.FONT_DISPLAY_BOLD)
	vb.add_child(name_lbl)
	return chip

func _build_rewards() -> Control:
	var panel: PanelContainer = TabHelpers.make_panel(Palette.UI_BG_1, Palette.UI_LINE_2)
	var m: MarginContainer = TabHelpers.margin(12, 10, 12, 10)
	panel.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	m.add_child(vb)
	vb.add_child(TabHelpers.label("▸ REWARDS", 9, Palette.UI_TEXT_3))
	vb.add_child(_reward_row("WIN", "+%d ★  +%d G  +%d XP" % [PlayerProfile.WIN_TROPHIES, PlayerProfile.WIN_GOLD, PlayerProfile.WIN_XP], Palette.UI_GREEN))
	vb.add_child(_reward_row("DRAW", "+%d ★  +%d G  +%d XP" % [PlayerProfile.DRAW_TROPHIES, PlayerProfile.DRAW_GOLD, PlayerProfile.DRAW_XP], Palette.UI_TEXT_2))
	vb.add_child(_reward_row("LOSS", "%d ★  +%d G  +%d XP" % [PlayerProfile.LOSS_TROPHIES, PlayerProfile.LOSS_GOLD, PlayerProfile.LOSS_XP], Palette.UI_RED))
	return panel

func _reward_row(tag: String, line: String, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lbl: Label = TabHelpers.label(tag, 10, color)
	lbl.custom_minimum_size = Vector2(50, 0)
	lbl.add_theme_font_override("font", Palette.FONT_DISPLAY_BOLD)
	row.add_child(lbl)
	row.add_child(TabHelpers.mono(line, 10, Palette.UI_TEXT_1))
	return row

func _build_timing() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var cfg := GameConfig.data
	# BUILD is a float since we tune sub-second timings — format with one
	# decimal, then trim a trailing ".0" so "7.5s" stays neat but "10s"
	# doesn't become "10.0s".
	var build_str: String = ("%.1f" % cfg.build_seconds).trim_suffix(".0") + "s"
	row.add_child(_time_stat("BUILD", build_str, Palette.UI_CYAN))
	row.add_child(_time_stat("MATCH", "%dm %ds" % [cfg.match_seconds / 60, cfg.match_seconds % 60], Palette.UI_AMBER))
	row.add_child(_time_stat("OT", "+%ds" % cfg.overtime_seconds, Palette.UI_RED))
	return row

func _time_stat(label: String, value: String, color: Color) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(TabHelpers.label(label, 8, Palette.UI_TEXT_3))
	var v: Label = TabHelpers.mono(value, 13, color)
	v.add_theme_font_override("font", Palette.FONT_MONO_BOLD)
	vb.add_child(v)
	return vb

func _build_buttons() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var cancel: Button = TabHelpers.ghost_button("◂ CANCEL", _close, Palette.UI_TEXT_1)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.size_flags_stretch_ratio = 1.0
	cancel.custom_minimum_size = Vector2(0, 48)
	row.add_child(cancel)
	var deploy: Button = TabHelpers.primary_button("▸ DEPLOY", _confirm)
	deploy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deploy.size_flags_stretch_ratio = 1.6
	deploy.custom_minimum_size = Vector2(0, 48)
	row.add_child(deploy)
	return row
