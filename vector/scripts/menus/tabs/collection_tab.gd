extends Control
## COLLECTION tab — summary strip, filter chips, 3-col card grid, upgrade
## banner. Reads from PlayerDeck.pool() + PlayerProfile for levels / costs.

enum Filter { ALL, OWNED, LOCKED }
var _filter: Filter = Filter.ALL
var _grid_host: Control
var _filter_buttons: Array[Button] = []
var _summary_host: VBoxContainer

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

	_summary_host = VBoxContainer.new()
	_summary_host.add_theme_constant_override("separation", 12)
	inner.add_child(_summary_host)
	_rebuild_summary()

	inner.add_child(_build_filter_row())

	_grid_host = VBoxContainer.new()
	_grid_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(_grid_host)
	_rebuild_grid()

	inner.add_child(_build_upgrade_banner())

	if PlayerProfile != null and not PlayerProfile.changed.is_connected(_on_profile_changed):
		PlayerProfile.changed.connect(_on_profile_changed)

func _on_profile_changed() -> void:
	_rebuild_grid()
	_rebuild_summary()

# ─── Summary strip ─────────────────────────────────────────────────────────

func _rebuild_summary() -> void:
	for c in _summary_host.get_children():
		c.queue_free()
	var panel: PanelContainer = TabHelpers.make_panel(Palette.UI_BG_1, Palette.UI_LINE_2, Palette.UI_CYAN)
	var m: MarginContainer = TabHelpers.margin(12, 12, 12, 12)
	panel.add_child(m)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	m.add_child(row)
	var pool: Array = PlayerDeck.pool() if PlayerDeck != null else []
	var total: int = pool.size()
	var owned: int = 0
	var upgrades_ready: int = 0
	if PlayerProfile != null:
		for c in pool:
			if PlayerProfile.is_card_unlocked(c):
				owned += 1
				if PlayerProfile.can_upgrade(c.id):
					upgrades_ready += 1
	# Left block: count
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	row.add_child(left)
	left.add_child(TabHelpers.label("COLLECTION", 9, Palette.UI_TEXT_3))
	var count_row := HBoxContainer.new()
	count_row.add_theme_constant_override("separation", 0)
	left.add_child(count_row)
	count_row.add_child(TabHelpers.hero_number(str(owned), 20, Palette.UI_TEXT_0))
	count_row.add_child(TabHelpers.hero_number("/%d" % total, 20, Palette.UI_TEXT_3))
	# Middle block: next unlock progress
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 4)
	row.add_child(middle)
	var pbar := PBar.new()
	pbar.progress = float(owned) / float(maxi(1, total))
	middle.add_child(pbar)
	var next_unlock := _next_locked_card(pool)
	var next_text: String = "ALL UNLOCKED"
	if next_unlock != null:
		next_text = "NEXT ▸ LVL %d · %s" % [next_unlock.unlock_level, next_unlock.display_name.to_upper()]
	middle.add_child(TabHelpers.mono(next_text, 9, Palette.UI_TEXT_3))
	# Right block: upgrades count
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 2)
	row.add_child(right)
	right.add_child(TabHelpers.label("UPGRADES", 9, Palette.UI_TEXT_3))
	right.add_child(TabHelpers.hero_number(str(upgrades_ready), 20, Palette.UI_AMBER))
	_summary_host.add_child(panel)

func _next_locked_card(pool: Array) -> CardData:
	if PlayerProfile == null:
		return null
	var best: CardData = null
	var best_level: int = 999
	for c in pool:
		if PlayerProfile.is_card_unlocked(c):
			continue
		if c.unlock_level < best_level:
			best = c
			best_level = c.unlock_level
	return best

# ─── Filter chips ─────────────────────────────────────────────────────────

func _build_filter_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_filter_buttons.clear()
	var pool: Array = PlayerDeck.pool() if PlayerDeck != null else []
	var counts := {
		Filter.ALL: pool.size(),
		Filter.OWNED: _count(pool, func(c): return PlayerProfile.is_card_unlocked(c) if PlayerProfile != null else true),
		Filter.LOCKED: _count(pool, func(c): return not (PlayerProfile.is_card_unlocked(c) if PlayerProfile != null else true)),
	}
	for spec in [[Filter.ALL, "ALL"], [Filter.OWNED, "OWNED"], [Filter.LOCKED, "LOCKED"]]:
		var f_id = spec[0]
		var label: String = spec[1]
		var b := Button.new()
		b.text = "%s  %d" % [label, int(counts.get(f_id, 0))]
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 32)
		b.add_theme_font_override("font", Palette.FONT_DISPLAY)
		b.add_theme_font_size_override("font_size", 10)
		b.pressed.connect(func():
			SfxBank.play_ui(&"ui_click")
			_filter = f_id
			_refresh_filter_buttons()
			_rebuild_grid())
		row.add_child(b)
		_filter_buttons.append(b)
	_refresh_filter_buttons()
	return row

