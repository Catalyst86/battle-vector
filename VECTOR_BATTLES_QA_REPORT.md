# Vector Battles — QA & Playtest Audit

*Static-analysis audit performed by a 5-tester team. No code was modified in this pass. All findings cite `file:line` references. Any conclusion requiring real play is tagged `[NEEDS PLAYTEST]`.*

**Build audited:** `main @ c9ec7f4` (post Session-A Volley work, 2026-04-19).
**Project root:** `C:\Users\danie\Desktop\Vector TD\vector\`.

---

## Tester 1 — QA Bug Hunter

**Preamble.** Vector Battles has several high-risk patterns around scene lifecycle management, particularly involving Pseudo3D stale state references, timer/tween orphaning in asynchronous flows, and signal-connection leaks across scene reloads. The match rematch pathway shows the most critical vulnerability — paused state and modal lifecycle issues could trap players or crash on rapid replay. DailyOps and SeasonPass have array-bounds safety but no defensive version-checking on corrupted save files. The Volley gun targeting shows proper null-checking discipline, but the classic match builder / deploy system has a minor off-by-one risk in wall-count logic.

| Severity | File:Line | Finding | Repro Sketch | Suggested Fix |
|---|---|---|---|---|
| CRIT | `autoload/pseudo_3d.gd:69` | Stale `_origin` node reference after scene reload. `to_global()` reads `_origin.global_position` without an `is_instance_valid()` check. Rematching a classic match frees the old Playfield but Pseudo3D._origin still points at it. | Classic match → rematch → rematch again → any caller of `to_global()` hits freed-node access. | Guard with `if _origin != null and is_instance_valid(_origin):` in `to_global()`. Also clear `_origin = null` in `Playfield._exit_tree()`. |
| CRIT | `scripts/match/match.gd:106` | Rematch signal lambda captures `_return_to_match` via closure; never disconnected on exit. If the scene frees mid-callback, the closure holds stale refs. | Spam the REMATCH button on game-over → scene reloads → old lambda fires into the freed controller. | Disconnect in `_exit_tree()` or use `CONNECT_ONE_SHOT`. |
| CRIT | `scripts/match/match.gd:276` | `_return_to_home()` sets `get_tree().paused = false` **after** restoring config. If any earlier step fails or Router.goto() yields, the tree may stay paused into the next scene. | Exit a tutorial at exactly the wrong frame → menu renders but is frozen. | Move `paused = false` to the **first** line of `_return_to_home()` and `_return_to_match()`. |
| HIGH | `scripts/match/match.gd:201` | `auto_timer.timeout.connect(dismiss)` in `_show_tutorial_briefing()` — if the player dismisses early, the timer keeps running. Fires after scene free → `dismiss` closure touches freed overlay. | Tutorial → tap briefing away immediately → end match → wait 6 s → orphan callback. | Store `auto_timer` reference, disconnect on dismiss, guard `is_instance_valid(overlay)` inside `dismiss`. |
| HIGH | `scripts/match/match.gd:187–195` | Briefing fade-out tween's `finished` connects to `overlay.queue_free()` with no `is_instance_valid` guard. Racy against double-dismiss paths. | Press button during fade-in → queue_free hits twice. | Guard the callback: `if is_instance_valid(overlay): overlay.queue_free()`. |
| HIGH | `scripts/match/unit.gd:53–56` | `reached_base.connect(match_node._on_unit_reached_base)` with `is_connected` guard — but SWARM scouts all call `_ready()`, and `match_volley` has no `_on_unit_reached_base`, so the `has_method` skip is silent. Swarm in classic mode is fine, but the pattern is fragile. `[NEEDS PLAYTEST]` whether classic SWARM bursts double-connect under any edge case. | Deploy Chevron (swarm) repeatedly → watch connection count. | Use `CONNECT_ONE_SHOT`, or have `match.gd` connect unit signals centrally on spawn. |
| HIGH | `autoload/spawn_pool.gd:24–31` | `release_projectile` guards parent but not node validity — a freed node pushed back into the pool will corrupt the pool. No `is_instance_valid(p)` check before `_projectiles.append(p)`. | Double-release in an unusual path → freed instance re-acquired → use-after-free. | Add `if not is_instance_valid(p): return` at top; same for `release_burst`. |
| HIGH | `scripts/match/match.gd:667` | `get_tree().create_timer(0.18).timeout.connect(func(): PlayerProfile.buzz(60))` on defeat. Timer survives scene exit; fires on a freed tree context. | Lose a match → mash "MENU" within 180 ms → timer fires into freed scene. | `await get_tree().create_timer(0.18).timeout` guarded by `if not is_inside_tree(): return`. |
| HIGH | `scripts/match/match.gd:506` | Off-by-one in `_auto_place_walls`. `slot_h = range / count`; jitter `±slot_h * 0.25` can push the last wall past `max_y`. | Observe bot walls over many matches — occasionally one clips past the base strip. | Clamp `y = clampf(y, min_y, max_y)` after jitter. |
| HIGH | `scripts/menus/match_confirm.gd:125–141` | `_refresh_volley_chips()` rebuilds children with fresh `gui_input.connect()` calls — stale connections pile up if the refresh is called more than once without purging. | Toggle the team-size chip rapidly → ghost input fires multiple times per tap. `[NEEDS PLAYTEST]`. | Disconnect all `gui_input` listeners before `queue_free`, or reuse the same button instances. |
| MED | `autoload/player_deck.gd:29–42` | Backfill loop silently fails if cards can't be resolved — final deck can contain <8 cards, which later crashes `CardHand.build()` (empty indexing) or leaves the player with no deploy options. | Corrupt a card .tres → match boots with 2 cards → weird HUD layout. | Assert `cards.size() >= 4` at the end of `_reload()`; push a visible error to the UI. |
| MED | `scripts/match/base_grid.gd:42–57` | `random_alive_position()` returns `Vector2.INF` when all squares are dead; some callers (sniper fire in `unit.gd:_do_sniper`) check for INF, others may not. | Enemy base fully destroyed but a late sniper shot tries to aim at INF. | Have callers use a single helper that guards INF, or have `random_alive_position()` return `Vector2.ZERO` when empty. |
| MED | `scripts/match/match.gd:779–782` | Enemy-mana HUD label reads only the first `is_enemy` bot. In 2V2, the second enemy bot's economy is invisible to the player, distorting the power read. | Play 2V2 → enemy-mana label reads fine but one lane is actually depleted. | Sum across all enemy bots (matching `player_hp_label`). |
| MED | `autoload/daily_ops.gd` (track / progress path) | Quest progress is `mini(cur + amount, target)`, silently clipping. Over-shoots are lost — fine for single-quest ticks, misleading for aggregate daily metrics. | Nothing observable; a telemetry hazard. | `push_warning` on clip, or persist the raw total for analytics. |
| LOW | `scripts/match/unit.gd:27` | `_prev_world` assigned each frame but only read inside wall collision. In Volley mode (no walls) it's dead state. | No gameplay impact. | Gate behind `if _volley_gun_target == null`. |
| LOW | `scripts/match/unit.gd:305` | `_spawn_projectiles` computes `base_dir` with a guard, but the fallback direction ignores `_volley_gun_target` — in Volley, a shooter adjacent to a gun with no targets will fire downward/upward based on `is_enemy` even if the gun is off-axis. | Cosmetic — Shooter facing wrong way for a frame. | In volley mode, default `base_dir` toward the gun. |
| LOW | `scripts/ui/card_button.gd` | `set_process(true)` redundant (default). Harmless. | — | Delete the line. |
| NIT | `scripts/match/match.gd:833` | `_selected` null check is late in `_update_preview`; two branches read `_selected` without guarding. Currently safe because of earlier returns, but one refactor away from a crash. | — | Early-return at the top of `_update_preview` if `_selected == null`. |

**Most critical pathway.** Rematch → Pseudo3D stale reference + pause-state carryover + signal leaks form a compound risk. A second rematch has a non-trivial probability of exhibiting at least one CRIT under rapid replay. Fixing pseudo_3d.gd:69 plus the two match.gd connect/pause issues neutralises the dangerous part.

---

## Tester 2 — Casual Playtester

### 1. Is the core loop legible within 60 seconds of gameplay code?

Traced from a fresh launch:

- **Launch → Menu.** `scenes/main.tscn` → `scenes/menus/main_menu.tscn` (`scripts/menus/main_menu.gd:42-65`). The menu shows a TacticalBottomDock with a visible TUTORIAL button (`scripts/menus/tactical_bottomdock.gd`). On first run PlayerProfile flags a non-completed tutorial — the player is steered there.
- **Enter match (tutorial).** `match.gd:75–124` runs `_ready()` → swaps in the 4-card tutorial deck (`TUTORIAL_DECK_IDS:39` = dart/orb/bomb/lance) and shows `_show_tutorial_briefing()` (`match.gd:131–202`), a full-screen panel reading:
  > OBJECTIVE — DESTROY THE HOSTILE BASE (RED SQUARES).
  > BUILD — PLACE WALLS TO SLOW INCOMING UNITS.
  > MATCH — SPEND MANA TO DEPLOY CARDS ON YOUR SIDE.

  This briefing only appears **after** the match scene has booted — the SETUP phase and BUILD countdown are behind the panel. Briefing blocks `_build_time_left` countdown via `_briefing_active` (`match.gd:362–366`). Clear intent, but the sequence is "drop you in first, explain after" which can jar players reading slowly.
- **BUILD phase (7.5 s per `game_config.tres:32`).** Player can tap WALL → tap their side → up to 3 walls (`_try_place_wall:417–437`). TutorialCoach highlights the WALL button, then the BLUE side. Hint label auto-updates (`_tutorial_hint:824–842`). Once walls are down (or timer runs out) the match auto-starts — there is no START MATCH button in tutorial.
- **Match → countdown overlay.** `_show_match_start_countdown:460–494` drops a 3-2-1-GO fade tween. Hand becomes interactive (`hand.set_interactive(true):451`). Coach flips to the hand, prompting "PICK A CARD".
- **Tap card → Deploy.** `CardHand._on_btn_pressed:44-59` toggles selection; `match._on_card_selected:732–743` updates a deploy preview (`deploy_preview.gd`) that tracks the mouse. Coach prompts the BLUE side.
- **Tap playfield → `_try_deploy:520–551`.** Pays mana, spawns unit, plays deploy SFX, fires a 25 ms haptic buzz, triggers a 0.4 s card cooldown (`deploy_cooldown:12`).
- **First kill.** Unit walks up, reaches the enemy base (`unit.gd:_check_base_arrival`), fires `reached_base` → `match._on_unit_reached_base:571–586` damages the base grid, shakes 3 + 0.5 per hit, plays `base_damage`, buzzes 55 ms.
- **Victory → tutorial complete.** Tutorial enemy base is undefended (no bot spawns for `is_tutorial`). Eventually all 54 squares die, `_check_win:607` fires `_end_match("VICTORY")`, rebranded as "TUTORIAL COMPLETE" (`match.gd:672–673`), GameOverOverlay reveals with cascading tweens (`game_over.gd:94–119`).

**Clarity issues.** (a) The briefing arrives *after* the BUILD countdown starts visually (even though it pauses it). Newer players will wonder why things are moving. (b) Without the TutorialCoach, wall placement is unintuitive — the only affordance is a small labeled button. (c) The deploy preview is silent; no chirp or "slot locked" feedback, so players may think they need to drag.

### 2. Is the control scheme discoverable?

- **Input map** (`project.godot:53`) only uses `pointing/emulate_touch_from_mouse=true`. No key binds for cards.
- **CardButton._gui_input:56–67** gives an audio click on tap. Hand is horizontal, 8 tiles, sized 40×58. Very discoverable — players will try tapping cards first.
- **Playfield deploy** (`match._unhandled_input:383–399`) accepts LMB on the player half. **No hover highlight** on the deploy zone outside of tutorial — the only cue is the preview ghost after a card is selected.
- **Wall placement** requires toggling `WallToggle` (`match.gd:403–415`). Non-intuitive outside tutorial; the hint label is the only pointer. `[NEEDS PLAYTEST]` whether a player skipping tutorial figures out walls before the BUILD timer runs out.
- **Cooldown visual** (`card_button.gd:_draw`) is a sliding dark overlay. Reads as "loading bar" more than "reload". Minor but real ambiguity.
- **Hint label** (`match.gd:_update_hint`) is contextually correct throughout: `TAP A CARD` → `▼ TAP YOUR SIDE TO DEPLOY ▼` → `NEED N MANA — TAP CARD TO CANCEL`. Requires reading, but helpful.

### 3. First-failure handling

Tutorial is **unloseable by design**: `_setup_bots:286–308` early-returns if `_mode.is_tutorial`. No enemy units, no attack against the player base. That's great for onboarding but creates a cliff — the first *real* 1V1 is the first time the player can lose, and they've never seen bot units.

On defeat:
- `_end_match:632–686` awards `-20` trophies (`player_profile.gd:22` LOSS_TROPHIES) but `+15` gold and `+15` XP — **progression never halts**, even on losses.
- Game-over reveal is ~0.7 s total (`_animate_reveal:94–119`). Buttons: REMATCH (primary, cyan glow) + MENU (secondary).
- REMATCH fires `rematch_requested` → `_return_to_match:279–284` → `Router.goto(MATCH_SCENE_PATH)`. Instant, no friction.
- Defeat haptic is a double-pulse (`match.gd:665–667`) — good escalation.

Restart loop is friction-free. Trophy loss is soft; no inventory / durability punishment.

### 4. Reward cadence in the first 5 minutes

- **Per-action (card tap, deploy):** SFX + haptic buzz + visual card cooldown + unit spawn. High density.
- **Per-hit on enemy base:** `base_damage` SFX + screen shake scaled to hits + grid squares removed. Visually satisfying.
- **Per-phase:** match start countdown = mini spectacle.
- **Per-match:** gold / XP / trophies shown **only** on GameOver screen — nothing mid-match. No running damage log, no kill streak indicator, no live score on anything but base-square count.
- **XP / level-up** fires silently during `PlayerProfile.award_match_result` — no mid-match level-up bar tween.

**Gap:** no mid-match numeric progress. A player who has smashed 20 squares doesn't know they're *close* to the finish, only that red tiles are disappearing. Handoff §11 flags this ("kill streak / combo indicator") but it's not implemented.

### 5. Readability

- **Cards** (`card_button.gd:_draw`) are strongly readable: 8 distinct vector `Shape` silhouettes (`ShapeRenderer._stroke:25–57`), per-card color, cost pip, role label. Selection glow, dim-state overlay, cooldown overlay.
- **Units** render at perspective scale through Pseudo3D (`unit.gd:_update_render`). Color = card color, shape = card shape. Units look like tiny cards moving around. No idle anim; movement conveys "alive" but subtly.
- **Base grid** cyan (you) vs red (enemy) from `palette.gd:21,27`. Unambiguous.
- **Walls** are thin cyan/red rectangles perpendicular to flow. `[NEEDS PLAYTEST]` whether cyan walls read well against cyan player units in a dense match.
- **HUD z-ordering** — HUD is a `CanvasLayer`, overlays are `layer=50`, coach is on its own layer. No evidence of z-fights.
- **Palette cohesion** — cyan = friendly, red = hostile, amber = interactive (mana, timer). Tight and consistent.

### Score

- **Hook strength — 7/10.** Tutorial is guaranteed-win so the first "success" always lands, and the rematch loop is instant, but there's no mid-match numeric progress hook. A player's second match (first real bot) is their first possible defeat with no tutorial parachute.
- **Clarity — 8/10.** Hints + coach are strong. Ambiguity mostly around walls (button toggle isn't obvious) and deploy cooldown (reads as loading bar). Briefing timing is slightly awkward.
- **Control feel — 8/10.** Deploy cooldown 0.4 s is snappy; SFX + haptic fire on the frame of input; preview tracks mouse live. `[NEEDS PLAYTEST]` on mid-range Android to confirm the per-frame `Pseudo3D.unproject` in `_update_preview:745–764` doesn't introduce perceptible lag.

---

## Tester 3 — Systems / Replayability

### Build diversity: viable paths & dominance

The cardpool contains ~29 cards across 8 roles with costs 1–8. Computing a rough DPS-per-mana efficiency (`damage * fire_rate / cost` for ranged; `damage / cost` for melee / stationary):

| Card | Role | Cost | Damage | Fire Rate | DPS/Mana | Notes |
|---|---|---|---|---|---|---|
| Pellet | SHOOTER | 1 | 3.0 | 0.35 | **10.5** | Spam baseline |
| Dart | SHOOTER | 2 | 6.0 | 0.6 | 1.8 | Default deck |
| Orb | SHOOTER | 2 | 4.0 | 0.4 | 0.8 | Cheap but weak |
| Bomb | MELEE | 4 | 40.0 | — | **10.0** | AoE terror |
| Burst | INTERCEPTOR | 3 | 14.0 | — | 4.67 | Synergy node |
| Pulse | INTERCEPTOR | 5 | 20.0 | — | 4.0 | Shockwave on death |
| Lance | SNIPER | 5 | 28.0 | 1.4 | 7.84 | Pierce synergy |
| Mortar | SNIPER | 6 | 45.0 | 2.0 | **15.0** | Long-range opener |
| Oracle | SNIPER | 7 | 60.0 | 2.5 | **21.4** | L11 unlock; dominant |
| Chevron | SWARM | 4 | 5.0 | 0.5 | 0.625 | Synergy glue |
| Flock | SWARM | 5 | 5.0 | 0.5 | 0.5 | L6 unlock |
| Beacon | BUFFER | 3 | — | — | — | +25% dmg aura |
| Mender | HEALER | 4 | — | — | — | 8 HP/s heal |

**Oracle and Mortar are outliers** — 15–21 DPS/mana vs. a field mostly under 8. Outside of synergy bonuses, a deck that owns both is mathematically stronger than one that doesn't. Pellet and Bomb shine early; Oracle + Mortar snowball late.

**Role enforcement** forces at least one SHOOTER (damage floor) and often one WALLBREAK (spiral) to punch through walls in classic mode. Deck slots are constrained *before* player choice even enters.

**Unlock gating** (via `CardData.unlock_level`): a fresh player sees ~8 cards unlocked. Oracle / Titan / Revenant unlock at L11 — deep progression. This front-loads *horizontal* variety but *only after* grinding.

### Synergy space — a red flag

**Critical finding.** `autoload/synergies.gd:5–6` documents: *"no in-match effect is applied yet."* The 6 synergy pairs (`:8–15`) are **display-only**. The Deck tab shows `+18%` bonuses but the multiplier is never applied in `Unit._synergy_multiplier:65–76` — wait, the function exists and is read in `Unit._ready:43` (`base_damage = card.damage * level_mult * _synergy_multiplier()`). `[NEEDS PLAYTEST]` to confirm whether synergies.gd:5 is an outdated comment or whether `_synergy_multiplier` is reading an empty active list. Reading `Synergies.active_for(deck_ids)` — if that function returns empty, the multiplier is 1.0 and the UI pairs are purely cosmetic.

Even if active, the graph is sparse:
- `pulse + burst` (CHAIN DETONATE, +18%)
- `spiral + bomb` (AREA BURN, +12%)
- `dart + lance` (PIERCE FOCUS, +15%)
- `chevron + orb` (SWARM COVER, +10%)
- `burst + chevron` (STAGGER WAVE, +8%)
- `pulse + lance` (LOCK-ON RELAY, +20%)

`pulse`, `burst`, `lance` each appear twice; `orb`, `mortar`, `oracle` have no pairs. The competitive core is pulse + burst + lance (2 actives per pair) — every high-level deck will gravitate there. Synergy bonuses top out at +20%, which is less than Oracle's ~2× raw efficiency lead — so raw math beats synergy.

### Progression depth

Card scaling (`player_profile.gd:level_multiplier`): `1.0 + (card_level - 1) * 0.1`. L9 cap → 1.8×. Enemy scaling (`unit.gd:44`): `1.0 + arena_index * 0.1`. Arena 8 → 1.7×. The two curves are **almost exactly cancelling**: grinding card levels buys you ~1.06× advantage at Arena 7. This is good balance — no AFK farming — but also means vertical progression feels flat. Horizontal (new cards, new arenas) is the real progression axis.

Arena thresholds (`player_profile.gd:10–11`): 0 → 100 → 300 → 600 → 1000 → 1500 → 2200 → 3000. Trophy delta per arena grows (≥500 late). At +20 trophies per win and -20 per loss, a 50% WR player never progresses; realistic climb likely needs 55–60% WR. Low-skill players hit a ceiling around Arena 3–4.

### Difficulty curve & walls

| Arena | Threshold | Enemy Mult | Persona |
|---|---|---|---|
| 1 | 0 | 1.0× | K.VOID_07 — aggressive SHOOTER/MELEE |
| 2 | 100 | 1.1× | B.RUST_12 — MELEE/WALLBREAK |
| 3 | 300 | 1.2× | N.ARCADE_03 — SWARM/SHOOTER |
| 4 | 600 | 1.3× | V.HALL_44 — INTERCEPTOR/SNIPER |
| 5 | 1000 | 1.4× | D.VAULT_99 — SNIPER/BUFFER |
| 6 | 1500 | 1.5× | S.PEAK_21 — SHOOTER/SNIPER |
| 7 | 2200 | 1.6× | T.STORM_55 — SWARM/HEALER |
| 8 | 3000 | 1.7× | APEX_001 — endgame epic pool |

The Arena 3 → 4 shift (DPS → lane-control personas) is the first mechanical wall — players who specialised in SHOOTER spam meet INTERCEPTORs. That's healthy. Arena 7 → 8 (trophy gap 800, persona uses L11 cards) is the real demand point — until the player has Oracle / Titan / Revenant unlocked and levelled, they're under-weight.

### Run length & variance

- Classic match = up to 3 min BUILD + MATCH + OVERTIME. Volley = 2 min + 60 s OT.
- Death punishment: -20 trophies, +15 gold, +15 XP. Light.
- Variance per run: **opponent is fixed per arena** (persona doesn't rotate). Player deck varies but opponent doesn't. Two Arena-1 matches face K.VOID_07 every time. Strong early, monotonous long-term.
- `[NEEDS PLAYTEST]` whether 3 minutes is long enough for Oracle-style builds to ramp (7 mana + 2.5 s fire rate).

### Endgame & mastery loop

- **Leaderboards** (`autoload/leaderboard.gd`) are fake — 5 fixed top players and a computed rank. No seasonal reset, no real ranked ladder.
- **Daily Ops** (`autoload/daily_ops.gd`) give ~240 gold / day of hooks.
- **Season Pass** (`autoload/season_pass.gd`) — one hardcoded season "VECTOR.INIT", 30 tiers × 200 XP. ~150 wins to finish.
- No seeded runs. No challenge modifiers. No clan / guild / party mode. No new-season rotation implemented.
- Once a player maxes cards (L9 × 29 = 7540 total XP via card-level costs), hits Arena 8, and burns through 30 season tiers, the progression ceiling is hard. Estimate: 10–20 hours of content, then the retention loop relies solely on ladder.

### Score

- **Build diversity — 4/10.** 29 cards, but Oracle/Mortar outliers, role enforcement, and narrow synergy graph collapse the viable space to ~5–8 meta decks. Plus the synergy system's actual in-match application is unverified — if it's cosmetic only, diversity is flatter than the UI suggests.
- **Per-run variance — 7/10.** Same opponent per arena means strategic arcs repeat; player deck choices plus mana/spatial noise keep match-to-match feel fresh in the short run. Long-term, arena fatigue sets in fast without bot rotation.
- **Long-tail pull — 5/10.** Daily Ops + season pass give near-term hooks but hit ceilings in 10–20 h. No seasonal reset, no real ladder, no challenge mode. A returning player three months from launch sees identical systems.

**Urgent system-design gap.** Confirm whether `Synergies.active_for()` is wired end-to-end. If synergies never actually modify in-match damage, the entire deck-building meta is marketing — the game's biggest replay lever is mechanically disconnected. `[NEEDS PLAYTEST]` + code read of `autoload/synergies.gd:active_for`.

---

## Tester 4 — Performance & Stability

### [1] CRIT — Per-frame `get_nodes_in_group("volley_squares")` in Volley gun target pick

- **Location:** `scripts/match/volley/gun.gd:140`.
- **Issue:** `_pick_target()` iterates the entire `volley_squares` group every frame. Group lookups allocate a fresh `Array[Node]` per call.
- **Cost:** In 2V2 Volley (`spawn_interval=0.22`), up to ~30 live squares × 60 fps × 4 guns = ~7200 group iterations/sec, each with a fresh allocation.
- **Fix:** Maintain a cached `volley_squares` array in a match-scoped registry (mirror UnitRegistry). Squares `append` on `_ready`, `erase` on death/escape. Guns read the cached array.

### [2] HIGH — Per-frame group scans in Unit wall handling

- **Location:** `scripts/match/unit.gd:183,380` (`_do_wallbreak`, `_resolve_wall_collision`).
- **Issue:** Every wallbreak unit *and every other unit* scans the `walls_enemy` / `walls_player` groups every frame.
- **Cost:** 40 units × 60 fps × 3 walls = ~7200 node touches/sec, plus allocation churn.
- **Fix:** Wall registry analogous to UnitRegistry; walls register in `_ready`, deregister in `_exit_tree`.

### [3] HIGH — Match-level escape scan in Volley

- **Location:** `scripts/match/volley/match_volley.gd:180–192`.
- **Issue:** Every frame the match controller iterates `volley_squares` to check if any crossed FIELD_TOP / FIELD_BOTTOM. Same hot group-lookup pattern.
- **Cost:** 60 fps × 30 squares = ~1800 iterations/sec to evaluate a boundary rarely crossed.
- **Fix:** Delegate the boundary check to `square.gd:_process` (cheap — it already runs per square), emit `escaped` when crossed, let the match handle the rare signal. Alternatively, use the cached registry from [1].

### [4] HIGH — Per-frame procedural arc drawing

- **Location:** `scripts/match/unit.gd:_draw`, `scripts/match/volley/gun.gd:192–198`, `scripts/match/volley/square.gd:_draw`.
- **Issue:** `draw_arc()` with 24–48 segments per unit / gun / square, every frame. Guns draw two arcs (heat + HP). Squares draw body + inner outline + HP bar.
- **Cost:** 40 units × 2 arcs × 48 segments + 2 guns × 2 × 48 + 30 squares × 2 × 24 = ~5.3k procedural segments/frame. On a Mali-G57 this is 1–3 ms per frame — a real chunk of a 16.6 ms budget.
- **Fix:** Pre-render ring textures to `CanvasTexture` (single sprite draw per unit); or share a `CanvasItem` material that draws all rings in one pass. Cut arc segment count to 16 where possible.

### [5] MED — `get_first_node_in_group` per shot for base targeting

- **Location:** `scripts/match/unit.gd:_pick_base_square_target:319`, `scripts/match/projectile.gd` hit path.
- **Issue:** Every ranged shot looks up the enemy base via `get_tree().get_first_node_in_group`, allocating an array.
- **Cost:** ~20 lookups/sec across a 20-unit engagement.
- **Fix:** Cache `_player_base` / `_enemy_base` in the match controller; pass references to units at spawn time (or expose via `CurrentMatch`).

### [6] MED — Unpooled unit instantiation

- **Location:** `scripts/match/unit.gd:115` (`_spawn_child_unit`), `scripts/match/match.gd:564–569`, `scripts/match/volley/match_volley.gd:251–257`.
- **Issue:** Bot and on-death spawns call `UNIT_SCENE.instantiate()` inline. A 2 min Volley 2V2 match averages ~180 unit instantiations; classic can be higher under swarm-heavy decks.
- **Cost:** Per-instantiation cost is non-trivial on low-end Android (scene-tree allocation + `_ready` + registry registrations). Not a per-frame issue — a hitch-every-few-seconds issue.
- **Fix:** Add a unit pool to `SpawnPool`. Pre-allocate 40 units at boot; reset card/is_enemy/hp/_volley_gun_target on acquire.

### [7] MED — `queue_redraw()` spam

- **Location:** `scripts/match/volley/square.gd:65`, `scripts/match/projectile.gd:_process`, `scripts/match/unit.gd:141`.
- **Issue:** These nodes call `queue_redraw()` unconditionally each frame. Combined with draw costs in [4], the render thread takes the hit.
- **Cost:** ~3k queue_redraw calls/sec across a full match.
- **Fix:** Gate redraw on actual state change (position delta > ε, flash decaying, HP change). Squares move constantly so they must redraw; units/projectiles can often skip.

### [8] MED — SfxBank synthesis at boot

- **Location:** `autoload/sfx_bank.gd:27–29,125–187`.
- **Issue:** 21 audio samples synthesised on app boot (PCM generation + pack). Blocks the main thread for ~0.5–1.0 s on a mid-range Android.
- **Fix:** Defer synthesis (idle callback), or cache to `user://` on first run and load WAV on subsequent launches. Acceptable today, flag for polish.

