extends Control
## DECK tab — 4-col deck grid, detail panel for selected card, balance meter,
## active synergies, EDIT DECK primary CTA.
##
## Long-press a deck tile to pop a context menu (VIEW INFO / REMOVE).
## VIEW INFO opens a full-screen card detail modal; REMOVE saves the deck
## with that slot dropped and sends the player to the deck builder to
## pick a replacement.

const LONG_PRESS_SEC: float = 0.45
const LONG_PRESS_MAX_DRIFT: float = 20.0

var _selected_idx: int = 0
var _detail_host: Control
var _balance_host: Control
var _synergy_host: Control
var _grid_host: Control

var _press_idx: int = -1
var _press_pos: Vector2
var _press_tile: Control = null
var _press_timer: Timer
var _long_press_fired: bool = false
var _context_menu: Control = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_press_timer = Timer.new()
	_press_timer.one_shot = true
	_press_timer.wait_time = LONG_PRESS_SEC
	_press_timer.timeout.connect(_on_long_press_fired)
	add_child(_press_timer)
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
	# Custom gui_input instead of a Button so we can detect long-press
	# without Button's built-in click semantics consuming the event first.
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(e: InputEvent):
		_handle_tile_input(e, idx, panel))

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
	icon.silhouette_id = c.silhouette_id
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
	icon.silhouette_id = c.silhouette_id
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
			var ia := ShapeIcon.new(); ia.shape = card_a.shape; ia.color = card_a.color; ia.silhouette_id = card_a.silhouette_id; ia.icon_size = 9.0; ia.custom_minimum_size = Vector2(18, 18)
			row.add_child(ia)
			row.add_child(TabHelpers.mono("+", 10, Palette.UI_TEXT_3))
			var ib := ShapeIcon.new(); ib.shape = card_b.shape; ib.color = card_b.color; ib.silhouette_id = card_b.silhouette_id; ib.icon_size = 9.0; ib.custom_minimum_size = Vector2(18, 18)
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

# ─── Long-press + context menu ─────────────────────────────────────────────

func _handle_tile_input(event: InputEvent, idx: int, tile: Control) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press_idx = idx
			_press_pos = mb.position
			_press_tile = tile
			_long_press_fired = false
			_press_timer.start()
		else:
			_press_timer.stop()
			if _long_press_fired:
				_long_press_fired = false
				return  # context menu already showed; don't also select
			if _press_idx == idx:
				# Tap — select card.
				SfxBank.play_ui(&"ui_click")
				_selected_idx = idx
				_rebuild_grid()
				_rebuild_detail()
			_press_idx = -1
			_press_tile = null
	elif event is InputEventMouseMotion:
		# Cancel long-press if the finger drifts past the threshold — that's
		# the user trying to scroll, not holding to pop the menu.
		if _press_idx == idx:
			var mm := event as InputEventMouseMotion
			if mm.position.distance_to(_press_pos) > LONG_PRESS_MAX_DRIFT:
				_press_timer.stop()
				_press_idx = -1

func _on_long_press_fired() -> void:
	if _press_idx < 0:
		return
	_long_press_fired = true
	SfxBank.play_ui(&"ui_confirm")
	_show_context_menu(_press_idx)

