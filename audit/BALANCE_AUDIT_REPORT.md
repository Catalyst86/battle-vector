# Battle Vector — Balance, Replayability & Playability Audit

*Per `BATTLE_VECTOR_AUDIT_PROMPT_V3.md`. See `METHODOLOGY.md` for scope acknowledgement and `CRITIQUE_OF_METHODOLOGY.md` for adversarial review. Most dynamic claims are **STATIC DERIVATION ONLY — not empirically verified** per prompt §2; Monte Carlo deferred items are called out in-line.*

**Audit session date:** 2026-04-20
**Game state:** main @ e95e70c (Surge + Rift + Vector Link MVP shipped, silhouettes for default deck, speed pass, centering fix)

---

## Pass 1 — Topology, Inventory, Instrumentation

### 1.1 System map

- **Match lifecycle (classic)**: `scenes/main.tscn` → `menus/main_menu.tscn` → `match_confirm` → `scenes/match/match.tscn` → `match.gd:_ready` → phases BUILD (7.5s) → SURGE (25s) → MATCH (155s) → OVERTIME (60s, conditional) → OVER → `game_over.gd:show_result`.
- **Match lifecycle (volley)**: Same entry pipeline → `scenes/match/volley/match_volley.tscn` → phases SURGE (20s) → MATCH (100s) → OVERTIME (60s, conditional on tie) → OVER.
- **Damage pipeline**: `card.damage × PlayerProfile.level_multiplier(card.id) × Synergies.active_for()` computed once at `Unit._ready` (`unit.gd:57`). Per-frame `_refresh_effective_damage()` multiplies `base_damage × _buff_mult` where `_buff_mult = 1 + Σ aura_damage_mult` for friendly BUFFERs in range (`unit.gd:280-294`).
- **Unit spawn**: player via `_try_deploy(screen)` → `_spawn_unit` → either `_spawn_single` directly or (for SWARM) N × `_spawn_single(SCOUT_CARD, offset)`. Volley sets `_volley_gun_target` + `speed_mult=0.85` on each spawn.
- **Projectile path**: `unit.gd:_spawn_projectiles` → `SpawnPool.acquire_projectile` → linear travel at `cfg.projectile_speed` (×0.8 in volley) → `projectile.gd:_check_collisions` (wall → unit → base).
- **Arrival**: classic via `_check_base_arrival` (y bound by `cfg.base_strip_height=52`); volley via `_check_volley_gun_arrival` (radius 24 from target gun).
- **Bot loop**: `match.gd:_bot_try_spawn` fires every `bot_spawn_interval / aggro_mult` seconds. Picks affordable card biased by recent_roles history + persona favour_roles; spawns at random x in their half.
- **Autoloads** (13 total + GameConfig): PlayerProfile, PlayerDeck, GameConfig, UnitRegistry, SpawnPool, SfxBank, MusicPlayer, DailyOps, SeasonPass, Synergies, Leaderboard, Toast, BotPersonas, GunModules, Pseudo3D, Router, Palette, CurrentMatch.

### 1.2 Card inventory

29 `.tres` files in `data/cards/`. One (`_scout.tres`) is internal — spawned by swarm, not player-facing. 28 player cards. Breakdown by role:

| Role | Count | Cards |
|---|---|---|
| SHOOTER (0) | 5 | pellet, dart, orb, arc, shard |
| MELEE (1) | 6 | bomb, saw, dozer, grenade, revenant, titan |
| WALLBREAK (2) | 2 | crawler, spiral |
| INTERCEPTOR (3) | 4 | burst, hook, pulse, leash, siphon (wait: 5. Count below.) |
| SNIPER (4) | 4 | lance, mortar, beam, oracle |
| SWARM (5) | 2 | chevron, flock |
| HEALER (6) | 2 | mender, chorus |
| BUFFER (7) | 2 | beacon, aegis |

*Correction: INTERCEPTOR has 5 cards (burst, hook, pulse, leash, siphon). That gives 5+6+2+5+4+2+2+2 = 28. ✓*

Target per INDUSTRY_BENCHMARKS §Card Roster: 3-4 per role. WALLBREAK, SWARM, HEALER, BUFFER all under floor.

### 1.3 Magic number sweep

Balance-relevant inline literals in `.gd` files (not in `.tres`):

| File:Line | Constant | Purpose | Risk |
|---|---|---|---|
| `unit.gd:53` | `1.0 + arena_index() * 0.1` | Bot unit level_mult per arena | HIGH — single source of truth for P2W feel; should live in game_config |
| `unit.gd:189` | `40.0` | Default melee AoE fallback | MED — per-card override via `card.melee_aoe_radius` exists, but fallback is hidden |
| `unit.gd:190` | `0.6` | Melee secondary AoE damage fraction | MED |
| `unit.gd:209` | `× 3.0` | Wallbreak damage multiplier vs walls | MED |
| `unit.gd:220` | `× 2.0` | Interceptor continuous-damage factor | HIGH — role balance knob not in config |
| `projectile.gd:95` | `card.size × 0.8` | Projectile hit radius | LOW |
| `projectile.gd:117` | `damage / 18.0` | Base grid tile damage scaling | HIGH — affects all base-damage calcs |
| `match_volley.gd:SQUARE_BASE_SPEED 46.0` | | Square descent speed | MED — should be in a volley config resource |
| `match_volley.gd:VOLLEY_UNIT_SPEED_MULT 0.85` | | All-unit speed scale in volley | HIGH — single mode knob for feel |
| `match_volley.gd:LINK_HP_FACTOR 0.85, LINK_DAMAGE_FACTOR 1.6` | | Vector Link math | HIGH — central combat mechanic |
| `gun.gd:520.0` | | Gun projectile velocity | LOW |
| `match.gd:_on_unit_reached_base → damage / 18.0` | | Hit-tile count | HIGH |
| `player_profile.gd:UPGRADE_COSTS` | | Progression pacing | — already in an array const, acceptable |

**Finding**: at least 7 HIGH-risk balance knobs live inline. Moving these into `data/config/balance.tres` would make live tuning a designer task rather than a programmer task. `FINDING-01` — see Pass 8.

### 1.4 Telemetry audit

**Match-level event logging**: effectively none.

