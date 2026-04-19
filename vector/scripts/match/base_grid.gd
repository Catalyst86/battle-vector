class_name BaseGrid
extends Node2D
## A 18×3 grid of base squares. Each square is drawn as a perspective-projected
## quad. On "destruction" the alive[] flag flips; rendering shows dead squares
## as faint outlines. Data-driven from GameConfig.

const SIDE_YOU := 0
const SIDE_ENEMY := 1

## Emitted whenever a base square dies. Match listens to resolve win conditions.
signal squares_changed(remaining: int)

@export_enum("YOU:0", "ENEMY:1") var side: int = SIDE_YOU

var alive: Array[bool] = []
var _cols: int = 0
var _rows: int = 0

func _ready() -> void:
	var cfg := GameConfig.data
	_cols = cfg.base_cols
	_rows = cfg.base_rows
	alive.resize(_cols * _rows)
	alive.fill(true)
	add_to_group("enemy_base" if side == SIDE_ENEMY else "player_base")
	queue_redraw()

func count_alive() -> int:
	var n := 0
	for v in alive:
		if v:
			n += 1
	return n

## Damage the nearest alive square to a world-space impact; kills `hits` of them.
func damage_at(world_pos: Vector2, hits: int) -> int:
	var cfg := GameConfig.data
	var killed := 0
	for _i in range(hits):
		var best := -1
		var best_d := INF
		for idx in range(alive.size()):
			if not alive[idx]:
				continue
			var c := _cell_world_center(idx, cfg)
			var d := c.distance_squared_to(world_pos)
			if d < best_d:
				best_d = d
				best = idx
		if best < 0:
			break
		alive[best] = false
		killed += 1
	if killed > 0:
		squares_changed.emit(count_alive())
	queue_redraw()
	return killed

func _cell_world_center(idx: int, cfg: GameConfigData) -> Vector2:
	var row: int = idx / _cols
	var col: int = idx % _cols
	var cell_w: float = cfg.map_width / float(_cols)
	var cell_h: float = cfg.base_strip_height / float(_rows)
	var strip_top: float = 0.0 if side == SIDE_ENEMY else (cfg.map_height - cfg.base_strip_height)
	return Vector2(
		cell_w * (col + 0.5),
		strip_top + cell_h * (row + 0.5)
	)

## Random alive square's world center. Used by ranged units to pick a specific
## square to fire at (instead of always aiming at the base's geometric middle).
## Returns Vector2.INF when no squares remain.
func random_alive_position() -> Vector2:
	var alive_idx: Array[int] = []
	for i in alive.size():
		if alive[i]:
			alive_idx.append(i)
	if alive_idx.is_empty():
		return Vector2.INF
	return _cell_world_center(alive_idx[randi() % alive_idx.size()], GameConfig.data)

## Column-aware hit test. Finds the first alive cell in the impact column,
## walking from the row the projectile meets first toward the back of the
## strip — so a shot passing through a dead front-row square still damages
## the row behind it. Returns squares killed (0 = impact column is fully
## dead or off-grid). If `hits > 1`, the hit cascades to nearest alive
## neighbours from the initial impact.
func hit_at(world_pos: Vector2, hits: int) -> int:
	var cfg := GameConfig.data
	var cell_w: float = cfg.map_width / float(_cols)
	var col: int = int(floor(world_pos.x / cell_w))
	if col < 0 or col >= _cols:
		return 0
	# Projectile traversal order: for the enemy base, rounds come from below
	# so the near row is rows-1; for the player base, from above so row 0
	# is near. Walk the column in that order and hit the first alive cell.
	var idx: int = -1
	var row_range: Array = range(_rows - 1, -1, -1) if side == SIDE_ENEMY else range(_rows)
	for r in row_range:
		var candidate: int = r * _cols + col
		if alive[candidate]:
			idx = candidate
			break
	if idx < 0:
		return 0
	alive[idx] = false
	var killed: int = 1
	var anchor := _cell_world_center(idx, cfg)
	for _i in range(hits - 1):
		var best: int = -1
		var best_d: float = INF
		for j in range(alive.size()):
			if not alive[j]:
				continue
			var c := _cell_world_center(j, cfg)
			var d := c.distance_squared_to(anchor)
			if d < best_d:
				best_d = d
				best = j
		if best < 0:
			break
		alive[best] = false
		killed += 1
	squares_changed.emit(count_alive())
	queue_redraw()
	return killed

func _draw() -> void:
	var cfg := GameConfig.data
	var color: Color = Palette.BASE_ENEMY if side == SIDE_ENEMY else Palette.BASE_YOU
	var cell_w: float = cfg.map_width / float(_cols)
	var cell_h: float = cfg.base_strip_height / float(_rows)
	var strip_top: float = 0.0 if side == SIDE_ENEMY else (cfg.map_height - cfg.base_strip_height)
	var gap := 1.0
	for row in range(_rows):
		for col in range(_cols):
			var idx := row * _cols + col
			var is_alive := alive[idx]
			var wx := cell_w * col + gap
			var wy := strip_top + cell_h * row + gap
			var ww := cell_w - gap * 2.0
			var wh := cell_h - gap * 2.0
			var tl := Pseudo3D.project(Vector2(wx, wy))
			var tr := Pseudo3D.project(Vector2(wx + ww, wy))
			var br := Pseudo3D.project(Vector2(wx + ww, wy + wh))
			var bl := Pseudo3D.project(Vector2(wx, wy + wh))
			var pts := PackedVector2Array([tl, tr, br, bl])
			if is_alive:
				var fill := color
				fill.a = 0.85
				draw_polygon(pts, PackedColorArray([fill, fill, fill, fill]))
				var edge := color
				edge.a = 0.5
				var loop := pts.duplicate()
				loop.append(tl)
				draw_polyline(loop, edge, 1.0, true)
			else:
				var edge := color
				edge.a = 0.15
				var loop := pts.duplicate()
				loop.append(tl)
				draw_polyline(loop, edge, 1.0, true)