func _show_context_menu(idx: int) -> void:
	if _context_menu != null and is_instance_valid(_context_menu):
		_context_menu.queue_free()
	var cards: Array = PlayerDeck.cards if PlayerDeck != null else []
	if idx < 0 or idx >= cards.size():
		return
	var card: CardData = cards[idx]
	var tile: Control = _press_tile
	if tile == null or not is_instance_valid(tile):
		return

	# Overlay fills the whole tab — backdrop absorbs outside taps. The menu
	# itself is a small floating panel positioned next to the source tile.
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 30
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.016, 0.027, 0.047, 0.5)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_context_menu())
	overlay.add_child(backdrop)

	# Build the floating menu.
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.UI_BG_2
	sb.border_color = Palette.UI_CYAN
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_width_left = 1; sb.border_width_right = 1
	sb.shadow_color = Palette.UI_CYAN_GLOW
	sb.shadow_size = 14
	panel.add_theme_stylebox_override("panel", sb)
	overlay.add_child(panel)

	var m: MarginContainer = TabHelpers.margin(10, 8, 10, 8)
	panel.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	m.add_child(col)

	# Compact header: name only, card-colored. Glyph omitted to save width.
	var name_lbl: Label = TabHelpers.label(card.display_name.to_upper(), 11, card.color)
	name_lbl.add_theme_font_override("font", Palette.FONT_DISPLAY_BOLD)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_lbl)
	col.add_child(TabHelpers.divider(Palette.UI_LINE_2))

	var info_btn: Button = TabHelpers.ghost_button("▸ VIEW INFO", func():
		_close_context_menu()
		_show_card_detail(card), Palette.UI_CYAN)
	info_btn.custom_minimum_size = Vector2(0, 36)
	col.add_child(info_btn)
	var remove_btn: Button = TabHelpers.ghost_button("× REMOVE", func():
		_close_context_menu()
		_remove_from_deck(idx), Palette.UI_RED)
	remove_btn.add_theme_color_override("font_color", Palette.UI_RED)
	remove_btn.custom_minimum_size = Vector2(0, 36)
	col.add_child(remove_btn)

	add_child(overlay)
	_context_menu = overlay

	# Defer positioning until the panel has measured itself, so we know the
	# real width/height and can pick the best side.
	panel.modulate = Color(1, 1, 1, 0)
	panel.scale = Vector2(0.92, 0.92)
	_position_context_menu.call_deferred(panel, tile)

func _position_context_menu(panel: PanelContainer, tile: Control) -> void:
	if panel == null or not is_instance_valid(panel) or tile == null or not is_instance_valid(tile):
		return
	var menu_size: Vector2 = panel.get_combined_minimum_size()
	menu_size.x = maxf(menu_size.x, 150.0)
	var tile_rect: Rect2 = tile.get_global_rect()
	var viewport: Vector2 = get_viewport_rect().size
	var margin: float = 8.0
	var screen_edge: float = 6.0

	# Prefer right-of-tile, fall back to left, then below, then above —
	# always staying inside the viewport.
	var pos := Vector2.ZERO
	var space_right: float = viewport.x - (tile_rect.position.x + tile_rect.size.x) - screen_edge
	var space_left: float = tile_rect.position.x - screen_edge
	var space_below: float = viewport.y - (tile_rect.position.y + tile_rect.size.y) - screen_edge
	var space_above: float = tile_rect.position.y - screen_edge

	if space_right >= menu_size.x + margin:
		pos.x = tile_rect.position.x + tile_rect.size.x + margin
		pos.y = tile_rect.position.y
	elif space_left >= menu_size.x + margin:
		pos.x = tile_rect.position.x - menu_size.x - margin
		pos.y = tile_rect.position.y
	elif space_below >= menu_size.y + margin:
		pos.x = tile_rect.position.x + tile_rect.size.x * 0.5 - menu_size.x * 0.5
		pos.y = tile_rect.position.y + tile_rect.size.y + margin
	else:
		pos.x = tile_rect.position.x + tile_rect.size.x * 0.5 - menu_size.x * 0.5
		pos.y = maxf(screen_edge, tile_rect.position.y - menu_size.y - margin)

	# Clamp both axes so the menu never hangs off an edge.
	pos.x = clampf(pos.x, screen_edge, viewport.x - menu_size.x - screen_edge)
	pos.y = clampf(pos.y, screen_edge, viewport.y - menu_size.y - screen_edge)

	# Use anchors 0,0 — position via offset directly on the PanelContainer.
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = pos.x
	panel.offset_top = pos.y
	panel.offset_right = pos.x + menu_size.x
	panel.offset_bottom = pos.y + menu_size.y
	panel.pivot_offset = menu_size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.14)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _close_context_menu() -> void:
	if _context_menu == null or not is_instance_valid(_context_menu):
		return
	SfxBank.play_ui(&"ui_back")
	var menu := _context_menu
	_context_menu = null
	var tw := create_tween()
	tw.tween_property(menu, "modulate:a", 0.0, 0.12)
	tw.finished.connect(func(): menu.queue_free())

