# Balance Frameworks — Reference for Battle Vector Audit

This is a reference doc the auditor cites when applying formal analysis in passes 2–8. Each framework is a tool; the auditor picks the right tool per finding.

## 1. Pareto Frontier (Card & Role Domination)

**Definition:** In a multi-objective space (mana, DPS, EHP, utility, range, speed), card A **Pareto-dominates** card B if A is at least as good as B on every axis and strictly better on at least one. Pareto-dominated cards are dead by construction — no rational player picks them.

**Application:** Plot every card in the key objective space. The **Pareto frontier** is the set of non-dominated cards. Healthy card games: all or nearly all cards on or very near the frontier. Unhealthy: half the cards fall strictly below.

**How to compute:** For each card C, check if any other card Pareto-dominates C. If yes, C is dominated. Output: list of dominated cards + which cards dominate them.

**Useful when:** Pass 2 (per-card audit), Pass 3 (role balance). Use to formally identify dead cards.

## 2. Nash Equilibrium (Meta Stability)

**Definition:** A **mixed-strategy Nash equilibrium** on the matchup matrix M (M[A][B] = win rate of A vs B) is a probability distribution over cards/decks where no single player benefits from deviating. The **support** of the equilibrium is the set of cards/decks that appear with nonzero probability in optimal play.

**Interpretation:**
- Cards in the Nash support = competitive meta.
- Cards outside the support = meta-dead (no rational top player uses them).
- Large support (many cards) = healthy diverse meta.
- Small support (2–3 decks) = solved meta, replayability dies.
- **No equilibrium exists** in pure intransitive structures = meta oscillates forever, feels arbitrary.

**How to compute:** Given 28×28 matchup matrix M, use linear programming or the `nashpy` Python library. For zero-sum 2-player games (1v1 card game with symmetric decks), the Nash equilibrium is solvable in polynomial time.

**Useful when:** Pass 3 (matchup matrix analysis). The single most informative output of the entire audit.

## 3. Elo Simulation (P2W & Matchmaking)

**Definition:** Elo rating system models relative skill such that the expected win rate of player A vs B is `1 / (1 + 10^((R_B - R_A) / 400))`. A 200-point Elo gap implies ~75% win rate for the higher-rated player; 400 points implies ~91%.

**Application:** For P2W analysis, assign each deck composition an effective "deck Elo" based on simulated win rates against a reference deck. Then compare the Elo gap between a median-F2P deck at day N and a max-level deck.

**Rule of thumb:**
- Elo gap < 100: meaningful skill can overcome deck gap (healthy).
- Elo gap 100–200: deck matters more than skill within 1 tier (borderline).
- Elo gap > 200: deck effectively determines outcome (P2W dominant).

**How to compute:** `simulate_elo_progression.py`: run N=10,000 simulated matches between deck configurations, compute win rates, convert to Elo deltas.

**Useful when:** Pass 4 (P2W risk). Turns an intuition into a number.

## 4. Mana Curve (Deck Construction Health)

**Definition:** Distribution of mana costs across a deck's 8 cards. Standard shape in successful card games: roughly bell-curved with peak at 3–4 mana, tails at 1–2 and 5+.

**Application:**
- If the only viable decks cluster around one mana cost, card cost distribution is wrong.
- If every deck needs a cheap cycle card AND a heavy win condition, check that multiple cheap cycle cards and multiple heavy win conditions exist — otherwise cards become auto-includes.

**Useful when:** Pass 3 (deck archetype viability). Complements Nash analysis.

## 5. Tempo vs Value (Card Power Axis)

**Definitions:**
- **Tempo**: board-state advantage per mana spent, immediate impact.
- **Value**: total cards drawn/units produced/damage output across the card's lifetime.

**Application:** Every card falls somewhere on the tempo-vs-value axis. A healthy meta has decks that win via tempo AND decks that win via value — if one strategy dominates, the meta flattens.

**Symptom of imbalance:** All top-tier decks are tempo (rush) → game has no control strategy. All top-tier decks are value (late-game) → opening moves don't matter.

**Useful when:** Pass 3 (archetype analysis), Pass 7 (replayability — does strategic variety exist?).

## 6. Power Budget

**Definition:** Each card has an implicit "power budget" = sum of its stats weighted by how valuable each stat is. Cards of the same mana cost should have roughly equal power budgets.

**Application:** For each mana tier, list every card and its stat totals. Flag cards whose power budget is significantly above/below the tier average — they're over/undertuned. This is independent of Pareto analysis (a card can be on the Pareto frontier but still overtuned).

**Useful when:** Pass 2 (per-card). Gives a numeric target for balance changes in Pass 8.

## 7. Cycle Speed (Deck Rotation)

**Definition:** How many turns/seconds until a player has seen and redrawn every card. In Clash Royale: cycle speed = 4 (hand) / (cards played per second).

**Application:**
- Cycle < once per match: players never get their win condition reliably. Frustrating.
- Cycle 1–2x per match: sweet spot. Strategy matters, but matches aren't won purely by whoever draws right.
- Cycle > 3x per match: cards feel interchangeable, individual card choice matters less.

**How to compute:** Avg card cost / mana-per-second × hand size.

**Useful when:** Pass 5 (mana economy), Pass 6 (match flow).

## 8. Variance / Coin-Flip Detection

**Definition:** Standard deviation of win rate across identical same-skill matchups. In a pure skill game, variance is low (same-skill players converge on 50/50). In a pure luck game, variance is high.

**Application:** Run N=100 simulations of the same deck-vs-deck matchup. If win rate stdev > 20%, match outcomes are heavily RNG-dependent — players lose even when playing well. Retention suffers.

**Useful when:** Pass 2 (individual card variance), Pass 3 (matchup variance). High variance is a finding even when mean is balanced.

## 9. Monte Carlo Sample Sizing

Rough targets for statistical confidence in this audit:
- Per-card stat verification: **N=100** runs (stat means converge quickly).
- Per-matchup win rate: **N=200** runs (for ±3% CI at 95% confidence).
- Elo projection: **N=10,000** matches (for smooth distribution).
- Bot fuzz tests: **N=1,000** runs per adversarial deck (to surface rare exploits).

If compute is constrained, sample priorities in this order: per-card verification > matchup win rates > bot fuzz > Elo projection. Elo projection can be cut to N=1,000 with noticeable but acceptable noise.

## 10. When NOT to Use These Frameworks

Frameworks can mislead if misapplied:
- **Pareto** can't see situational strengths. A card dominated on average stats might be the only counter to a specific threat — that's a utility the frontier doesn't capture. Flag "situationally dominant" cards separately.
- **Nash** assumes rational play. Real ladders have irrational players; the Nash support is ceiling-meta, not floor-meta.
- **Elo** assumes one-dimensional skill. Actual card games have deck-specific skill layers.
- **Monte Carlo** is only as good as the bot playing the simulation. If the simulation bot plays suboptimally, the results describe what bad players experience, not the ceiling meta.

Explicitly note framework limitations when citing in findings.
