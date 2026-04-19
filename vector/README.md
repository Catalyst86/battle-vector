# Vector — PvP Tower Defense (Godot 4.6.2)

Clash-Royale + Vector-TD-inspired mobile PvP tower defense. Design reference
lives in `../design_handoff_vector_pvp_tower_defense/`.

## Open the project

1. Launch `C:\Users\danie\Desktop\Godot_v4.6.2-stable_win64.exe`
2. **Import** → browse to this folder → pick `project.godot`
3. Press F5 to run (or the ▶ button).

## Where to edit things (no code needed)

| What to tweak | Where |
|---|---|
| Card stats (cost/hp/damage/speed/range) | `data/cards/<card>.tres` |
| Match timing, mana regen, map size | `data/config/game_config.tres` |
| **Pseudo-3D perspective strength** | `data/config/game_config.tres` → `far_scale`, `far_width_pinch`, `far_y_lift` |
| Deploy "drop" animation | `data/config/game_config.tres` → `deploy_pop_distance`, `deploy_pop_duration` |
| All colors (bg, unit, walls, mana) | `autoload/palette.gd` |
| Menu layout / buttons | `scenes/menus/*.tscn` (edit visually) |
| Match HUD layout | `scenes/match/match.tscn` (edit visually) |

The Inspector-editable Resources mean you can hot-swap an entire "profile"
(e.g. a casual vs hardcore balance sheet) just by pointing `game_config_loader.gd`
at a different `.tres`.

## Folder layout

```
project.godot              Mobile portrait, 360x780 design space.
icon.svg                   Vector app icon.
autoload/
  game_config_loader.gd    Loads GameConfig resource on boot.
  palette.gd               All color tokens.
  pseudo_3d.gd             Perspective projection (project/unproject/scale).
  router.gd                Scene transitions with fade.
resources/
  card_data.gd             @tool CardData Resource (stats + shape + role).
  game_config.gd           @tool GameConfig Resource (match tunables).
data/
  cards/*.tres             The 8 starter cards — edit freely.
  config/game_config.tres  The active match config.
scenes/
  main.tscn                Boot → routes to main menu.
  menus/
    main_menu.tscn         PLAY / DECK / SETTINGS.
    deck_builder.tscn      Placeholder for 8-of-50 picker.
    settings.tscn          Placeholder for live tweakers.
  match/
    match.tscn             Match scene root.
    playfield.tscn         (optional reusable playfield)
    unit.tscn              Single unit instance.
scripts/
  main.gd                  Boot routing.
  menus/                   One script per menu.
  match/                   match.gd, playfield.gd, base_grid.gd, unit.gd, shape_renderer.gd
```

## Current state (v0.1)

- ✅ Menu nav: Main → Match → back
- ✅ Pseudo-3D playfield: trapezoidal surface, grid converges toward far edge
- ✅ Base grids: 18×3 on both sides, enemy side shrinks via perspective
- ✅ Tap-to-deploy: tapping your half spawns a Dart that "drops" onto the plane
- ✅ Unit walks upward; scales smaller as it recedes toward enemy base

## Next up (not yet implemented)

- Mana regen + cost gating + cooldowns
- Card hand UI (8 cards at bottom of match scene)
- Remaining 5 AI roles (melee / wallbreak / interceptor / sniper / swarm)
- Projectiles
- Wall placement (build phase)
- Match timer + overtime + win/lose overlay
- Enemy bot AI
- Deck builder screen
- Networking