func _remove_from_deck(idx: int) -> void:
	if PlayerDeck == null:
		return
	var cards: Array[CardData] = PlayerDeck.cards.duplicate()
	if idx < 0 or idx >= cards.size():
		return
	var removed: CardData = cards[idx]
	cards.remove_at(idx)
	PlayerDeck.save_deck(cards)
	Toast.notify("▸ %s REMOVED — PICK A REPLACEMENT" % removed.display_name.to_upper(), 2.0)
	Router.goto("res://scenes/menus/deck_builder.tscn")

# ─── Card detail modal ─────────────────────────────────────────────────────

func _show_card_detail(card: CardData) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 35
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.016, 0.027, 0.047, 0.92)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_detail(overlay))
	overlay.add_child(backdrop)

	var sheet := PanelContainer.new()
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet.offset_left = 16; sheet.offset_right = -16
	sheet.offset_top = 60; sheet.offset_bottom = -60
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.UI_BG_1
	sb.border_color = Palette.UI_CYAN
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_width_left = 1; sb.border_width_right = 1
	sheet.add_theme_stylebox_override("panel", sb)
	overlay.add_child(sheet)
	# Corner brackets — added as direct children and anchored full-rect;
	# works here because the sheet is a PanelContainer with just this one
	# content child, the Corners acts as the second child covering the rect.
	var corners := Corners.new()
	corners.color = Palette.UI_CYAN
	corners.top_left = true
	corners.top_right = true
	corners.bottom_left = true
	corners.bottom_right = true
	sheet.add_child(corners)

	var m: MarginContainer = TabHelpers.margin(18, 18, 18, 18)
	sheet.add_child(m)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	m.add_child(sc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(col)

	col.add_child(_detail_header(card))
	col.add_child(_detail_glyph(card))
	col.add_child(_detail_description(card))
	col.add_child(_detail_stats(card))
	col.add_child(_detail_synergies(card))

	var close_btn: Button = TabHelpers.primary_button("▸ CLOSE", func(): _close_detail(overlay))
	col.add_child(close_btn)

	add_child(overlay)
	# Fade-in
	overlay.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.18)

func _close_detail(overlay: Control) -> void:
	SfxBank.play_ui(&"ui_back")
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 0.0, 0.14)
	tw.finished.connect(func(): overlay.queue_free())

func _detail_header(card: CardData) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(TabHelpers.label("▸ UNIT FILE", 9, Palette.UI_TEXT_3))
	var name_lbl: Label = TabHelpers.label(card.display_name.to_upper(), 22, card.color)
	name_lbl.add_theme_font_override("font", Palette.FONT_DISPLAY_BOLD)
	col.add_child(name_lbl)
	col.add_child(TabHelpers.mono("%s  //  %s" % [card.role_label(), String(card.rarity).to_upper()], 10, Palette.UI_TEXT_2))
	row.add_child(col)
	# Cost pip
	var pip := PanelContainer.new()
	pip.custom_minimum_size = Vector2(48, 48)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Palette.UI_AMBER
	psb.border_color = Palette.UI_AMBER
	pip.add_theme_stylebox_override("panel", psb)
	var cost_lbl := Label.new()
	cost_lbl.text = str(card.cost)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_override("font", Palette.FONT_MONO_BOLD)
	cost_lbl.add_theme_font_size_override("font_size", 22)
	cost_lbl.add_theme_color_override("font_color", Color.BLACK)
	pip.add_child(cost_lbl)
	row.add_child(pip)
	return row

func _detail_glyph(card: CardData) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.047, 0.055, 0.071, 0.7)
	sb.border_color = Palette.UI_LINE_2
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_width_left = 1; sb.border_width_right = 1
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(0, 140)
	var icon := ShapeIcon.new()
	icon.shape = card.shape
	icon.color = card.color
	icon.silhouette_id = card.silhouette_id
	icon.icon_size = 42.0
	icon.glow = true
	panel.add_child(icon)
	return panel

