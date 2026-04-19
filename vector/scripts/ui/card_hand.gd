class_name CardHand
extends Control
## Horizontal hand of 8 cards. Instantiates CardButton scenes from the deck
## resource array and wires up single-select. Match scene listens to
## `card_selected` (null means "nothing selected").

signal card_selected(card: CardData)

const CARD_BUTTON_SCENE := preload("res://scenes/ui/card_button.tscn")

@export var deck: Array[CardData] = []
@export var card_width: float = 40.0
@export var card_height: float = 58.0
@export var separation: float = 4.0

var _buttons: Array[CardButton] = []
var _selected_id: StringName = &""

func _ready() -> void:
	build()

func build() -> void:
	for c in get_children():
		c.queue_free()
	_buttons.clear()
	if deck.is_empty():
		return
	var n := deck.size()
	var total_w: float = float(n) * card_width + float(n - 1) * separation
	var start_x: float = (size.x - total_w) * 0.5
	var y: float = (size.y - card_height) * 0.5
	for i in n:
		var c: CardData = deck[i]
		if c == null:
			continue
		var btn := CARD_BUTTON_SCENE.instantiate()
		add_child(btn)
		btn.size = Vector2(card_width, card_height)
		btn.position = Vector2(start_x + i * (card_width + separation), y)
		btn.card = c
		btn.pressed.connect(_on_btn_pressed)
		_buttons.append(btn)

func _on_btn_pressed(card: CardData) -> void:
	if card == null:
		return
	if _selected_id == card.id:
		_selected_id = &""
	else:
		_selected_id = card.id
	for b in _buttons:
		b.set_selected(b.card != null and b.card.id == _selected_id)
	var emit_card: CardData = null
	if _selected_id != &"":
		for c in deck:
			if c != null and c.id == _selected_id:
				emit_card = c
				break
	card_selected.emit(emit_card)

func deselect() -> void:
	_selected_id = &""
	for b in _buttons:
		b.set_selected(false)
	card_selected.emit(null)

func set_affordability(mana: int) -> void:
	for b in _buttons:
		if b.card != null:
			b.set_dimmed(b.card.cost > mana)

## Dim the button for the card just deployed. Spec says 400ms after deploy.
func trigger_cooldown(card: CardData, seconds: float = 0.4) -> void:
	if card == null:
		return
	for b in _buttons:
		if b.card != null and b.card.id == card.id:
			b.start_cooldown(seconds)
			return

func first_button() -> CardButton:
	if _buttons.is_empty():
		return null
	return _buttons[0]

## During BUILD phase, whole hand should be untappable.
func set_interactive(enabled: bool) -> void:
	for b in _buttons:
		b.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
		# When disabled, force dim. When enabled, preserve whatever dim
		# (unaffordable) the caller set via set_affordability().
		b.set_dimmed((not enabled) or (enabled and b.is_dimmed))
