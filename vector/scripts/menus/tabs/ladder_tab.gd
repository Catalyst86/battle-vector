extends Control
## LADDER tab — trophy hero, arena progression path, leaderboard.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var sc: ScrollContainer = TabHelpers.tab_scroll()
	add_child(sc)
	var col: VBoxContainer = TabHelpers.tab_column()
	sc.add_child(col)
	var m: MarginContainer = TabHelpers.margin(14, 14, 14, 110)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner: VBoxContainer = TabHelpers.tab_column()
	m.add_child(inner)
	col.add_child(m)

	inner.add_child(TabHelpers.with_corners(_build_trophy_hero(), Palette.UI_AMBER))
	inner.add_child(TabHelpers.label("▸ ARENA PROGRESSION", 10, Palette.UI_TEXT_3))
	inner.add_child(_build_arena_path())
	inner.add_child(_build_leaderboard())

func _build_trophy_hero() -> Control:
	var panel: PanelContainer = TabHelpers.make_panel(Palette.UI_BG_1, Palette.UI_LINE_2, Palette.UI_CYAN)
	var grid := GridBg.new()
	grid.spacing = 8.0
	grid.color = Color(0.47, 0.588, 0.706, 0.05)
	panel.add_child(grid)
	var m: MarginContainer = TabHelpers.margin(14, 14, 14, 14)
	panel.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(vb)
	vb.add_child(_centered(TabHelpers.label("TROPHY COUNT", 9, Palette.UI_TEXT_3)))
	# Big amber trophy number
	var trophies: int = PlayerProfile.data.trophies if PlayerProfile != null else 0
	var tnum_row := HBoxContainer.new()
	tnum_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tnum_row.add_theme_constant_override("separation", 8)
	vb.add_child(tnum_row)
	tnum_row.add_child(TabHelpers.hero_number("★", 28, Palette.UI_AMBER))
	tnum_row.add_child(TabHelpers.hero_number(str(trophies), 42, Palette.UI_AMBER))
	var arena_name: String = PlayerProfile.arena_name() if PlayerProfile != null else "GROUND ZERO"
	vb.add_child(_centered(TabHelpers.label("ARENA %d — %s" % [(PlayerProfile.arena_index() + 1 if PlayerProfile != null else 1), arena_name], 13, Palette.UI_CYAN)))
	# Progress
	var prog_row := HBoxContainer.new()
	prog_row.add_theme_constant_override("separation", 8)
	vb.add_child(prog_row)
	var next_threshold: int = -1
	var floor_t: int = 0
	if PlayerProfile != null:
		next_threshold = PlayerProfile.next_arena_threshold()
		floor_t = PlayerProfile.current_arena_floor()
	var span: int = maxi(1, next_threshold - floor_t)
	var delta: int = trophies - floor_t
	prog_row.add_child(TabHelpers.mono("%d/%d" % [trophies, next_threshold if next_threshold > 0 else trophies], 10, Palette.UI_TEXT_2))
	var pbar := PBar.new()
	pbar.color = Palette.UI_AMBER
	pbar.color_dim = Palette.UI_AMBER_DIM
	pbar.progress = clampf(float(delta) / float(span), 0.0, 1.0)
	pbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prog_row.add_child(pbar)
	prog_row.add_child(TabHelpers.mono("▸ ARENA %d" % (PlayerProfile.arena_index() + 2 if PlayerProfile != null else 2), 9, Palette.UI_TEXT_3))
	# Record
	var div := ColorRect.new()
	div.color = Palette.UI_LINE_1
	div.custom_minimum_size = Vector2(0, 1)
	vb.add_child(div)
	var record := HBoxContainer.new()
	record.add_theme_constant_override("separation", 14)
	record.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(record)
	var wins: int = PlayerProfile.data.wins if PlayerProfile != null else 0
	var losses: int = PlayerProfile.data.losses if PlayerProfile != null else 0
	var draws: int = PlayerProfile.data.draws if PlayerProfile != null else 0
	var winpct: int = int(round((PlayerProfile.win_rate() if PlayerProfile != null else 0.0) * 100.0))
	record.add_child(_record_stat("WINS", str(wins), Palette.UI_GREEN))
	record.add_child(_record_stat("LOSS", str(losses), Palette.UI_RED))
	record.add_child(_record_stat("DRAW", str(draws), Palette.UI_TEXT_2))
	record.add_child(_record_stat("WIN%", str(winpct), Palette.UI_CYAN))
	return panel

func _centered(c: Control) -> Control:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(c)
	return hb

func _record_stat(label_text: String, value: String, color: Color) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(_centered(TabHelpers.label(label_text, 8, Palette.UI_TEXT_3)))
	var v: Label = TabHelpers.mono(value, 14, color)
	v.add_theme_font_override("font", Palette.FONT_MONO_BOLD)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(v)
	return vb