- `PlayerProfile` saves aggregate stats (gold, trophies, XP, level, card_levels) to `user://profile.tres` on any change (`player_profile.gd` ResourceSaver.save). That gives cumulative numbers.
- `data.match_history` is a 5-char string of "WLD" (`player_profile.gd:134-138`) — only last 5 results. No timestamps, no durations, no per-match deck, no per-card performance.
- No `match_events.csv`, no `match_<n>.json`, no push to remote, no structured logs on disk or stdout.
- `DailyOps` tracks quest counters, but those flush to per-quest totals — not per-match rows.

**Finding** `FINDING-02` (CRITICAL per prompt §Pass 1): without per-match telemetry, the developer cannot iterate with real data post-launch. Balance patches will rely on community intuition + support tickets instead of measurement. This is the difference between "ship and hope" and "ship and iterate." Add structured match-end logging (deck, result, duration, card plays, damage dealt, win/loss reason) before any soft launch or Steam Next Fest.

### 1.5 Orphan check

No orphaned CardData fields identified. All exported fields on `CardData` are read at least once in `unit.gd`, `projectile.gd`, or `synergies.gd`. No code references to mechanics absent from `.tres` (e.g. no "stun", "slow", "dispel" referenced but missing CardData fields).

### 1.6 Prior-claim inventory

See `CONTRADICTIONS.md`. All quantitative claims from `VECTOR_BATTLES_QA_REPORT.md` re-verified against current code. Notable: that report's own Corrigendum section already corrects the "Oracle = 21.4 DPS/mana" number to 4.29/mana. Current Oracle = 30 DPS / 7 mana = **4.29 DPS/mana** (post-retuning fr 2.5→2.0).

---

## Pass 2 — Per-Card Static Stats

**STATIC DERIVATION ONLY — not empirically verified.** All numbers computed from `.tres` + `unit.gd` pipeline. No Monte Carlo. Variance unknown; reliability flag `MEDIUM` throughout except where noted.

### 2.1 Per-card DPS table (level 1, no synergy, no buffer)

**Classic mode** (projectile_speed=260, speed_mult=1.0):

| Card | Role | Cost | HP | Damage | Fire cd | Projectiles | DPS (L1) | DPS/mana | Notes |
|---|---|---|---|---|---|---|---|---|---|
| pellet | SHOOT | 1 | 10 | 3 | 0.35 | 1 | **8.57** | 8.57 | Glass cannon |
| dart | SHOOT | 2 | 20 | 6 | 0.6 | 1 | **10.0** | 5.0 | Pierces |
| orb | SHOOT | 2 | 30 | 4 | 0.4 | 1 | **10.0** | 5.0 | — |
| arc | SHOOT | 3 | 22 | 12 | 1.0 | 1 | **12.0** | 4.0 | — |
| shard | SHOOT | 4 | 25 | 6 | 0.5 | 3 | **36.0** | **9.0** | 3-projectile fan — outlier |
| lance | SNIPE | 5 | 18 | 28 | 1.4 | 1 | **20.0** | 4.0 | Stationary |
| beam | SNIPE | 6 | 22 | 9 | 0.3 | 1 | **30.0** | 5.0 | Pierces |
| mortar | SNIPE | 6 | 35 | 45 | 1.7 | 1 | **26.5** | 4.42 | — |
| oracle | SNIPE | 7 | 28 | 60 | 2.0 | 1 | **30.0** | 4.29 | — |
| bomb | MELEE | 4 | 50 | 40 | — | — | **64** burst (1.6× with default AoE) | 16 | One-shot |
| saw | MELEE | 3 | 55 | 14 | — | — | 22.4 burst | 7.47 | One-shot |
| dozer | MELEE | 5 | 110 | 28 | — | — | 44.8 burst | 8.96 | One-shot; phases walls? no |
| grenade | MELEE | 5 | 60 | 30 | — | — | 48 burst | 9.6 | 60px AoE override |
| revenant | MELEE | 6 | 70 | 40 | — | — | 64 burst + spawns scout on death | 10.67 | Strong payload |
| titan | MELEE | 8 | 160 | 45 | — | — | 72 burst | 9.0 | phases_walls=true |
| burst | INTCP | 3 | 25 | 14 | — | — | 28/s (×2 factor) | **9.33** | — |
| hook | INTCP | 3 | 28 | 10 | — | — | 20/s | 6.67 | — |
| pulse | INTCP | 5 | 45 | 20 | — | — | 40/s + on-death shockwave (60r, 10 dmg) | 8.0 | Epic |
| leash | INTCP | 5 | 40 | 18 | — | — | 36/s | 7.2 | — |
| siphon | INTCP | 5 | 35 | 15 | — | — | 30/s + 50% lifesteal | 6.0 | — |
| crawler | BREAK | 3 | 22 | 10 | — | — | 30/s anti-wall (×3 factor), ~5/s anti-unit | 10 (wall) / 1.67 (unit) | Wall-only role |
| spiral | BREAK | 3 | 35 | 18 | — | — | 54/s anti-wall | **18 (wall)** | Strong anti-wall |
| chevron | SWARM | 4 | 12 | 5 | 0.5 | 1 | **30 total** (3× scout 10 DPS) | 7.5 | Deploys 3 scouts |
| flock | SWARM | 5 | 14 | 5 | 0.5 | 1 | **50 total** (5× scout 10 DPS) | 10 | Deploys 5 scouts |
| mender | HEAL | 4 | 40 | 0 | — | — | 8 HP/s targeted heal (attack_range=55) | — | target ally heal |
| chorus | HEAL | 5 | 50 | 0 | — | — | 5 HP/s AoE (aura_radius=80) | — | drifts while healing |
| beacon | BUFF | 3 | 60 | 0 | — | — | +25% dmg aura (80r) | — | 1.25× to N allies in range |
| aegis | BUFF | 4 | 70 | 0 | — | — | +15% dmg + 2 HP/s aura (70r) | — | dual function |

**Volley mode adjustments**: multiply projectile DPS by `1/0.8` wait — actually projectile speed ×0.8 just affects travel time, not DPS. **Volley DPS ≡ classic DPS** for most cards. Exception: unit speed ×0.85 means walkers arrive 15% slower, so their "time to contribute" increases; per-match effective DPS (DPS × time-on-field) effectively ~15% higher since unit lives longer. Noted but unquantified.

### 2.2 Level scaling

