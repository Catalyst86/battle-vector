# Vector TD — VOLLEY MODE

*Design doc v0.1. Working name; rename freely.*

Alternates to consider if VOLLEY doesn't land: **DESCENT**, **CASCADE**, **BARRAGE**, **RAIN**, **OVERWATCH**.

---

## 1. Concept (one line)

> Two players share a descending wave of squares. Each has an auto-targeting gun + a deck of units (siege / interceptor) and spells. Highest kills at the buzzer (or first to a target count) wins.

The existing 1V1 / 2V2 mode stays in the game. Volley is a second battle type on the main dock, not a replacement.

---

## 2. Field layout

Portrait 360 × 780. Vertical field, two guns facing each other across the midline — same geometry as current matches, but the objective inside changes.

```
┌──────────────────────────────┐
│   [P2 GUN BAY]    (y ≈ 60)    │   ← ENEMY's auto-gun, visible top-center
│                              │
│   descent zone — P2's side   │
│   squares moving ↑ toward P2 │
│                              │
├──────── midline ─────────────│   ← squares SPAWN here, half go up half down
│                              │
│   descent zone — P1's side   │
│   squares moving ↓ toward P1 │
│                              │
│   [P1 GUN BAY]    (y ≈ 720)   │   ← YOUR auto-gun, visible bottom-center
├──────────────────────────────┤
│   HAND STRIP (cards + spells)│
└──────────────────────────────┘
```

Shared wave: any square is fair game for either player's gun. Your gun prioritizes squares **heading toward you** (squares bound for the opponent are lower priority but still hittable).

Cards still walk the existing pseudo-3D trapezoid. Direction depends on card type (next section).

---

## 3. Units + Spells + Guns

### 3a. Card deck — same 8 slots, three card *types*

The Collection / Deck / Deck Builder UI all keep working. Cards gain a new `kind` field:

| Kind | Behaviour |
|---|---|
| **SIEGE** | Walks across field toward the enemy's gun. On arrival, does damage-over-time + can stun. Existing SHOOTER / MELEE / WALLBREAK / SWARM / INTERCEPTOR / SNIPER / SNIPER all retag as SIEGE for v0. |
| **INTERCEPTOR** | Walks *into* the descent zone and hunts squares. Doesn't cross the midline. On arrival it parks and shoots at whatever descending square is closest. New behaviour. |
| **SPELL** | Instant-cast effect on your own gun or the opposing wave. No walking unit spawns. Examples below. |

Deck composition is free — 0 spells + 8 siege all the way to 8 spells + 0 units. Same mana economy as current (cost pip). Hand UI unchanged.

### 3b. Spells — launch list

| Spell | Effect | Cost (draft) |
|---|---|---|
| **COOLANT** | Instantly vents 50% of gun heat | 2 |
| **OVERCLOCK** | Gun fire rate × 2 for 4 seconds | 4 |
| **SPREAD** | Next 10 gun shots fire a 3-way fan | 3 |
| **FOCUS** | Next 5 gun shots pierce through all squares in line | 3 |
| **SIPHON** | For 3 seconds, every gun kill also damages enemy's gun | 5 |
| **SURGE** | Enemy gun takes 1s stun + 25% heat injection | 4 |

### 3c. Gun mechanics

- **Auto-target**: picks nearest square on your side moving toward you. Ties broken by lowest HP for clean kills.
- **Fire rate**: base 2 shots/sec. Modified by upgrades + spells.
- **Heat**: every shot adds +5 heat. Max 100. At 100, gun stops firing until heat drops below 60. Passive cooldown −15/sec when not firing.
- **HP + stun**: gun has 100 HP. Siege unit arriving does DOT (1 HP/sec while attached). At 0 HP, gun enters 2s reboot — can't fire. Stun via opposing SURGE spell: 1s freeze.
- **Pre-match loadout — 3 upgrade modules**. Selected in the deploy briefing before launch. Each module is a chosen tree level across all your owned modules.

### 3d. Gun upgrade modules (pre-match loadout)

You pick 3 modules from an unlockable pool. Module stats stack additively (e.g. two damage modules = full bonus).

| Module | Max tier | Effect |
|---|---|---|
| **BARREL** | 5 | +15% damage per tier |
| **COOLING** | 5 | −10% heat per shot per tier |
| **TRIGGER** | 5 | +12% fire rate per tier |
| **AMMO** | 5 | Splash radius +4px / tier |
| **SCOPE** | 5 | Range +20% / tier (reaches earlier into descent zone) |
| **PLATING** | 5 | +20 gun HP per tier |
| **DAMPER** | 5 | −15% stun duration per tier |
| **REPAIR** | 5 | +0.5 HP/sec auto-regen per tier |

Module progression is per-module XP, earned from match kills. (Could map existing card XP system here — cheap reuse.)

### 3e. Cosmetics

Gun visual swaps based on equipped modules — scope module adds a barrel extension, plating adds side shields, etc. (Vector primitives, drawn in code, no new assets needed.) This is the "many many looks" axis the player asked for.

---

## 4. Squares (the enemies)

Spawned at the midline, every ~0.3s during MATCH phase. Spawn biased: 50% heading to P1, 50% to P2.

### Square types