func _build_arena_path() -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	var arena_names: Array = PlayerProfile.ARENA_NAMES if PlayerProfile != null else []
	var arena_thresholds: Array = PlayerProfile.ARENA_THRESHOLDS if PlayerProfile != null else []
	var current: int = PlayerProfile.arena_index() if PlayerProfile != null else 0
	var trophies: int = PlayerProfile.data.trophies if PlayerProfile != null else 0
	var glyphs: Array = [CardData.Shape.TRIANGLE, CardData.Shape.SQUARE, CardData.Shape.SPIRAL, CardData.Shape.STAR, CardData.Shape.DIAMOND, CardData.Shape.CIRCLE, CardData.Shape.CHEVRON, CardData.Shape.RING]
	for i in arena_names.size():
		vb.add_child(_build_arena_row(i, arena_names[i], arena_thresholds[i], glyphs[i], current, trophies))
	return vb

func _build_arena_row(i: int, arena_name: String, req: int, glyph: int, current: int, trophies: int) -> Control:
	var state: String
	if i == current: state = "current"
	elif trophies >= req: state = "done"
	else: state = "locked"

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 52)
	# Node
	var node := PanelContainer.new()
	node.custom_minimum_size = Vector2(38, 38)
	var nsb := StyleBoxFlat.new()
	nsb.bg_color = Color(0.357, 0.878, 1.0, 0.08) if state == "current" else Color(0.024, 0.031, 0.047, 1.0)
	nsb.border_color = Palette.UI_CYAN if state == "current" else (Palette.UI_LINE_3 if state == "done" else Palette.UI_LINE_1)
	nsb.border_width_top = 1; nsb.border_width_bottom = 1
	nsb.border_width_left = 1; nsb.border_width_right = 1
	if state == "current":
		nsb.shadow_color = Palette.UI_CYAN_GLOW
		nsb.shadow_size = 8
	node.add_theme_stylebox_override("panel", nsb)
	var icon := ShapeIcon.new()
	icon.shape = glyph
	var node_color: Color = Palette.UI_TEXT_3 if state == "locked" else (Palette.UI_CYAN if state == "current" else Palette.UI_TEXT_1)
	icon.color = node_color
	icon.icon_size = 11.0
	node.add_child(icon)
	row.add_child(node)
	# Info
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	col.add_child(TabHelpers.label("%02d  //  %s" % [i + 1, arena_name], 11, node_color))
	var status: String = "CLEARED" if state == "done" else ("IN PROGRESS" if state == "current" else "REQ %d" % req)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 4)
	col.add_child(status_row)
	status_row.add_child(TabHelpers.mono(status, 9, Palette.UI_TEXT_3))
	if state == "current":
		var dot := StatusDot.new()
		dot.color = Palette.UI_CYAN
		dot.radius = 3.0
		dot.mode = StatusDot.Mode.BLINK
		status_row.add_child(dot)
	row.add_child(col)
	# Req number
	row.add_child(TabHelpers.mono(str(req), 11, node_color))
	return row

func _build_leaderboard() -> Control:
	var panel: PanelContainer = TabHelpers.make_panel(Palette.UI_BG_1, Palette.UI_LINE_2)
	var m: MarginContainer = TabHelpers.margin(12, 12, 12, 12)
	panel.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	m.add_child(vb)
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	vb.add_child(hdr)
	hdr.add_child(TabHelpers.label("SEASON 01  //  TOP OPS", 10, Palette.UI_TEXT_2))
	hdr.add_child(TabHelpers.spacer(0))
	hdr.get_child(hdr.get_child_count() - 1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(TabHelpers.mono("ENDS 12D 04H", 9, Palette.UI_TEXT_3))
	var rows: Array = Leaderboard.rows(3) if Leaderboard != null else []
	for r in rows:
		vb.add_child(_leaderboard_row(r))
	return panel

func _leaderboard_row(r: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if r.get("me", false):
		# Divider above the "me" row
		var sep := VBoxContainer.new()
		sep.add_theme_constant_override("separation", 6)
		var div := ColorRect.new()
		div.color = Palette.UI_LINE_2
		div.custom_minimum_size = Vector2(0, 1)
		sep.add_child(div)
		sep.add_child(_build_ld_row_inner(r, Palette.UI_CYAN, true))
		return sep
	return _build_ld_row_inner(r, Palette.UI_TEXT_1, false)

func _build_ld_row_inner(r: Dictionary, name_color: Color, me: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 22)
	var rank_lbl: Label = TabHelpers.mono("#%d" % int(r.rank), 10, Palette.UI_TEXT_3)
	rank_lbl.custom_minimum_size = Vector2(42, 0)
	row.add_child(rank_lbl)
	var name_lbl: Label = TabHelpers.label(String(r.name).to_upper(), 11, name_color)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if me:
		name_lbl.add_theme_font_override("font", Palette.FONT_DISPLAY_BOLD)
	row.add_child(name_lbl)
	row.add_child(TabHelpers.mono("★ %d" % int(r.trophies), 11, Palette.UI_AMBER))
	return row
