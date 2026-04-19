extends Node
## Central color palette — design tokens from the handoff. Change a color here
## and it propagates everywhere. Keep this as the single source of truth.

const BG := Color("06080b")
const TEXT := Color("e5e7eb")
const TEXT_DIM := Color("9ca3af")
const DIVIDER := Color(1, 1, 1, 0.2)
const PARTICLE := Color("ffffff")

const CARD_BG := Color(0.047, 0.055, 0.071, 0.75)
const CARD_BORDER := Color(1, 1, 1, 0.12)

const WALL_YOU := Color("67e8f9")
const WALL_ENEMY := Color("fb7185")
const WALL_ACCENT := Color("86efac")
const MANA := Color("fbbf24")

const BASE_YOU := Color("67e8f9")
const BASE_ENEMY := Color("fb7185")

## Unit colors by card id (keep keys in sync with data/cards/*.tres ids)
const UNIT := {
	&"dart":    Color("7dd3fc"),
	&"bomb":    Color("fb7185"),
	&"spiral":  Color("c084fc"),
	&"burst":   Color("fbbf24"),
	&"lance":   Color("67e8f9"),
	&"orb":     Color("86efac"),
	&"chevron": Color("f472b6"),
	&"pulse":   Color("a78bfa"),
}

func unit_color(card_id: StringName) -> Color:
	return UNIT.get(card_id, TEXT)
