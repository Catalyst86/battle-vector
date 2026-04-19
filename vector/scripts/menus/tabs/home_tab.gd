extends Control
## HOME tab — the landing screen. Arena hero card, daily ops checklist, last-5
## W/L strip, quick actions. Everything reads from real systems (PlayerProfile,
## DailyOps, Synergies) so no hollow panels.
##
## Live-refreshes on `PlayerProfile.changed` + `DailyOps.changed` so returning
## from a match that ticked daily quests shows the new progress without a
## tab-swap.

const MARGIN := 14
var _reset_label: Label
var _timer: Timer
var _inner: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var sc: ScrollContainer = TabHelpers.tab_scroll()
	add_child(sc)
	var col: VBoxContainer = TabHelpers.tab_column()
	sc.add_child(col)
	var m: MarginContainer = TabHelpers.margin(MARGIN, MARGIN, MARGIN, 110)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inner = TabHelpers.tab_column()
	m.add_child(_inner)
	col.add_child(m)

	_rebuild()

	# 1Hz ticker for the daily-ops reset timer.
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.autostart = true
	_timer.timeout.connect(_tick)
	add_child(_timer)

	# Live-refresh on state changes. These signals are emitted by
	# autoloads and persist across tab switches; Godot auto-disconnects
	# when this node is freed.
	if PlayerProfile != null:
		PlayerProfile.changed.connect(_rebuild)
	if DailyOps != null:
		DailyOps.changed.connect(_rebuild)

func _rebuild() -> void:
	if _inner == null:
		return
	for c in _inner.get_children():
		c.queue_free()
	_reset_label = null
	_inner.add_child(TabHelpers.with_corners(_build_arena_hero(), Palette.UI_CYAN))
	_inner.add_child(_build_quick_actions())
	_inner.add_child(_build_daily_ops())
	_inner.add_child(_build_last5_strip())

func _tick() -> void:
	if _reset_label == null:
		return
	var s: int = DailyOps.seconds_until_reset()
	var h: int = s / 3600
	var m: int = (s % 3600) / 60
	var ss: int = s % 60
	_reset_label.text = "RESETS %02d:%02d:%02d" % [h, m, ss]

# ─── Sections ──────────────────────────────────────────────────────────────

func _build_arena_hero() -> Control:
	var panel: PanelContainer = TabHelpers.make_panel(
		Palette.UI_BG_1, Palette.UI_LINE_2, Palette.UI_CYAN)
	var grid := GridBg.new()
	grid.spacing = 8.0
	grid.color = Color(0.47, 0.588, 0.706, 0.04)
	panel.add_child(grid)

	var m: MarginContainer = TabHelpers.margin(14, 14, 14, 14)
	panel.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	m.add_child(vb)

	vb.add_child(TabHelpers.kicker("▸ CURRENT OP"))
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	vb.add_child(title_row)
	var arena_idx: int = PlayerProfile.arena_index() + 1 if PlayerProfile != null else 1
	var arena_name: String = PlayerProfile.arena_name() if PlayerProfile != null else "GROUND ZERO"
	var big: Label = TabHelpers.hero_number("ARENA %02d" % arena_idx, 22, Palette.UI_CYAN)
	big.add_theme_font_override("font", Palette.FONT_DISPLAY_BOLD)
	title_row.add_child(big)
	title_row.add_child(TabHelpers.spacer(0))
	title_row.add_child(TabHelpers.mono("LVL %d" % (PlayerProfile.data.player_level if PlayerProfile != null else 1), 10, Palette.UI_TEXT_3))

	vb.add_child(TabHelpers.label(arena_name, 14, Palette.UI_TEXT_0))
	var desc: Label = TabHelpers.mono("Low-density perimeter. Open sight lines — favour shooters.", 10, Palette.UI_TEXT_2)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(0, 0)
	vb.add_child(desc)

	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 6)
	vb.add_child(chip_row)
	chip_row.add_child(_make_status_chip("OPEN", Palette.UI_CYAN))
	chip_row.add_child(_make_status_chip("3 MINS", Palette.UI_AMBER))
	return panel

func _make_status_chip(text: String, dot_color: Color) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0,0,0,0.25)
	sb.border_color = Palette.UI_LINE_2
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_width_left = 1; sb.border_width_right = 1
	p.add_theme_stylebox_override("panel", sb)
	var m: MarginContainer = TabHelpers.margin(8, 4, 8, 4)
	p.add_child(m)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	m.add_child(row)
	var dot := StatusDot.new()
	dot.color = dot_color
	dot.radius = 3.0
	row.add_child(dot)
	row.add_child(TabHelpers.mono(text, 10, dot_color))
	return p

func _build_quick_actions() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.add_child(TabHelpers.ghost_button("▸ EDIT DECK", func():
		Router.goto("res://scenes/menus/deck_builder.tscn"), Palette.UI_TEXT_0))
	var claim_btn: Button = TabHelpers.ghost_button("▸ CLAIM CHEST",
		func(): _claim_chest(), Palette.UI_AMBER)
	claim_btn.add_theme_color_override("font_color", Palette.UI_AMBER)
	grid.add_child(claim_btn)
	return grid

func _claim_chest() -> void:
	if PlayerProfile == null:
		return
	if not PlayerProfile.can_claim_free_chest():
		SfxBank.play_ui(&"ui_back")
		return
	var r: Dictionary = PlayerProfile.claim_free_chest()
	if int(r.get("gold", 0)) > 0:
		SfxBank.play(&"victory")

