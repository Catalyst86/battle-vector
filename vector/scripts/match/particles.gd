class_name BattleParticles
extends Node2D
## Faint drifting specks in the playfield background. Purely cosmetic,
## density controlled by GameConfig.particle_density. Each particle wraps
## when it exits the field.

var _particles: Array = []

func _ready() -> void:
	_respawn_all()

func _respawn_all() -> void:
	var cfg := GameConfig.data
	_particles.clear()
	for i in cfg.particle_density:
		_particles.append({
			"pos": Vector2(randf() * cfg.map_width, randf() * cfg.map_height),
			"r": randf_range(0.3, 1.5),
			"speed": randf_range(4.0, 10.0),
		})

func _process(delta: float) -> void:
	var cfg := GameConfig.data
	for p in _particles:
		p.pos.y += p.speed * delta
		if p.pos.y > cfg.map_height:
			p.pos.y = 0.0
			p.pos.x = randf() * cfg.map_width
	queue_redraw()

func _draw() -> void:
	var c: Color = Palette.PARTICLE
	c.a = 0.35
	for p in _particles:
		var s := Pseudo3D.project(p.pos)
		draw_circle(s, p.r, c)
