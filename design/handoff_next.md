# Handoff — Continuation Brief

*Handoff point: commit `636dab7`. Context at ~86%, starting a fresh session for
the remaining Volley work.*

**First thing to do in the new session:** read `design/volley_mode.md` (the
full spec) then this doc. Then confirm with the user which priority order to
take (they said "yellow then red then green" — that's weird because red is
critical; ask them to confirm before you start).

---

## Where the project is at

Volley mode is **spawned and playable as a gun-only match**. You walk a fresh
player into it, the briefing + team-size chip appears, the loadout modal
fires, the match launches with starter modules (BARREL + COOLING + TRIGGER),
gun auto-aims, squares descend, kills count, 2-minute timer resolves with a
Victory/Defeat/Draw. 2V2 variant works — 4 guns, team HP, faster spawn rate.

**What's missing** is everything that makes Volley feel like a deck-builder
battle rather than a reflex gun. Cards can't be played. The enemy doesn't
deploy. You can't upgrade modules. Details below.

---

## 🔴 Critical — Volley is incomplete without these

### 1. Card hand not drawn in Volley HUD

`scenes/match/volley/match_volley.tscn` has no `CardHand` instance. The
HUD only has the top strip (timer + scores) and a single HintLabel at the
bottom. Need to:

- Add a `%Hand` node under the HUD using `res://scenes/ui/card_hand.tscn`.
- Add a `%ManaBar` + `%ManaLabel` + `%EnemyManaLabel` so the mana economy
  reads in Volley too.
- In `match_volley.gd`'s `_ready()`, get references via `@onready`, call
  `hand.deck = ...`, `hand.build()`, hook `hand.card_selected` to a new
  `_on_card_selected`.
- Copy the deploy flow from `match.gd`:
  - `_process` regens mana
  - `_unhandled_input` catches LEFT click, calls `_try_deploy`
  - `_try_deploy` pays mana, spawns unit, sets cooldown, etc.
- Use the player's real `PlayerDeck.cards` just like classic mode.

**Tutorial-mode deck from classic** doesn't apply here — just use `PlayerDeck.cards` unconditionally for MVP.

### 2. SIEGE units don't retarget the enemy Gun

`scripts/match/unit.gd` is written around `enemy_base` / `player_base`
(`BaseGrid` nodes) for arrival detection. In Volley those don't exist.

Two options (pick the less invasive one):

**Option A — add `_volley_gun_target: Gun` field to Unit.** When set, the
unit ignores `BaseGrid` arrival and instead checks distance to `Gun`. On
contact, calls `gun.take_damage(damage)` and `queue_free()`. `match_volley`
sets this on every player-spawned unit to the enemy gun, and every bot-
spawned unit to the player gun.

**Option B — create a virtual "gun zone" strip** that the existing
`_check_base_arrival` logic already handles, and map arrival to gun damage
through match.gd's `_on_unit_reached_base`. Simpler signal path but
couples Volley to the base-strip math. Probably fine.

Suggest **A** — cleaner separation. Add a `_volley_gun_target: Node2D = null`
field to Unit. In Unit's `_process` dispatch path, if `_volley_gun_target`
is set, replace the normal target-picking + base-arrival logic with
"walk toward gun, on contact deal damage + self-destruct."

### 3. Bot enemy doesn't deploy cards in Volley

Classic mode has `BotState` loop in `match.gd` (`_bot_try_spawn`) that
ticks every `bot_spawn_interval` seconds, picks a card, spawns a unit on
the bot's half of the field. Volley has no equivalent.

Port the `BotState` struct + loop into `match_volley.gd`. When a bot spawns
a unit, set its `_volley_gun_target` to the player's gun so it walks down.

For 2V2, spawn one ally bot (is_enemy=false) + two enemy bots (is_enemy=true),
like classic 2V2. Reuse `BotPersonas.for_arena` for deck selection so the
opponent flavour is consistent.

### 4. Game-over line reads "X VS Y SQUARES" in Volley

`scripts/match/game_over.gd:show_result` hardcodes that string for
non-tutorial matches. Add a branch — if the result label text indicates
a Volley match, or if we pass a flag, say **"X VS Y KILLS"** instead.

Cleanest: add a `subtitle_override: String = ""` optional param and have
`match_volley._end_match` pass `"%d VS %d KILLS" % [_player_score, _enemy_score]`.

---

## 🟡 Module upgrade loop not reachable from UI

### 5. No UI to spend gold on module tiers

