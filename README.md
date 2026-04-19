# Vector — PvP Tower Defense

A mobile-first PvP tower defense game built in **Godot 4.6.2**, inspired by
Clash Royale + Vector TD. Two players face off on a vertical, pseudo-3D
playfield: deploy vector-shape units, build walls, manage mana, and crack the
opponent's base grid before the clock runs out.

> **Status:** playable end-to-end against bot stand-ins. Real-time
> networking for human-vs-human 1v1/2v2 is the next major milestone.

## Highlights

- **28 cards, 8 roles** — shooter / melee / wallbreak / interceptor / sniper /
  swarm / healer / buffer. All stat-driven Resources — edit a card by opening
  its `.tres` in the Inspector.
- **Pseudo-3D playfield** — trapezoidal perspective projection. Units scale
  and shift as they advance, without a real 3D pipeline. Works on mobile
  `gl_compatibility`.
- **Match loop** — BUILD phase with auto-start countdown → 3:00 match →
  1:00 overtime → VICTORY / DEFEAT / DRAW with rewards. Walls block units
  and projectiles (wallbreak + phases-walls units drill through).
- **Meta-game** — card levels 1–10 (gold-funded), player XP + levels 1–15,
  card unlocks per player level, trophy ladder across 8 arenas, win/loss
  tracking, daily free chest, tutorial with visual coach overlay.
- **Polish** — multi-pass glow on every shape, death-burst particles, screen
  shake on impacts, hit-flash on damage, radial vignette, drifting background
  particles.

## Run it

1. Install [Godot 4.6.2 stable](https://godotengine.org/download/archive/4.6.2-stable/).
2. Launch the editor → **Import** → pick `vector/project.godot`.
3. Press **F5** to run. The game boots into the home screen.

If the editor shows script-parse errors after you pull new changes, close the
editor completely and reopen the project — Godot caches autoloads and class
names in `.godot/global_script_class_cache.cfg` and sometimes holds stale
state until a full restart.

## Folder layout

```
vector/                          Godot 4.6.2 project root
├── autoload/                    Global singletons (Pseudo3D, PlayerProfile, ...)
├── data/                        .tres Resource instances (cards, configs, modes)
├── resources/                   Resource class scripts (CardData, GameMode, ...)
├── scenes/                      .tscn scenes (match, menus, ui)
├── scripts/                     GDScript logic by feature
├── shaders/                     .gdshader files (vignette, ...)
└── project.godot                Engine config

design_handoff_vector_pvp_tower_defense/
                                 Original design reference (React/SVG prototype)
```

See `vector/README.md` for project-specific editing notes and tunable knobs.

## What's next

- Networking (ENet or managed service) for real 1v1 / 2v2
- Audio — music loop + ~10 SFX
- Mobile export presets (Android + iOS) + on-device testing
- Real settings screen (volume, haptics, player name)
- Shop expansion (gem currency, card deals)
- Balance audit after playtest data

## License

TBD.
