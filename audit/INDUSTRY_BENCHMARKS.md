# Industry Benchmarks — Reference for Battle Vector Audit

Numbers here are approximate — drawn from public developer talks, community data-mining, and published patch notes for Clash Royale (CR), Marvel Snap (MS), Hearthstone (HS), Legends of Runeterra (LoR), and Brawl Stars (BS). Use these as targets for Battle Vector's metrics, not absolute rules. "Within range" = healthy. Significantly outside = finding.

## Match Pacing

| Metric | CR | MS | HS | LoR | Battle Vector target |
|---|---|---|---|---|---|
| Avg match length | 3:00 + 1:00 OT | 2:30 | 8–12 min | 6–10 min | 3:00 + 1:00 OT ✓ |
| Decisions per minute | 15–20 | 6–8 | 3–5 | 5–8 | 10–20 |
| Mana/resource generated per match | ~20 elixir | ~40 energy | ~55 mana | ~35 mana | Derive + compare |
| Cards played per match | 15–25 | 12 | 15–25 | 10–15 | 15–25 |
| Deck cycle per match | 1.5–2.5x | 1x (6/12) | 0.8–1.2x | 1x | 1.5–2x |

**CR-specific for PvP TD**: avg match 3:00 + 1:00 OT with average 16 cards played per player — this is the closest analog for Battle Vector and should be the primary comparison.

## Session Structure

| Metric | CR | MS | HS | Target |
|---|---|---|---|---|
| Matches per session (median) | 4–6 | 3–5 | 3–6 | 4–6 |
| Session length (median) | 15–25 min | 12–20 min | 30–45 min | 15–25 min |
| Daily active ratio (matches/day) | 6–10 | 4–6 | 4–8 | 6–10 |
| Daily chest / login reward | Yes | Yes | Yes (quest) | Yes ✓ |
| First-win-of-day bonus | Yes | — | Yes | **Should exist** |

If the game has no natural stopping cue every 4–6 matches (chest full, daily done, etc.), players either stop early (low retention) or play too long (burnout). Both hurt D7 retention.

## F2P Economy Pacing

| Metric | CR | MS | HS | Target |
|---|---|---|---|---|
| Days to max 1 card (F2P median) | 60–120 | 30–60 | 15–30 per meta-deck | **60–120** |
| Days to max a competitive deck | 300–600 | 180–360 | 45–90 per deck | **300–600 acceptable, <300 generous, >600 P2W-suspicious** |
| New-card unlock cadence (early) | 1–2 per level for first 5 levels | ~1 per week | 1 expansion / 4mo + catch-up | **Every level 1–5 should unlock something** |
| Chest RNG duplicate protection | Yes (pity) | Yes (collector) | Yes (dust crafting) | **Should exist** — 10 copies of a useless card is a retention killer |
| Gold per daily chest (relative to upgrade cost) | 2–5% of next upgrade | N/A (different model) | N/A | **2–5% of next card-level upgrade cost** |

**Critical rule of thumb**: "days to max 1 card" < 30 means upgrades are meaningless (no aspiration). > 180 means upgrades are F2P-hostile. 60–120 is the industry sweet spot.

## Win Rate Targets

| Metric | Target | Rationale |
|---|---|---|
| New player first 10 matches | 60–70% wins | Retention requires early success |
| New player matches 10–50 | 55–60% wins | Gentle ramp into skill-based matching |
| Ladder equilibrium (settled rating) | 48–52% | Matchmaking working correctly |
| Top 100 players vs median F2P | <65% for max-level player | P2W boundary — >65% means pay-to-win is real |
| Best deck vs worst deck (same levels) | 55–65% | Clear hierarchy is fine; >70% = card balance broken |
| Matchup matrix variance (same-skill Monte Carlo) | σ < 15% | High variance = coin-flip game |

## Card Roster & Role Coverage

| Metric | CR | MS | HS | Target for Battle Vector |
|---|---|---|---|---|
| Total cards at launch | 42 | 150+ | 200+ per expansion | 28 ✓ (small but intentional) |
| Roles/archetypes | ~6 | ~8 | ~9 classes × 3 | 8 ✓ |
| Cards per role | 6–8 | ~18 | 20–30 | **3–4 per role** — this is tight; every card matters |
| Cards on Pareto frontier | 80%+ | 70%+ | 60%+ (more variance tolerable at higher count) | **>85%** (low card count means each dead card is felt hard) |
| Nash equilibrium support size | 10–15 cards | 20–30 | 15–25 | **≥12 cards** (if <12 of 28 are in the meta, 57%+ of roster is dead) |

