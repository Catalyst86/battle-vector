# Battle Vector — Balance, Replayability & Playability Audit (v3)
## Engineered for Claude Opus 4.7 at xhigh effort

## Context

You are auditing **Battle Vector**, a PvP tower defense game (Godot 4.6.2, Clash Royale + Vector TD inspired). 28 cards, 8 roles, mana economy, card levels 1–10, trophy ladder, daily chests, bot stand-ins pending networking.

Read these companion docs before beginning:
- **`audit/BALANCE_FRAMEWORKS.md`** — Pareto frontier, Nash equilibrium, Elo simulation, mana curve, tempo/value, power budget, cycle speed. Cite the frameworks explicitly in findings.
- **`audit/INDUSTRY_BENCHMARKS.md`** — reference numbers from Clash Royale, Marvel Snap, Hearthstone for time-to-max, session length, match pacing, win-rate targets, unlock cadence. Compare findings against these.
- **Prior work**: `VECTOR_BATTLES_QA_REPORT.md` + `design/` + `design_handoff_vector_pvp_tower_defense/`. Treat as suspect (Shadow Dagger precedent: prior audit listed 122 DPS, actual was 48).

## Environment

- **Opus 4.7 at `xhigh` effort**. Drop to `high` only for Pass 8 synthesis if tokens are a concern.
- **Claude Code with filesystem + bash**. Several passes require headless Godot execution: `godot --headless --script res://audit/verification/<script>.gd --quit-after <N>`.
- Expected runtime: **8–14 hours** wall-clock across all passes. Monte Carlo simulation is the bulk of this.
- If the audit completes in under 5 hours, you likely skipped simulations. Re-verify.

## Ground Rules

1. **No code changes until Pass 8 is reviewed.**
2. **Every quantitative claim needs one of:** (a) file:line citation, (b) Monte Carlo simulation output with N ≥ 100 runs and reported variance, or (c) the string "STATIC DERIVATION ONLY — not empirically verified" explicitly attached.
3. **Assume existing comments, docstrings, UI tooltips, and prior audit docs lie** until verified.
4. **Confidence flags:** `HIGH` (Monte Carlo verified, variance reported, cross-source reconciled), `MEDIUM` (single-source traced + plausibility check), `LOW` (suspicion only).
5. **All findings land in structured files.** Chat output is a progress summary + decision-requests only.
6. **Flag but do not fix** in passes 1–7. Fixes are designed in Pass 8 with pre/post simulations and only implemented after developer review.
7. **Say "Pass N blocked because X"** if a pass cannot be completed. Never invent data.
8. **Push back on this prompt** in Pass 0 if anything is misordered, redundant, or wrong for this codebase.

## State Files

Under `audit/` throughout the run:

- **`AUDIT_STATE.json`** — resumable progress: `current_pass`, `completed_passes[]`, `cards_audited[]`, `simulations_run[]`, `contradictions_open`, `last_updated`. Update before every long-running operation.
- **`BALANCE_AUDIT_REPORT.md`** — human-readable report, one section per pass.
- **`CONTRADICTIONS.md`** — every case where two sources disagree. Columns: source_a, claim_a, source_b, claim_b, resolution, confidence.
- **`VERIFICATION/`** — all Godot scripts (`verify_*.gd`) and Python scripts (`analyze_*.py`) with their output logs.
- **`SIMULATIONS/`** — Monte Carlo run outputs in CSV. Name: `matchup_<cardA>_vs_<cardB>_L<level>_N<runs>.csv`.
- **`FINDINGS/`** — one file per significant finding. Name: `YYYYMMDD-<severity>-<slug>.md`.
- **`BENCHMARKS_CHECK.md`** — for each metric in `INDUSTRY_BENCHMARKS.md`, your measured value and the delta from benchmark.

**If resumed mid-audit, read `AUDIT_STATE.json` first.** Do not redo completed passes.

## Pass 0 — Methodology, Environment & Determinism

**Goal:** Plan the audit. Verify the environment supports it. Self-critique before executing.

**0A — Read and synthesize.** Read README, `vector/README.md`, prior QA report, `design/` materials, and both companion docs (`BALANCE_FRAMEWORKS.md`, `INDUSTRY_BENCHMARKS.md`). Write `audit/METHODOLOGY.md`:
- Interpretation of the core balance questions for this PvP mana-economy card-level-scaled game
- Specific verification techniques planned per pass (e.g., "Monte Carlo N=500 matchup simulation via headless Godot")
- Proposed pass order — reorder if 1–8 as specified is suboptimal
- Known risks to audit quality and mitigations