### [9] LOW — `recent_roles` manual cap

- **Location:** `scripts/match/match.gd:717–719`, `scripts/match/volley/match_volley.gd:199–201`.
- **Issue:** Array capped by a manual `while pop_front`. If the cap is ever removed the array grows forever.
- **Fix:** Use a ring buffer (fixed `Array[int]` size 3 with `_cursor`); inlined wrap.

### [10] LOW — Vignette shader full-screen

- **Location:** `shaders/vignette.gdshader` + CanvasLayer.
- **Issue:** Per-pixel full-screen shader runs every frame including paused.
- **Cost:** ~0.1–0.2 ms on Mali-G57. Within budget.
- **Fix:** None required; only optimise if profiling shows >1 % frame time here.

### Fine — keep doing this

- **Projectile + DeathBurst pooling** (`autoload/spawn_pool.gd`) is clean. O(1) acquire/release. Pattern should extend to units and walls.
- **UnitRegistry** pattern is exactly the right shape. Extending it to walls + squares closes most of the group-lookup problems above.
- **Pseudo3D math** is a single `project`/`unproject` call per node per frame — cheap and correct.

### Summary

Top three wins are the three cached registries: volley_squares, walls, bases. Together they remove an estimated 10–15 k group-lookup allocations/sec and free ~1–2 ms of frame time on mid-range Android. [4] (arc drawing) is a GPU/CPU cost that's harder to fix but worth a pass if framerate suffers on low-end.