| Type | HP | Speed | Score | Notes |
|---|---|---|---|---|
| **Standard** | 4 | 1.0× | +1 | Small cyan square. ~80% of spawns. |
| **Fast** | 2 | 1.8× | +2 | Thin outlined square. ~10%. |
| **Armored** | 12 | 0.7× | +3 | Thick-bordered square. ~6%. |
| **Elite** | 40 | 0.5× | +5 | Glowing square with corner brackets. ~3%. Forgiving HP gates. |
| **Boss** | 120 | 0.3× | +10 | Massive, pulsing, hard to kill inside the 2-min window. ~1%. Big risk — if you can't drop it before it lands, you ate that DPS for nothing. |

No damage-on-reach — squares just descend. Answer 3 says: if a square reaches the bottom (past P1's gun), it's credited to the opposing player as a kill. This creates "defend your lane" pressure without a health-bar fail state.

---

## 5. Match flow

Phases:

1. **LOADOUT** — new pre-match screen: pick 3 of your unlocked gun modules. (Replaces walls-placement; no walls in Volley.)
2. **MATCH** — 2 minutes. Squares spawn, guns fire, cards deploy, spells cast.
3. **OVERTIME** — if scores are tied at 2:00, first player to destroy 10 more squares wins. Hard cap at +60s; after that, higher-score at 3:00 wins; final tie = DRAW.
4. **OVER** — game-over screen shows kill counts per player, bonus breakdown (standard / fast / armored / elite / boss), spell casts, gun HP remaining.

**Win condition:** first to **300 kills** OR highest kill count at 2:00. (300 is a first guess — tune by playtesting; might be 400–500 depending on spawn rate.)

---

## 6. New systems required

| System | Est. effort |
|---|---|
| New `match_volley.tscn` + `match_volley.gd` — phase loop, timer, scoring | 2h |
| `SquareSpawner` node + `Square` unit class (pool-friendly) | 2h |
| `Gun` node — auto-aim, fire, heat, HP, stun, module stacking | 3h |
| `LoadoutScreen` — 3-module picker modal (replaces wall-placement) | 2h |
| New CardData fields: `kind` (SIEGE / INTERCEPTOR / SPELL), `spell_effect` | 1h |
| Spell system — cast handlers for the 6 launch spells | 2h |
| Interceptor behaviour (stops at midline, hunts descending squares) | 1h |
| New game-over layout — kill breakdown + gun HP remaining | 1h |
| Gun upgrade module data + persistence on PlayerProfile | 1h |
| Dock entry — new "VOLLEY" button on main menu alongside 1V1 / 2V2 | 1h |
| Tutorial variant for Volley (minimal) | 2h |
| Balance iteration (the real time sink) | 4h+ |

**Total rough estimate: ~22 hours of focused work** for a playable prototype, not counting balance passes.

---

## 7. Existing systems changes

| File | Change |
|---|---|
| `card_data.gd` | Add `kind` enum (SIEGE / INTERCEPTOR / SPELL), `spell_id` for spells |
| `unit.gd` | Branch on `kind` — siege keeps current behaviour; interceptor stops at midline and targets squares |
| `player_profile.gd` | New dictionary for gun module tiers |
| `main_menu.gd` bottom dock | Add third primary button for VOLLEY |
| `match_confirm.gd` | Variant shows module loadout picker + opponent's module loadout preview when available |

Existing cards split into:
- Keep all 29 cards as SIEGE (they already walk + attack, just retarget the enemy's gun instead of the base grid).
- Add ~6 INTERCEPTOR cards (could reuse existing art — e.g. PULSE, ORB, BURST make sense as defensive turrets).
- Add ~6 SPELL cards with new shapes/colors.

---

## 8. MVP scope (what ships first)

For the first playable prototype, skip these:
- Gun cosmetic variations (ship with one default gun visual).
- Spell variety (ship with just COOLANT + OVERCLOCK).
- Advanced square types (ship with Standard + Armored + Elite; skip Fast and Boss).
- Gun upgrade trees (ship with 3 of the 8 modules — BARREL / COOLING / TRIGGER).
- PvP bot variety (reuse current arena bot personas).

Post-MVP, layer in: more spells → more modules → more square types → gun cosmetics → tutorial.

---

## 9. Open design questions

- **Name.** VOLLEY vs DESCENT vs CASCADE vs your pick.
- **Spawn rate.** Start with 0.3s/spawn and tune up/down based on how chaotic matches feel.
- **Card kind distribution in current deck** — for launch, any existing card is SIEGE by default. Do we want to immediately reclassify some as INTERCEPTORS (PULSE, ORB feel like defenders) or wait until we've tested?
- **Are gun modules their own shop tab? Or do we extend Collection to show both cards + modules?**
- **Spell UI** — same card tile as units, just with a different visual treatment (e.g. lightning-bolt glyph overlay)? Or different hand slot?

---

## 10. Recommended build order

1. **Draft & approve this doc** ← we are here
2. Ship a new `match_volley.tscn` with the bare loop: one gun (no upgrades), standard squares only, score-at-2min. Confirm the **core loop is fun** before adding depth.
3. Add interceptor + spell card kinds. Two spells (COOLANT + OVERCLOCK). Retune spawn rate.
4. Gun module system + LOADOUT phase.
5. More square types + elite HP gates.
6. More spells + modules to fill out the upgrade axis.
7. Tutorial + polish.

---

*End of doc.*