**Critical**: with only 28 cards, Battle Vector cannot afford dead cards. Dead card ratio > 20% is a CRITICAL finding.

## Deck Construction

| Metric | CR | MS | HS | Target |
|---|---|---|---|---|
| Deck size | 8 | 12 | 30 | 8 ✓ |
| Avg mana/energy cost across deck | 3.2–3.8 | 3.5 | 3.0–3.5 | 3.0–4.0 |
| Decks in top-10 meta distinct archetypes | 4–6 | 5–8 | 6–10 | **≥4 distinct archetypes in viable meta** |
| Single card appearance rate across top decks | <60% | <50% | <40% | **<60% for any single card** (higher = auto-include = dead slot) |

## Match Structure

| Metric | CR | Target |
|---|---|---|
| Build/prep phase duration | 0–5s countdown | 3–8s is fine; >10s feels slow |
| Overtime trigger | Draw at 3:00 | Draw or explicit trigger ✓ |
| Overtime duration | 1:00 | 0:45–1:30 acceptable |
| Overtime mana regen rate | 2x normal | **Should accelerate** — forces decisions, reduces stall |
| Stall-to-draw viability | Low (mana regen punishes defense-only) | **Low is the target** — stalling should be losing strategy |
| Win probability decided before final 30s | <40% | If >40% of matches are decided early, late game is noise |

## Bot AI Benchmarks (for pre-networking phase)

| Metric | Target |
|---|---|
| Tier 1 (tutorial) bot win rate vs brand-new player | 30–40% |
| Tier 2–3 (early arena) bot win rate vs competent player | 40–50% |
| Top-tier bot win rate vs top-tier human | 45–55% |
| Exploit deck vs any bot tier | <70% win rate (80%+ = ladder-breaking) |
| Coherent deck archetype per bot | Required — grab-bag decks break matchup learning |
| Bot difficulty scales with trophy level | Yes, required |

## Progression Structure

| Metric | CR | BS | Target |
|---|---|---|---|
| Player levels | 1–15 (KingTower) | 1–35 | 1–15 ✓ |
| Content unlocks per level | New card/arena most levels | New brawler some levels | **Avoid dead levels — every level should unlock something visible** |
| XP-to-next-level curve | Super-linear | Super-linear | Super-linear expected |
| Matches to hit max player level (F2P) | 300–500 | 200–400 | **300–500 is reasonable, <150 too fast, >800 grind** |

## Retention Targets (for Post-Launch Reference)

These are industry D1/D7/D30 retention targets for F2P mobile card games. Can't measure pre-launch but design should aim for:

| Metric | "Good" | "Great" |
|---|---|---|
| D1 retention | 35% | 45% |
| D7 retention | 15% | 22% |
| D30 retention | 6% | 10% |

Retention is driven primarily by (1) first-hour experience, (2) daily-loop hook quality, (3) progression legibility. Balance findings feed into all three.

## Red-Flag Numbers (Automatic Critical Findings)

If the audit surfaces any of these, flag as CRITICAL:
- Days to max a competitive deck > 600
- Elo gap median-F2P to max-level > 250
- Cards on Pareto frontier < 70%
- Nash equilibrium support < 10 cards (of 28)
- Match outcome decided before 2:00 mark > 50% of the time
- Exploit deck win rate vs max-tier bot > 80%
- New-player win rate first 10 matches < 50%
- Match coin-flip variance (σ) > 20%
- Any role with zero cards in Nash support

## Sources & Caveats

Numbers are derived from:
- Supercell developer talks and CR patch-note analysis
- Marvel Snap design interviews (Second Dinner public content)
- Hearthstone balance philosophy docs
- Mobile F2P retention data (GameAnalytics industry reports)
- Community data-mining of ladder distributions

These are industry **reference points**, not laws. Deviation is acceptable when justified by a specific design intent. What's not acceptable is deviation without awareness. The auditor's job is to measure and compare — the developer decides what to do with a deviation.
