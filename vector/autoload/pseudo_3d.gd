extends Node
## Pseudo-3D projection for the match playfield.
##
## Game logic stays in flat 2D "world" coordinates (0..map_width, 0..map_height)
## matching the spec 1:1. For rendering, entities ask Pseudo3D to project their
## world position + size to screen space with a gentle perspective:
##   - Near edge (y=map_height, player side) renders at full scale
##   - Far edge (y=0, enemy side) renders at `far_scale` (e.g. 0.75)
##   - Horizontal axis pinches toward the far edge (trapezoidal)
##   - A slight vertical lift on the far edge sells the camera-tilt
##
## Input flows the other way: tap coords → unproject → world coords for deploy logic.

## The node that owns the playfield's top-left in screen space. Set by Playfield
## on _ready so all projection math is relative to it.
var _origin: Node2D = null

func set_origin(n: Node2D) -> void:
	_origin = n

func _cfg() -> GameConfigData:
	return GameConfig.data

## Normalized depth 0 (far / enemy side) → 1 (near / player side).
func depth_at(world_y: float) -> float:
	var cfg := _cfg()
	if cfg.map_height <= 0.0:
		return 1.0
	return clampf(world_y / cfg.map_height, 0.0, 1.0)

## Per-depth scale multiplier. Near = 1.0, far = cfg.far_scale.
func scale_at(world_y: float) -> float:
	var cfg := _cfg()
	return lerpf(cfg.far_scale, 1.0, depth_at(world_y))

## Project world (x,y) to screen-local (relative to playfield origin).
func project(world: Vector2) -> Vector2:
	var cfg := _cfg()
	var d := depth_at(world.y)
	var pinch := lerpf(cfg.far_width_pinch, 1.0, d)
	var cx := cfg.map_width * 0.5
	var screen_x := cx + (world.x - cx) * pinch
	var lift := cfg.far_y_lift * (1.0 - d)
	var screen_y := world.y + lift
	return Vector2(screen_x, screen_y)

## Inverse — given a tap in screen-local space, return the world coord.
## Used by match input to decide deploy location.
func unproject(screen: Vector2) -> Vector2:
	var cfg := _cfg()
	# Solve screen_y = world_y + lift(world_y), where lift = far_y_lift * (1 - y/H).
	# screen_y = y + L * (1 - y/H) = y * (1 - L/H) + L
	# => y = (screen_y - L) / (1 - L/H)
	var L := cfg.far_y_lift
	var H := cfg.map_height
	var denom := 1.0 - (L / maxf(H, 1.0))
	var world_y := (screen.y - L) / maxf(denom, 0.0001)
	world_y = clampf(world_y, 0.0, H)
	var d := depth_at(world_y)
	var pinch := lerpf(cfg.far_width_pinch, 1.0, d)
	var cx := cfg.map_width * 0.5
	var world_x := cx + (screen.x - cx) / maxf(pinch, 0.0001)
	return Vector2(world_x, world_y)

## Convenience: returns screen position (absolute in viewport) for a world coord,
## assuming the playfield origin has been registered.
func to_global(world: Vector2) -> Vector2:
	var local := project(world)
	if _origin == null:
		return local
	return _origin.global_position + local

## The four corners of the playfield trapezoid, clockwise from top-left,
## in playfield-local coords. Useful for drawing the deploy-zone outline.
func trapezoid_corners() -> PackedVector2Array:
	var cfg := _cfg()
	return PackedVector2Array([
		project(Vector2(0, 0)),
		project(Vector2(cfg.map_width, 0)),
		project(Vector2(cfg.map_width, cfg.map_height)),
		project(Vector2(0, cfg.map_height)),
	])
