# Adversarial Self-Review — Methodology Critique (Pass 0D)

*Skeptical senior engineer attacking the plan in METHODOLOGY.md. Each critique either gets folded back or explicitly accepted as a limitation.*

## 1. "Static derivation is rigorous" is overconfident

The methodology treats static derivation as a solid substitute for Monte Carlo. It isn't — not in this codebase. Reasons:

- **Buffer auras are per-frame.** `unit.gd:_refresh_effective_damage` iterates the friendly BUFFER list each frame and multiplies `base_damage` by the aura. A card's "DPS on paper" changes based on who's standing next to it at the moment of firing. Static math assumes no buffers; actual damage is variable.
- **Volley vs classic math diverges.** `speed_mult=0.85` applies only in volley. Projectile speed is multiplied by 0.8 in volley. `unit.gd` branches on `_volley_gun_target` in three places. Per-mode DPS is not a single number.
- **Fused units skip `level_mult`.** `_try_fuse` in match_volley sets `fused.level_mult = 1.0` AFTER `_ready` ran. Static math for "Vector Link output" has to reproduce that override or it lies by the level multiplier amount.

**Folded back:** every per-card DPS calculation will be reported as TWO numbers — `classic_static_DPS_no_buff` and `volley_static_DPS_no_buff` — and every report row annotates the multiplier chain used. Fused-unit DPS gets its own section.

## 2. Pareto frontier at L5 is a snapshot, not a verdict

The methodology says "run Pareto at L5 stats." But a card might be Pareto-dominated at L5 and dominant at L10 if its stat scaling is higher — or the reverse. Flagging one level masks diagonal shifts.

**Folded back:** Pareto frontier run at L1, L5, L10 separately. A card is called dominated only if dominated at *all three* levels.

## 3. "Role coverage" isn't role balance

Counting cards per role doesn't tell you if the role is viable. Healers might all exist but still be mathematically underpowered. The methodology mentions this but needs a sharper bar.

**Folded back:** for each role, compute heal-per-mana vs fresh-unit-HP-per-mana (for healers), buff-bonus × ally-DPS × duration vs raw-unit-DPS-per-mana (for buffers), etc. Role viability is a computed number, not a count.

## 4. Ignoring the bot's deck selection biases all "P2W" estimates

`bot_personas.gd` hardcodes bot decks per arena. A "days-to-max-deck" estimate assumes you're fighting a meta-representative opponent, but the bot deck is a fixed curated list. P2W projection must be framed as "vs the bot at arena N" not "vs meta at arena N" — those are different answers.

**Folded back:** Pass 4 reports P2W relative to the bot persona's deck at the arena gate, and explicitly notes the fixed-deck caveat. Real P2W under human opponents is `UNCLEAR — changes under human opponents: YES`.

## 5. The prompt says "no code changes until Pass 8" — but the audit expects file deltas for findings

The methodology should be explicit: during passes 1-7, I only WRITE to `audit/` and DO NOT touch `vector/`. Even obvious bugs (like a typo in a .tres) get logged, not fixed. Pass 8 is when fixes get proposed, and the developer green-lights before implementation.

**Folded back:** audit-only read on `vector/` through Pass 7. Pass 8 produces fix *proposals* with numeric diffs; implementation happens only after developer review.

## 6. "Playtest-feel" issues get lost in a static audit

Game feel (hit-pause depth, screen shake curve, audio layering) doesn't surface in static analysis. The methodology acknowledges this but risks producing a balance report that ignores the actual retention-driving dimension.

**Folded back:** Pass 7 personas get explicit feel-oriented observations where code reveals them (e.g. "shake amount = 3.0 + 0.5×hits is linear — a kill-streak of 10 drops 8.0 shake units per kill, may be too chaotic"). These are observations, not numeric findings.

## 7. Bot AI is a stand-in, not a balance source

Every finding based on "the bot plays like this" is contaminated by the fact that the bot is scripted-ish and will change when humans arrive. The prompt requires tagging; the methodology must not let me forget.

**Folded back:** every Pass 3/4/6 finding carries an explicit **"changes under human opponents: YES/NO/UNCLEAR"** tag in the report. Default to YES unless the code is provably deterministic independent of opponent type.

## 8. "Benchmarks are targets, not laws"

The methodology treats `INDUSTRY_BENCHMARKS.md` as the arbiter. But a benchmark like "3-4 cards per role" is descriptive of CR/MS, not prescriptive. A design intent of 2 cards per role + depth is not automatically a failure.

**Folded back:** benchmark deviations get reported with a "design intent: known-deliberate / unknown-deviation" flag. An unknown-deviation is a finding; a known-deliberate one is a documentation gap (maybe still a finding, just a different kind).

## 9. Vector Link + Rift + Surge + Catch-up regen are new this session

These systems ship untested. The audit prompt was written against a simpler game. I have to either audit them (which means inventing target behaviour since no benchmark exists) or explicitly carve them out.

**Folded back:** new-system audits get their own sub-section in Pass 3 and Pass 6, flagged `STATIC — needs playtest`. Targets will be inferred from design intent (pitch in the chat history) rather than benchmarks.

## 10. Token budget risk

8 passes with full structured reports will produce ~20-50K tokens of output. Hitting the context ceiling could truncate Pass 8 — the most actionable pass. Mitigate by writing compact tables, citing rather than quoting code, putting long logs in sub-files.

**Folded back:** every pass aims for ≤2K words in its report section; overflow goes to sub-files under `audit/VERIFICATION/` or `audit/SIMULATIONS/`.

## What survives review

- Static-analysis-only audit is legitimate but must be labeled.
- Deferred items must be actionable, not vague.
- Every finding tags "changes under human opponents".
- Pareto at three levels, not one.
- Role viability computed, not counted.
- Playtest-feel observations get their own lane and don't contaminate balance findings.

## What didn't survive

- Any confidence rating of HIGH for a dynamic-stat claim without simulation. Downgraded.
- The assumption that L5 is representative. Replaced with three-level sweep.
- The assumption that bot-vs-player findings transfer. Flagged per-finding.