func _detail_description(card: CardData) -> Control:
	var desc_text: String = card.description if card.description != "" else _default_role_desc(card.role)
	var lbl: Label = TabHelpers.mono(desc_text, 11, Palette.UI_TEXT_1)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(0, 0)
	return lbl

func _default_role_desc(role: int) -> String:
	match role:
		CardData.Role.SHOOTER: return "Fires ranged projectiles at the nearest enemy unit."
		CardData.Role.MELEE: return "Walks toward the enemy and detonates on contact for AoE damage."
		CardData.Role.WALLBREAK: return "Drills through walls without stopping. Good for cracking defences."
		CardData.Role.INTERCEPTOR: return "Chases down and rams into enemy units at close range."
		CardData.Role.SNIPER: return "Stationary, long-range. Picks off distant targets."
		CardData.Role.SWARM: return "Deploys multiple small scouts instead of a single unit."
		CardData.Role.HEALER: return "Restores HP to nearby allies."
		CardData.Role.BUFFER: return "Emits an aura that boosts allies in range."
	return "Deployed combat unit."

func _detail_stats(card: CardData) -> Control:
	var panel: PanelContainer = TabHelpers.make_panel(Palette.UI_BG_1, Palette.UI_LINE_2)
	var m: MarginContainer = TabHelpers.margin(12, 10, 12, 10)
	panel.add_child(m)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	m.add_child(grid)
	grid.add_child(_stat_cell("DMG", "%d" % int(card.damage), Palette.UI_RED))
	grid.add_child(_stat_cell("HP", "%d" % int(card.hp), Palette.UI_GREEN))
	grid.add_child(_stat_cell("COST", str(card.cost), Palette.UI_AMBER))
	grid.add_child(_stat_cell("RNG", "%d" % int(card.attack_range / 20.0), Palette.UI_CYAN))
	var rate_txt: String = "—" if card.fire_rate <= 0.0 else "%.1f/s" % (1.0 / card.fire_rate)
	grid.add_child(_stat_cell("RATE", rate_txt, Palette.UI_TEXT_0))
	grid.add_child(_stat_cell("SPEED", "%d" % int(card.speed), Palette.UI_TEXT_0))
	return panel

func _stat_cell(label_text: String, value: String, color: Color) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(TabHelpers.label(label_text, 8, Palette.UI_TEXT_3))
	var v: Label = TabHelpers.mono(value, 14, color)
	v.add_theme_font_override("font", Palette.FONT_MONO_BOLD)
	vb.add_child(v)
	return vb

func _detail_synergies(card: CardData) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.add_child(TabHelpers.label("▸ SYNERGIES", 10, Palette.UI_TEXT_3))
	var rows_added: int = 0
	if Synergies != null:
		for pair in Synergies.PAIRS:
			if pair.a != card.id and pair.b != card.id:
				continue
			var partner_id: StringName = pair.b if pair.a == card.id else pair.a
			var partner: CardData = _find_card(partner_id)
			if partner == null:
				continue
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			var partner_icon := ShapeIcon.new()
			partner_icon.shape = partner.shape
			partner_icon.color = partner.color
			partner_icon.silhouette_id = partner.silhouette_id
			partner_icon.icon_size = 9.0
			partner_icon.custom_minimum_size = Vector2(20, 20)
			row.add_child(partner_icon)
			row.add_child(TabHelpers.mono("+ %s  —  %s +%d%%" % [
				partner.display_name.to_upper(), String(pair.label),
				int(round(float(pair.bonus) * 100.0))], 10, Palette.UI_TEXT_1))
			vb.add_child(row)
			rows_added += 1
	if rows_added == 0:
		vb.add_child(TabHelpers.mono("NO KNOWN SYNERGIES.", 10, Palette.UI_TEXT_3))
	return vb
