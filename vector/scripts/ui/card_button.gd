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
			pressed.emit(card)

func _refresh() -> void:
	if not is_inside_tree():
		return
	if card == null:
		if role_label: role_label.text = ""
		if name_label: name_label.text = ""
		if cost_label: cost_label.text = ""
		queue_redraw()
		return
	role_label.text = card.role_label()
	role_label.add_theme_color_override("font_color", card.color)
	name_label.text = card.display_name.to_upper()
	cost_label.text = str(card.cost)
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	# Background.
	var bg: Color = Palette.CARD_BG
	if is_selected and card:
		var tint := card.color
		tint.a = 0.22
		bg = tint
	draw_rect(rect, bg, true)
	# Border.
	var border: Color = Palette.CARD_BORDER
	if is_selected and card:
		border = card.color
	draw_rect(rect, border, false, 1.0)

	# Shape icon (centered, about 38% of the card's width).
	if card != null:
		var icon_size: float = size.x * 0.22
		var icon_center := Vector2(size.x * 0.5, size.y * 0.45)
		draw_set_transform(icon_center, 0.0, Vector2.ONE)
		ShapeRenderer.draw(self, card.shape, card.color, icon_size, 0.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Cost pip (bottom-left corner).
		var pip_center := Vector2(8.0, size.y - 9.0)
		draw_circle(pip_center, 3.0, Palette.MANA)

	# Dim overlay when unaffordable.
	if is_dimmed:
		draw_rect(rect, Color(0, 0, 0, 0.55), true)
	# Cooldown overlay — solid black sliding down as time decreases.
	if on_cooldown() and cooldown_total > 0.0:
		var frac: float = cooldown_remaining / cooldown_total
		var cd_h: float = size.y * frac
		draw_rect(Rect2(0.0, size.y - cd_h, size.x, cd_h), Color(0, 0, 0, 0.65), true)
