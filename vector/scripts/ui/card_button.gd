class_name CardButton
extends Control
## Single card in the hand. Pure presentation + input — deploys are resolved
## by the match scene reading the `card_selected` signal on CardHand.
## Visual tokens come from `card.color` + Palette so the whole hand restyles
## if a designer edits a CardData resource.

signal pressed(card: CardData)

@export var card: CardData:
	set(value):
		card = value
		_refresh()

var is_selected: bool = false
var is_dimmed: bool = false
var cooldown_remaining: float = 0.0
var cooldown_total: float = 0.0
## Drives procedural animation for silhouette icons (wing flap, exhaust
## pulse, etc.). Advances in _process only when the card has a registered
## silhouette — plain-shape cards don't animate so we skip the redraw cost.
var _t: float = 0.0

@onready var role_label: Label = $RoleLabel
@onready var name_label: Label = $NameLabel
@onready var cost_label: Label = $CostLabel

func _ready() -> void:
	custom_minimum_size = Vector2(40, 58)
	set_process(true)
	_refresh()

func _process(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
		queue_redraw()
	elif card != null and card.silhouette_id != &"":
		_t += delta
		queue_redraw()

## Dim + block interaction for `seconds`. Visual cooldown overlay sweeps
## down as time remaining decreases.
func start_cooldown(seconds: float) -> void:
	cooldown_total = seconds
	cooldown_remaining = seconds
	queue_redraw()

func on_cooldown() -> bool:
	return cooldown_remaining > 0.0

func set_selected(b: bool) -> void:
	if is_selected == b:
		return
	is_selected = b
	queue_redraw()

func set_dimmed(b: bool) -> void:
	if is_dimmed == b:
		return
	is_dimmed = b
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	# Only MouseButton — Godot's emulate_mouse_from_touch feeds mobile taps
	# through as mouse events, so listening to both would double-fire and
	# instantly de-select the card the user just picked.
	if on_cooldown():
		return
	if event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.pressed and m.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			SfxBank.play_ui(&"ui_click")
			pressed.emit(card)

func _refresh() -> void:
	if not is_inside_tree():
		return
	# Hide the .tscn-era Label children — _draw() renders role/name/cost inline
	# with the tactical typography so we don't double-draw.
	if role_label: role_label.visible = false
	if name_label: name_label.visible = false
	if cost_label: cost_label.visible = false
	if card == null:
		queue_redraw()
		return
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	# Background — dark tactical bg, tinted by card color when selected.
	var bg: Color = Palette.UI_BG_1
	if is_selected and card:
		var tint := card.color
		tint.a = 0.15
		bg = Palette.UI_BG_1.blend(tint)
	draw_rect(rect, bg, true)

	# Role stripe along the top (2px) — color-code by function at a glance.
	if card != null:
		draw_rect(Rect2(0.0, 0.0, size.x, 2.0), card.color, true)

	# Border.
	var border: Color = Palette.UI_LINE_2
	if is_selected and card:
		border = card.color
	draw_rect(rect, border, false, 1.0)

	# Shape icon centered, role label above it, name below.
	if card != null:
		var role_font: Font = Palette.FONT_DISPLAY
		var role_text: String = card.role_label()
		var role_fs: int = 7
		var role_sz: Vector2 = role_font.get_string_size(role_text, HORIZONTAL_ALIGNMENT_CENTER, -1, role_fs)
		draw_string(role_font,
			Vector2(size.x * 0.5 - role_sz.x * 0.5, 12.0),
			role_text, HORIZONTAL_ALIGNMENT_CENTER, -1, role_fs, card.color)

		# Icon — route through the Silhouettes library when the card has a
		# registered silhouette so the hand matches the on-field piece.
		# Empty id falls back to the generic primitive shape.
		var icon_size: float = size.x * 0.24
		var icon_center := Vector2(size.x * 0.5, size.y * 0.52)
		draw_set_transform(icon_center, 0.0, Vector2.ONE)
		if card.silhouette_id != &"" and Silhouettes.has(card.silhouette_id):
			Silhouettes.draw(self, card.silhouette_id, card.color, icon_size, _t, 0.0)
		else:
			ShapeRenderer.draw_with_glow(self, card.shape, card.color, icon_size, 0.0, 0.6)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Name at bottom.
		var name_font: Font = Palette.FONT_DISPLAY_BOLD
		var name_text: String = card.display_name.to_upper()
		var name_fs: int = 8
		var name_sz: Vector2 = name_font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_CENTER, -1, name_fs)
		draw_string(name_font,
			Vector2(size.x * 0.5 - name_sz.x * 0.5, size.y - 6.0),
			name_text, HORIZONTAL_ALIGNMENT_CENTER, -1, name_fs, Palette.UI_TEXT_0)

		# Cost pip (top-left corner, amber circle with number).
		var pip_center := Vector2(9.0, 12.0)
		draw_circle(pip_center, 7.5, Palette.UI_AMBER)
		var cost_font: Font = Palette.FONT_MONO_BOLD
		var cost_text: String = str(card.cost)
		var cost_fs: int = 9
		var cost_sz: Vector2 = cost_font.get_string_size(cost_text, HORIZONTAL_ALIGNMENT_CENTER, -1, cost_fs)
		draw_string(cost_font,
			pip_center - Vector2(cost_sz.x * 0.5, -3.0),
			cost_text, HORIZONTAL_ALIGNMENT_CENTER, -1, cost_fs, Color.BLACK)

	# Dim overlay when unaffordable.
	if is_dimmed:
		draw_rect(rect, Color(0, 0, 0, 0.55), true)
	# Cooldown overlay — solid black sliding down as time decreases.
	if on_cooldown() and cooldown_total > 0.0:
		var frac: float = cooldown_remaining / cooldown_total
		var cd_h: float = size.y * frac
		draw_rect(Rect2(0.0, size.y - cd_h, size.x, cd_h), Color(0, 0, 0, 0.65), true)

	# Selection glow — brighter 1px inner outline.
	if is_selected and card:
		var glow := card.color
		glow.a = 0.5
		draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), glow, false, 1.0)
