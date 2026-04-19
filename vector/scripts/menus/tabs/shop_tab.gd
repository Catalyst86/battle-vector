extends Control
## SHOP tab — gold balance, featured chest with countdown, featured bundles,
## season pass track, currency packs.

var _chest_countdown: Label
var _chest_button: Button
var _timer: Timer

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

	inner.add_child(_build_gold_bar())
	inner.add_child(TabHelpers.with_corners(_build_chest(), Palette.UI_CYAN))
	inner.add_child(TabHelpers.label("▸ FEATURED", 10, Palette.UI_TEXT_3))
	inner.add_child(_build_bundles())
	inner.add_child(_build_season_track())
	inner.add_child(TabHelpers.label("▸ RESOURCES", 10, Palette.UI_TEXT_3))
	inner.add_child(_build_currency_packs())

	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.autostart = true
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_tick()

func _tick() -> void:
	if _chest_countdown == null:
		return
	var secs: int = PlayerProfile.seconds_until_free_chest() if PlayerProfile != null else 0
	var h: int = secs / 3600
	var mins: int = (secs % 3600) / 60
	var s: int = secs % 60
	_chest_countdown.text = "%02d:%02d:%02d" % [h, mins, s]
	if _chest_button != null:
		_chest_button.text = "CLAIM" if PlayerProfile != null and PlayerProfile.can_claim_free_chest() else "LOCKED"
		_chest_button.disabled = PlayerProfile == null or not PlayerProfile.can_claim_free_chest()

func _build_gold_bar() -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.714, 0.282, 0.04)
	sb.border_color = Color(1.0, 0.714, 0.282, 0.2)
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_width_left = 1; sb.border_width_right = 1
	panel.add_theme_stylebox_override("panel", sb)
	var m: MarginContainer = TabHelpers.margin(12, 10, 12, 10)
	panel.add_child(m)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	m.add_child(row)
	row.add_child(TabHelpers.label("◆", 12, Palette.UI_AMBER))
	row.add_child(TabHelpers.label("BALANCE", 10, Palette.UI_TEXT_2))
	row.add_child(TabHelpers.spacer(0))
	row.get_child(row.get_child_count() - 1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gold: int = PlayerProfile.data.gold if PlayerProfile != null else 0
	var gold_lbl: Label = TabHelpers.hero_number(str(gold), 18, Palette.UI_AMBER)
	row.add_child(gold_lbl)
	return panel

func _build_chest() -> Control:
	var panel: PanelContainer = TabHelpers.make_panel(Palette.UI_BG_1, Palette.UI_CYAN, Palette.UI_CYAN)
	var sb: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		sb.bg_color = Color(0.357, 0.878, 1.0, 0.05)
	var grid := GridBg.new()
	grid.spacing = 8.0
	grid.color = Color(0.47, 0.588, 0.706, 0.04)
	panel.add_child(grid)
	var m: MarginContainer = TabHelpers.margin(14, 14, 14, 14)
	panel.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	m.add_child(vb)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	vb.add_child(top)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(titles)
	titles.add_child(TabHelpers.label("▸ DAILY_FREE", 9, Palette.UI_CYAN))
	titles.add_child(TabHelpers.label("SIGNAL CACHE", 18, Palette.UI_CYAN))
	# Chest icon: draw a simple rectangle with a lock slot
	var chest := Control.new()
	chest.custom_minimum_size = Vector2(48, 48)
	chest.draw.connect(func(): _draw_chest_icon(chest))
	top.add_child(chest)
	vb.add_child(TabHelpers.mono("80–160 GOLD  +  30–80 XP", 10, Palette.UI_TEXT_1))
	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 8)
	vb.add_child(progress_row)
	var pbar := PBar.new()
	pbar.progress = 0.02
	pbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_row.add_child(pbar)
	_chest_countdown = TabHelpers.mono("--:--:--", 11, Palette.UI_TEXT_0)
	progress_row.add_child(_chest_countdown)
	_chest_button = TabHelpers.ghost_button("LOCKED", func():
		if PlayerProfile != null and PlayerProfile.can_claim_free_chest():
			var r: Dictionary = PlayerProfile.claim_free_chest()
			if int(r.get("gold", 0)) > 0:
				SfxBank.play(&"victory"), Palette.UI_TEXT_3)
	vb.add_child(_chest_button)
	return panel

