# Handoff: Vector PvP Tower Defense

## Overview

**Vector** is a mobile PvP tower defense game for two players. The core match takes place on a vertical, portrait-orientation map. Each player owns a **base** at their end of the map made of a grid of small squares (blue for the player, red for the opponent). Players bring 8 cards (out of a pool of ~50) into the match. Each card is a **vector-shape unit** with a distinct role. Players spend regenerating mana to deploy units on their half of the map. Units travel toward the enemy and fight per their role. Players can also place up to 3 buildable walls on their half as blocking geometry.

**Objective**: destroy all of the enemy's base squares before the 3-minute match timer expires. If neither player has destroyed the other's base when the timer hits zero, the match enters a 1-minute **overtime**. After overtime, the player with fewer remaining base squares loses (ties are a DRAW).

## About the Design Files

The files in this bundle are **design references created in HTML** (React + Babel running inline). They are prototypes showing the intended look, feel, and behavior of the match screen — not production code to copy directly.

Your task is to **recreate these designs in the target codebase's existing environment**. If the target is mobile (iOS / Android), use the platform's native game-capable rendering stack (SpriteKit / Jetpack Compose Canvas / a cross-platform engine like Unity or Godot). If building for web/React Native, lift the React component structure shown here as a starting point, but port the game loop to a proper fixed-timestep system driven by `requestAnimationFrame` or an engine's update callback.

The React prototype uses a single SVG canvas for all rendering. For a real shipping game you will almost certainly want a WebGL/Canvas2D (PixiJS, Phaser, Three.js) or engine-native (Unity, Godot, SpriteKit) renderer to handle the particle counts and simultaneous units well.

## Fidelity

**High-fidelity prototype.** Exact colors, sizes, typography, layout and animation feel are documented below and visible in the live mock. Pixel-fidelity to the prototype is the target. The only intentional placeholder is the deck-builder / menu / matchmaking surrounding screens — those are out of scope for this handoff; only the in-match experience is designed.

## Screens / Views

### 1. Match Screen (the only screen in this handoff)

**Purpose**: the core PvP combat experience. Two players battle by deploying vector-shape units to destroy each other's base squares.

