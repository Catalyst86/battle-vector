# Battle Vector Audit — Methodology (Pass 0)

*Following `BATTLE_VECTOR_AUDIT_PROMPT_V3.md`. See `CRITIQUE_OF_METHODOLOGY.md` for adversarial self-review.*

## Scope acknowledgement & pushback (Pass 0D honesty)

The v3 prompt expects 8-14 hours wall-clock with Monte Carlo at N≥100 for per-card stats, N=200 for matchups (784 × 200 = 157K simulations), N=10K for Elo, N=1K for bot fuzz. That demands a headless Godot simulation harness this codebase does not have. Building such a harness from scratch — a bot that can play both sides, a deterministic match stub, a result collector — is itself 4-8 hours of focused engineering, and the Shadow Dagger precedent (122 vs 48 DPS) warns that naively re-implementing combat math in Python will diverge from actual game behaviour.

**I do not have time or tools to run Monte Carlo at the prescribed sample sizes in this session.** I will not pretend to. Per the prompt's own rule §2, every quantitative claim in this audit that lacks Monte Carlo backing will be tagged **`STATIC DERIVATION ONLY — not empirically verified`**.

What I *can* do in this session:

1. **Static derivation at rigour** — read every `.tres` + the combat pipeline in `unit.gd`/`projectile.gd`, trace all multipliers (level_mult, synergy, buffer auras), compute DPS / EHP / mana-efficiency for every card at L1 / L5 / L10. Cross-check .tres value, computed value, and (where feasible) the tooltip text.
2. **Formal static analysis** — Pareto frontier on the computed stat table, power-budget per mana tier, mana curve distribution. These require no Monte Carlo.
3. **Economic projection** — read `player_profile.gd` upgrade costs + chest values + XP curve; derive days-to-max-card and days-to-max-deck under realistic match cadences.
4. **Code audits** — match-flow phase transitions, bot AI enumeration, overtime bias from the trigger logic, telemetry coverage, orphan-flag scan.
5. **Benchmark comparison** — every measurable metric compared against `INDUSTRY_BENCHMARKS.md` with the delta reported.
6. **Persona-driven playability review** — four personas, code-backed observations only.

What I **cannot** do and will flag explicitly:

- **Nash equilibrium on the matchup matrix.** Requires 784 Monte Carlo-verified matchup cells. Marked `DEFERRED — requires simulation harness`.
- **Elo gap P2W quantification.** Requires ladder simulation at N=10K. Marked `DEFERRED`.
- **Bot fuzz testing for exploit decks.** Requires N=1K runs per adversarial deck. I will identify likely exploit archetypes via static reasoning and mark them `STATIC — needs fuzz confirmation`.
- **Variance / coin-flip detection.** Can only be measured empirically.
- **Pre/post simulation for fix plan.** Pass 8 fixes get static impact projections, not before/after sims.

## Interpretation of the core balance questions

This game is a real-time PvP tower defense with cards-as-units (Clash Royale lineage) plus a new Volley mode (unit + gun hybrid). Core balance questions:

1. **Is every card viable?** Proxy: Pareto frontier ratio. Target >85% per benchmarks (§Card Roster).
2. **Is the meta stable?** Nash support proxy: count of cards with plausible-dominant-strategy positions. Deferred for real test.
3. **Is there a P2W cliff?** Proxy: days-to-max vs F2P gold-per-day; identify arena where level deficit becomes outcome-determining.
4. **Does a match read?** Match timing + mana-per-match + cards-played-per-match vs benchmark ranges.
5. **Are the new systems (Surge, Rift, Vector Link) balanced?** No empirical data yet; static reasoning + red-flag call-out.

## Pass order

Following the prompt's order 0→8. I reorder nothing — the prompt's sequence matches good static-audit practice. Exception: parts of Pass 3 (Nash) and Pass 4 (Elo) are DEFERRED not skipped; their sections in the report will be stubs pointing at what remains to verify.

## Primary verification techniques per pass

| Pass | Technique | Empirical depth |
|---|---|---|
| 1 | File-read inventory + grep magic numbers + telemetry grep | Full |
| 2 | Derive from .tres + unit.gd math | Static only |
| 3 | Pareto frontier on L5 stats; role-coverage count | Static only; Nash deferred |
| 4 | Economic projection from PlayerProfile + chest configs | Static only; Elo deferred |
| 5 | Measure against INDUSTRY_BENCHMARKS.md | Full (static metrics) |
| 6 | Read phase machines + bot loop | Static only; fuzz deferred |
| 7 | Read onboarding + coach + UI; persona lens | Full (static) |
| 8 | Prioritise findings; numeric proposals | Static projections only |

## Shadow-Dagger mitigation

The prompt cites a prior audit that reported 122 DPS when the real number was 48 — a 2.5× overstatement from trusting comments/docs. To mitigate:

- **I will read the actual multiplier chain** (`card.damage × level_mult × _synergy_multiplier() × buffer_aura_mult × projectile_count`) and reproduce the math inline in findings, not cite a summary.
- **I will cross-check** .tres `damage` × .tres `fire_rate` reciprocal against the derivation.
- **I will not trust** prior docs including `VECTOR_BATTLES_QA_REPORT.md` without re-reading the code.
- **Where ambiguity exists** (e.g. "is fire_rate cooldown or rate?") I will cite the using line to resolve.

## Confidence flags used in this audit

- **HIGH** — Verified by reading the authoritative source file (e.g. .tres + unit.gd) and reproducing the derivation inline. Reserved for static claims where the code is the authority.
- **MEDIUM** — Single-source traced, plausibility-checked against adjacent stats, but derivation uncertainties remain (e.g. "does the level_mult apply to HP regen?" without ground truth).
- **LOW** — Suspicion or symptom-level finding without deep verification.

Anywhere I say "probably" or "likely" without a file:line, that's LOW.

## Known audit-quality risks

1. **Static combat math diverges from runtime.** Mitigated by reading the exact pipeline; not eliminated.
2. **Inner `speed_mult` field added this session (volley-only, 0.85).** I will verify this is applied in the right places before quoting on-field DPS.
3. **Vector Link fusion post-overrides stats after _ready.** Fused units bypass `level_mult`. I'll note this as a balance hazard to flag.
4. **Recent surge + rift + catch-up regen are new and untested.** I will flag these as structurally novel and likely-miscalibrated without actually measuring.
5. **Synergies are implemented but sparse.** Pass 3 will report the synergy graph.
6. **I may miss emergent behaviour** — stall loops, swarm overflow, etc. — that only surfaces in play. Deferred to user playtest.

## Output discipline

- State files live under `audit/`.
- Chat output per pass: progress line + key finding summary + pointer to the report file.
- All findings go into `audit/BALANCE_AUDIT_REPORT.md` sectioned per pass; critical ones duplicate into `audit/FINDINGS/<date>-<sev>-<slug>.md`.
- `BENCHMARKS_CHECK.md` gets populated incrementally.
- `CONTRADICTIONS.md` opens with every quantitative claim in the prior QA report as `unresolved`.

## Deferred-work registry

Anything `DEFERRED` in the final report should be actionable — the developer should be able to pick it up later or hand it to a simulation specialist. Each deferred item will include: exact scope, required harness, expected runtime, expected output.