func _count(arr: Array, pred: Callable) -> int:
	var n := 0
	for x in arr:
		if pred.call(x):
			n += 1
	return n

func _refresh_filter_buttons() -> void:
	for i in _filter_buttons.size():
		var active: bool = i == _filter
		var b := _filter_buttons[i]
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.357, 0.878, 1.0, 0.08) if active else Color(0, 0, 0, 0)
		sb.border_color = Palette.UI_CYAN if active else Palette.UI_LINE_2
		sb.border_width_top = 1; sb.border_width_bottom = 1
		sb.border_width_left = 1; sb.border_width_right = 1
		for sn in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(sn, sb)
		b.add_theme_color_override("font_color", Palette.UI_CYAN if active else Palette.UI_TEXT_2)
		b.add_theme_color_override("font_hover_color", Palette.UI_CYAN if active else Palette.UI_TEXT_0)

# ─── Card grid ─────────────────────────────────────────────────────────────

func _rebuild_grid() -> void:
	for c in _grid_host.get_children():
		c.queue_free()
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_host.add_child(grid)
	var pool: Array = PlayerDeck.pool() if PlayerDeck != null else []
	var filtered: Array = []
	for c in pool:
		var unlocked: bool = PlayerProfile.is_card_unlocked(c) if PlayerProfile != null else true
		match _filter:
			Filter.ALL: filtered.append(c)
			Filter.OWNED: if unlocked: filtered.append(c)
			Filter.LOCKED: if not unlocked: filtered.append(c)
	for c in filtered:
		grid.add_child(_build_card_tile(c))