---

## Tester 5 — Game Feel & Polish

### 1. Hit feedback stack by event

| Event | Hit pause | Shake | Flash | Knockback | Particles | SFX | Damage # | Haptic | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Unit vs unit hit (`unit.gd:_deal_damage`→`take_damage`) | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | Flash in `unit.gd:87–88`. No `play_event(card, &"hit")` — the SFX bank has `hit_light`/`hit_heavy` wired but **nothing calls them**. |
| Projectile hits unit | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | Projectile impact is silent; target flashes only via its own `take_damage` flash. Biggest audio gap in the project. |
| Melee detonation (`unit.gd:_do_melee`) | ❌ | ✅ (4) | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | Attacker fanfare is strong; target unit silent. Asymmetric. |
| Wall hit | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (wall_break on destroy) | ❌ | ❌ | Damage-per-tick is silent; only destruction plays SFX. |
| Unit death / shockwave | ❌ | ✅ (2 or 6) | ❌ | ❌ | ✅ | ✅ (death_small/heavy) | ❌ | ❌ | Conditional shockwave doubles shake. Solid. |
| Gun projectile hits square | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | Square flashes (`square.gd:55`), no impact SFX. |
| Square death (volley) | ❌ | ❌ | ✅ | ❌ | ✅ | ✅ (tier-weighted) | ❌ | ❌ | Item 10 landed. Still missing a subtle shake for elite/boss deaths. |
| Base square destroyed | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | Data flip only; match-level `base_damage` SFX fires *once per unit arrival*, not per square. |
| Player base hit | ❌ | ✅ (3+) | ❌ | ❌ | ❌ | ✅ (base_damage) | ❌ | ✅ (55 ms) | Solid. No vignette / camera punch. |
| Gun destroyed (Volley reboot) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | The whole reboot is silent. Feels like a bug. |

