extends Control
## Deck builder — 8-of-pool picker. Tap a card in the pool to add to your
## deck, tap a slot to remove. Save writes to user://deck.tres via PlayerDeck.

const CARD_BUTTON_SCENE: PackedScene = preload("res://scenes/ui/card_button.tscn")
const DECK_SIZE := 8

@onready var slots_row: HBoxContainer = %SlotsRow
@onready var pool_grid: GridContainer = %PoolGrid
@onready var count_label: Label = %CountLabel
@onready var save_btn: Button = %SaveButton
@onready var back_btn: Button = %BackButton

var _deck: Array[CardData] = []
var _slot_buttons: Array[CardButton] = []
var _pool_buttons: Array[CardButton] = []

func _ready() -> void:
	_deck = PlayerDeck.cards.duplicate()
	save_btn.pressed.connect(_on_save)
	back_btn.pressed.connect(func(): Router.goto("res://scenes/menus/main_menu.tscn"))
	_build_slots()
	_build_pool()
	_refresh()

func _build_slots() -> void:
	for c in slots_row.get_children():
		c.queue_free()
	_slot_buttons.clear()
	for i in DECK_SIZE:
		var btn := CARD_BUTTON_SCENE.instantiate() as CardButton
		btn.custom_minimum_size = Vector2(40, 58)
		btn.pressed.connect(_on_slot_pressed.bind(i))
		slots_row.add_child(btn)
		_slot_buttons.append(btn)

func _build_pool() -> void:
	for c in pool_grid.get_children():
		c.queue_free()
	_pool_buttons.clear()
	# Only unlocked cards can go into a deck.
	var pool: Array[CardData] = PlayerProfile.unlocked_cards() if PlayerProfile != null else PlayerDeck.pool()
	for card in pool:
		var btn := CARD_BUTTON_SCENE.instantiate() as CardButton
		btn.custom_minimum_size = Vector2(40, 58)
		btn.card = card
		btn.pressed.connect(_on_pool_pressed)
		pool_grid.add_child(btn)
		_pool_buttons.append(btn)

func _on_pool_pressed(card: CardData) -> void:
	if card == null or _deck.size() >= DECK_SIZE:
		return
	if _has_card(card):
		return
	_deck.append(card)
	_refresh()

func _on_slot_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _deck.size():
		return
	_deck.remove_at(slot_index)
	_refresh()

func _on_save() -> void:
	if _deck.size() < DECK_SIZE:
		return
	PlayerDeck.save_deck(_deck)
	Router.goto("res://scenes/menus/main_menu.tscn")

func _has_card(card: CardData) -> bool:
	for c in _deck:
		if c != null and c.id == card.id:
			return true
	return false

func _refresh() -> void:
	for i in _slot_buttons.size():
		var btn := _slot_buttons[i]
		btn.card = _deck[i] if i < _deck.size() else null
		btn.set_selected(false)
		btn.set_dimmed(false)
	for btn in _pool_buttons:
		btn.set_dimmed(_has_card(btn.card) or _deck.size() >= DECK_SIZE)
	count_label.text = "DECK %d/%d" % [_deck.size(), DECK_SIZE]
	save_btn.disabled = _deck.size() < DECK_SIZE
