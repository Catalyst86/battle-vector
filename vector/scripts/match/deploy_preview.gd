extends Node2D
## Watermark / ghost of the selected card that tracks the cursor inside the
## valid deploy zone. Purely visual — deploy itself is still a tap on the
## playfield. Updated by match.gd on card selection + mouse motion.

var card: CardData
var world_pos: Vector2 = Vector2.ZERO
var affordable: bool = true

func _ready() -> void:
	visible = false

func show_card(c: CardData, can_afford: bool) -> void:
	card = c
	affordable = can_afford
	visible = (c != null)
	queue_redraw()

func hide_preview() -> void:
	visible = false
	card = null

func set_world_pos(wp: Vector2) -> void:
	world_pos = wp
	position = Pseudo3D.project(world_pos)
	var s := Pseudo3D.scale_at(world_pos.y)
	scale = Vector2.ONE * s * GameConfig.data.unit_display_scale

func _draw() -> void:
	if card == null:
		return
	# Faint "footprint" on the ground — a thin circle a bit wider than the unit.
	var footprint := card.color if affordable else Color(1, 0.4, 0.4)
	footprint.a = 0.22
	draw_arc(Vector2.ZERO, card.size * 1.25, 0.0, TAU, 48, footprint, 1.0, true)
	# The watermark shape itself — translucent outline of the card.
	# Routes through Silhouettes when the card has one so the ghost
	# matches what's about to spawn; static t=0 keeps the preview calm.
	var ghost := card.color if affordable else Color(1, 0.4, 0.4)
	ghost.a = 0.32 if affordable else 0.45
	if card.silhouette_id != &"" and Silhouettes.has(card.silhouette_id):
		Silhouettes.draw(self, card.silhouette_id, ghost, card.size, 0.0, 0.0)
	else:
		ShapeRenderer.draw_with_glow(self, card.shape, ghost, card.size, 0.0, 0.6)