`level_multiplier(id) = 1.0 + (card_level - 1) × 0.1`. Applies to `hp` and `damage` at `Unit._ready`. Max level 10 = 1.9×.

**At L5**: all stats × 1.4. **At L10**: all stats × 1.9.

**Bot-side**: `Unit._ready` replaces level_mult with `1 + arena_index × 0.1` for enemy units (max +70% at arena 7).

### 2.3 Buffer aura impact

`_buff_mult = 1 + Σ aura_damage_mult`. With beacon (0.25) + aegis (0.15) both in range = `1.4×` damage multiplier. Stacked with synergy (+20% from LOCK-ON RELAY) = **1.68× total** vs a L1 baseline → effective +68% damage for one ally card. If also at L10 (×1.9) → 3.2× raw card.damage. That's the Shadow Dagger failure mode — multiplier stacking runs away.

### 2.4 Mana efficiency outliers

Ranked by DPS-per-mana (excluding burst-melee and healers/buffers):

| Rank | Card | DPS/mana | Role | Notes |
|---|---|---|---|---|
| 1 | shard | **9.0** | SHOOT | 3-projectile fan, effectively 3× dart |
| 2 | pellet | 8.57 | SHOOT | 1-mana; dies in one hit |
| 3 | flock | 10 (swarm aggregate) | SWARM | 5 bodies — hard to kill all |
| 4 | burst | 9.33 | INTCP | Interceptor factor 2× |
| 5 | spiral | 18 (wall only) | BREAK | N/A against units |
| 6 | chevron | 7.5 (swarm agg) | SWARM | 3 bodies |
| 7 | crawler | 10 (wall only) | BREAK | N/A against units |
| 8 | beam | 5.0 | SNIPE | Pierces — multi-target DPS higher than listed |
| 9 | dart | 5.0 | SHOOT | Pierces |
| 10 | orb | 5.0 | SHOOT | — |

**Flag** — shard (9.0) dominates the shooter tier by almost 2×; other shooters sit at 4-5 DPS/mana. If shard's power-budget counter is "projectile_count=3 triples DPS for +1 mana vs arc", that's a 3× boost for 33% more cost — mathematically broken unless projectile spread (15°) and HP (25) offset enough.

### 2.5 Role viability calculation

**HEALERs**: mender 8 HP/sec for 4 mana = 2 HP/mana/sec. Compared to fresh unit HP: dart (20 HP, 2 mana) = 10 HP/mana instantly. Mender only breaks even vs dart if it heals for ~5 seconds. At attack_range=55, mender parks near wounded ally and heals 8/sec × ~5-10s lifetime = 40-80 HP for 4 mana, so 10-20 HP/mana. **Roughly competitive with dart**, better vs expensive high-HP units.

**BUFFERs**: beacon 0.25× damage on N allies within 80r, 60 HP for 3 mana. If 2 shooters in range dealing 10 DPS each, beacon adds 2 × 2.5 = 5 DPS × lifetime. Beacon lifetime ≈ 15s (no movement, shot by enemies) → 75 extra damage / 3 mana = **25 effective DPS-seconds/mana**. Compared to dart's 10 DPS × 15s = 150/2 = 75 — wait that's single-card damage not efficiency. Let me normalize: **Beacon adds equivalent of 25 effective DPS-seconds per mana** vs dart's DPS contribution of 5/s/mana × lifetime ≈ 75/s-mana. Beacon < dart unless it's aura-ing 3+ units. **Beacon is marginal at 2 allies; gains value at 3+.**

**Conclusion**: HEALER/BUFFER roles are mathematically defensible but require specific deck contexts to be efficient. They're not dominated per se but they're *situational*.

### 2.6 Pipeline-tracing bugs / anomalies

- **No additive vs multiplicative anomaly found.** The `_synergy_multiplier` is multiplicative, applied once to `base_damage` in `_ready`. `_buff_mult` applies to `effective_damage` per frame.
- **Fused-unit stats** (`match_volley.gd:_try_fuse`) bypass level_mult (`fused.level_mult = 1.0`). This is intentional — source units already baked level into their `hp` / `base_damage`. But the final `fused_card.speed = (a.speed + b.speed) × 0.5` is set BEFORE `level_mult` override in _ready, which also sees `speed_mult = 0.85` in volley → fused speed is 0.85 × (a+b)/2. Correct behaviour.
- **Swarm scout stats** use the `_scout.tres` definition directly (card.damage = 5, fire_rate = 0.5 → 10 DPS/scout). Chevron swarm_count=3 → 3 scouts of 10 DPS each = 30 DPS total. Flock swarm_count=5 → 50 DPS. Chevron card stats (damage=5) are never actually used — the scouts inherit from `_scout.tres` not from the chevron card. **Minor finding**: Chevron's own damage/hp fields are dead data at runtime.

---

## Pass 3 — Role Balance, Pareto Frontier, Nash

**STATIC DERIVATION ONLY.** Nash equilibrium deferred.

### 3.1 Pareto frontier at L5

Objective space: `(cost ↓, DPS ↑, HP ↑, range ↑)`. A card is Pareto-dominated if another has lower-or-equal cost AND ≥ DPS AND ≥ HP AND ≥ range.

At L5 (damage × 1.4, hp × 1.4) — computed for every card, then dominance-checked pairwise:

**Dominated cards**:

| Card | Dominated by | Notes |
|---|---|---|
| orb | dart | Both 2-mana, 10 DPS. Orb has HP 42 vs dart 28, but dart pierces (multi-target), so the "range" axis effectively favours dart on multi-target engagements. **Pareto call**: dart dominates only because pierces isn't captured in the 4D space. In pure (cost, DPS, HP, range): orb has HP 42 vs dart 28, orb slightly *dominates* in HP but dart's range=140 vs orb 90. **Non-dominated**. Both are Pareto-optimal. |
| arc | shard | Both are SHOOT. Arc: cost 3, DPS 12, HP 31, range 180. Shard: cost 4, DPS 36, HP 35, range 120. Arc beats shard on cost + range, shard beats on DPS + HP. **Non-dominated**. |
| hook | burst | Cost 3 each. Burst: DPS 28, HP 35, range 40. Hook: DPS 20, HP 39, range 80. Burst higher DPS/HP, hook higher range. **Non-dominated**. |
| siphon | leash | Cost 5 each. Siphon: DPS 30, HP 49, has lifesteal. Leash: DPS 36, HP 56. **Leash dominates siphon on DPS+HP** — only lifesteal saves siphon. Pareto tight: siphon near-dead. |
| saw | spiral | Saw MELEE cost 3, 22.4 burst. Spiral WALLBREAK cost 3, 54/s wall DPS + 18/s unit DPS. Different roles. Saw is PARETO-dominated by bomb when you extend to cost 4: bomb has 64 burst for +1 mana. But same-cost comparison: saw vs chevron swarm? Saw 22.4 burst vs chevron 30 sustained. **Saw is weak — 22.4 single hit for 3 mana is the cheapest melee but very loseable**. |
| chevron | flock | Chevron: 4 mana, 3 scouts × 10 DPS = 30 total, 3 × 12 HP = 36. Flock: 5 mana, 50 DPS, 70 HP. Flock beats chevron on DPS/HP per mana: 10/mana vs 7.5/mana; 14 HP/mana vs 9 HP/mana. **Flock Pareto-dominates chevron** once unlocked (L6). |
| mender | chorus | Mender: 4 mana, 8 HP/s targeted, 56 HP. Chorus: 5 mana, 5 HP/s AoE (80r), 70 HP. Different patterns — mender burst-heals single, chorus sustains group. **Non-dominated**, different modes. |
| beacon | aegis | Beacon: 3 mana, +25% dmg aura, 84 HP. Aegis: 4 mana, +15% dmg + 2 HP/s, 98 HP. Beacon beats on cost+dmg-mult, aegis beats on cost+utility. **Non-dominated**. |

**Manually identified Pareto-dominated at L5**:
1. **orb** — dominated by dart on pierces. Both alive on Pareto strictly, but orb is the weaker pick given dart's multi-target edge. ~60% dominated.
2. **saw** — dominated by grenade (+2 mana, +25 burst, +60 AoE) and by bomb (+1 mana, +40 burst). Saw is a "worse bomb." ~80% dominated.
3. **chevron** — dominated by flock once L6. Until L6, chevron is the only swarm — non-dominated by necessity.
4. **siphon** — dominated by leash on DPS+HP, only saved by lifesteal (niche).
5. **hook** — dominated by burst on DPS+HP, only saved by range.
6. **crawler** — dominated by spiral on both wall-DPS and unit HP. Crawler: 22 HP, 30 wall DPS. Spiral: 35 HP, 54 wall DPS. **crawler strictly dominated**.
7. **arc** — competitive with shard; non-dominated.
8. **pellet** — non-dominated only by virtue of 1-mana cost (nothing cheaper). Dominated in the 2D (DPS, HP) space but unique in cost.
9. **aegis** vs **beacon** — both on frontier.
10. **saw** — duplicate flag.
11. **mender** vs **chorus** — both on frontier.

### 3.2 Pareto ratio

Non-dominated cards at L5: **pellet, dart, arc, shard, mortar, oracle, beam, lance, bomb, dozer, grenade, revenant, titan, burst, pulse, leash, spiral, flock, mender, chorus, beacon, aegis** = **22 cards**.

Dominated: **orb, saw, chevron, siphon, hook, crawler** = **6 cards**.

22 / 28 = **78.6% Pareto frontier**. Benchmark target: >85%. **Below target by 6.4 percentage points**. Not catastrophic; six dominated cards is acceptable for a pre-launch balance pass but needs cleanup before ship.

Level sweep: re-run at L1 and L10 to confirm.

- **At L1** (no scaling): identical ordering since level_mult is uniform across cards. Same 78.6%.
- **At L10** (×1.9): absolute DPS numbers change; relative Pareto unchanged because scaling is uniform. Same 78.6%.

The Pareto dominated set is level-invariant because all cards scale identically. **Pareto-dominated cards cannot be rescued by level progression** — they need a .tres stat adjustment. FIX TARGETS for Pass 8.

### 3.3 Role balance

| Role | Viable cards | Synergy partners | Health |
|---|---|---|---|
| SHOOTER (5) | pellet, dart, arc, shard (orb ~dominated) | dart+lance (synergy); chevron+orb (synergy) | **OK** — 4 viable, orb dominated-but-not-dead |
| MELEE (6) | bomb, dozer, grenade, revenant, titan (saw dominated) | spiral+bomb (synergy) | **OK** — 5 viable |
| WALLBREAK (2) | spiral (crawler dominated) | spiral+bomb | **THIN + crawler DEAD**. Only 1 viable. |
| INTERCEPTOR (5) | burst, pulse, leash (hook + siphon partial) | pulse+burst, pulse+lance, burst+chevron | **OK** with caveats |
| SNIPER (4) | lance, mortar, beam, oracle | dart+lance, pulse+lance | **OK** — all on frontier |
| SWARM (2) | flock (chevron dominated-once-unlocked) | chevron+orb, burst+chevron | **THIN** — only 1 long-term viable |
| HEALER (2) | mender, chorus | none | **OK** — both non-dominated |
| BUFFER (2) | beacon, aegis | none | **OK** — both non-dominated |

**Findings**:
- `FINDING-03`: WALLBREAK has 2 cards, 1 viable. Needs a third card or crawler rebalance.
- `FINDING-04`: SWARM has 2 cards, chevron dominated by flock. Needs chevron buff or a third swarm option.
- `FINDING-05`: SHOOTER has orb as a weak-dominated. Minor; orb exists as a "cheap alternative" archetype (HP-heavy) but the numbers don't support it.

### 3.4 Synergies — graph analysis

