class_name SquareSpawner
extends Node2D
## Spawns Square targets at the midline at a steady cadence during the
## match. For MVP, only Standard tier spawns; tier variety + boss pacing
## layered in later passes.
##
## Each spawn is biased left/right so squares appear across the full
## field width rather than stacking in the centre column. Each spawn
## gets a random `bound_for_enemy` flag so the wave splits evenly.

signal square_spawned(sq: Square)

const SQUARE_SCENE: PackedScene = preload("res://scenes/match/volley/square.tscn")

@export var spawn_interval: float = 0.35
@export var spawn_x_min: float = 30.0
@export var spawn_x_max: float = 330.0
@export var spawn_y: float = 260.0
@export var active: bool = true

var _cooldown: float = 0.0

func _process(delta: float) -> void:
	if not active:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown = spawn_interval
	_spawn_one()

func _spawn_one() -> void:
	var sq: Square = SQUARE_SCENE.instantiate() as Square
	sq.tier = _roll_tier()
	sq.bound_for_enemy = randf() < 0.5
	get_parent().add_child(sq)
	sq.position = Vector2(randf_range(spawn_x_min, spawn_x_max), spawn_y)
	square_spawned.emit(sq)

func _roll_tier() -> int:
	# MVP tier mix — heavily standard with a sprinkle of tougher types.
	# Later the doc calls for 80/10/6/3/1 distribution.
	var r: float = randf()
	if r < 0.80:
		return Square.Tier.STANDARD
	if r < 0.90:
		return Square.Tier.FAST
	if r < 0.97:
		return Square.Tier.ARMORED
	if r < 0.995:
		return Square.Tier.ELITE
	return Square.Tier.BOSS
