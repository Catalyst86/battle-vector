extends Node
## Card synergies. Static pair-bonus table — if a deck contains BOTH cards
## in a pair, the synergy is active: its percentage bonus multiplies the
## damage of every unit matching either card in the pair.
##
## Effect site: `scripts/match/unit.gd:_synergy_multiplier()`. Called once in
## `Unit._ready()` so `base_damage = card.damage * level_mult * synergy_mult`
## is fixed for the unit's lifetime. The Deck tab reads the same table via
## `active_for()` to display the active synergies to the player.

const PAIRS: Array[Dictionary] = [
	{ "a": &"pulse",   "b": &"burst",   "label": "CHAIN DETONATE",  "bonus": 0.18 },
	{ "a": &"spiral",  "b": &"bomb",    "label": "AREA BURN",       "bonus": 0.12 },
	{ "a": &"dart",    "b": &"lance",   "label": "PIERCE FOCUS",    "bonus": 0.15 },
	{ "a": &"chevron", "b": &"orb",     "label": "SWARM COVER",     "bonus": 0.10 },
	{ "a": &"burst",   "b": &"chevron", "label": "STAGGER WAVE",    "bonus": 0.08 },
	{ "a": &"pulse",   "b": &"lance",   "label": "LOCK-ON RELAY",   "bonus": 0.20 },
	# Audit C3 additions — reach into the long tail so more cards have a
	# partner. Keeps bonuses small (0.10–0.15) so stacking stays bounded.
	{ "a": &"mortar",  "b": &"shard",   "label": "MULTI-LOCK",      "bonus": 0.12 },
	{ "a": &"revenant","b": &"chevron", "label": "GRAVE SWARM",     "bonus": 0.15 },
	{ "a": &"beacon",  "b": &"dart",    "label": "GUIDED FIRE",     "bonus": 0.10 },
	{ "a": &"chorus",  "b": &"flock",   "label": "HIVE SANCTUARY",  "bonus": 0.10 },
]

## Stacking cap for synergy multipliers. Adversarial review of the audit
## fix plan flagged that more pairs = more multiplicative power. Capped
## so no unit exceeds +50% from synergies alone (still stackable with
## buffer auras and level_mult — those are separate multipliers).
const MAX_STACK_BONUS: float = 0.50

## Returns the synergies active for the supplied deck (array of card ids).
func active_for(card_ids: Array) -> Array[Dictionary]:
	var ids: Dictionary = {}
	for id in card_ids:
		ids[id] = true
	var out: Array[Dictionary] = []
	for p in PAIRS:
		if ids.has(p.a) and ids.has(p.b):
			out.append(p)
	return out

## Comma-separated label listing active synergy names — used by the match
## HUD to confirm to the player which pairs their deck unlocked. Empty
## string if no synergies fire, so the caller can skip the toast cleanly.
func active_label(card_ids: Array) -> String:
	var active: Array[Dictionary] = active_for(card_ids)
	if active.is_empty():
		return ""
	var parts: Array[String] = []
	for p in active:
		parts.append(String(p.label))
	return ", ".join(parts)