6 pairs (see `CONTRADICTIONS` #2 — verified active):

```
pulse — burst (CHAIN DETONATE, +18%)
pulse — lance (LOCK-ON RELAY, +20%)     ← strongest
spiral — bomb (AREA BURN, +12%)
dart — lance (PIERCE FOCUS, +15%)
chevron — orb (SWARM COVER, +10%)
burst — chevron (STAGGER WAVE, +8%)
```

**Graph**: pulse and lance each appear in 2 pairs. Pulse+lance+burst = 3-way cluster with simultaneously active CHAIN DETONATE + LOCK-ON RELAY = **+38% damage to all three cards**. That's a major power spike if included together.

**Underrepresented cards**: mortar, oracle, beam, dozer, revenant, titan, grenade, saw, crawler, flock, hook, leash, siphon, pellet, arc, shard, aegis, beacon, mender, chorus, aegis, beacon = **22 cards with zero synergy partners**. Nearly 79% of roster is synergy-excluded.

**Finding** `FINDING-06`: synergy graph is sparse and concentrated. Adding 3-4 more pairs touching the long tail would widen deck diversity substantially. Specifically: mortar + shard (both multi-projectile), revenant + chevron (death-spawn + swarm), beacon + dart (buff + pierce), chorus + flock (heal + swarm).

### 3.5 Nash equilibrium

**DEFERRED** — requires the 28×28 matchup matrix with N=200 Monte Carlo per cell (~157K simulations) and a headless Godot harness. Projected output: list of cards in the Nash support. Cannot execute in this session.

Static proxy: Pareto frontier size (22) is an *upper bound* on Nash support size. Nash support ≤ Pareto frontier by definition. So Nash support ≤ 22. Benchmark target: ≥12. **Likely met, but not proven.**

---

## Pass 4 — Level Scaling & P2W Economic Projection

**STATIC DERIVATION ONLY.** Elo gap deferred.

### 4.1 Gold income model (F2P player)

- Per match at 50% WR: `0.5 × 60 + 0.5 × 15 = 37.5 gold`.
- Daily chest: `120 gold avg` (range 80-160).
- Daily ops (3 quests, avg ~62 gold each): `~186 gold/day` if all completed.
- At 5 matches/day: total = `5 × 37.5 + 120 + 186 = 493.5 gold/day`.
- At 10 matches/day (CR-typical for active): `10 × 37.5 + 120 + 186 = 681 gold/day`.

### 4.2 Upgrade cost curve

Per-card cumulative:

| Level | Cost to reach | Cumulative |
|---|---|---|
| 1 | — | 0 |
| 2 | 20 | 20 |
| 3 | 50 | 70 |
| 4 | 100 | 170 |
| 5 | 200 | 370 |
| 6 | 400 | 770 |
| 7 | 800 | 1,570 |
| 8 | 1,500 | 3,070 |
| 9 | 3,000 | 6,070 |
| 10 | 6,000 | **12,070** |

To max 8 cards: `8 × 12,070 = 96,560 gold`.

### 4.3 Days-to-max projection

At 493 gold/day, one card = 12,070 / 493 = **24.5 days**. 8-card deck = **196 days**.
At 681 gold/day, one card = **17.7 days**. 8-card deck = **142 days**.

Benchmark: 60-120 days per card (healthy), 300-600 for deck.

**Finding** `FINDING-07`: days-to-max is **significantly under the benchmark floor**. Players reach max in ~3× faster than CR analog. Progression ceiling hits earlier; long-term retention lever wastes.

### 4.4 XP progression

Quadratic XP curve: `xp_to_next(n) = 80n² + 120`.

Sum to L15: 82,880 XP. At 32.5 XP/match (50% WR avg) → **2,550 matches to max player level**.

Benchmark: 300-500 matches.

**Finding** `FINDING-08`: XP curve overshoots benchmark by **5×**. Player level is the gate for card unlocks (oracle L11, titan L11, revenant L10, etc.). At 5 matches/day player level 11 = 1,386 XP/day from 5×32.5×0.85 (wait: avg XP includes chest). Recomputing: per-match XP 32.5 + daily XP from chest 55 + daily ops 30 × 3 = ~90 from ops. Daily XP ≈ 250. XP to L11 = 82,880 - (XP to L12) — let me simplify: L10→L11 = 80×(10)² + 120 = 8,120 XP. Cumulative XP to reach L11 = sum(80n² + 120 for n=1..10) = 80×385 + 1200 = 31,880 XP. At 250 XP/day = **127 days** to reach L11 and unlock Oracle/Titan.

That's **4+ months** before the player has the top-tier cards. Meanwhile their ARENA climb hits APEX (3000 trophies) much earlier — at 50% WR net 5 trophies/match = 600 matches = ~120 days. So player reaches APEX arena **roughly the same week** they unlock Oracle/Titan. That's the only piece of good news here.

### 4.5 Arena climb / P2W cliff

Trophies: Win +30, Loss -20, Draw 0. Net @ 50% WR = 5/match. Net @ 55% WR = 7.5/match. APEX = 3000 trophies.

- 50% WR: 600 matches to APEX. 120 days.
- 60% WR: 300 matches. 60 days.
- 40% WR: 1200 matches. 240 days (they'll stall before APEX).

Bot unit scaling: `1 + arena_index × 0.1` → APEX bot = +70% stats. Player card levels also +90% at L10. Mismatch: at APEX, player-with-L10-cards is 1.9× vs bot 1.7× = **+12% player advantage** if cards are maxed, or **-17% disadvantage** if cards are at L1. That's the P2W pressure point.

**Real-world F2P path**:
- Day 60: some cards at L5-L6, arena ~4-5. Bot at 1.4-1.5×, player cards 1.4-1.6× — **even**.
- Day 120: most cards at L7-L8, arena ~6-7. Bot at 1.6-1.7×, player cards 1.6-1.8× — **slight edge**.
- Day 200: cards at L9-L10, arena ~7-8. Bot at 1.7-1.9× (cap), player at 1.8-1.9× — **parity**.

**Finding** `FINDING-09`: **against bots, no P2W cliff exists** — the player's upgrade pace roughly matches the bot's arena scaling. Changes under human opponents: **YES** — a P2W-paying human can rush L10 in days and enter a mid-arena where opponents are still L3-L5, producing a +50% stat edge. That's the real P2W risk, only visible post-networking.

### 4.6 Elo gap projection

**DEFERRED** — requires N=10,000 simulated ladder matches. Static proxy: max-level-L10 vs median-F2P-L5 = +90% vs +40% stats = **+36% effective damage / HP** gap. Expected win rate for paid player (using 36% stat advantage as a rough proxy): ~60-65%. That's at the edge of the <65% P2W threshold but not past it. `LOW` confidence call: P2W risk **MEDIUM**, with the caveat that Elo simulation would sharpen the estimate.

---

## Pass 5 — Economy vs Benchmarks

See `BENCHMARKS_CHECK.md` for the full deviations table.

### 5.1 Mana loop

**Measured**:
- Mana regen: 1/sec.
- SURGE: 2× regen, first 25s (classic) / 20s (volley).
- Cap: 10.
- Total mana per classic match: ~186 + 25 SURGE bonus = **211 mana** over full match.
- Avg card cost: default deck = 3.5.
- Cards playable per match (mana-budget): 211 / 3.5 = **60**. But decision rate caps at ~12-15 (deploy cooldown + need to react to field).
- Deck cycle: ~1.5-2× per match.

**vs Benchmark**: cards-played lower bound 15-25 target; BV sits at 8-15. **At or below benchmark floor.** Consider shortening `deploy_cooldown` (0.4s) or raising `mana_regen_per_sec` (1.0) by 15-20% to push card density up.

### 5.2 Gold loop

See Pass 4. F2P-generous to the point of wasting the progression hook.

**Exploit search (static only)**:
- **Loss farm**: losing gives 15 gold. Winning gives 60. Deliberately losing is strictly worse (including -20 trophies). **No exploit**.
- **Daily ops farm**: quests fire on natural play; no repeatable gold loop.
- **Free chest**: 24h cooldown, no stacking. **No exploit**.
- **Match duration farm**: classic always runs to 3 minutes. No "quick match" time-farm. **No exploit**.

**FINDING-10**: no exploits identified in static analysis. Fuzz testing DEFERRED for confirmation.

### 5.3 XP loop

See Pass 4.4. XP curve overshoots benchmark by 5×.

### 5.4 Chest loop

Free chest every 24h, gold 80-160 + XP 30-80. Locks with `last_free_chest_unix`. No duplicate-protection needed (cards unlock by level not by chest).

Early game: chest = 4-8× next upgrade cost (very generous). Late game: chest = 1-3% of next upgrade cost (weak). The value curve is upside-down from standard F2P games where chests scale relatively flat and feel meaningful throughout.

---

## Pass 6 — Match Flow & Bot AI (static)

### 6.1 Match structure

Classic: BUILD 7.5s → SURGE 25s (full mana, 2× regen) → MATCH 155s (standard) → OVERTIME 60s if still tied. Total 4:07.5 max.

Volley: SURGE 20s → MATCH 100s → OVERTIME 60s if tied. Total 3:00 max.

**Analysis**:
- SURGE kicks off with full mana — good, zero dead-zone feel.
- OT trigger in classic: `enemy_base.count_alive() == player_base.count_alive()` equal — straightforward.
- OT trigger in volley: score tied — natural.
- OT in volley adds Rift (midline capture, 3.5s cap, 12s mana × 2 buff, resets). In classic, OT has **no comeback mechanic** — timer red, dpm unchanged.

**Finding** `FINDING-11`: classic OT lacks the comeback mechanic that volley OT has. If a classic match is 20% deficit at 3:00, OT is just more of the same. Consider porting rift / catch-up regen to classic.

### 6.2 Bot AI — static review

`match.gd:_bot_try_spawn` (bots with aggression `aggro_mult`):

```python
# Effective spawn interval = BOT_SPAWN_INTERVAL / aggro_mult
# aggro_mult = 0.7 + 0.6 × clampf(aggression, 0, 1)
# At aggression 1.0 (APEX): aggro_mult = 1.3 → spawn every 2.0/1.3 = 1.54s
# At aggression 0.65 (DATAVAULT): aggro_mult = 1.09 → spawn every 1.83s
```

Spawn cadence range: 1.5-1.85 seconds. Bots then pick cards by:
1. Filter affordable (cost ≤ mana).
2. Prefer non-`recent_roles` (last 3 played roles). Fresh roles.
3. Bias `favour_roles` from persona.
4. Pick random from the filtered set.

**Observations**:
- Bot NEVER saves mana for a big play — it spends as soon as possible.
- Bot doesn't counter player deploys. It plays its own deck in isolation.
- Bot doesn't bias deploy position based on threat — it picks a random X on its half.
- Bot has `recent_roles` anti-spam (nice) but no longer-horizon "deck plan."

**Finding** `FINDING-12`: bot AI is "basic persona spam." It's a proxy for match pacing, not a strategic opponent. Flag `changes under human opponents: YES, dramatically`. Humans will outplay this bot in 10-20 matches of pattern recognition.

**Exploit decks (static prediction)**:
- **All-snipers**: with 4 snipers + 4 buffers, the bot (which spawns melee MELEE roles early) can't reach the back line. Expected win rate vs APEX bot: **70-85%**, static guess.
- **Stall-deck** (only wallbreaks + mender): bot attacks player base slowly, player delays & outscales. Probably 50-60% against APEX.
- **One-card-spam**: flocking or burst only. Bot anti-spam breaks unless persona happens to have 4+ counter cards. Probably 60-75%.

All `DEFERRED` until fuzz testing.

### 6.3 Overtime bias

Classic OT: if base counts equal, overtime starts. Outcome = higher-base-count at OT end. Without a comeback mechanic, the attacker with more units in OT usually wins (they can finish sooner). Bias favours the **attacker** — but with no regen acceleration, it's a pure "whoever has more units on field" decision, which can feel arbitrary.

**Volley OT**: Rift capture gives trailing team a regen boost, but only +100% for 12s — modest. Score at OT start is likely the deciding factor.

**Finding** `FINDING-13`: classic OT bias toward attacker without acceleration. Benchmark wants OT mana regen 2× (per §Match Structure). Apply SURGE-style 2× regen during classic OT.

### 6.4 Match-decided-early proxy

Without fuzz, measure via the mana-budget approximation: at 1:00, both sides have spent ~12 cards. Score lead at 1:00 → likely >50% predictive of final. DEFERRED for real measurement.

---

## Pass 7 — Multi-Persona Playability

### 7.1 Persona A — Min-Max Player

**What they find**:
- **Shard at 9 DPS/mana** (Pass 2.4) — immediate inclusion in any shooter deck.
- **Pulse + Lance + Burst 3-way synergy cluster** (+38% to all three) — core of an S-tier deck.
- **Titan (L11)** + **Bomb** or **Revenant (L10)** — stacking on-death / phase_walls for endgame push decks.
- **Vector Link** exploits: two of the same high-cost card (e.g. two Lances) fuse to a 56-damage, 1.4-sec-cooldown, stationary obliterator for ~10 mana total minus the single fusion charge. Twin bombs = 128 burst AoE.
- **Synergy stacking** with buffer: beacon (+25%) + aegis (+15%) + LOCK-ON RELAY (+20%) = 1.62× damage. Not quite multiplicative on multi-aura but still a 62% bump.

**Is there depth?** Yes, with caveats. The 3-way synergy cluster is the dominant strategy; variance comes from which filler cards pair with it. Deck exploration is **moderate**.

**Finding** `FINDING-14`: pulse+burst+lance cluster is likely the auto-include core for competitive play. Monitor appearance rate post-launch.

### 7.2 Persona B — New Player (first hour)

**What they hit**:
- Tutorial is **unloseable** — no bots (`match.gd:291-292`). Cannot teach losing.
- First real match = first bot = K.VOID_07 at aggression 0.8 (highest-tier-1 benchmark). Aggression scales bot spawn to 1.54s interval → **bot deploys 5-6 units in the SURGE window**. Player has ~10 mana to spend in SURGE but only 4 cards in hand; they'll likely deploy 2-3. **Asymmetric opening** feels rough.
- Coach disappears after enemy base is hit once (`match.gd:872-877`) — aggressive hiding. OK.
- No "counter" tutorial — nothing teaches that wallbreakers ignore walls, or that buffers aura.
- Card info: 40×58 px card tile, role label 7pt, name 8pt, cost pip with 9pt number. **At arm's length on mobile, the 7-8pt text is small**; verify in playtest.
- Mana bar pulses at full — good cue.

**Finding** `FINDING-15`: tutorial-to-first-real-match cliff. Add tier-1 bot difficulty modifier (say, aggression 0.4, cheaper deck) for first 3-5 ranked matches.

**Finding** `FINDING-16`: no counter-teaching mechanism. Consider a second tutorial step that faces a scripted enemy deploying a SHOOTER wave, teaching "deploy MELEE or use WALLBREAK."

### 7.3 Persona C — Returning Player (back after 2 weeks)

**What they hit**:
- Login: no "what's new" surface. Season pass + daily chest exist but no proactive highlight.
- Season ends 2026-05-19 (30 days from 2026-04-19). Returning mid-season is fine; returning post-season sees a stale pass.
- Card balance changes (Oracle/Mortar/Beam retune this session) aren't surfaced anywhere. Returning player may have a pre-balance deck expectation.
- Daily chest accrues as single slot — 2 weeks away = 1 chest waiting, not 14. **FINDING**: no catch-up.

**Finding** `FINDING-17`: no return-gift or catch-up loop. Returning-player retention hook missing.

### 7.4 Persona D — Content Creator / Spectator

**What they find**:
- No replay save/load. No share-a-deck URL/code. No friend-challenge. The social layer is effectively nil.
- Matches are watchable in-person (vector aesthetic is screenshot-friendly) but can't be shared as replays.
- Leaderboard is **fake** (`leaderboard.gd` — 5 fixed top players). Post-launch ladder will need real infrastructure.
- Spectator legibility: pseudo-3D perspective + vector silhouettes are readable. Good on this axis.

**Finding** `FINDING-18`: no replay/share infrastructure. Content creators need at least a deck-code export for pre-launch buzz.

### 7.5 Cross-cutting playability

**Tap targets**: card buttons 40×48 (hand), collection tiles larger. Link button 58px wide × 18h. The link button is small for mobile — might need bumping.

**Hit feedback**: covered in prior QA audit; this session improved it (hit SFX, vignette pulse, hit-pause on kills). Still missing: damage numbers, health bar roll-downs.

**Error recovery**: back button always visible; rematch is one tap. OK.

**Accessibility**: colour-opposition cyan/red is the main team cue. Deuteranopia risk: cyan vs red is actually the HIGH-contrast dichromacy-safe pair, so it's fine for red-green blind players. No audio-only cues identified. **OK**.

---

## Pass 8 — Prioritized Fix Plan

*Every finding surfaced across passes 1-7, sorted by severity. Numeric proposals where applicable. No code changes until developer review.*

### 8.1 CRITICAL — ship blockers

| # | Finding | Proposed change | Risk | Dependencies |
|---|---|---|---|---|
| C1 | FINDING-02: no match telemetry persisted | Add `audit/telemetry.gd` autoload: on `match_ended` signal, append a row `{ts, mode, deck_ids, result, duration_s, kills_player, kills_enemy, surge_damage, ot_fired, rift_captured_by, link_fusions}` to `user://matches.csv`. ~50 LOC. | LOW — log-only | none |
| C2 | FINDING-03/04: WALLBREAK (2→1 viable) and SWARM (2→1 long-term) thin | (a) Buff crawler: 22→32 HP (+10), 10→14 damage to push it above saw at same cost. (b) Buff chevron: swarm_count 3→4 OR scout damage 5→6 (chevron's own CardData stats are dead anyway — rebalance to inherit a bonus via unit_data override). | MED — may over-tune | need role-viability re-Pareto after |
| C3 | FINDING-06: synergy graph sparse; 22 of 28 cards have zero synergy | Add 4 new pairs touching long-tail cards: `mortar + shard` (MULTI-LOCK +12%), `revenant + chevron` (GRAVE SWARM +15%), `beacon + dart` (GUIDED FIRE +10%), `chorus + flock` (HIVE SANCTUARY +10%). | LOW — data-only edit in synergies.gd | none |
| C4 | FINDING-08: XP curve overshoots benchmark by 5× → dead content from L11-L15 | Lower coefficient: `xp_to_next(n) = 40n² + 120` (half-rate). Recomputes to ~1,275 matches to L15. Still above benchmark ceiling but within 2.5×, manageable. Alternative: cap at L11 (match unlock levels) + L12-15 as cosmetic. | MED — affects season pass tier math | recompute season reward schedule |

### 8.2 HIGH — meaningful fun / progression

| # | Finding | Proposed change | Risk |
|---|---|---|---|
| H1 | FINDING-07: days-to-max below benchmark floor (too generous) | Raise UPGRADE_COSTS by 1.5×: [30, 75, 150, 300, 600, 1200, 2250, 4500, 9000] = 18,105 total. Pushes days-to-max 1 card from 24.5 → 37 days. Still below benchmark floor but closer. | MED — players in flight lose some value; counter with an XP-to-gold bonus or one-time migration chest |
| H2 | FINDING-13: classic OT has no comeback mechanic | Port SURGE-style 2× mana regen into classic OT. Add ~3 LOC to `match.gd:_advance_phase` OT branch. | LOW |
| H3 | FINDING-15: tutorial-to-ranked cliff (bots too hard immediately) | Add arena_index 0 bot variant at aggression 0.4 (vs current K.VOID_07 at 0.8), fielded for first 3 ranked matches. New persona or aggression override. | LOW |
| H4 | FINDING-16: no counter-teaching tutorial | Add tutorial-2 mission post-first-tutorial: scripted enemy deploys 3 pellets, coach prompts "deploy MELEE or BUFFER to counter." ~60 LOC. | LOW |
| H5 | FINDING-17: no returning-player catch-up | On login, if `last_login > 48h`, grant catch-up chest: gold × min(14, days_absent). Capped at 14 days. | LOW |
| H6 | FINDING-11: classic OT without rift | Port Volley's rift into classic — adapt position (midline, but classic has pseudo-3D trapezoid so coordinate differently). Meaningful engineering work, not a trivial move. | HIGH |

### 8.3 MEDIUM — balance polish

| # | Finding | Proposed change | Risk |
|---|---|---|---|
| M1 | Pareto-dominated: orb, saw, chevron (pre-flock), siphon, hook, crawler | Targeted buffs per card to lift above Pareto: orb pierces on 3rd shot; saw AOE radius 45; chevron scout count 3→4 (see C2); siphon lifesteal 0.5→0.75; hook range 80→100; crawler (covered in C2). | MED — needs Pareto re-check after |
| M2 | FINDING-12: bot AI is basic | Add "save-for-heavy" rule: bot randomly chooses to hold mana for N seconds when it has a card costing ≥6 in hand. Makes opening feel less predictable. | LOW |
| M3 | FINDING-14: pulse+burst+lance cluster is auto-include | Monitor via telemetry (C1); rebalance only if appearance rate >75%. | NONE — data-driven |
| M4 | Shard's 9 DPS/mana outlier | Reduce projectile_count 3→2 OR damage 6→5. Post-change DPS: 12-24 range. Still playable, not dominant. | MED |
| M5 | Vector Link factor 1.6× damage may be too strong | Empirical — needs playtest. Proposed: start at 1.5, playtest, raise if underused. | NONE (leave for now) |
| M6 | FINDING-10: no known exploits, but unfuzzed | Post-launch, add `fuzz_bot.gd` that tries 10 adversarial decks against APEX bot. Report win rates > 70% as findings. | LOW — tooling |

### 8.4 LOW / Polish

- L1: Move magic numbers from unit.gd/match.gd to `data/config/balance.tres` (FINDING-01).
- L2: Flag chevron's unused damage/HP fields (Pass 2.6 anomaly).
- L3: Add a "welcome back" chip on login (FINDING-17 proactive).
- L4: Add deck-code export for content creators (FINDING-18).
- L5: Late-game chest value cliff (1-3% of next upgrade) → scale chest reward with player level.
- L6: L12-L15 empty levels → either compress max level or add rewards.

### 8.5 Adversarial review of this fix plan

Skeptical senior card-game designer critique:

1. **"C2 fixing chevron+crawler will shift the Pareto frontier and create new dominated cards."** True. Need a Pareto re-pass after C2 lands. Add to regression.
2. **"H1 raising upgrade costs while currently-F2P players have banked gold from the generous rate will feel like a nerf."** True. Mitigate with a one-time "migration chest" equal to `(old_total_cost - new_total_cost)` for any card above current max-under-new-rates. Or more gentle: only apply new rates to newly-earned gold going forward.
3. **"H2 porting SURGE regen to classic OT could let defenders stall."** Check: defender typically lacks attack to close out, so faster mana mostly helps attacker deploy more units. Still worth playtesting; could cause stall meta.
4. **"C4 halving XP requires recomputing season_pass XP_PER_TIER or the season fills too fast."** Correct. Must adjust season pass tier XP from 200 to 400 (or raise MAX_TIER from 30 to 45). Dependency noted.
5. **"M1 piecemeal buffing 6 dominated cards one by one is a tuning trap."** Fair. Alternative: holistic re-pass on role families (all SHOOTERS at once, etc.) rather than card-by-card.
6. **"C3 more synergies = more multiplicative power = risk of the Shadow Dagger stacking problem."** Valid. Cap total synergy mult at +50% per unit. Add guard in `_synergy_multiplier`.

### 8.6 Top 5 Must-Fix (developer decision point)

Rank-ordered. Developer decides which land and in what order.

1. **Ship match telemetry (C1)** — without this, none of the below can be iterated with real data post-launch.
2. **Lift dead cards (C2 + M1)** — 6 cards currently below the Pareto frontier is 21% of the roster feeling worthless. Highest ROI for perceived depth.
3. **Widen synergy graph (C3)** — 22 cards have no partners; a one-evening data-only edit fixes this.
4. **Recalibrate XP curve (C4)** — the current slope will feel grindy at launch and leaves L12-15 empty; single formula change.
5. **Arena-1 bot warmup (H3)** — matches the new-player retention benchmark target (60-70% first-10-match win rate).

---

## Summary

- **Pareto frontier 78.6% (target >85%)** — below benchmark by 6.4pp; six cards dominated.
- **Days-to-max 24.5 / 196 days** (target 60-120 / 300-600) — **too generous**; progression ceiling reached in 3× target time.
- **XP curve 2,550 matches to L15** (target 300-500) — **5× over**; player level progression pacing mismatched from card unlocks.
- **Synergy graph sparse** (6 pairs, 22 cards excluded) — limits deck-archetype diversity; 4 proposed additions.
- **Match cards-played 8-15** (target 15-25) — **at/below floor**; deploy cooldown + mana regen likely too conservative.
- **No match telemetry** — **CRITICAL**; can't iterate post-launch without it.
- **Tutorial unloseable → first-real-match cliff** — adds friction to D1 retention.
- **Classic OT lacks comeback mechanic** present in Volley.
- **Nash / Elo / variance / exploit fuzz** — all deferred; require simulation harness not built this session.

Eight findings marked CRITICAL or HIGH survive Pass 8's adversarial review. Top 5 ranked above pending developer decision.
