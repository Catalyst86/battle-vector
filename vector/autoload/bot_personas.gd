extends Node
## Arena-themed bot personas. Each persona is a bot identity with a fixed
## deck and an aggression value that tunes how quickly it spends mana and
## how much it favours offensive roles. The match picks a persona based on
## the player's current arena index so climbing the ladder meaningfully
## changes what you're playing against.
##
## Replaces the previous "random 8-subset of the unlocked pool" logic —
## which produced same-y matches regardless of arena progression.

const PERSONAS: Array[Dictionary] = [
	# Arena 1 — GROUND ZERO — basic-cost fast deck, aggressive
	{
		"name": "K.VOID_07",
		"arena": 0,
		"deck": [&"dart", &"pellet", &"bomb", &"orb", &"chevron", &"arc", &"burst", &"hook"],
		"aggression": 0.8,
		"favour_roles": [CardData.Role.SHOOTER, CardData.Role.MELEE],
	},
	# Arena 2 — SCRAP ALLEY — ground-up brawler, heavier melee
	{
		"name": "B.RUST_12",
		"arena": 1,
		"deck": [&"bomb", &"dart", &"dozer", &"grenade", &"spiral", &"chevron", &"saw", &"burst"],
		"aggression": 0.85,
		"favour_roles": [CardData.Role.MELEE, CardData.Role.WALLBREAK],
	},
	# Arena 3 — NEON ARC — balanced swarm + shooter
	{
		"name": "N.ARCADE_03",
		"arena": 2,
		"deck": [&"dart", &"orb", &"chevron", &"flock", &"burst", &"bomb", &"spiral", &"beacon"],
		"aggression": 0.75,
		"favour_roles": [CardData.Role.SWARM, CardData.Role.SHOOTER],
	},
	# Arena 4 — VOID HALLS — lane control + interceptors
	{
		"name": "V.HALL_44",
		"arena": 3,
		"deck": [&"orb", &"pulse", &"burst", &"chevron", &"grenade", &"spiral", &"hook", &"lance"],
		"aggression": 0.7,
		"favour_roles": [CardData.Role.INTERCEPTOR, CardData.Role.SNIPER],
	},
	# Arena 5 — DATAVAULT — sniper + buff heavy
	{
		"name": "D.VAULT_99",
		"arena": 4,
		"deck": [&"lance", &"beam", &"beacon", &"oracle", &"burst", &"orb", &"chevron", &"pulse"],
		"aggression": 0.65,
		"favour_roles": [CardData.Role.SNIPER, CardData.Role.BUFFER],
	},
	# Arena 6 — SIGNAL PEAK — aggressive mixed deck
	{
		"name": "S.PEAK_21",
		"arena": 5,
		"deck": [&"dart", &"lance", &"bomb", &"shard", &"mortar", &"burst", &"chevron", &"spiral"],
		"aggression": 0.9,
		"favour_roles": [CardData.Role.SHOOTER, CardData.Role.SNIPER],
	},
	# Arena 7 — STORM LAYER — swarm + heal combos
	{
		"name": "T.STORM_55",
		"arena": 6,
		"deck": [&"chevron", &"flock", &"chorus", &"mender", &"bomb", &"burst", &"pulse", &"orb"],
		"aggression": 0.75,
		"favour_roles": [CardData.Role.SWARM, CardData.Role.HEALER],
	},
	# Arena 8 — APEX GRID — endgame — everything epic, max aggression
	{
		"name": "APEX_001",
		"arena": 7,
		"deck": [&"lance", &"pulse", &"titan", &"revenant", &"siphon", &"aegis", &"beam", &"mortar"],
		"aggression": 1.0,
		"favour_roles": [CardData.Role.SNIPER, CardData.Role.WALLBREAK, CardData.Role.BUFFER],
	},
]

## Picks a persona for a given arena index (0-based). Falls back to the
## closest defined arena when the player is somewhere we don't have a bot
## for — defensive in case ARENA_THRESHOLDS in PlayerProfile grows.
func for_arena(idx: int) -> Dictionary:
	for p in PERSONAS:
		if int(p.arena) == idx:
			return p
	# Closest match.
	var best: Dictionary = PERSONAS[0]
	var best_d: int = 9999
	for p in PERSONAS:
		var d: int = absi(int(p.arena) - idx)
		if d < best_d:
			best_d = d
			best = p
	return best

## Resolves a persona's deck StringNames to loaded CardData. Skips any id
## whose .tres file doesn't exist (so a typo in the table doesn't crash —
## the match just gets a slightly smaller deck for that persona).
func deck_for(persona: Dictionary) -> Array[CardData]:
	var result: Array[CardData] = []
	for id in persona.get("deck", []):
		var path: String = "res://data/cards/%s.tres" % String(id)
		if not ResourceLoader.exists(path):
			push_warning("BotPersonas: card '%s' not found at %s" % [id, path])
			continue
		var c: CardData = load(path) as CardData
		if c != null:
			result.append(c)
	return result