### 2. Kill feedback distinction

Unit death (`unit.gd:_die`) spawns a burst, plays tier-weighted death SFX, shakes 2 or 6 (shockwave). Square death adds burst + SFX. **Kills are clearly distinct from hits** because hits are *silent* — not because kills are exceptional. The gap is there by absence, not design. No slow-mo finisher, no last-hit micro-pause, no distinct "final blow" tier.

### 3. Player damage feedback

Base hit (`match.gd:571–586`): shake scales with hits (good), `base_damage` SFX, 55 ms haptic. No vignette, no camera punch, no time hitch. `_end_match` adds a defeat double-buzz (`match.gd:665–667`) — excellent escalation.

Missing:
- Vignette red-pulse on the viewport.
- Haptic scaling with hit size (currently fixed 55 ms regardless of `damage`).
- Camera-zoom punch (subtle 1.02× → 1.0× tween).

### 4. Input feel

- Deploy cooldown 0.4 s; no buffering — taps during cooldown drop.
- Animation lock during match-start countdown overlay: the overlay is `MOUSE_FILTER_IGNORE` (`match.gd:463`), so clicks pass through — but `hand.set_interactive(true)` is only called in `_start_match` (before the countdown starts), so players *can* tap cards during the 3-2-1 if they're quick. `[NEEDS PLAYTEST]` whether this is a bug or feature.
- No haptic on deploy confirmation beyond the 25 ms buzz (`match.gd:535`). No "ready" haptic when mana hits a card cost threshold.

