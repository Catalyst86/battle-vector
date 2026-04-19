extends Node2D
## The pseudo-3D battlefield surface. Owns its own grid/backdrop drawing and
## publishes itself to Pseudo3D so all projection is relative to this node's
## origin. Child to this node for anything that lives "on the field."

@export_range(1, 24) var grid_step_px: float = 24.0
@export var show_deploy_zone: bool = true

var _time: float = 0.0

func _ready() -> void:
	Pseudo3D.set_origin(self)
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var cfg := GameConfig.data
	var corners := Pseudo3D.trapezoid_corners()
	_draw_filled_trapezoid(corners, cfg.background_color.lightened(0.02))
	_draw_grid(cfg)
	_draw_trapezoid_outline(corners, Palette.DIVIDER)
	_draw_midline(cfg)
	if show_deploy_zone:
		_draw_deploy_zone(cfg)

func _draw_filled_trapezoid(corners: PackedVector2Array, color: Color) -> void:
	var colors := PackedColorArray([color, color, color, color])
	draw_polygon(corners, colors)

func _draw_trapezoid_outline(corners: PackedVector2Array, color: Color) -> void:
	var loop := corners.duplicate()
	loop.append(corners[0])
	draw_polyline(loop, color, 1.0, true)

func _draw_grid(cfg: GameConfigData) -> void:
	var col := cfg.grid_color
	# Horizontal lines (constant world_y steps) — each gets projected trapezoid-wide.
	var y := grid_step_px
	while y < cfg.map_height:
		var a := Pseudo3D.project(Vector2(0.0, y))
		var b := Pseudo3D.project(Vector2(cfg.map_width, y))
		draw_line(a, b, col, 1.0, true)
		y += grid_step_px
	# Vertical lines (constant world_x) — converge toward far edge naturally.
	var x := grid_step_px
	while x < cfg.map_width:
		var a := Pseudo3D.project(Vector2(x, 0.0))
		var b := Pseudo3D.project(Vector2(x, cfg.map_height))
		draw_line(a, b, col, 1.0, true)
		x += grid_step_px

func _draw_midline(cfg: GameConfigData) -> void:
	var a := Pseudo3D.project(Vector2(0.0, cfg.midline_y))
	var b := Pseudo3D.project(Vector2(cfg.map_width, cfg.midline_y))
	_draw_dashed(a, b, Color(1, 1, 1, 0.25), 6.0, 4.0, 1.0)

func _draw_deploy_zone(cfg: GameConfigData) -> void:
	# Dashed outline around the player's half (below midline).
	var tl := Pseudo3D.project(Vector2(0.0, cfg.midline_y))
	var tr := Pseudo3D.project(Vector2(cfg.map_width, cfg.midline_y))
	var br := Pseudo3D.project(Vector2(cfg.map_width, cfg.map_height))
	var bl := Pseudo3D.project(Vector2(0.0, cfg.map_height))
	var col := Color(Palette.WALL_YOU.r, Palette.WALL_YOU.g, Palette.WALL_YOU.b, 0.12)
	draw_polygon(PackedVector2Array([tl, tr, br, bl]), PackedColorArray([col, col, col, col]))

func _draw_dashed(a: Vector2, b: Vector2, color: Color, dash: float, gap: float, width: float) -> void:
	var dir := (b - a)
	var total := dir.length()
	if total <= 0.001:
		return
	dir = dir / total
	var pos := 0.0
	while pos < total:
		var s := a + dir * pos
		var e := a + dir * minf(pos + dash, total)
		draw_line(s, e, color, width, true)
		pos += dash + gap