func _build_card_tile(c: CardData) -> Control:
	var unlocked: bool = PlayerProfile.is_card_unlocked(c) if PlayerProfile != null else true
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 118)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.UI_BG_1
	sb.border_color = Palette.UI_LINE_2 if unlocked else Palette.UI_LINE_1
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_width_left = 1; sb.border_width_right = 1
	panel.add_theme_stylebox_override("panel", sb)
	if not unlocked:
		panel.modulate.a = 0.55

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	panel.add_child(vb)
	# Role stripe (2px)
	var stripe := ColorRect.new()
	stripe.color = c.color
	stripe.custom_minimum_size = Vector2(0, 2)
	vb.add_child(stripe)
	var m: MarginContainer = TabHelpers.margin(6, 4, 6, 4)
	vb.add_child(m)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 3)
	m.add_child(inner)
	# Top row: role tag + level chip
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	inner.add_child(top)
	var role: Label = TabHelpers.label(c.role_label(), 8, c.color)
	role.add_theme_font_override("font", Palette.FONT_DISPLAY)
	top.add_child(role)
	var top_spacer: Control = TabHelpers.spacer(0)
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_spacer)
	var level: int = PlayerProfile.get_card_level(c.id) if PlayerProfile != null else 1
	var lvl_chip: Label = TabHelpers.mono("L%d" % level, 8, Palette.UI_TEXT_2)
	top.add_child(lvl_chip)
	# Glyph area — aspect 1
	var glyph_panel := PanelContainer.new()
	glyph_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(0.047, 0.055, 0.071, 0.7)
	gsb.border_color = Palette.UI_LINE_2
	gsb.border_width_top = 1; gsb.border_width_bottom = 1
	gsb.border_width_left = 1; gsb.border_width_right = 1
	glyph_panel.add_theme_stylebox_override("panel", gsb)
	glyph_panel.custom_minimum_size = Vector2(0, 64)
	inner.add_child(glyph_panel)
	var glyph_inner := Control.new()
	glyph_inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph_panel.add_child(glyph_inner)
	# Cost pip (amber circle bottom-left)
	var pip := _make_cost_pip(c.cost)
	pip.position = Vector2(4, 40)
	glyph_inner.add_child(pip)
	# Rarity LED (top-right)
	var led := StatusDot.new()
	led.color = Palette.rarity_color(c.rarity)
	led.radius = 3.0
	led.position = Vector2(glyph_panel.size.x - 16, 4)
	led.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	led.offset_left = -14; led.offset_top = 4
	led.offset_right = -4; led.offset_bottom = 14
	glyph_inner.add_child(led)
	# Glyph centered
	var icon := ShapeIcon.new()
	icon.shape = c.shape
	icon.color = c.color if unlocked else Palette.UI_TEXT_3
	icon.icon_size = 22.0
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.offset_left = -22; icon.offset_top = -22
	icon.offset_right = 22; icon.offset_bottom = 22
	glyph_inner.add_child(icon)
	# Name
	var name_lbl: Label = TabHelpers.label(c.display_name.to_upper(), 10, Palette.UI_TEXT_0 if unlocked else Palette.UI_TEXT_3)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", Palette.FONT_DISPLAY_BOLD)
	inner.add_child(name_lbl)
	# Upgrade CTA / lock label
	if unlocked:
		var cost: int = PlayerProfile.upgrade_cost(c.id) if PlayerProfile != null else -1
		var cta := Button.new()
		cta.flat = false
		cta.focus_mode = Control.FOCUS_NONE
		cta.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		cta.add_theme_font_override("font", Palette.FONT_MONO_BOLD)
		cta.add_theme_font_size_override("font_size", 9)
		var cta_sb := StyleBoxFlat.new()
		cta_sb.bg_color = Color(1.0, 0.714, 0.282, 0.08)
		cta_sb.border_color = Palette.UI_AMBER_DIM
		cta_sb.border_width_top = 1
		for sn in ["normal", "hover", "pressed"]:
			cta.add_theme_stylebox_override(sn, cta_sb)
		cta.custom_minimum_size = Vector2(0, 22)
		if cost < 0:
			cta.text = "MAX"
			cta.disabled = true
			cta.add_theme_color_override("font_color", Palette.UI_GREEN)
			cta.add_theme_color_override("font_disabled_color", Palette.UI_GREEN)
		else:
			cta.text = "UPGRADE %d" % cost
			var affordable: bool = PlayerProfile.can_upgrade(c.id) if PlayerProfile != null else false
			cta.add_theme_color_override("font_color", Palette.UI_AMBER)
			cta.add_theme_color_override("font_hover_color", Color(1.0, 0.86, 0.35))
			cta.add_theme_color_override("font_disabled_color", Palette.UI_TEXT_3)
			cta.disabled = not affordable
			var card_id: StringName = c.id
			cta.pressed.connect(func():
				SfxBank.play_ui(&"ui_confirm")
				if PlayerProfile != null and PlayerProfile.upgrade(card_id):
					pass)
		inner.add_child(cta)
	else:
		var lk: Label = TabHelpers.mono("LVL %d" % c.unlock_level, 9, Palette.UI_TEXT_3)
		lk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(lk)
	return panel

func _make_cost_pip(cost: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(16, 16)
	c.draw.connect(func():
		c.draw_circle(Vector2(8, 8), 8, Palette.UI_AMBER)
		var f := Palette.FONT_MONO_BOLD
		var txt := str(cost)
		var txt_size: Vector2 = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
		c.draw_string(f, Vector2(8 - txt_size.x * 0.5, 8 + 4),
			txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.BLACK))
	return c

# ─── Upgrade banner ─────────────────────────────────────────────────────────

func _build_upgrade_banner() -> Control:
	var ready: Array[CardData] = []
	if PlayerProfile != null and PlayerDeck != null:
		for c in PlayerDeck.pool():
			if PlayerProfile.can_upgrade(c.id):
				ready.append(c)
	if ready.is_empty():
		return Control.new()
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.714, 0.282, 0.04)
	sb.border_color = Color(1.0, 0.714, 0.282, 0.35)
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_width_left = 1; sb.border_width_right = 1
	panel.add_theme_stylebox_override("panel", sb)
	var m: MarginContainer = TabHelpers.margin(12, 10, 12, 10)
	panel.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	m.add_child(col)
	col.add_child(TabHelpers.label("▸ READY TO UPGRADE", 10, Palette.UI_AMBER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	# Up to 3 glyph chips
	for c in ready.slice(0, 3):
		var icon := ShapeIcon.new()
		icon.shape = c.shape
		icon.color = c.color
		icon.icon_size = 14.0
		icon.custom_minimum_size = Vector2(28, 28)
		row.add_child(icon)
	row.add_child(TabHelpers.mono("%d CARDS READY" % ready.size(), 10, Palette.UI_TEXT_1))
	row.get_child(row.get_child_count() - 1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel
