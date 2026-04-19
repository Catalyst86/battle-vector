extends Control
## Gun loadout modal — shown after match_confirm for VOLLEY matches.
## 3 slots + a pool of every module the player has unlocked. Tap a pool item
## to equip / unequip. DEPLOY when all 3 slots are filled; CANCEL returns.
##
## Persists the selection back to PlayerProfile.data.gun_loadout so the Gun
## script reads it on match boot.

signal confirmed(target_scene: String)

var target_scene: String = "res://scenes/match/volley/match_volley.tscn"

@onready var backdrop: ColorRect = $Backdrop
@onready var sheet: PanelContainer = %Sheet

var _slots: Array[StringName] = []
var _slot_controls: Array[Control] = []
var _pool_host: VBoxContainer
var _deploy_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close())
	# Sheet
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.UI_BG_1
	sb.border_color = Palette.UI_CYAN
	sb.border_width_top = 1; sb.border_width_left = 1; sb.border_width_right = 1
	sheet.add_theme_stylebox_override("panel", sb)
	var corners := Corners.new()
	corners.top_left = true
	corners.top_right = true
	corners.bottom_left = false
	corners.bottom_right = false
	corners.color = Palette.UI_CYAN
	sheet.add_child(corners)
	# Seed slots from profile
	_slots = PlayerProfile.data.gun_loadout.duplicate()
	while _slots.size() < 3:
		_slots.append(&"")
	# Content
	var m: MarginContainer = TabHelpers.margin(16, 18, 16, 18)
	sheet.add_child(m)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	m.add_child(sc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(col)
	col.add_child(_build_header())
	col.add_child(_build_slots())
	col.add_child(_build_pool())
	col.add_child(_build_buttons())
	# Slide in
	var start_y: float = sheet.offset_top
	sheet.offset_top = 260.0
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(sheet, "offset_top", start_y, 0.25)

func _close() -> void:
	SfxBank.play_ui(&"ui_back")
	var tw := create_tween().set_ease(Tween.EASE_IN)
	tw.tween_property(sheet, "offset_top", 260.0, 0.18)
	tw.parallel().tween_property(backdrop, "modulate:a", 0.0, 0.18)
	tw.finished.connect(func(): queue_free())

func _confirm() -> void:
	if _filled_slots() < 3:
		Toast.notify("EQUIP 3 MODULES TO DEPLOY", 1.4)
		return
	SfxBank.play_ui(&"ui_confirm")
	# Persist loadout
	var out: Array[StringName] = []
	for s in _slots:
		if s != &"":
			out.append(s)
	PlayerProfile.data.gun_loadout = out
	PlayerProfile.save()
	confirmed.emit(target_scene)
	queue_free()

func _filled_slots() -> int:
	var n: int = 0
	for s in _slots:
		if s != &"":
			n += 1
	return n

# ─── Sections ──────────────────────────────────────────────────────────────

func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	col.add_child(TabHelpers.label("▸ GUN LOADOUT", 9, Palette.UI_TEXT_3))
	col.add_child(TabHelpers.label("PICK 3 MODULES", 18, Palette.UI_CYAN))
	row.add_child(col)
	return row

func _build_slots() -> Control:
	var panel: PanelContainer = TabHelpers.make_panel(Palette.UI_BG_1, Palette.UI_LINE_2)
	var m: MarginContainer = TabHelpers.margin(10, 10, 10, 10)
	panel.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	m.add_child(vb)
	vb.add_child(TabHelpers.label("▸ EQUIPPED", 9, Palette.UI_TEXT_3))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vb.add_child(row)
	_slot_controls.clear()
	for i in 3:
		var slot := _build_slot(i)
		row.add_child(slot)
		_slot_controls.append(slot)
	return panel

func _build_slot(idx: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 58)
	var mod_id: StringName = _slots[idx] if idx < _slots.size() else &""
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.UI_BG_2 if mod_id != &"" else Color(0, 0, 0, 0)
	sb.border_color = Palette.UI_CYAN if mod_id != &"" else Palette.UI_LINE_2
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_width_left = 1; sb.border_width_right = 1
	p.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	var m := TabHelpers.margin(6, 4, 6, 4)
	p.add_child(m)
	m.add_child(vb)
	if mod_id == &"":
		var empty: Label = TabHelpers.mono("EMPTY", 9, Palette.UI_TEXT_3)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(empty)
		var slot_lbl: Label = TabHelpers.label("SLOT %d" % (idx + 1), 9, Palette.UI_TEXT_3)
		slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(slot_lbl)
	else:
		var info: Dictionary = GunModules.info(mod_id)
		var t: int = GunModules.tier(mod_id)
		var name_lbl: Label = TabHelpers.label(String(info.get("name", "?")), 11, Palette.UI_CYAN)
		name_lbl.add_theme_font_override("font", Palette.FONT_DISPLAY_BOLD)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(name_lbl)
		var tier_lbl: Label = TabHelpers.mono("L%d" % t, 9, Palette.UI_AMBER)
		tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(tier_lbl)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_unequip(idx))
	return p

