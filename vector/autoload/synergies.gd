extends Node
## Card synergies. Static pair-bonus table — if a deck contains BOTH cards
## in a pair, the synergy is active and shown in the Deck tab.
##
## These are display-only hints for now; no in-match effect is applied yet.
## The effect hook can live in unit.gd later, reading from this table.

const PAIRS: Array[Dictionary] = [
	{ "a": &"pulse",   "b": &"burst",   "label": "CHAIN DETONATE",  "bonus": 0.18 },
	{ "a": &"spiral",  "b": &"bomb",    "label": "AREA BURN",       "bonus": 0.12 },
	{ "a": &"dart",    "b": &"lance",   "label": "PIERCE FOCUS",    "bonus": 0.15 },
	{ "a": &"chevron", "b": &"orb",     "label": "SWARM COVER",     "bonus": 0.10 },
	{ "a": &"burst",   "b": &"chevron", "label": "STAGGER WAVE",    "bonus": 0.08 },
	{ "a": &"pulse",   "b": &"lance",   "label": "LOCK-ON RELAY",   "bonus": 0.20 },
]

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
