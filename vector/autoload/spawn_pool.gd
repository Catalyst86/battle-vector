extends Node
## Object pool for high-frequency match transients — projectiles and death
## bursts. Both are hot: a shooter fires every 0.3–1.4s, and every unit
## emits a burst on death. Without pooling that's thousands of
## PackedScene.instantiate() calls per match, each allocating a fresh
## Node subtree. With pooling: one-time-per-engine-run allocation,
## O(1) acquire/release thereafter.
##
## Pooled nodes are removed from the tree on release (no parent) and
## re-parented on acquire. Their scripts own `reset()` which zeroes the
## per-use state; `_ready()` still only fires once per Node (first use).

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/match/projectile.tscn")
const DEATH_BURST_SCENE: PackedScene = preload("res://scenes/match/death_burst.tscn")

var _projectiles: Array[Node] = []
var _bursts: Array[Node] = []

func acquire_projectile(parent: Node) -> Node:
	var p: Node = _projectiles.pop_back() if not _projectiles.is_empty() else PROJECTILE_SCENE.instantiate()
	parent.add_child(p)
	return p

func release_projectile(p: Node) -> void:
	if not is_instance_valid(p):
		return
	if p.get_parent() != null:
		p.get_parent().remove_child(p)
	if p.has_method("reset"):
		p.reset()
	_projectiles.append(p)

func acquire_burst(parent: Node) -> Node:
	var b: Node = _bursts.pop_back() if not _bursts.is_empty() else DEATH_BURST_SCENE.instantiate()
	parent.add_child(b)
	return b

func release_burst(b: Node) -> void:
	if not is_instance_valid(b):
		return
	if b.get_parent() != null:
		b.get_parent().remove_child(b)
	if b.has_method("reset"):
		b.reset()
	_bursts.append(b)