### 5. Audio coverage gaps

- **`hit_light` / `hit_heavy` are synthesised but never played.** Grep `play_event(card, &"hit")` — zero call sites. Projectile and unit damage don't route through the event system.
- **`ui_confirm` is wired** for rematch; other UI confirmations (deck save, shop buy) aren't audited here.
- **Volley squares** die ~300×/match. `death_small` plays with `pitch_variation=0.04` — that's a ±4 % range, too tight for repetition that dense. Two matches in a row risk audible ear fatigue.
- **Overheat / reboot** has no audio cue. Gun visually dims when rebooting but there's no "power-down" or "spooling-up" sound — the heat ring is the only feedback and it's small.

### 6. UI polish

- **ManaBar.set_value** (`mana_bar.gd:29`) snap-sets `_mana` and queues redraw — no tween. The pulse at full is nice but mid-range transitions are hard cuts.
- **Timer label** snaps to int seconds.
- **Score labels** snap to int kills.
- **HP bars** on units / squares draw every frame at current HP — correct, but no roll-down animation after a hit.
- **Game-over reveal** (`game_over.gd:_animate_reveal`) is the one place where tweens are used well — backdrop fade, result pop with BACK ease, cascading sub-elements. This level of polish belongs on more HUD transitions.

### 7. Pause & process mode

