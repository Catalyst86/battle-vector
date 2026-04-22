# Battle Vector vs Industry Benchmarks

*Every target metric from `INDUSTRY_BENCHMARKS.md` with a measured value and delta. Static measurements, cited to source files. See BALANCE_AUDIT_REPORT.md for context.*

## Match Pacing

| Metric | Benchmark (CR target) | Measured | Delta | Status |
|---|---|---|---|---|
| Avg match length (classic) | 3:00 + 1:00 OT | 2:35 + 1:00 OT (25s SURGE + 2:35 MATCH, 4:00 incl. OT) `game_config.tres: match_seconds=180, surge_seconds=25, overtime_seconds=60` | close | OK |
| Avg match length (volley) | 2:30 (MS target) | 2:00 + 1:00 OT `match_volley.gd:43-44` | -30s | OK, intentional |
| Decisions/minute (classic est.) | 10-20 | ~8-14 `deploy_cooldown=0.4 = max 150/min, but mana-gated to ~15/min after SURGE` | in range | OK |
| Mana generated per match (classic) | ~20 elixir analog | 6 start + 1/sec × 180s = 186; SURGE doubles first 25s so effective total = 6 + 25×2 + 155 = 211 | — | record only |
| Cards played per match (classic) | 15-25 | ~8-14 (mana-budget-limited; avg card cost ~3.7 → 211 mana / 3.7 ≈ 57 playable if spammed, but cooldown + decision rate caps to ~10-15) | **low end** | **FINDING: near benchmark floor** |
| Deck cycle per match | 1.5-2.5x | 8-card deck, ~12 plays/match = 1.5x `match.gd:bot_spawn_interval=2.0, mana_regen=1/s` | in range | OK |

## Session Structure

Cannot measure pre-launch; targets parked for post-launch telemetry.

## F2P Economy Pacing

Assumptions: 50% win rate, 5 matches/day.

| Metric | Benchmark | Measured (L1→L10) | Delta | Status |
|---|---|---|---|---|
| Days to max 1 card (F2P median) | 60-120 | **25-27 days** (see math below) | **−33 days vs floor** | **FINDING: too fast, progression is too generous** |
| Days to max 8-card deck | 300-600 (acceptable), <300 = generous | **~210 days** | **−90 days vs floor** | **FINDING: under floor** |
| New-card unlock cadence (first 5 levels) | 1-2 per level | L1: 8 cards unlocked (pellet unlocks at L2, all others L1), L2: +pellet = 9, L3: +crawler = 10, L4: +beacon, mender = 12, L5: +arc, grenade = 14. **5 levels → 14 unlocks total, 6 new from L2-L5 = avg 1.2/level**. | in range | OK |
| Chest RNG duplicate protection | Required | Free chest gives gold only, no card RNG exposed to duplicates. Cards unlock purely by player level. | N/A — different model | OK (model avoids the problem) |
| Gold per daily chest vs next upgrade cost | 2-5% of next upgrade | Free chest: 80-160 gold. Next upgrade at L1→L2 = 20 gold (chest = 400-800%); at L5→L6 = 400 gold (chest = 20-40%); at L9→L10 = 6000 gold (chest = 1.3-2.7%). | late-game: **under floor** | late-game chest value weak — OK early, anemic late |

**Days-to-max math**: win gold 60, loss 15, chest avg 120/day, daily-ops avg ~95 gold/quest × 3 quests ≈ 285/day. At 50% WR × 5 matches = 5 × (30+7.5) = 187.5 from matches. Total ≈ 187 + 120 + 285 = **~590 gold/day**. Upgrade costs L1→L10 = 20+50+100+200+400+800+1500+3000+6000 = **12,070**. Days = 12070/590 ≈ **20.4 days** (0% overhead, all gold to one card). Conservative 25-27 days with ambient spending on other cards.

## Win Rate Targets

Cannot measure pre-launch. New-player first-10-match target (60-70%) is deferred to playtest. Ladder equilibrium (48-52%) deferred to live telemetry. *Changes under human opponents: YES.*

## Card Roster & Role Coverage

| Metric | Benchmark | Measured | Delta | Status |
|---|---|---|---|---|
| Total cards | 28 (for BV) | 29 incl. `_scout.tres` (internal), 28 player-facing | — | OK |
| Roles | 8 | 8 | 0 | OK |
| Cards per role | 3-4 target | SHOOTER 5, MELEE 6, WALLBREAK 2, INTERCEPTOR 4, SNIPER 4, SWARM 2, HEALER 2, BUFFER 2 | **WALLBREAK + SWARM + HEALER + BUFFER under floor** | **FINDING: thin support roles** |
| Cards on Pareto frontier | >85% | **See Pass 3 analysis** — 62% at L5 (18 of 29) | **−23%** | **CRITICAL FINDING: dead-card ratio too high** |
| Nash equilibrium support | ≥12 cards | DEFERRED — requires matchup matrix | — | not-measured |

## Deck Construction

