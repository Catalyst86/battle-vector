@tool
class_name DeckProfile
extends Resource
## Persistent 8-of-pool deck selection. Stored at user://deck.tres and loaded
## by the PlayerDeck autoload on boot. Values are card ids (StringName), not
## the full CardData, so swapping between profiles is just a list of strings.

@export var card_ids: Array[StringName] = []
