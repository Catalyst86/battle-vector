class_name CardSlot
extends Control
## Card tile for the home screen's Collection view. Shows shape + name +
## level + upgrade button. Upgrades charge through PlayerProfile.

signal upgraded(card: CardData)

@export var card: CardData:
	set(value):
		card = value
		_refresh()

@onready var name_label: Label = $NameLabel
@onready var level_label: Label = $LevelLabel
@onready var upgrade_btn: Button = $UpgradeButton

func _ready() -> void:
	custom_minimum_size = Vector2(82, 108)
	upgrade_btn.pressed.connect(_on_upgrade_pressed)
	PlayerProfile.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	if not is_inside_tree():
		return
	if card == null:
		name_label.text = ""
		level_label.text = ""
		upgrade_btn.visible = false
		modulate.a = 1.0
		queue_redraw()
		return
	upgrade_btn.visible = true
	name_label.text = card.display_name.to_upper()
	name_label.add_theme_color_override("font_color", card.color)
	# Locked cards: dim the slot and show the required level instead of upgrade.
	var unlocked: bool = PlayerProfile.is_card_unlocked(card)
	if not unlocked:
		level_label.text = "LOCKED"
		upgrade_btn.text = "L%d REQ" % card.unlock_level
		upgrade_btn.disabled = true
		modulate.a = 0.45
		queue_redraw()
		return
	modulate.a = 1.0
	var lvl: int = PlayerProfile.get_card_level(card.id)
	level_label.text = "L%d" % lvl
	var cost: int = PlayerProfile.upgrade_cost(card.id)
	if cost < 0:
		upgrade_btn.text = "MAX"
		upgrade_btn.disabled = true
	else:
		upgrade_btn.text = "▲ %d" % cost
		upgrade_btn.disabled = not PlayerProfile.can_upgrade(card.id)
	queue_redraw()

func _on_upgrade_pressed() -> void:
	if card == null:
		return
	if PlayerProfile.upgrade(card.id):
		upgraded.emit(card)
		_refresh()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Palette.CARD_BG, true)
	draw_rect(rect, Palette.CARD_BORDER, false, 1.0)
	if card == null:
		return
	var icon_size: float = 14.0
	var icon_center := Vector2(size.x * 0.5, 28.0)
	draw_set_transform(icon_center, 0.0, Vector2.ONE)
	ShapeRenderer.draw(self, card.shape, card.color, icon_size, 0.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
