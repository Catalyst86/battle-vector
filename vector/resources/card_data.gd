@tool
class_name CardData
extends Resource

## Single source of truth for every deployable card. One .tres per card in data/cards/.
## Open any card in the inspector to tweak — no code changes needed.

enum Role {
	SHOOTER,     # ranged attacker; fires projectiles
	MELEE,       # walks in, detonates on contact (AoE)
	WALLBREAK,   # targets walls; phases through them
	INTERCEPTOR, # chases + rams enemy units
	SNIPER,      # stationary; long-range fire
	SWARM,       # deploy replaced by N scouts
	HEALER,      # heals nearest wounded ally in range
	BUFFER,      # passive aura; boosts ally damage in radius
}
enum Shape { TRIANGLE, SQUARE, DIAMOND, CIRCLE, RING, STAR, CHEVRON, SPIRAL }

@export var id: StringName = &""
@export var display_name: String = ""
@export var shape: Shape = Shape.CIRCLE
@export var role: Role = Role.SHOOTER
@export_color_no_alpha var color: Color = Color(1, 1, 1)
@export_multiline var description: String = ""
## Player level required to own/play this card. Default 1 = always available.
@export_range(1, 20) var unlock_level: int = 1
## Rarity tier. Drives UI treatment (LED color, border, shop filtering).
## Values: &"common" / &"rare" / &"epic" / &"legend".
@export var rarity: StringName = &"common"

@export_group("Combat")
@export_range(1, 10) var cost: int = 2
@export_range(1, 500) var hp: float = 20.0
@export_range(0, 200) var damage: float = 6.0
@export_range(0, 200) var speed: float = 50.0
@export_range(0, 500) var attack_range: float = 140.0
@export_range(0.0, 5.0, 0.05) var fire_rate: float = 0.6
@export_range(6, 40) var size: float = 14.0

@export_group("Swarm-only")
@export_range(0, 10) var swarm_count: int = 0

@export_group("Projectile modifiers")
## Shooter/sniper projectiles pass through enemies instead of stopping on first hit.
@export var pierces: bool = false
## How many projectiles to fire per shot (fanned). 1 = normal, 3 = spread.
@export_range(1, 9) var projectile_count: int = 1
## Angular spread between fanned projectiles, in degrees.
@export_range(0.0, 45.0, 1.0) var projectile_spread_deg: float = 12.0

@export_group("Melee")
## AoE radius on contact detonation. 0 uses engine default (~40 units).
@export_range(0.0, 120.0, 1.0) var melee_aoe_radius: float = 40.0

@export_group("Aura (healer / buffer)")
## Radius of the aura effect in world units.
@export_range(0.0, 200.0, 1.0) var aura_radius: float = 0.0
## Damage multiplier added to allies inside the aura. 0.25 = +25%.
@export_range(0.0, 2.0, 0.05) var aura_damage_mult: float = 0.0
## HP per second healed to allies inside the aura.
@export_range(0.0, 40.0, 0.5) var aura_heal_per_sec: float = 0.0

@export_group("Advanced mechanics")
## Ignores wall collision like a wallbreak unit.
@export var phases_walls: bool = false
## Fraction of damage dealt that heals self. 0.5 = 50% lifesteal.
@export_range(0.0, 2.0, 0.05) var lifesteal_frac: float = 0.0
## If set, spawns this card (as the same team) on death — e.g. Revenant → Scout.
@export var on_death_spawn: Resource = null

@export_group("On-death effects")
## Radius of a shockwave emitted when this unit dies (world units). 0 = none.
@export_range(0.0, 200.0, 1.0) var on_death_shockwave_radius: float = 0.0
## Damage dealt to enemies inside the shockwave radius.
@export_range(0.0, 200.0, 0.5) var on_death_shockwave_damage: float = 0.0

@export_group("Audio (optional overrides)")
## SFX ids that override the role-derived defaults. Empty = use role default.
## Valid ids are whatever SfxBank has synthesised (see SfxBank._build_bank).
@export var sfx_deploy: StringName = &""
@export var sfx_shoot: StringName = &""
@export var sfx_death: StringName = &""
@export var sfx_hit: StringName = &""

func role_label() -> String:
	match role:
		Role.SHOOTER: return "SHOOT"
		Role.MELEE: return "MELEE"
		Role.WALLBREAK: return "BREAK"
		Role.INTERCEPTOR: return "INTCP"
		Role.SNIPER: return "SNIPE"
		Role.SWARM: return "SWARM"
		Role.HEALER: return "HEAL"
		Role.BUFFER: return "BUFF"
	return "?"
