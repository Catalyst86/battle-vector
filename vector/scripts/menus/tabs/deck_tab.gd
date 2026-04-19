extends Control
## DECK tab — 4-col deck grid, detail panel for selected card, balance meter,
## active synergies, EDIT DECK primary CTA.

var _selected_idx: int = 0
var _detail_host: Control
var _balance_host: Control
var _synergy_host: Control
var _grid_host: Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var sc: ScrollContainer = TabHelpers.tab_scroll()
	add_child(sc)
	var outer: VBoxContainer = TabHelpers.tab_column()
	sc.add_child(outer)
	var m: MarginContainer = TabHelpers.margin(14, 14, 14, 110)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner: VBoxContainer = TabHelpers.tab_column()
	m.add_child(inner)
	outer.add_child(m)

	# Header
	inner.add_child(_build_header())
	# Deck grid
	_grid_host = VBoxContainer.new()
	_grid_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(_grid_host)
	_rebuild_grid()
	# Detail panel
	_detail_host = VBoxContainer.new()
	_detail_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(_detail_host)
	_rebuild_detail()
	# Balance meter
	_balance_host = VBoxContainer.new()
	_balance_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(_balance_host)
	_rebuild_balance()
	# Synergy panel
	_synergy_host = VBoxContainer.new()
	_synergy_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(_synergy_host)
	_rebuild_synergy()
	# CTA
	inner.add_child(TabHelpers.primary_button("▸ EDIT DECK", func():
		Router.goto("res://scenes/menus/deck_builder.tscn")))

func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(TabHelpers.label("ACTIVE LOADOUT", 9, Palette.UI_TEXT_3))
	var deck_size: int = PlayerDeck.cards.size() if PlayerDeck != null else 0
	col.add_child(TabHelpers.label("DECK_01  //  %d/8" % deck_size, 14, Palette.UI_TEXT_0))
	row.add_child(col)
	return row

func _rebuild_grid() -> void:
	for c in _grid_host.get_children():
		c.queue_free()
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_host.add_child(grid)
	var cards: Array = PlayerDeck.cards if PlayerDeck != null else []
	for i in cards.size():
		grid.add_child(_build_deck_tile(cards[i], i))