`GunModules.upgrade(id)` works; `UPGRADE_COSTS` is reused from the card
curve. Needs a UI entry point. Two reasonable options:

**Option A:** Add an UPGRADE action inside the Loadout Modal — long-press
a module pool row or add a "▲ UPGRADE" button on each row that shows cost,
disabled when unaffordable, calls `GunModules.upgrade(id)` on tap and
rebuilds the pool.

**Option B:** Add a new COLLECTION-tab section "GUN MODULES" that lists
all modules (owned + locked) with tier + upgrade CTA, same pattern as
the existing card tiles in `collection_tab.gd`.

Suggest **A** for first-ship — it's where the player already is when
they're thinking about modules. Add B later if the module count grows.

### 6. Non-starter modules never unlock

`GunModules.ensure_starters` only seeds BARREL / COOLING / TRIGGER. The
other 5 (AMMO / SCOPE / PLATING / DAMPER / REPAIR) have no unlock source.

Pick one:
- **Level-gated unlock** — hardcode a `unlock_level` per module, check
  player level on Loadout modal open.
- **Season-pass tier rewards** — extend `SeasonPass.REWARDS` to grant
  modules at specific tiers.
- **Shop purchase** — new row in the shop tab.

Suggest **level-gated** for first-ship because it doesn't require new UI —
just a mapping in `gun_modules.gd` and a check in `is_unlocked`.

### 7. Enemy gun uses flat base stats

`Gun._apply_loadout` early-returns when `is_enemy` is true. Fine for now
but high-arena matches feel flat. Quick fix: give the enemy gun a synthetic
scaling loadout via `GunModules.compute_stats` using `arena_index`-based
tier values.

---

## 🟢 Polish / low-stakes

### 8. No opponent persona label in Volley

Classic mode shows `ENEMY // K.VOID_07`. Volley has no name. 5-min fix:
copy the `BotPersonas.for_arena` + label-write from `match.gd:_apply_tactical_hud`
into `match_volley.gd`.

### 9. Gun state visuals

Overheat stops firing silently — add a red pulse on the heat arc, maybe a
brief "OVERHEAT" chip floating above. Reboot state currently dims the body
colour but that's subtle. Consider a visible reboot countdown + a shake.

### 10. Square death lacks VFX / SFX

Squares just `queue_free()`. Add a small burst particle + small SFX. This
is the single best feel-win in the project; nothing else matches the
satisfaction uplift of a "pop" on kill.

### 11. Match HUD feels thin

- Module loadout display mid-match (small chips like "BARREL L2").
- Kill streak / combo indicator.
- Boss square spawning announcement ("▸ BOSS INBOUND").

---

## Files touched recently (for orientation)

- `resources/card_data.gd` — added `Kind` enum + `spell_id`.
- `autoload/gun_modules.gd` — NEW. 8 modules, stat computation.
- `autoload/player_profile.gd` — added `_ensure_gun_modules` hook.
- `resources/player_profile.gd` — added `gun_modules` + `gun_loadout`.
- `data/game_modes/solo_volley.tres` — 1V1 Volley mode.
- `data/game_modes/solo_volley_2v2.tres` — NEW, 2V2 Volley.
- `scenes/match/volley/*.tscn` — volley scenes (match, gun, projectile, square).
- `scripts/match/volley/*.gd` — volley scripts.
- `scenes/menus/loadout_modal.tscn` + `scripts/menus/loadout_modal.gd` — NEW.
- `scripts/menus/main_menu.gd` — route volley through Loadout modal.
- `scripts/menus/match_confirm.gd` — team-size toggle for volley.
- `scripts/menus/tactical_bottomdock.gd` — 4-button layout with VOLLEY.

---

## Recommended session plan

**Session A (~3h):** Items 1 + 2 + 3 + 4 + 10.
After this, Volley is the intended game. Single highest-impact session.

**Session B (~1.5h):** Items 5 + 6.
Module progression loop now works end-to-end.

**Session C (~1h):** Items 7 + 8 + 9 + 11.
Feel polish.

Plus the mode-pivot work mentioned in `volley_mode.md` §10 (more spells,
interceptor cards, more squares, gun cosmetics, tutorial) — those come
after Session C.

---

## Opening line for the new session

> "Read design/handoff_next.md. Start Session A — items 1 + 2 + 3 + 4 + 10
> in that order. Commit + push after each item so rollback is cheap. Ship
> an APK at the end."

Or whatever the user says when they open the new window. They're in the
driver's seat — the order above is my rec, not a mandate.