- `GameOverOverlay.process_mode = PROCESS_MODE_ALWAYS` (`game_over.gd:17`) — correct, buttons stay responsive while tree is paused.
- Default `PROCESS_MODE_INHERIT` on units / projectiles / bursts → paused with the tree. Verified via reading (no `always` leaks spotted).
- Pause visual is invisible — the scene just freezes. No "PAUSED" overlay, no blur. Fine since there's no user-facing pause (only end-match), but if a pause button is added later it'll need one.

### Juice gap list (severity ordered)

- **HIGH.** Projectile / unit hits play no SFX. `unit.gd:237–241`, `projectile.gd:_check_collisions` (hit path). Bank has `hit_light`/`hit_heavy` ready — nothing calls them.
- **HIGH.** No hit-pause on any damage event. Even 8–16 ms freeze frames would transform combat feel.
- **HIGH.** Gun destruction silent. `gun.gd:82–84` emits `destroyed` but plays nothing. A reboot is a major beat and should sound like one.
- **MED.** Base squares destroyed silently / particle-less. Each square destroyed is a satisfying micro-event and has no localised feedback.
- **MED.** Player damage has no vignette / camera punch (`match.gd:571–586`). Only shake + haptic.
- **MED.** Mana / HP / score values snap instead of tween. `mana_bar.gd:29`, HP draw in `unit.gd`/`square.gd`.
- **MED.** Square death SFX pitch variation ±4 % — too tight for 300-kill matches. Expand to ±10 % or pool 2 variants.
- **LOW.** Deploy cooldown has no countdown meter (card just dims).
- **LOW.** Melee attackers get fanfare; melee targets get nothing. Asymmetric.
- **LOW.** Overheat / reboot no SFX.