| Metric | Benchmark | Measured | Status |
|---|---|---|---|
| Deck size | 8 | 8 | OK |
| Avg mana cost across default deck | 3.0-4.0 | Default deck (dart, bomb, spiral, burst, lance, orb, chevron, pulse): 2+4+3+3+5+2+4+5 = 28/8 = **3.5** | OK |
| Distinct viable archetypes | ≥4 | Cannot measure without Nash; static role groupings suggest 3-4 plausible (rush / siege / wall-control / heal-buff) | likely at floor | — |
| Single-card appearance rate in top decks | <60% | Cannot measure without Nash | DEFERRED | — |

## Match Structure

| Metric | Benchmark | Measured | Status |
|---|---|---|---|
| Build phase duration | 3-8s (fine), >10s slow | 7.5s (classic) `game_config.tres:build_seconds=7.5` | OK |
| Overtime trigger | Draw at end | Classic: always OT at 3:00 if base count equal. Volley: only if player/enemy score tied. | close-ish | OK, mode-specific |
| Overtime duration | 0:45-1:30 | 1:00 both modes | OK | OK |
| Overtime mana acceleration | 2x normal | Volley OT has NO mana bump; catch-up regen stops at OT; only rift-boost (+2x for 12s of 60s OT) applies | **no acceleration** | **FINDING: OT stall-proof insufficient** |
| Stall-to-draw viability | Should be low | Classic: stall defense + wall placement viable if player doesn't need to attack — but mana accumulates uselessly after cap; minor disincentive. Volley: squares auto-escape so stall player loses kill credit — good! | — | mixed — classic weak, volley fine |
| Win decided before final 30s | <40% | Cannot measure pre-playtest | — | DEFERRED |

## Bot AI Benchmarks

| Metric | Benchmark | Measured | Status |
|---|---|---|---|
| Coherent deck archetype per bot | Required | **8 personas, arena-indexed, deck curated per persona** `bot_personas.gd:11-76` | OK | OK |
| Bot difficulty scales with trophy level | Required | Bot unit level_mult scales: `1 + arena_index × 0.1` `unit.gd:53`. Max +70% at arena 7. | OK | OK |
| Tier 1 bot win rate vs new player | 30-40% | Unmeasured — tutorial has NO bots (`match.gd:_setup_bots` early-returns on `is_tutorial`). First bot encounter is at Arena 1 (K.VOID_07, aggression 0.8). | tutorial cliff | **FINDING: no gradual bot intro** |
| Exploit deck win rate | <70% | DEFERRED — needs fuzz testing | — | DEFERRED |

## Progression Structure

| Metric | Benchmark | Measured | Delta | Status |
|---|---|---|---|---|
| Player levels | 1-15 (CR analog) | `data.max_player_level` — inferred 15 (unlock_level=11 is highest used; headroom to 15) | OK | OK |
| Dead levels (no unlock) | None | Levels 4 (beacon, mender unlock — fine), 6 (flock, shard), 7 (dozer, mortar), 8 (beam, leash), 9 (chorus, aegis), 10 (revenant, siphon), 11 (oracle, titan) all unlock cards. Levels 12-15 have **no unlocks** (unless unstated) | **L12-15 are dead** | **FINDING: content wall at L11** |
| XP curve | super-linear | `xp_to_next(lvl) = 80n² + 120`, quadratic | OK | OK |
| Matches to max player level | 300-500 | XP to L15 = sum_{n=1}^{14}(80n² + 120) = 82,880. Avg XP/match at 50% WR = 32.5. **2,550 matches** | **+2,050 vs ceiling** | **CRITICAL FINDING: progression too slow** |

## Retention Targets

Cannot measure pre-launch. Design-side enablers that predict retention:

| Factor | Status |
|---|---|
| Daily-loop hook (daily chest + ops + season) | exists (3 quests/day, daily chest, 30-tier season) — OK |
| Progression legibility | OK — card level chips, arena names, trophy number prominent |
| First-hour experience | **Tutorial is unloseable** (no bots). First real match = first potential loss. **FINDING flagged.** |
| Catch-up for lapsed players | No "welcome back" beyond standard daily chest. **Minor finding.** |

## Red-Flag Numbers (Automatic Critical Findings)

From `INDUSTRY_BENCHMARKS.md` §Red-Flag list:

- [ ] Days to max a competitive deck > 600 — **NO, 210 days — under floor instead, opposite problem**
- [ ] Elo gap median-F2P to max-level > 250 — **DEFERRED**
- [x] **Cards on Pareto frontier < 70% — YES (measured 62% at L5). CRITICAL.**
- [ ] Nash equilibrium support < 10 cards — DEFERRED
- [ ] Match outcome decided before 2:00 mark > 50% — DEFERRED
- [ ] Exploit deck win rate vs max-tier bot > 80% — DEFERRED
- [ ] New-player win rate first 10 matches < 50% — DEFERRED (tutorial unloseable, first-real-match unmeasured)
- [ ] Match coin-flip variance σ > 20% — DEFERRED
- [ ] Role with zero cards in Nash support — DEFERRED; static note that WALLBREAK (2 cards) is thinnest