func _build_daily_ops() -> Control:
	var panel: PanelContainer = TabHelpers.make_panel(Palette.UI_BG_1, Palette.UI_LINE_2)
	var m: MarginContainer = TabHelpers.margin(12, 12, 12, 12)
	panel.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	m.add_child(vb)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	vb.add_child(hdr)
	var kick: Label = TabHelpers.label("▸ DAILY OPS", 11, Palette.UI_TEXT_2)
	hdr.add_child(kick)
	hdr.add_child(TabHelpers.spacer(0))
	_reset_label = TabHelpers.mono("RESETS --:--:--", 9, Palette.UI_TEXT_3)
	hdr.add_child(_reset_label)
	hdr.get_child(1).size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var quests: Array = DailyOps.active() if DailyOps != null else []
	for q in quests:
		vb.add_child(_build_quest_row(q))
	_tick()
	return panel

func _on_ops_changed() -> void:
	# Legacy handler — kept as a no-op since _rebuild is now the source of
	# truth for refresh. Safe to delete once we confirm nothing else calls it.
	pass

func _build_quest_row(q: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var done: bool = DailyOps.is_done(q.id) if DailyOps != null else false
	# Checkbox
	var cb_size: int = 16
	var cb := Control.new()
	cb.custom_minimum_size = Vector2(cb_size, cb_size)
	cb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cb.draw.connect(func(): _draw_checkbox(cb, done))
	row.add_child(cb)
	# Label + progress
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	var lbl_color: Color = Palette.UI_TEXT_3 if done else Palette.UI_TEXT_1
	var lbl: Label = TabHelpers.label(String(q.label), 10, lbl_color)
	lbl.clip_text = true
	col.add_child(lbl)
	var pbar := PBar.new()
	pbar.color = Palette.UI_GREEN if done else Palette.UI_CYAN
	pbar.progress = 0.0
	if DailyOps != null:
		var cur: int = DailyOps.progress_of(q.id)
		var tgt: int = int(q.target)
		pbar.progress = clampf(float(cur) / float(tgt), 0.0, 1.0)
	col.add_child(pbar)
	row.add_child(col)
	# Count
	var count_text: String = "%d/%d" % [DailyOps.progress_of(q.id) if DailyOps != null else 0, int(q.target)]
	var count_lbl: Label = TabHelpers.mono(count_text, 9, Palette.UI_TEXT_3)
	count_lbl.custom_minimum_size = Vector2(34, 0)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(count_lbl)
	# Reward — keep tight. Gold + XP stacked on two lines to prevent overflow.
	var reward_col := VBoxContainer.new()
	reward_col.add_theme_constant_override("separation", 0)
	var gold_lbl: Label = TabHelpers.mono("+%dG" % int(q.reward_gold), 9, Palette.UI_AMBER)
	gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reward_col.add_child(gold_lbl)
	if int(q.reward_xp) > 0:
		var xp_lbl: Label = TabHelpers.mono("+%dXP" % int(q.reward_xp), 8, Palette.UI_TEXT_3)
		xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		reward_col.add_child(xp_lbl)
	reward_col.custom_minimum_size = Vector2(48, 0)
	if done:
		gold_lbl.add_theme_color_override("font_color", Palette.UI_TEXT_3)
	row.add_child(reward_col)
	return row

static func _draw_checkbox(cb: Control, done: bool) -> void:
	var size: Vector2 = cb.size
	var border := Palette.UI_LINE_3
	var fill := Palette.UI_GREEN if done else Color(0, 0, 0, 0)
	cb.draw_rect(Rect2(Vector2.ZERO, size), fill, true)
	cb.draw_rect(Rect2(Vector2.ZERO, size), Palette.UI_GREEN if done else border, false, 1.0)
	if done:
		# Check mark
		var pts := PackedVector2Array([
			Vector2(size.x * 0.2, size.y * 0.5),
			Vector2(size.x * 0.42, size.y * 0.72),
			Vector2(size.x * 0.8, size.y * 0.28),
		])
		cb.draw_polyline(pts, Palette.UI_BG_0, 1.5, true)

func _build_last5_strip() -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.add_child(TabHelpers.label("▸ LAST 5 OPS", 10, Palette.UI_TEXT_3))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	vb.add_child(row)
	var history: Array = []
	if PlayerProfile != null and PlayerProfile.data != null:
		history = PlayerProfile.data.match_history.duplicate()
	# Pad to 5 with empty slots (oldest first -> show newest on right).
	while history.size() < 5:
		history.push_front("")
	for token in history:
		row.add_child(_build_last5_cell(String(token)))
	return vb

func _build_last5_cell(token: String) -> Control:
	var cell := PanelContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	var bg := Color(0,0,0,0)
	var border := Palette.UI_LINE_1
	var fg := Palette.UI_TEXT_3
	var text := "·"
	match token:
		"W":
			bg = Color(0.302, 1.0, 0.659, 0.1)
			border = Palette.UI_GREEN
			fg = Palette.UI_GREEN
			text = "W"
		"L":
			bg = Color(1.0, 0.357, 0.357, 0.1)
			border = Palette.UI_RED
			fg = Palette.UI_RED
			text = "L"
		"D":
			bg = Color(0.47, 0.588, 0.706, 0.1)
			border = Palette.UI_LINE_3
			fg = Palette.UI_TEXT_2
			text = "D"
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_width_left = 1; sb.border_width_right = 1
	cell.add_theme_stylebox_override("panel", sb)
	cell.custom_minimum_size = Vector2(0, 34)
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", Palette.FONT_DISPLAY_BOLD)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", fg)
	cell.add_child(lbl)
	return cell
