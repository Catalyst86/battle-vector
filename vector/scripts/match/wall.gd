class_name Wall
extends Node2D
## Buildable blocking geometry placed during the BUILD phase. Blocks any unit
## whose role isn't WALLBREAK. Takes damage from contact (shooter/melee) or
## from wallbreak units drilling through. Opacity tracks HP.

signal destroyed

@export var side: int = 0  # 0 = player, 1 = enemy

var world_pos: Vector2 = Vector2.ZERO
var max_hp: float = 80.0
var hp: float = 80.0
var _dying: bool = false

func _ready() -> void:
	var cfg := GameConfig.data
	max_hp = cfg.wall_hp
	hp = max_hp
	add_to_group("walls_enemy" if side == 1 else "walls_player")
	add_to_group("walls")
	queue_redraw()

func _process(_delta: float) -> void:
	var cfg := GameConfig.data
	position = Pseudo3D.project(world_pos)
	var s := Pseudo3D.scale_at(world_pos.y)
	scale = Vector2.ONE * s * cfg.unit_display_scale
	queue_redraw()

func take_damage(amount: float) -> void:
	if _dying:
		return
	hp = maxf(0.0, hp - amount)
	if hp <= 0.0:
		_dying = true
		destroyed.emit()
		queue_free()

## Axis-aligned bounds in world coords. Used by unit collision.
func bounds() -> Rect2:
	var cfg := GameConfig.data
	return Rect2(
		world_pos - Vector2(cfg.wall_width * 0.5, cfg.wall_height * 0.5),
		Vector2(cfg.wall_width, cfg.wall_height)
	)

func _draw() -> void:
	var cfg := GameConfig.data
	var w: float = cfg.wall_width
	var h: float = cfg.wall_height
	var color: Color = Palette.BASE_YOU if side == 0 else Palette.BASE_ENEMY
	var hp_frac: float = clampf(hp / max_hp, 0.0, 1.0)
	var fill := color
	fill.a = 0.75 * hp_frac + 0.15
	draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), fill, true)
	var border := color
	border.a = 0.9
	draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), border, false, 1.0)