**0B — Determinism check.** Write `audit/verification/verify_determinism.gd`. Run the same bot-vs-bot match with a fixed seed twice. Compare outputs byte-for-byte (or structurally if byte-exact isn't feasible due to timing). Report:
- Is the game deterministic given fixed seed? If NO, all subsequent Monte Carlo has a confound — document and flag as a CRITICAL finding.
- Is there a seed-injection hook? If not, how will you fix randomness for verification runs?
- What are the non-deterministic sources? (Frame timing, physics, RNG seed sources — enumerate.)

**0C — Benchmark load.** Read `INDUSTRY_BENCHMARKS.md`. Create `BENCHMARKS_CHECK.md` with every target metric pre-populated, awaiting measured values. This ensures no benchmark gets missed.

**0D — Adversarial self-review.** Write `CRITIQUE_OF_METHODOLOGY.md` as a skeptical senior engineer. Attack the plan. Fold critique back into `METHODOLOGY.md`.

**Stop and wait for developer acknowledgment** before Pass 1.

## Pass 1 — Topology, Inventory, Instrumentation

**Goal:** Map the system. Inventory prior claims. Audit telemetry.

- **Card inventory**: all 28 `.tres` manifest + `CardData` schema.
- **System maps**: match loop (executable pseudocode), damage pipeline, level scaling formula, mana regen, phase transitions, bot AI entry points, gold/XP/chest/arena formulas.
- **Magic number sweep**: grep for hardcoded numeric literals in `.gd` files that should be in `.tres` config. Any balance-relevant number in code is a maintainability bug.
- **Telemetry audit** (previously missing — critical for post-launch iteration):
  - What match events are logged? (Match start/end, card plays, unit deaths, damage dealt, mana spent, wins/losses.)
  - Where do logs go? (Local file, remote, just print?)
  - Can you reconstruct a match from logs alone?
  - If telemetry is absent or weak, this is a CRITICAL Pass 1 finding — without it, you cannot iterate after Steam Next Fest or post-launch with real data.
- **Orphan check**: scripts referencing mechanics not in any `.tres`; `.tres` flags with no script implementation.
- **Populate `CONTRADICTIONS.md`** with every quantitative claim from prior QA report and design docs — all initially `unresolved`.

## Pass 2 — Per-Card Stats: Monte Carlo Verification

**Goal:** Ground-truth every card stat with statistical rigor.

For each of 28 cards at levels 1, 5, 10:

**Static derivation**: DPS, EHP, mana efficiency from `.tres` + scaling formula. Fast first-pass table.

**Monte Carlo verification (required for HIGH confidence)**:
- `verify_card_<n>_L<level>.gd` instantiates the card vs. a standard dummy, runs N=100 controlled scenarios with seed variation, measures damage/HP/timing empirically.
- Report mean, median, standard deviation, min, max for each stat.
- **If mean empirical stat differs from static derivation by >5%, that's a bug** (stat stacking, order-of-operations, floor/cap mismatch). Log to `CONTRADICTIONS.md`.
- Variance itself is a finding: a card with high variance feels unreliable even if mean is balanced.

**Three-way compare**: `.tres` value vs in-game tooltip text vs Monte Carlo mean. All three should agree.

**Pipeline tracing**: trace damage and heal paths through every file. Apply Pareto check — is any stat stacking multiplicatively when intended additive? (Thick Skin pattern.)

**Deliverables**: Master stat CSV (card × level × metric × mean × stdev), Monte Carlo logs, bug list, updated contradictions.

## Pass 3 — Role Balance, Pareto Frontier, Nash Equilibrium

**Goal:** Apply formal frameworks to role and card balance.

**Role viability (Pareto frontier analysis)**:
- For each card, compute its position in (mana, DPS, EHP, utility) space.
- A card is **Pareto-dominated** if another card matches or exceeds it on every axis. Pareto-dominated cards are dead by construction.
- Identify the Pareto frontier — cards that are non-dominated. Healthy card games have all 28 cards on or very near the frontier; dead cards fall significantly below.

**Matchup matrix (Monte Carlo, target 28×28)**:
- For each pair, run N=200 simulated matches with varied decks built around each card. Report win rate of A vs B with confidence interval.
- 28×28 = 784 matchups × 200 runs = 157K simulations. Tractable over a weekend at xhigh. If compute is the blocker, document what's blocked and produce 8×8 role-level as fallback.

**Nash equilibrium check on matchup matrix**:
- Does a stable mixed-strategy equilibrium exist? (Use `analyze_nash.py` via `numpy` + `nashpy` or equivalent.)
- If the meta is rock-paper-scissors-unstable (no Nash), the competitive meta will oscillate forever and feel arbitrary to players.
- Identify the support of the Nash equilibrium — which cards have nonzero probability in optimal play. Cards outside the support are meta-dead.

**Support role scrutiny**: healers and buffers. Heal-per-mana vs fresh-unit-per-mana. Buff-magnitude × duration × buffed-DPS vs buff-mana-cost. If the math doesn't favor the support card, the role is dead.

**Deliverables**: Pareto frontier plot (ASCII or CSV), 28×28 matchup matrix with CIs, Nash equilibrium support, role viability call.

## Pass 4 — Level Scaling, P2W via Elo Simulation

**Goal:** Quantify P2W pressure. The #1 failure mode for this genre.

**Elo simulation**:
- `simulate_elo_progression.py` runs N=10,000 simulated ladder matches between decks of varying levels.
- Compare Elo gap between "median F2P player at day 30" (derived from economy model below) and "max-level player."
- If median F2P Elo is >200 below max, trophy ladder is effectively segregated by payment.

**Economic projection (feed the Elo sim)**:
- Gold/day for median player: daily chest + (expected wins/day × gold/win).
- Gold to max one card (1→10): sum upgrade cost table.
- **Days to max one card. Days to max an 8-card deck.** Compare against `INDUSTRY_BENCHMARKS.md`.
- Arena trophy bracket at which median F2P encounters meaningfully leveled opponents. If bracket < median F2P deck level at that bracket, there's a structural P2W cliff.

**Stat-identity scaling check**: does any card's level scaling disproportionately boost one stat (e.g., +10%/level DPS, +50%/level HP)? This changes the card's role at high level and breaks counter-triangle assumptions from Pass 3.

**Deliverables**: Elo simulation results with distributions, economic projection, explicit P2W rating (LOW/MEDIUM/HIGH) with supporting numbers.

## Pass 5 — Economy vs. Industry Benchmarks

**Goal:** Audit four parallel loops. Compare everything against benchmarks.

For each loop (mana / gold / XP / chest), derive measured values and compare to `INDUSTRY_BENCHMARKS.md` targets. Any metric outside the benchmark range is a finding.

**Mana**: regen rate, cap, total-per-match, avg cards played per match. Target: deck cycle 1.5–2x per match.

**Gold**: per win/loss/draw/chest. Exploit search: loss-farm loops, time-based farms, bot-exploit farms. Write a bot that plays optimally-for-gold and measure gold/hour vs. expected.

**XP**: matches-to-level-15. Unlock cadence — new card per level or dead levels? Compare against Clash Royale's ramp.

**Chest**: daily chest value vs one-match gold value. RNG-variance analysis — can a streak of bad chest rolls leave a player with unusable card distribution?

**Deliverables**: Four mini-reports, `BENCHMARKS_CHECK.md` fully populated with deltas from industry targets, exploit list.

## Pass 6 — Match Flow, Bot AI, Fuzz Testing

**Goal:** Verify match structure produces good games. Stress-test bot AI.

**Match structure**: build-phase decisions, mid-match pacing, stall viability (can a player force a 3:00 draw without attacking?), overtime bias (favor attacker or defender — verify empirically with N=500 overtime simulations).

**Bot AI**:
- Enumerate difficulty tiers and behavior per tier.
- Coherent deck archetype per bot, or grab-bag?
- Scripted vs reactive? If scripted, the pattern is exploitable.

**Fuzz-test the bot**:
- Script N=1000 bot-vs-player-exploit-deck runs.
- Try at least 5 adversarial decks: all-swarm, all-sniper, stall-deck, one-card-spam, no-win-condition-pure-defense.
- Report win rate per adversarial deck. Any exploit deck with >80% win rate at max bot tier is a ladder-breaking finding.

**Determinism re-verification**: re-run Pass 0 determinism check under load. Some non-determinism only appears under stress.

**Flag migration concerns**: every bot-AI finding gets tagged with "changes under human opponents: YES/NO/UNCLEAR" so networking milestone knows what to re-test.

**Deliverables**: Match-flow timing, overtime bias with CI, bot-tier breakdown, fuzz results, exploit list.

## Pass 7 — Multi-Persona Playability & Replayability

**Goal:** Replace the single-lens v2 Pass 7 with four explicit personas.

For each persona, produce a separate findings section. A finding appears under the persona(s) affected.

**Persona A — Min-Max Player** (tries to break the game):
- Dominant strategies surfaced in Pass 3/4/6.
- Exploits from Pass 5/6.
- Is there depth for them, or is the game "solved" at the top?

**Persona B — New Player** (first hour):
- Tutorial coverage vs what they actually need (counters, mana, walls).
- First-match win probability — should be 60–70% for retention.
- Onboarding friction: any screen they might get stuck on.
- Information density: can they read card info on mobile in <1s?

**Persona C — Returning Player** (back after 2 weeks):
- Login flow: is there context for what changed?
- Does daily-chest/season structure exist? If not, nothing welcomes them back.
- Are their decks still viable post-any-balance-change?

**Persona D — Content Creator / Spectator**:
- Is there skill expression visible from outside the player's head?
- Are matches watchable (clear state, readable action)?
- Replay save/load? Share-a-deck feature? Friend challenges?

**Cross-cutting playability**: tap targets, hit feedback, death feedback, error recovery, accessibility (colorblind-safe, no audio-only cues).

**Deliverables**: Four persona sections, cross-cutting playability list sorted by severity.

## Pass 8 — Fix Plan with Pre/Post Sim + Regression Spec + Adversarial Review

**Goal:** Prioritized fix plan where every change is validated before commit.

**8A — Draft fix plan.** For each finding across passes 1–7:
- Severity, Category, Files affected
- **Specific proposed change** (numbers, not directions)
- Expected player-experience impact
- Risk of the change
- Dependencies

**8B — Pre/post simulation for every proposed balance change.**
- Re-run the relevant Pass 2/3/4 simulation with the proposed values.
- Report: "Before: metric X = Y. After: metric X = Z. Projected meta impact: ..."
- If the simulated post-change state is worse or unchanged, revise the proposed change. Do not ship fixes that don't simulate better.

**8C — Regression test spec.**
- For each fix, write `regression/<fix_id>.gd` — a script that verifies the fix holds. Post-implementation, these scripts get run to confirm nothing regressed.
- Include at least 3 per fix: does-fix-apply, does-not-break-X, does-not-break-Y.

**8D — Adversarial self-review.** `CRITIQUE_OF_FIX_PLAN.md` as skeptical senior card-game designer with 3 shipped titles. Attack the plan:
- Symptoms-not-causes?
- Cascade risks?
- "Bugs" that are actually intentional features?
- Shipped-card-game requirements absent from the plan?

Fold critique back. Mark which items survived review.

**8E — Top 5 summary.** First page of the fix plan: top 5 fixes the developer must decide on before scope expansion. Specific, numeric, justified.

**Stop and wait for developer review.**

---

## What This Audit Will NOT Do

To set expectations honestly:
- It will not play the game as a human would (no "does it FEEL good" except through proxy metrics).
- It will not replace real playtesting. Steam Next Fest is still where the ground truth lives.
- It will not catch balance issues that only emerge against real human opponents who innovate (bot AI is a proxy, not a replacement).
- It will not audit monetization beyond basic F2P pacing, because this is a pre-launch solo-dev title.
- It will not evaluate art, sound, or feel beyond what surfaces in instrumentation.

## Notes for the Auditor

- Developer prefers direct execution, minimal explanation. Chat = progress + decisions only.
- The game is pre-networking — flag every finding with "changes under human opponents: YES/NO/UNCLEAR."
- Pass 0 is non-skippable. Planning-phase fault detection is the highest-leverage use of 4.7's capabilities.
- Running verification scripts is non-optional. Static reasoning + doc trust is exactly how Shadow Dagger (122 → 48 DPS) happened.
- If you finish in under 5 hours you skipped the Monte Carlo. Go back.
