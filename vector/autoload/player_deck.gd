extends Node
## Global deck holder. Persists across scenes and writes to user://deck.tres.
## Match scene reads `PlayerDeck.cards`; deck builder writes via `save_deck()`.
##
## Pool discovery: scans res://data/cards/ for .tres files, skips any file
## starting with "_" (internal cards like the Chevron scout).

const DECK_PATH := "user://deck.tres"
const CARDS_DIR := "res://data/cards/"
const DEFAULT_IDS: Array[StringName] = [
	&"dart", &"bomb", &"spiral", &"burst",
	&"lance", &"orb", &"chevron", &"pulse",
]

var cards: Array[CardData] = []
var _pool_cache: Array[CardData] = []

func _ready() -> void:
	_reload()

func _reload() -> void:
	var profile: DeckProfile = null
	if FileAccess.file_exists(DECK_PATH):
		profile = load(DECK_PATH) as DeckProfile
	if profile == null or profile.card_ids.is_empty():
		profile = DeckProfile.new()
		profile.card_ids = DEFAULT_IDS.duplicate()
	cards = _resolve_ids(profile.card_ids)
	if cards.size() < DEFAULT_IDS.size():
		# Backfill any missing slots with the defaults.
		var present: Dictionary = {}
		for c in cards:
			present[c.id] = true
		for id in DEFAULT_IDS:
			if cards.size() >= DEFAULT_IDS.size():
				break
			if not present.has(id):
				var c: CardData = _load_card(id)
				if c != null:
					cards.append(c)
				else:
					push_warning("PlayerDeck backfill: default card '%s' not found at %s%s.tres." % [id, CARDS_DIR, id])

func save_deck(new_cards: Array[CardData]) -> void:
	cards = new_cards
	var profile := DeckProfile.new()
	for c in new_cards:
		if c != null:
			profile.card_ids.append(c.id)
	var err := ResourceSaver.save(profile, DECK_PATH)
	if err != OK:
		push_error("PlayerDeck save failed: %d" % err)

## All playable cards in the pool, sorted by cost then name for stable UI.
##
## Handles three entry shapes that DirAccess can surface depending on build:
##   - foo.tres        (editor runs, desktop exports)
##   - foo.tres.remap  (Android/iOS exports — Godot renames the original)
##   - foo.tres.import (rare; import-sidecar variant)
## All three map back to the same resource path `foo.tres`. We de-dupe by
## card id so if two variants of the same file show up, we only add it once.
func pool() -> Array[CardData]:
	if not _pool_cache.is_empty():
		return _pool_cache
	var dir := DirAccess.open(CARDS_DIR)
	if dir == null:
		push_error("PlayerDeck: cannot open %s" % CARDS_DIR)
		return []
	var seen_ids: Dictionary = {}
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir():
			var stem: String = file
			for suffix in [".remap", ".import"]:
				if stem.ends_with(suffix):
					stem = stem.trim_suffix(suffix)
					break
			if stem.ends_with(".tres") and not stem.begins_with("_"):
				var c := load(CARDS_DIR + stem) as CardData
				if c != null and not seen_ids.has(c.id):
					seen_ids[c.id] = true
					_pool_cache.append(c)
		file = dir.get_next()
	_pool_cache.sort_custom(func(a: CardData, b: CardData) -> bool:
		if a.cost != b.cost:
			return a.cost < b.cost
		return a.display_name < b.display_name)
	return _pool_cache

func _resolve_ids(ids: Array) -> Array[CardData]:
	var result: Array[CardData] = []
	for raw in ids:
		var id: StringName = raw as StringName
		var c: CardData = _load_card(id)
		if c != null:
			result.append(c)
	return result

func _load_card(id: StringName) -> CardData:
	var path := "%s%s.tres" % [CARDS_DIR, id]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as CardData
