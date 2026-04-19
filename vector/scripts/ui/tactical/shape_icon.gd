@tool
class_name ShapeIcon
extends Control
## Small card glyph renderer for menu UI (Collection tiles, Deck panel, etc).
## Wraps ShapeRenderer's primitives at a given size and color. For in-match
## rendering, keep using ShapeRenderer directly — this is UI-layer only.

@export var shape: CardData.Shape = CardData.Shape.TRIANGLE:
	set(v): shape = v; queue_redraw()
@export var color: Color = Color("5be0ff"):
	set(v): color = v; queue_redraw()
@export_range(6.0, 80.0, 1.0) var icon_size: float = 22.0:
	set(v): icon_size = v; queue_redraw()
@export var glow: bool = false:
	set(v): glow = v; queue_redraw()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(icon_size * 2.0, icon_size * 2.0)

func from_card(c: CardData) -> void:
	if c == null:
		return
	shape = c.shape
	color = c.color
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	draw_set_transform(center, 0.0, Vector2.ONE)
	if glow:
		ShapeRenderer.draw_with_glow(self, shape, color, icon_size, 0.0)
	else:
		ShapeRenderer.draw(self, shape, color, icon_size, 0.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
