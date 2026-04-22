@tool
class_name ShapeIcon
extends Control
## Small card glyph renderer for menu UI (Collection tiles, Deck panel,
## synergy chips, Ladder / Shop banners). Wraps ShapeRenderer's primitives
## at a given size and color. For in-match rendering, keep using
## ShapeRenderer / Silhouettes directly — this is the UI-layer wrapper.
##
## When `silhouette_id` is set, the icon routes through the Silhouettes
## library and ticks `_t` per frame so wings flap / afterburners pulse
## everywhere the piece shows up in menus. Empty id falls back to the
## generic primitive Shape so un-silhouetted pieces still render cleanly.

@export var shape: CardData.Shape = CardData.Shape.TRIANGLE:
	set(v): shape = v; queue_redraw()
@export var color: Color = Color("5be0ff"):
	set(v): color = v; queue_redraw()
@export_range(6.0, 80.0, 1.0) var icon_size: float = 22.0:
	set(v): icon_size = v; queue_redraw()
@export var glow: bool = false:
	set(v): glow = v; queue_redraw()
## When non-empty and registered in `Silhouettes.IDS`, draws the
## procedural silhouette (jet, warhead, drill, etc.) instead of the
## primitive Shape. Set via `from_card()` or directly.
@export var silhouette_id: StringName = &"":
	set(v): silhouette_id = v; queue_redraw()

var _t: float = 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(icon_size * 2.0, icon_size * 2.0)
	set_process(true)

func _process(delta: float) -> void:
	if silhouette_id != &"":
		_t += delta
		queue_redraw()

## Convenience setter — copies shape, color, and silhouette_id from the
## card in one call. Leaves icon_size / glow alone so the caller can still
## tune those separately.
func from_card(c: CardData) -> void:
	if c == null:
		return
	shape = c.shape
	color = c.color
	silhouette_id = c.silhouette_id
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	draw_set_transform(center, 0.0, Vector2.ONE)
	if silhouette_id != &"" and Silhouettes.has(silhouette_id):
		Silhouettes.draw(self, silhouette_id, color, icon_size, _t, 0.0)
	elif glow:
		ShapeRenderer.draw_with_glow(self, shape, color, icon_size, 0.0)
	else:
		ShapeRenderer.draw(self, shape, color, icon_size, 0.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
