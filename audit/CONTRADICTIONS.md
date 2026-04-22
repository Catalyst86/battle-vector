# Contradictions Log

*Every case where two sources disagree. Resolved where possible; flagged otherwise. Static-analysis only; no Monte Carlo.*

| # | Source A | Claim A | Source B | Claim B | Resolution | Confidence |
|---|---|---|---|---|---|---|
| 1 | Prior QA report (v1) | "Oracle: 21.4 DPS/mana, dominant outlier" | Code: `oracle.tres` damage=60, fire_rate=2.0 → 30 DPS; cost=7 → 4.29 DPS/mana | **Prior report used `damage × fire_rate / cost`; formula inverted. Corrected in QA report corrigendum (`VECTOR_BATTLES_QA_REPORT.md` §Corrigendum, commit fb2a65b).** | HIGH |
| 2 | Prior QA report | "Synergies are display-only, never applied" | Code: `synergies.gd` + `unit.gd:_synergy_multiplier` both called in `_ready` | **Synergies are applied. Prior comment in synergies.gd:5-6 was stale. Fixed in commit 8f8617d.** | HIGH |
| 3 | Balance audit frameworks | `fire_rate` interpreted as shots-per-second by some tools | Code: `unit.gd:315 _fire_cd = card.fire_rate` → cooldown in seconds | **Cooldown in seconds. DPS = damage × projectile_count / fire_rate.** | HIGH |
| 4 | Volley CardData vs Classic | Volley applies `speed_mult = 0.85` + projectile 0.8× | Classic does not | **Both correct — mode-specific via `_volley_gun_target` branch. DPS differs by mode.** Document both numbers per card in Pass 2. | HIGH |
| 5 | Prior QA report | "Tests are skipped, simulations required" | v3 audit prompt requires N≥100 Monte Carlo | **Neither was run this session. Explicitly DEFERRED.** | — |
| 6 | Vector Link fusion math (`match_volley.gd:_try_fuse`) | `fused.level_mult = 1.0` | Base Unit `level_mult` = `PlayerProfile.level_multiplier(card.id)` | **Fused units intentionally skip level-mult since stats are already combined from source units' post-mult values.** Documented in METHODOLOGY.md §Shadow-Dagger mitigation. | HIGH |
| 7 | Mender vs Chorus healer role | `mender.tres` aura_radius=0 | `chorus.tres` aura_radius=80 | **Two different healer behaviours. unit.gd:_do_healer branches on `aura_radius > 0`.** Both documented in Pass 3 role-viability. | HIGH |
| 8 | "Match length" claim in design doc | "3:00 match" | Code: match_seconds=180 + surge_seconds=25 = 205s, plus 60s OT = 265s max | **Design doc is pre-SURGE. Current total incl. SURGE = 205s (3:25).** Not contradictory per se, but benchmarks need the updated number. | HIGH |
| 9 | Pre-balance Oracle/Mortar/Beam stats (git history) | Oracle fr=2.5, Mortar fr=2.0, Beam dmg=12 | Current .tres files (post-commit fb2a65b) | **Rebalanced. Current values used throughout this audit.** | HIGH |

No open contradictions blocking analysis. Several DEFERRED simulation items are *gaps*, not contradictions.