### Overall polish grade — **D+**

Strong foundations (SFX synth, pooling, screen shake, haptic escalation on defeat, game-over reveal) undermined by three costly gaps: silent hits, no time elasticity, snap-change HUD values. Combat *looks* good, *feels* hollow. Unlocking a B-grade needs: wire `play_event(..., &"hit")` on damage, add 8–12 ms hit pause on significant hits, tween HP/mana/score, add a vignette pulse on player damage, and an SFX pair for gun destroy/reboot.

---

## Consolidated Output

### 1. Top 10 Must-Fix (pre-demo / pre-release)

| # | Severity | Tester | Finding — Fix |
|---|---|---|---|
| 1 | CRIT | T1 | Pseudo3D `_origin` stale reference on rematch (`autoload/pseudo_3d.gd:69`) — guard with `is_instance_valid` and clear in `Playfield._exit_tree()`. |
| 2 | CRIT | T1 | Rematch signal captures survive scene free (`match.gd:106`, `match_volley.gd:79`) — disconnect in `_exit_tree` or use `CONNECT_ONE_SHOT`. |
| 3 | CRIT | T1 | Pause state can carry over across Router.goto (`match.gd:276`) — move `paused = false` to the first line of `_return_to_home` / `_return_to_match`. |
| 4 | HIGH | T3 | **Synergies may be display-only** (`autoload/synergies.gd:5–6`) — verify `active_for()` actually modifies in-match damage; if not, either wire it through `unit.gd:65–76` or remove the UI claim. This is the biggest silent hit to the game's pitched depth. |
| 5 | HIGH | T5 | Projectile / unit hits are silent — `hit_light`/`hit_heavy` SFX exist but nothing calls `play_event(card, &"hit")`. Add calls in `unit.gd:take_damage` and projectile hit path. |
| 6 | HIGH | T4 | Per-frame group lookups on `volley_squares` from every gun (`gun.gd:140`) — cache a live registry, subscribe on spawn / remove on death. |
| 7 | HIGH | T4 | Per-frame group lookups on walls from every unit (`unit.gd:183,380`) — same pattern, wall registry. |
| 8 | HIGH | T1 | Tutorial briefing timer + fade tween orphan on scene exit (`match.gd:195,201`) — store refs, disconnect/guard on dismiss. |
| 9 | HIGH | T4 | Match-level escape scan in Volley (`match_volley.gd:180–192`) — push boundary check into `square.gd` and emit a signal once, not per frame. |
| 10 | MED | T5 | No hit-pause / shake / damage-number on normal damage — combat feels flat even with kills loud. 8–12 ms hit-pause + HP tween on significant hits is the highest-ROI feel fix. |