func _build_deck_tile(c: CardData, idx: int) -> Control:
	var selected: bool = idx == _selected_idx
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 82)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.UI_BG_1
	sb.border_color = Palette.UI_CYAN if selected else Palette.UI_LINE_2
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_width_left = 1; sb.border_width_right = 1
	if selected:
		sb.shadow_color = Palette.UI_CYAN_GLOW
		sb.shadow_size = 6
	panel.add_theme_stylebox_override("panel", sb)
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(btn)
	btn.pressed.connect(func():
		SfxBank.play_ui(&"ui_click")
		_selected_idx = idx
		_rebuild_grid()
		_rebuild_detail())

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 2)
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 4; vb.offset_right = -4; vb.offset_top = 3; vb.offset_bottom = -3
	panel.add_child(vb)

	var role: Label = TabHelpers.label(c.role_label(), 7, c.color)
	vb.add_child(role)
	# Glyph
	var icon := ShapeIcon.new()
	icon.shape = c.shape
	icon.color = c.color
	icon.icon_size = 18.0
	icon.custom_minimum_size = Vector2(0, 34)
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(icon)
	# Name
	var name_lbl: Label = TabHelpers.label(c.display_name.to_upper(), 8, Palette.UI_TEXT_0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", Palette.FONT_DISPLAY_BOLD)
	vb.add_child(name_lbl)
	# Cost pip — draw manually in top-right
	var cost_lbl := Label.new()
	cost_lbl.text = str(c.cost)
	cost_lbl.add_theme_font_override("font", Palette.FONT_MONO_BOLD)
	cost_lbl.add_theme_font_size_override("font_size", 9)
	cost_lbl.add_theme_color_override("font_color", Palette.UI_AMBER)
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	cost_lbl.offset_left = 4; cost_lbl.offset_top = 2
	panel.add_child(cost_lbl)
	return panel

func _rebuild_detail() -> void:
	for c in _detail_host.get_children():
		c.queue_free()
	var cards: Array = PlayerDeck.cards if PlayerDeck != null else []
	if _selected_idx < 0 or _selected_idx >= cards.size():
		return
	var c: CardData = cards[_selected_idx]
	var panel: PanelContainer = TabHelpers.make_panel(Palette.UI_BG_1, Palette.UI_LINE_2, Palette.UI_CYAN)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var m: MarginContainer = TabHelpers.margin(12, 12, 12, 12)
	panel.add_child(m)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	m.add_child(row)
	# Glyph panel
	var gp := PanelContainer.new()
	gp.custom_minimum_size = Vector2(60, 60)
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(0.047, 0.055, 0.071, 0.7)
	gsb.border_color = Palette.UI_LINE_2
	gsb.border_width_top = 1; gsb.border_width_bottom = 1
	gsb.border_width_left = 1; gsb.border_width_right = 1
	gp.add_theme_stylebox_override("panel", gsb)
	var icon := ShapeIcon.new()
	icon.shape = c.shape
	icon.color = c.color
	icon.icon_size = 22.0
	gp.add_child(icon)
	row.add_child(gp)
	# Info col
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	row.add_child(info)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	info.add_child(name_row)
	var name_lbl: Label = TabHelpers.label(c.display_name.to_upper(), 14, c.color)
	name_lbl.add_theme_font_override("font", Palette.FONT_DISPLAY_BOLD)
	name_row.add_child(name_lbl)
	name_row.add_child(TabHelpers.mono("// " + c.role_label(), 10, Palette.UI_TEXT_3))
	# Stat row — HFlowContainer in case the row ever gets crowded.
	var stats := HFlowContainer.new()
	stats.add_theme_constant_override("h_separation", 14)
	stats.add_theme_constant_override("v_separation", 4)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(stats)
	stats.add_child(_stat_pill("DMG", "%d" % int(c.damage), Palette.UI_RED))
	stats.add_child(_stat_pill("RNG", "%d" % int(c.attack_range / 20.0), Palette.UI_CYAN))
	var rate_txt: String = "—" if c.fire_rate <= 0.0 else "%.1f/s" % (1.0 / c.fire_rate)
	stats.add_child(_stat_pill("RATE", rate_txt, Palette.UI_GREEN))
	stats.add_child(_stat_pill("COST", str(c.cost), Palette.UI_AMBER))
	_detail_host.add_child(panel)

func _stat_pill(label_text: String, value: String, color: Color) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.add_child(TabHelpers.label(label_text, 8, Palette.UI_TEXT_3))
	var v: Label = TabHelpers.mono(value, 13, color)
	v.add_theme_font_override("font", Palette.FONT_MONO_BOLD)
	vb.add_child(v)
	return vb

func _rebuild_balance() -> void:
	for c in _balance_host.get_children():
		c.queue_free()
	var cards: Array = PlayerDeck.cards if PlayerDeck != null else []
	if cards.is_empty():
		return
	# Role distribution
	var role_counts: Dictionary = {}
	var role_colors: Dictionary = {}
	var total_cost: int = 0
	for c in cards:
		role_counts[c.role_label()] = int(role_counts.get(c.role_label(), 0)) + 1
		role_colors[c.role_label()] = c.color
		total_cost += c.cost
	var avg_cost: float = float(total_cost) / float(cards.size())

	var panel: PanelContainer = TabHelpers.make_panel(Palette.UI_BG_1, Palette.UI_LINE_2)
	var m: MarginContainer = TabHelpers.margin(12, 12, 12, 12)
	panel.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	m.add_child(vb)
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	vb.add_child(hdr)
	hdr.add_child(TabHelpers.label("▸ DECK BALANCE", 10, Palette.UI_TEXT_2))
	hdr.add_child(TabHelpers.spacer(0))
	hdr.get_child(hdr.get_child_count() - 1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(TabHelpers.mono("AVG COST %.1f" % avg_cost, 10, Palette.UI_TEXT_3))
	# Stacked role bar (segmented by role count)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 2)
	bar.custom_minimum_size = Vector2(0, 6)
	vb.add_child(bar)
	for role in role_counts.keys():
		var n: int = int(role_counts[role])
		var seg := ColorRect.new()
		seg.color = role_colors[role]
		seg.color.a = 0.85
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.size_flags_stretch_ratio = float(n)
		bar.add_child(seg)
	# Legend — HFlowContainer wraps to a second line when role count is high.
	var legend := HFlowContainer.new()
	legend.add_theme_constant_override("h_separation", 10)
	legend.add_theme_constant_override("v_separation", 4)
	legend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(legend)
	for role in role_counts.keys():
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 4)
		var dot := StatusDot.new()
		dot.color = role_colors[role]
		dot.radius = 3.0
		item.add_child(dot)
		item.add_child(TabHelpers.mono("%s ×%d" % [role, int(role_counts[role])], 9, Palette.UI_TEXT_2))
		legend.add_child(item)
	_balance_host.add_child(panel)

func _rebuild_synergy() -> void:
	for c in _synergy_host.get_children():
		c.queue_free()
	var ids: Array = []
	var cards: Array = PlayerDeck.cards if PlayerDeck != null else []
	for c in cards:
		ids.append(c.id)
	var active: Array = Synergies.active_for(ids) if Synergies != null else []
	if active.is_empty():
		return

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.357, 0.878, 1.0, 0.03)
	sb.border_color = Color(0.357, 0.878, 1.0, 0.2)
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_width_left = 1; sb.border_width_right = 1
	panel.add_theme_stylebox_override("panel", sb)
	var m: MarginContainer = TabHelpers.margin(12, 10, 12, 10)
	panel.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	m.add_child(vb)
	vb.add_child(TabHelpers.label("▸ ACTIVE SYNERGIES", 10, Palette.UI_CYAN))
	for pair in active:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var card_a: CardData = _find_card(pair.a)
		var card_b: CardData = _find_card(pair.b)
		if card_a and card_b:
			var ia := ShapeIcon.new(); ia.shape = card_a.shape; ia.color = card_a.color; ia.icon_size = 9.0; ia.custom_minimum_size = Vector2(18, 18)
			row.add_child(ia)
			row.add_child(TabHelpers.mono("+", 10, Palette.UI_TEXT_3))
			var ib := ShapeIcon.new(); ib.shape = card_b.shape; ib.color = card_b.color; ib.icon_size = 9.0; ib.custom_minimum_size = Vector2(18, 18)
			row.add_child(ib)
		var bonus_pct: int = int(round(float(pair.bonus) * 100.0))
		row.add_child(TabHelpers.mono("%s +%d%%" % [String(pair.label), bonus_pct], 10, Palette.UI_TEXT_1))
		vb.add_child(row)
	_synergy_host.add_child(panel)

func _find_card(id: StringName) -> CardData:
	if PlayerDeck == null:
		return null
	for c in PlayerDeck.pool():
		if c.id == id:
			return c
	return null