**Canvas**: portrait, 360 × 700 game units (scaled to fill a phone's viewport). Shown inside an iOS device frame in the prototype for context; production should be fullscreen on-device.

**Phases**:
1. `build` — SETUP phase. Timer shows `—:—`. Player places up to 3 walls on their half. Cards are disabled. Enemy walls are auto-placed. A "▸ START MATCH" button appears bottom-right.
2. `playing` — 3:00 countdown. Cards enabled. Both players deploy units.
3. `overtime` — 1:00 countdown, timer colored red. Triggered automatically when `playing` reaches 0:00 with no winner yet.
4. `over` — overlay with VICTORY / DEFEAT / DRAW + square counts + REMATCH button.

**Layout (top → bottom)**:
- Top: iOS status bar (device chrome)
- ~60px from top: enemy HUD row (avatar, username, center timer+phase label, mana + squares readout)
- BASE_H = 60px strip at top: enemy base grid (18 cols × 3 rows = 54 red squares)
- Battlefield: grid background with radial vignette; dashed midline at y = 350
- BASE_H = 60px strip at bottom: player base grid (18 × 3 = 54 blue squares)
- Above cards: player HUD row (avatar, username, squares + mana bar)
- Bottom left: WALL toggle button (48×32, shows `x/3`)
- Bottom right (build phase only): ▸ START MATCH button
- Bottom: card hand — 8 cards in a row, each ~72×108, gap 6px

### Components

**Base Grid**
- 18 columns × 3 rows of small filled rectangles, ~18 × 14 units each, 1-unit gap
- Border radius: 0.8
- Player color: `#67e8f9` (cyan); enemy color: `#fb7185` (rose)
- Alive squares: 0.85 opacity filled + 0.5 stroke; dead squares: transparent fill + stroke at 0.15 opacity
- Group-level drop-shadow glow matching color (intensity controlled by `glow` tweak)

**Walls** (buildable — player places up to 3; enemy gets 3 auto-placed on rows y=150/220/290)
- Size: 110 × 8 units, border-radius 2
- HP: 80/80. Visual opacity tracks HP.
- Fill tinted to owner color; stroke + glow in owner color
- Units will bump into and damage opposing walls (wallbreak role ignores walls)

**Units** (deployed vector shapes)
- Rendered as vector outline glyphs at position (x,y) with:
  - Allegiance ring (very faint circle, r = size * 0.75)
  - Core shape, stroked in unit color, rotating for triangle/diamond/star/chevron
  - HP bar 20 units wide × 2.2 tall, appears below unit when damaged
- Drop-shadow glow in unit color

**Cards (hand)**
- 8 buttons in a row, pointer-events disabled during build phase
- Each card is 72 × 108, border-radius 10
- Background `rgba(12,14,18,0.75)` when idle, `<color>22` hex + matching border when selected + translate-y -8px + `0 0 0 2px <color>44, 0 -4px 20px <color>55` shadow
- Backdrop-blur 8px
- Layout top→bottom: role label (7px uppercase, card color, top-left) → shape icon (centered) → card name (9px, uppercase, 600 weight) → cost pip (8px dot + number)
- Dimmed to 0.45 opacity when on cooldown, unaffordable, or wall mode active
- Pulse animation on cost pip when hovering

**HUD — Top row (enemy)**
- Left: avatar badge (28×28, rounded 6, 1.5px enemy-color border, `◣` glyph inside) + two-line label "ENEMY / K.VOID_07"
- Center: "MATCH" / "SETUP" / "OVERTIME" caption (8px, letter-spacing 3, opacity 0.5) + timer "M:SS" (18px, 700 weight, letter-spacing 2; glows red during overtime)
- Right: "⚡ N/10" mana readout (10px) + "SQUARES NN/54" count (8px, opacity 0.6)

**HUD — Bottom row (player)**
- Left: avatar badge in blue + "YOU / VEC.BLUE"
- Right: "SQUARES NN/54" (top) and mana pip bar (10 pips, filled in yellow `#fbbf24`, glowing)

**Wall Toggle**
- Position: left: 12, bottom: 134
- 48×32, border-radius 8, font 9px letter-spacing 1.5
- Two lines: `▭` glyph + "WALL N/3"
- Highlighted when active (green-accent stroke + tinted fill)

**Start Match Button** (build phase only)
- Position: right: 12, bottom: 134
- "▸ START MATCH" padded button, cyan border + tint, 10px letter-spacing 2

**Deploy/Build Zone Indicator**
- When a card is selected or wall mode is active, draw a dashed-outline rectangle over the player's half (from y=370 to y=640) at 0.04 opacity fill

**Hints (mid-screen text)**
- Build phase, idle: "▭ PLACE UP TO 3 WALLS, THEN START"
- Wall mode active: "▭ TAP YOUR SIDE TO PLACE WALL (N/3)"
- Card selected: "▼ TAP YOUR SIDE TO DEPLOY ▼"

**Game Over Overlay**
- Fullscreen `rgba(0,0,0,0.82)` + backdrop-blur 4
- "MATCH ENDED" (10px caption, opacity 0.5)
- Result: "VICTORY" (blue glow), "DEFEAT" (red glow), or "DRAW" (white glow) — 44px 700 weight, letter-spacing 2
- Final count: "NN vs NN SQUARES"
- "▸ REMATCH" button (1px stroke button)

**Particle Field**
- Configurable density (default 60). Each particle: random x/y, r 0.3–1.5, drifts downward slowly, wraps around screen edges
- Low opacity white specks

**FX (explosions)**
- Expanding ring (stroke-only, fades over 500ms) + inner filled circle at 30% opacity
- Drop-shadow glow colored to source
- Max 80 live FX kept in a ring buffer

## Cards / Unit Roles

8 cards live in the hand. Each has `role` governing AI behavior. Full stats table:

| id      | name    | shape    | role        | cost | hp | dmg | speed | range | fireRate | color     | desc                                      |
|---------|---------|----------|-------------|------|----|-----|-------|-------|----------|-----------|-------------------------------------------|
| dart    | Dart    | triangle | shooter     | 2    | 20 | 6   | 50    | 140   | 0.6      | `#7dd3fc` | Shoots piercing bolts at enemies.         |
| bomb    | Bomb    | square   | melee       | 4    | 50 | 40  | 35    | 18    | 0        | `#fb7185` | Walks up and detonates. AoE.              |
| spiral  | Spiral  | spiral   | wallbreak   | 3    | 35 | 18  | 30    | 24    | 0        | `#c084fc` | Bores through walls. Ignores units.       |
| burst   | Burst   | star     | interceptor | 3    | 25 | 14  | 70    | 40    | 0        | `#fbbf24` | Chases and rams enemies.                  |
| lance   | Lance   | diamond  | sniper      | 5    | 18 | 28  | 0     | 380   | 1.4      | `#67e8f9` | Stationary. Long-range base shot.         |
| orb     | Orb     | circle   | shooter     | 2    | 30 | 4   | 40    | 90    | 0.4      | `#86efac` | Cheap spam. Fast fire.                    |
| chevron | Chevron | chevron  | swarm       | 4    | 12 | 5   | 60    | 70    | 0.5      | `#f472b6` | Spawns 3 small scouts.                    |
| pulse   | Pulse   | ring     | interceptor | 5    | 45 | 20  | 45    | 50    | 0        | `#a78bfa` | Hunts enemies. Shockwave on kill.         |

### AI Role Rules

- **shooter**: target = nearest enemy unit (if in range+40) else a random alive base square. Advance toward target; stop when within `range`. Fire projectiles every `fireRate` seconds. Walls block movement + take damage from contact.
- **melee**: target like shooter. Move until contact (`range` ≈ body size). On first hit, deal `dmg` + self-destruct + AoE damage (`0.6 * dmg` to enemies within 40 units). Walls block.
- **wallbreak**: target = nearest opposing wall; else march to base. Ignores enemy units. Walls do not block (unit passes through while damaging). Contact damage over time (`dmg * dt * 3`).
- **interceptor**: target = nearest enemy unit only. Ignores base unless no enemies alive. Pulse shape spawns a 60-unit radius shockwave on death that damages enemies for 10.
- **sniper**: does not move. Fires projectiles at a central base square every `fireRate` seconds.
- **swarm**: on deploy, replaced by 3 small shooters (stats: hp=12, dmg=5, range=70, speed=60).

## Interactions & Behavior

### Input
- **Tap card** → select card (or deselect if already selected). Cooldown dims card for 400ms after deploy. Cost must be payable.
- **Tap map on your half** (y between 370 and 640) → deploys selected unit at that point, deducts mana cost.
- **Tap WALL toggle** → enter wall-placement mode (mutually exclusive with card selection).
- **Tap map in wall mode** → places a wall centered horizontally on the tap point (clamped so full width fits on screen). Max 3 walls per player.
- **Tap ▸ START MATCH** (build phase) → transitions to `playing` phase and starts 3:00 countdown.
- **Tap ▸ REMATCH** (game over) → resets state and re-enters build phase.

### Game Loop

Runs via `requestAnimationFrame` during `playing` / `overtime`. Delta-time clamped to 50ms. Each tick:

1. For each alive unit: advance age, decrement fire cooldown, resolve role-specific target + movement + attack.
2. For each projectile: step position, decay trail, check collisions (wall → unit → base).
3. Cleanup: remove dead walls, trigger pulse-death shockwaves, remove dead units.

### Projectile physics
- Speed: 260 units/sec
- Trail: last 6 positions
- Collide in order: walls (any side) → opposing units (within unit `size * 0.8`) → opposing base (by y-coordinate)

### Base damage
- On a successful base hit, find nearest alive square to impact point
- Kill `max(1, round(dmg / 18))` nearest alive squares
- Spawn a big FX ring at impact

### Mana
- Both sides start at 6
- Regenerate +1/sec, cap 10
- Cards consume their `cost` on deploy

### Enemy AI
- Every 2000ms: pick a random affordable card, spawn it at a random point in enemy half (y: 80–330, x: 60–300). Reset mana.
- Builds 3 walls at match start on rows y=150/220/290 at random x.

### Timer
- `playing` starts at 180 seconds. On reaching 0 → transitions to `overtime` at 60s.
- `overtime` 0 → tiebreaker: fewer alive squares = lose; tie = DRAW.
- Base destruction at any time (either side reaching 0 squares) instantly ends the match.

## State Management

**Top-level match state** (recommended interfaces):

```ts
type Phase = 'build' | 'playing' | 'overtime' | 'over';
type Side = 'you' | 'enemy';

interface Unit {
  id: number; cardId: string; side: Side;
  x: number; y: number;
  hp: number; maxHp: number;
  role: 'shooter'|'melee'|'wallbreak'|'interceptor'|'sniper'|'swarm';
  speed: number; range: number; dmg: number; fireRate: number;
  size: number; color: string; shape: string;
  fireCd: number; age: number;
}
interface Wall {
  id: string; x: number; y: number; w: number; h: number;
  side: Side; hp: number; maxHp: number;
}
interface BaseSquare {
  id: string; x: number; y: number; w: number; h: number;
  alive: boolean; side: Side;
}
interface Projectile {
  id: number; side: Side;
  x: number; y: number; vx: number; vy: number;
  dmg: number; color: string; life: number;
  trail: { x: number; y: number }[];
}
```

Mutated every frame: `units`, `projectiles`, `walls`, `playerBase`, `enemyBase`, `fx`.
Per-second: `timeLeft`, `mana`, `enemyMana`.
On demand: `phase`, `selectedCard`, `cardCooldowns`, `wallMode`, `gameOver`.

## Design Tokens

### Colors

```
--bg:           #06080b  (deep near-black with subtle blue)
--grid:         #ffffff  (0.5 opacity on 24px grid)
--text:         #e5e7eb
--divider:      rgba(255,255,255,0.2)
--particle:     #ffffff
--card-bg:      rgba(12,14,18,0.75)
--card-border:  rgba(255,255,255,0.12)

--wall-you:     #67e8f9  (player blue)
--wall-enemy:   #fb7185  (enemy red)
--wall-accent:  #86efac  (build-mode green)
--mana:         #fbbf24  (amber)

--unit-dart:    #7dd3fc
--unit-bomb:    #fb7185
--unit-spiral:  #c084fc
--unit-burst:   #fbbf24
--unit-lance:   #67e8f9
--unit-orb:     #86efac
--unit-chevron: #f472b6
--unit-pulse:   #a78bfa
```

The prototype also includes `neon` and `mono` aesthetic variants — see `getPalette()` in `match-screen.jsx`.

### Typography

- Family: `ui-monospace, "SF Mono", Menlo, monospace` (system monospace)
- Sizes: 7, 8, 9, 10, 11, 12, 13, 18, 44 (headline)
- Letter-spacing: small caption `3`, body caps `1.5–2`, pill labels `1`
- Weights: 400 body, 600 labels, 700 headlines

### Spacing scale
- 2, 4, 6, 8, 10, 12, 16, 20, 24

### Border radius
- 1 (hp bar), 2 (wall), 6 (small chip), 8 (button), 10 (card), 24 (pill button)

### Shadows / Glow
- Default glow: `drop-shadow(0 0 <glow>px <color>)` layered 1–3 times
- Card selected: `0 0 0 2px <color>44, 0 -4px 20px <color>55`
- Overtime timer: `0 0 10px <wall-enemy>`

### Grid / Map constants
```
MAP_W = 360        (game units)
MAP_H = 700
BASE_H = 60
MIDLINE = 350
BASE_COLS = 18, BASE_ROWS = 3 → 54 squares per base
WALL_W = 110, WALL_H = 8
MAX_WALLS_PER_PLAYER = 3
MATCH_SECONDS = 180
OVERTIME_SECONDS = 60
MANA_MAX = 10, MANA_REGEN = 1/sec
PROJECTILE_SPEED = 260 units/sec
```

## Assets

**None.** All visuals are drawn procedurally with SVG shapes. No bitmaps, fonts, or external assets needed. Use the platform's system monospace font.

The original hand-drawn sketch is included as `original-sketch.png` for reference — red bars = bases (now grids of squares), green lines = buildable walls, colored shapes = example projectiles/units.

## Out of Scope (future handoffs)

- Main menu / matchmaking / player profile
- **Deck builder**: 8-of-~50 selection from card collection
- **Upgrades**: abundant mid-match upgrades — draft every X seconds, currency shop, or passive XP (undecided)
- Post-match rewards / XP / progression
- Real-time networking (the prototype uses a local enemy bot)
- Sound + haptics

## Files in This Bundle

- `README.md` — this document
- `Vector PvP Tower Defense.html` — entry point for the live prototype
- `match-screen.jsx` — game loop, unit AI, rendering, HUD, wall placement
- `game-data.jsx` — card definitions + shape SVG renderer + role labels
- `ios-frame.jsx` — iOS device chrome (cosmetic, not part of the game)
- `original-sketch.png` — the hand-drawn design reference

To run locally: open the HTML file directly in a modern browser (React + Babel load from CDN).