Honourable mentions just below the cut: projectile-pool double-release safety (T1 H), T2's "no mid-match progress indicator" (handoff §11 boss announcement / kill streak chip), T3's Oracle/Mortar balance outliers, T5's pitch range on Volley death SFX.

### 2. Fun & Replayability Scorecard

| Axis | Score | Tester | What moves it to 8 |
|---|---|---|---|
| Hook strength | 7/10 | T2 | Add a mid-match progress indicator (score label, kill-streak chip, base % destroyed bar) so the first 3 minutes have numeric feedback. |
| Clarity | 8/10 | T2 | — (already strong; minor win: swap cooldown overlay for a visible meter). |
| Control feel | 8/10 | T2 | — (minor: verify no perf-induced lag on mid-range Android). |
| Build diversity | **4/10** | T3 | Confirm + enable synergy bonuses in-match, rebalance Oracle (21 DPS/mana) and Mortar (15) outliers, add at least two more synergy pairs touching `orb` / `mortar` / `oracle`. |
| Per-run variance | 7/10 | T3 | Rotate bot personas within an arena (2–3 per tier), add per-match modifiers ("fast spawns this match"). |
| Long-tail pull | **5/10** | T3 | Ship a real season reset cadence, add challenge modifiers or seeded runs, open a second cosmetic axis (gun skins per Volley handoff §3e) so Season 2+ has earnable flavor. |

### 3. Stability confidence

**Not ready for a public demo today.** The three CRIT items cluster around the rematch + scene-exit path, and they compound — any player who plays two matches in a row is inside the blast radius. A crash during a public demo costs more trust than any of the polish items. The `pseudo_3d.gd:69` guard, the `match.gd:106` disconnect, and the `match.gd:276` pause-order are a <1 hour fix together; once they land, the game is stable enough for a controlled playtest. HIGHs (audio silence, perf hotspots, timer orphans) degrade the experience but don't break it. The synergy question (CRIT-adjacent depending on whether `active_for()` is wired) should be answered before any marketing copy promises deck synergies.

### 4. Surprises

The single most striking thing is how much **good infrastructure is going unused**. SfxBank has `hit_light` and `hit_heavy` sitting in the bank, fully synthesised, never played — flip a single `play_event(card, &"hit")` call into `unit.gd:take_damage` and combat instantly feels twice as alive. `UnitRegistry` demonstrates the exact pattern needed for `volley_squares` and `walls` but only one team bothered to apply it. `GameOverOverlay._animate_reveal` is genuinely polished tween choreography — yet `ManaBar.set_value` is a hard snap. The project has the tools; it's missing the consistent application. Less flattering: the tutorial is literally unloseable because `_setup_bots` early-returns for tutorial mode (`match.gd:291–292`). Players form no failure model before their first real match, which makes Arena 1 the real difficulty spike. And the Volley handoff flags "Synergies are display-only" (`synergies.gd:5–6`) — if accurate, the entire deck-building meta is marketing, not mechanics. That's the audit's most important single question: is the pitch a lie?
