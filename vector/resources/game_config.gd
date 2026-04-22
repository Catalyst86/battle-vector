@tool
class_name GameConfigData
extends Resource

## All match / balance / layout constants. Edit data/config/game_config.tres
## in the inspector — no code changes needed.
## Spec source: design_handoff_vector_pvp_tower_defense/README.md

@export_group("Map — design space pixels")
@export var map_width: float = 360.0
@export var map_height: float = 700.0
@export var base_strip_height: float = 60.0
@export var midline_y: float = 350.0
@export var hud_top_height: float = 40.0
@export var hud_bottom_height: float = 40.0

@export_group("Bases")
@export var base_cols: int = 18
@export var base_rows: int = 3

@export_group("Walls")
@export var wall_width: float = 110.0
@export var wall_height: float = 8.0
@export var wall_hp: float = 80.0
@export var max_walls_per_player: int = 3

@export_group("Match timing")
@export var match_seconds: int = 180
@export var overtime_seconds: int = 60
## Seconds to place walls before the match auto-starts. Float so we can
## tune sub-second timings (e.g. 7.5). Display code ceilings to int.
@export_range(1.0, 120.0, 0.5) var build_seconds: float = 7.5

@export_group("Mana")
@export var mana_max: int = 10
@export var mana_start: int = 6
@export_range(0.1, 5.0, 0.05) var mana_regen_per_sec: float = 1.0

@export_group("Surge phase")
## Duration (seconds) of the SURGE opening sub-phase that fires at the
## start of MATCH. During Surge the player enters with full mana and the
## regen rate is multiplied — cuts the dead zone between BUILD and first
## meaningful engagement. Set to 0 to disable Surge entirely.
@export_range(0.0, 60.0, 0.5) var surge_seconds: float = 25.0
## Mana regen multiplier applied during SURGE. 2.0 = double speed.
@export_range(1.0, 5.0, 0.1) var surge_mana_regen_mult: float = 2.0

@export_group("Projectiles")
@export var projectile_speed: float = 260.0
@export var projectile_trail_length: int = 6

@export_group("Units on field")
## Global multiplier on how large deployed units render. 1.0 = card's native
## `size`, 0.7 = 30% smaller in-field. Hand icons are unaffected.
@export_range(0.3, 1.5, 0.05) var unit_display_scale: float = 0.7

@export_group("Pseudo-3D perspective")
## How much the far edge (enemy side) shrinks compared to the near edge (player side).
## 1.0 = no perspective. 0.6 = far edge is 60% the scale of near. Spec target: subtle ~0.75.
@export_range(0.40, 1.0, 0.01) var far_scale: float = 0.75
## Horizontal pinch at the far edge (trapezoid narrowing). 1.0 = no pinch.
@export_range(0.40, 1.0, 0.01) var far_width_pinch: float = 0.78
## Vertical lift: move the far edge up slightly on screen for a camera-tilt feel.
@export_range(0.0, 40.0, 1.0) var far_y_lift: float = 14.0
## Deploy "pop" — unit spawns with slight downward-toward-player offset, then settles.
@export_range(0.0, 60.0, 1.0) var deploy_pop_distance: float = 28.0
@export_range(0.05, 1.0, 0.01) var deploy_pop_duration: float = 0.35

@export_group("Visuals")
@export var particle_density: int = 60
@export_range(0.0, 8.0, 0.5) var glow_intensity: float = 3.0
@export_color_no_alpha var background_color: Color = Color("06080b")
@export_color_no_alpha var grid_color: Color = Color(1, 1, 1, 0.06)
@export var grid_spacing: float = 24.0

func total_height() -> float:
	return map_height + hud_top_height + hud_bottom_height