func _draw_chest_icon(c: Control) -> void:
	var pts := PackedVector2Array([
		Vector2(8, 18), Vector2(24, 10), Vector2(40, 18), Vector2(40, 40), Vector2(8, 40)
	])
	var loop := pts.duplicate(); loop.append(pts[0])
	var fill := Palette.UI_CYAN
	fill.a = 0.1
	c.draw_colored_polygon(pts, fill)
	c.draw_polyline(loop, Palette.UI_CYAN, 1.5, true)
	c.draw_line(Vector2(8, 18), Vector2(24, 26), Palette.UI_CYAN, 1.5, false)
	c.draw_line(Vector2(24, 26), Vector2(40, 18), Palette.UI_CYAN, 1.5, false)
	c.draw_line(Vector2(24, 10), Vector2(24, 26), Palette.UI_CYAN, 1.5, false)
	c.draw_rect(Rect2(22, 20, 4, 5), Palette.UI_AMBER, true)

func _build_bundles() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.add_child(_build_bundle("STARTER", "5 CARDS + 500G", "99", CardData.Shape.TRIANGLE, Palette.UI_CYAN, "NEW"))
	grid.add_child(_build_bundle("RARE BOX", "GUARANTEED EPIC", "240", CardData.Shape.STAR, Palette.UI_VIOLET, "LTD"))
	return grid

func _build_bundle(title: String, sub: String, price: String, shape: int, color: Color, tag: String) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.UI_BG_1
	sb.border_color = Palette.UI_LINE_2
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_width_left = 1; sb.border_width_right = 1
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(0, 124)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			SfxBank.play_ui(&"ui_click")
			Toast.coming_soon())
	var m: MarginContainer = TabHelpers.margin(10, 10, 10, 10)
	panel.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	m.add_child(vb)
	# Tag row (inline, top) — colored pill instead of an overlay so it can't
	# paint over the whole card when anchors don't apply in a Container parent.
	if tag != "":
		var tag_row := HBoxContainer.new()
		tag_row.alignment = BoxContainer.ALIGNMENT_END
		vb.add_child(tag_row)
		var tag_panel := PanelContainer.new()
		var tsb := StyleBoxFlat.new()
		tsb.bg_color = color
		tag_panel.add_theme_stylebox_override("panel", tsb)
		var tm: MarginContainer = TabHelpers.margin(6, 1, 6, 1)
		tag_panel.add_child(tm)
		var tag_lbl := Label.new()
		tag_lbl.text = tag
		tag_lbl.add_theme_color_override("font_color", Color.BLACK)
		tag_lbl.add_theme_font_override("font", Palette.FONT_MONO_BOLD)
		tag_lbl.add_theme_font_size_override("font_size", 8)
		tm.add_child(tag_lbl)
		tag_row.add_child(tag_panel)
	# Glyph banner
	var banner := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.047, 0.055, 0.071, 0.7)
	bsb.border_color = Palette.UI_LINE_2
	bsb.border_width_top = 1; bsb.border_width_bottom = 1
	bsb.border_width_left = 1; bsb.border_width_right = 1
	banner.add_theme_stylebox_override("panel", bsb)
	banner.custom_minimum_size = Vector2(0, 44)
	var icon := ShapeIcon.new()
	icon.shape = shape
	icon.color = color
	icon.icon_size = 18.0
	banner.add_child(icon)
	vb.add_child(banner)
	vb.add_child(TabHelpers.label(title, 11, Palette.UI_TEXT_0))
	vb.add_child(TabHelpers.mono(sub, 9, Palette.UI_TEXT_3))
	var div := ColorRect.new()
	div.color = Palette.UI_LINE_1
	div.custom_minimum_size = Vector2(0, 1)
	vb.add_child(div)
	var price_row := HBoxContainer.new()
	price_row.add_theme_constant_override("separation", 4)
	vb.add_child(price_row)
	price_row.add_child(TabHelpers.label("◆", 10, Palette.UI_AMBER))
	price_row.add_child(TabHelpers.mono(price, 12, Palette.UI_AMBER))
	return panel

