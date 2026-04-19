class_name Projectile
extends Node2D
## Straight-line projectile fired by shooter/sniper units. Travels in world
## space, projects into screen via Pseudo3D on each frame. Collides with
## opposing units first (size * 0.8 radius) then the opposing base (by
## y-coordinate crossing into the base strip). Dies on first hit unless
## `pierces` is true.

var world_pos: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var damage: float = 0.0
var color: Color = Color(1, 1, 1)
var owner_enemy: bool = false
var pierces: bool = false

const LIFE_MAX := 3.0
var _life: float = LIFE_MAX
var _hit_ids: Array[int] = []
var _prev_world: Vector2 = Vector2.ZERO

func _ready() -> void:
	_refresh_transform()

func _process(delta: float) -> void:
	_prev_world = world_pos
	world_pos += velocity * delta
	_life -= delta
	var cfg := GameConfig.data
	if _life <= 0.0 or world_pos.y < -16.0 or world_pos.y > cfg.map_height + 16.0:
		queue_free()
		return
	_refresh_transform()
	_check_collisions(cfg)
	queue_redraw()

func _refresh_transform() -> void:
	position = Pseudo3D.project(world_pos)
	var s := Pseudo3D.scale_at(world_pos.y)
	scale = Vector2.ONE * s * GameConfig.data.unit_display_scale

func _check_collisions(cfg: GameConfigData) -> void:
	# 1) Walls first. Opposing walls absorb the bolt (unless it pierces).
	#    Use a swept check: the projectile's path this frame intersects the
	#    wall rect. Prevents fast bullets from tunneling through thin walls.
	var walls_group: String = "walls_enemy" if not owner_enemy else "walls_player"
	for n in get_tree().get_nodes_in_group(walls_group):
		var w := n as Wall
		if w == null or w.is_queued_for_deletion():
			continue
		if _segment_hits_rect(_prev_world, world_pos, w.bounds()):
			w.take_damage(damage)
			if not pierces:
				queue_free()
				return
			# Piercing bolt still eats a small chunk per wall pass.
	# 2) Opposing units (body * 0.8 radius).
	var group: String = "enemy_units" if not owner_enemy else "player_units"
	for n in get_tree().get_nodes_in_group(group):
		if n.is_queued_for_deletion():
			continue
		var id: int = n.get_instance_id()
		if id in _hit_ids:
			continue
		var u := n as Node2D
		if u == null or u.get("card") == null:
			continue
		var body_r: float = (u.card.size) * 0.8
		if (u.world_pos - world_pos).length() <= body_r:
			_hit_ids.append(id)
			if u.has_method("take_damage"):
				u.take_damage(damage)
			if not pierces:
				queue_free()
				return
	# 3) Base by y-coordinate.
	if not owner_enemy and world_pos.y <= cfg.base_strip_height:
		_hit_base(1)
		queue_free()
	elif owner_enemy and world_pos.y >= cfg.map_height - cfg.base_strip_height:
		_hit_base(0)
		queue_free()

## True if the segment from `a` to `b` enters or ends inside `rect`. Used for
## wall collision so a fast projectile can't jump through a thin wall in one
## frame.
func _segment_hits_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	# Expand the rect slightly so nearly-grazing shots still register.
	var r := rect.grow(2.0)
	if r.has_point(a) or r.has_point(b):
		return true
	# Test segment against each edge of the rect.
	var corners := [
		r.position,
		r.position + Vector2(r.size.x, 0),
		r.position + r.size,
		r.position + Vector2(0, r.size.y),
	]
	for i in range(4):
		var p1: Vector2 = corners[i]
		var p2: Vector2 = corners[(i + 1) % 4]
		if Geometry2D.segment_intersects_segment(a, b, p1, p2) != null:
			return true
	return false

func _hit_base(side: int) -> void:
	var group_name: String = "enemy_base" if side == 1 else "player_base"
	var base := get_tree().get_first_node_in_group(group_name)
	if base != null and base.has_method("hit_at"):
		# Precise hit: if the projectile lands in a gap or on a square that
		# just died, no damage. That's what makes aimed fire feel intentional.
		var hits: int = maxi(1, roundi(damage / 18.0))
		base.hit_at(world_pos, hits)

func _draw() -> void:
	# Short motion trail behind the projectile (in local space — orientation
	# matches screen velocity closely enough thanks to the near-uniform
	# pseudo-3D scaling at a single projectile's depth).
	if velocity.length_squared() > 0.01:
		var trail_dir: Vector2 = -velocity.normalized() * 10.0
		var trail_c: Color = color
		trail_c.a = 0.32
		draw_line(Vector2.ZERO, trail_dir, trail_c, 2.0, true)
	var glow := color
	glow.a = 0.35
	draw_circle(Vector2.ZERO, 5.0, glow)
	draw_circle(Vector2.ZERO, 2.0, color)
