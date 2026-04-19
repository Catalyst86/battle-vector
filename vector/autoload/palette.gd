extends Node
## Central color palette — design tokens. Single source of truth for every
## color and font used on screen.
##
## Two sections:
##   - IN-GAME colors (field rendering, units, walls, particles)
##   - UI TOKENS (menu shell, HUD chrome, screens) — follow the "Vector Terminal"
##     design handoff. Hex values below match design-handoff/.../styles.css.

# ─── In-game colors ────────────────────────────────────────────────────────

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

# ─── UI tokens (Vector Terminal design system) ─────────────────────────────

## Backgrounds — darkest to lightest elevation
const UI_BG_0 := Color("04070c")
const UI_BG_1 := Color("0a1018")
const UI_BG_2 := Color("0f1620")
const UI_BG_3 := Color("151e2b")

## Hairlines (use as borders, dividers)
const UI_LINE_1 := Color(0.47, 0.588, 0.706, 0.08)   # faintest
const UI_LINE_2 := Color(0.47, 0.588, 0.706, 0.16)   # default
const UI_LINE_3 := Color(0.47, 0.588, 0.706, 0.32)   # emphasised

## Text ramp
const UI_TEXT_0 := Color("e8f1fa")    # primary
const UI_TEXT_1 := Color("b8c7d6")    # secondary
const UI_TEXT_2 := Color("7a8a9d")    # tertiary / labels
const UI_TEXT_3 := Color("4a5668")    # quaternary / disabled

## Accents
const UI_CYAN := Color("5be0ff")
const UI_CYAN_DIM := Color("2a7a94")
const UI_CYAN_GLOW := Color(0.357, 0.878, 1.0, 0.4)

const UI_AMBER := Color("ffb648")
const UI_AMBER_DIM := Color("8a5f20")
const UI_AMBER_GLOW := Color(1.0, 0.714, 0.282, 0.4)

const UI_MAGENTA := Color("ff4d8d")
const UI_VIOLET := Color("b56cff")
const UI_GREEN := Color("4dffa8")
const UI_RED := Color("ff5b5b")

## Card rarity colors (used on rarity LEDs in CardSlot)
const UI_RARITY := {
	&"common": Color("7a8a9d"),
	&"rare":   Color("5be0ff"),
	&"epic":   Color("b56cff"),
	&"legend": Color("ffb648"),
}

## Role colors (used on role pills, color-stripe at top of card)
const UI_ROLE := {
	&"SHOOT": Color("5be0ff"),
	&"MELEE": Color("ff5b5b"),
	&"BREAK": Color("b56cff"),
	&"INTCP": Color("ffb648"),
	&"SNIPE": Color("5be0ff"),
	&"SWARM": Color("ff4d8d"),
	&"HEAL":  Color("4dffa8"),
	&"BUFF":  Color("ffb648"),
	&"WALL":  Color("7a8a9d"),
}

func role_color(role_label: String) -> Color:
	return UI_ROLE.get(StringName(role_label), UI_TEXT_1)

func rarity_color(rarity: StringName) -> Color:
	return UI_RARITY.get(rarity, UI_TEXT_2)

# ─── Font resources ────────────────────────────────────────────────────────

## Display — Chakra Petch (Bold for hero numbers, SemiBold for titles/buttons).
## Wide, 90-degree letterforms. All UPPERCASE UI labels use this.
const FONT_DISPLAY: FontFile = preload("res://assets/fonts/ChakraPetch-SemiBold.ttf")
const FONT_DISPLAY_BOLD: FontFile = preload("res://assets/fonts/ChakraPetch-Bold.ttf")
const FONT_DISPLAY_REGULAR: FontFile = preload("res://assets/fonts/ChakraPetch-Regular.ttf")

## Body — reuse Chakra Petch Regular for longer copy. The handoff specified
## IBM Plex Sans but dropping it keeps the font bundle lean and keeps the
## visual voice cohesive. Swap later if body copy ever feels thin.
const FONT_BODY: FontFile = preload("res://assets/fonts/ChakraPetch-Regular.ttf")

## Mono — JetBrains Mono for all numbers / data readouts / `//` separators.
## Tabular numerals so counters don't jitter.
const FONT_MONO: FontFile = preload("res://assets/fonts/JetBrainsMono-Regular.ttf")
const FONT_MONO_BOLD: FontFile = preload("res://assets/fonts/JetBrainsMono-SemiBold.ttf")
const FONT_MONO_BLACK: FontFile = preload("res://assets/fonts/JetBrainsMono-Bold.ttf")

# ─── Font-size scale ───────────────────────────────────────────────────────
# Keep UI type to these sizes. Mobile at 360 width is dense; 8–11 is normal,
# 13–22 for hero numbers, 42 for the giant ladder trophy count.

const FS_TINY := 8
const FS_SMALL := 9
const FS_LABEL := 10
const FS_BODY := 11
const FS_BUTTON := 12
const FS_SECTION := 14
const FS_HERO := 18
const FS_BIG := 22
const FS_GIANT := 42

# ─── Spacing scale ─────────────────────────────────────────────────────────
# Keep layout rhythm to these values: 2 4 6 8 10 12 14 16 20 24 30

const SP_1 := 2
const SP_2 := 4
const SP_3 := 6
const SP_4 := 8
const SP_5 := 10
const SP_6 := 12
const SP_7 := 14
const SP_8 := 16
const SP_9 := 20
const SP_10 := 24
const SP_11 := 30

# ─── Letter-spacing recommendations (apply via theme_override_constants/outline_size etc.) ──
# Godot doesn't expose letter-spacing directly in Label theme overrides; use
# RichTextLabel for spaced labels, or bake spacing into the font resource.
# For simple labels, widen font tracking via the font's advance_multiplier.