func _build_season_track() -> Control:
	var panel: PanelContainer = TabHelpers.make_panel(Palette.UI_BG_1, Palette.UI_LINE_2)
	var m: MarginContainer = TabHelpers.margin(12, 12, 12, 12)
	panel.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	m.add_child(vb)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	vb.add_child(top)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(titles)
	titles.add_child(TabHelpers.label("SEASON %02d" % SeasonPass.SEASON_NUMBER, 9, Palette.UI_TEXT_3))
	titles.add_child(TabHelpers.label(SeasonPass.SEASON_NAME, 13, Palette.UI_TEXT_0))
	var tier: int = PlayerProfile.data.season_tier if PlayerProfile != null else 0
	top.add_child(TabHelpers.label("TIER %d / %d" % [tier, SeasonPass.MAX_TIER], 9, Palette.UI_AMBER))
	# Tier segments
	var seg_row := HBoxContainer.new()
	seg_row.add_theme_constant_override("separation", 3)
	vb.add_child(seg_row)
	var show_n: int = 12
	var start_tier: int = maxi(0, tier - 3)
	for i in show_n:
		var t: int = start_tier + i
		var is_done: bool = t < tier
		var is_current: bool = t == tier
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.custom_minimum_size = Vector2(0, 18)
		var csb := StyleBoxFlat.new()
		if is_done:
			csb.bg_color = Palette.UI_CYAN
			csb.border_color = Palette.UI_CYAN
		elif is_current:
			csb.bg_color = Color(0.357, 0.878, 1.0, 0.2)
			csb.border_color = Palette.UI_CYAN
		else:
			csb.bg_color = Color(0, 0, 0, 0)
			csb.border_color = Palette.UI_LINE_2
		csb.border_width_top = 1; csb.border_width_bottom = 1
		csb.border_width_left = 1; csb.border_width_right = 1
		cell.add_theme_stylebox_override("panel", csb)
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", Palette.FONT_MONO_BOLD)
		lbl.add_theme_font_size_override("font_size", 8)
		if is_done:
			lbl.text = "✓"
			lbl.add_theme_color_override("font_color", Color.BLACK)
		elif is_current:
			lbl.text = str(t + 1)
			lbl.add_theme_color_override("font_color", Palette.UI_CYAN)
		else:
			lbl.text = ""
		cell.add_child(lbl)
		seg_row.add_child(cell)
	var nxt_label: String = "NEXT ▸ %d XP ▸ %s" % [SeasonPass.XP_PER_TIER, SeasonPass.reward_at(tier).get("label", "GOLD")]
	vb.add_child(TabHelpers.mono(nxt_label, 9, Palette.UI_TEXT_3))
	# Claim button — shows up when there's an unclaimed tier the player
	# already earned. Claims the *lowest* unclaimed tier (simple + obvious).
	var next_claimable: int = _next_unclaimed_tier(tier)
	if next_claimable >= 0:
		var reward: Dictionary = SeasonPass.reward_at(next_claimable)
		var claim_btn: Button = TabHelpers.primary_button(
			"▸ CLAIM TIER %d — %s" % [next_claimable + 1, String(reward.get("label", "REWARD"))],
			func():
				var r: Dictionary = SeasonPass.claim(next_claimable)
				if not r.is_empty():
					SfxBank.play(&"victory")
					Toast.notify("+%d GOLD · TIER %d" % [int(r.get("gold", 0)), next_claimable + 1]))
		vb.add_child(claim_btn)
	return panel

## Returns the lowest tier index the player has unlocked but not yet claimed,
## or -1 if everything is caught up.
func _next_unclaimed_tier(current_tier: int) -> int:
	if PlayerProfile == null:
		return -1
	var claimed: Array = PlayerProfile.data.season_pass_claimed
	for t in current_tier:
		if not claimed.has(t):
			return t
	return -1

func _build_currency_packs() -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_child(_build_pack("500", "0.99", ""))
	grid.add_child(_build_pack("2,500", "4.99", "+10%"))
	grid.add_child(_build_pack("8,000", "14.99", "+25%"))
	return grid

func _build_pack(amount: String, price: String, tag: String) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.UI_BG_1
	sb.border_color = Palette.UI_LINE_2
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_width_left = 1; sb.border_width_right = 1
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(0, 96)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			SfxBank.play_ui(&"ui_click")
			Toast.coming_soon())
	var m: MarginContainer = TabHelpers.margin(8, 8, 8, 8)
	panel.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	m.add_child(vb)
	# Inline tag row (right-aligned). Empty spacer keeps vertical rhythm.
	var tag_row := HBoxContainer.new()
	tag_row.alignment = BoxContainer.ALIGNMENT_END
	tag_row.custom_minimum_size = Vector2(0, 14)
	vb.add_child(tag_row)
	if tag != "":
		var tag_p := PanelContainer.new()
		var tsb := StyleBoxFlat.new()
		tsb.bg_color = Palette.UI_AMBER
		tag_p.add_theme_stylebox_override("panel", tsb)
		var tm: MarginContainer = TabHelpers.margin(4, 0, 4, 0)
		tag_p.add_child(tm)
		var tag_lbl := Label.new()
		tag_lbl.text = tag
		tag_lbl.add_theme_color_override("font_color", Color.BLACK)
		tag_lbl.add_theme_font_override("font", Palette.FONT_MONO_BOLD)
		tag_lbl.add_theme_font_size_override("font_size", 7)
		tm.add_child(tag_lbl)
		tag_row.add_child(tag_p)
	vb.add_child(_centered(TabHelpers.label("◆", 14, Palette.UI_AMBER)))
	var amt: Label = TabHelpers.hero_number(amount, 14, Palette.UI_AMBER)
	amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(amt)
	var price_lbl: Label = TabHelpers.mono("$%s" % price, 9, Palette.UI_TEXT_3)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(price_lbl)
	return panel

func _centered(c: Control) -> Control:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(c)
	return hb