func _build_pool() -> Control:
	var panel: PanelContainer = TabHelpers.make_panel(Palette.UI_BG_1, Palette.UI_LINE_2)
	var m: MarginContainer = TabHelpers.margin(10, 10, 10, 10)
	panel.add_child(m)
	_pool_host = VBoxContainer.new()
	_pool_host.add_theme_constant_override("separation", 6)
	m.add_child(_pool_host)
	_pool_host.add_child(TabHelpers.label("▸ AVAILABLE MODULES", 9, Palette.UI_TEXT_3))
	_rebuild_pool()
	return panel

func _rebuild_pool() -> void:
	# Drop existing children beyond the header.
	for c in _pool_host.get_children().slice(1):
		c.queue_free()
	for mod in GunModules.MODULES:
		if not GunModules.is_unlocked(mod.id):
			continue
		_pool_host.add_child(_build_pool_row(mod))

func _build_pool_row(mod: Dictionary) -> Control:
	var row := PanelContainer.new()
	var equipped: bool = _slots.has(mod.id)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.047, 0.055, 0.071, 0.6)
	sb.border_color = Palette.UI_CYAN_DIM if equipped else Palette.UI_LINE_2
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_width_left = 1; sb.border_width_right = 1
	row.add_theme_stylebox_override("panel", sb)
	var m: MarginContainer = TabHelpers.margin(8, 6, 8, 6)
	row.add_child(m)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	m.add_child(hbox)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	hbox.add_child(col)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	col.add_child(title_row)
	var name_lbl: Label = TabHelpers.label(String(mod.name), 12, Palette.UI_TEXT_0 if not equipped else Palette.UI_CYAN)
	name_lbl.add_theme_font_override("font", Palette.FONT_DISPLAY_BOLD)
	title_row.add_child(name_lbl)
	title_row.add_child(TabHelpers.mono("L%d/%d" % [GunModules.tier(mod.id), int(mod.max_tier)], 10, Palette.UI_AMBER))
	col.add_child(TabHelpers.mono(String(mod.desc), 9, Palette.UI_TEXT_2))
	var tag: Label = TabHelpers.mono("EQUIPPED" if equipped else "TAP TO EQUIP", 9,
		Palette.UI_CYAN if equipped else Palette.UI_TEXT_3)
	hbox.add_child(tag)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_toggle_equip(mod.id))
	return row

func _toggle_equip(mod_id: StringName) -> void:
	SfxBank.play_ui(&"ui_click")
	var existing_idx: int = _slots.find(mod_id)
	if existing_idx >= 0:
		_slots[existing_idx] = &""
	else:
		# Fill first empty slot
		var empty: int = _slots.find(&"")
		if empty < 0:
			Toast.notify("LOADOUT FULL — UNEQUIP A SLOT FIRST", 1.4)
			return
		_slots[empty] = mod_id
	_refresh_all()

func _unequip(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _slots.size():
		return
	if _slots[slot_idx] == &"":
		return
	SfxBank.play_ui(&"ui_click")
	_slots[slot_idx] = &""
	_refresh_all()

func _refresh_all() -> void:
	# Rebuild slot row + pool row — cheaper than tracking individual nodes
	# and the whole thing is a single scroll view so overhead is negligible.
	var slots_row_parent: Container = _slot_controls[0].get_parent() as Container
	for c in _slot_controls:
		c.queue_free()
	_slot_controls.clear()
	for i in 3:
		var s := _build_slot(i)
		slots_row_parent.add_child(s)
		_slot_controls.append(s)
	_rebuild_pool()
	if _deploy_btn:
		_deploy_btn.disabled = _filled_slots() < 3

func _build_buttons() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var cancel: Button = TabHelpers.ghost_button("◂ BACK", _close, Palette.UI_TEXT_1)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.size_flags_stretch_ratio = 1.0
	cancel.custom_minimum_size = Vector2(0, 48)
	row.add_child(cancel)
	_deploy_btn = TabHelpers.primary_button("▸ DEPLOY", _confirm)
	_deploy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deploy_btn.size_flags_stretch_ratio = 1.6
	_deploy_btn.custom_minimum_size = Vector2(0, 48)
	_deploy_btn.disabled = _filled_slots() < 3
	row.add_child(_deploy_btn)
	return row
