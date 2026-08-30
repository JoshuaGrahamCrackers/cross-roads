extends Node2D

@onready var ghost_container = $Chars/Ghosts
@onready var blocker_container = $Chars/Blockers

var ghost_scene = preload("res://ghost.tscn")
var blocker_scene = preload("res://block_ghost.tscn")

const SIDES := ["left", "right", "up", "down"]

const OPPOSITE_DIR := {
	"left":  Vector2.RIGHT,
	"right": Vector2.LEFT,
	"up":    Vector2.DOWN,
	"down":  Vector2.UP,
}

const DIR_VECTORS := {
	"left":  Vector2.LEFT,
	"right": Vector2.RIGHT,
	"up":    Vector2.UP,
	"down":  Vector2.DOWN,
}

var occupied_markers := {}  # marker -> true, shared between ghosts AND blockers

func _spawn_ghost(scene: PackedScene, container: Node) -> void:
	var side: String = SIDES.pick_random()
	var all_markers := get_tree().get_nodes_in_group(side)
	var free_markers = all_markers.filter(func(m): return not occupied_markers.has(m))

	if free_markers.is_empty():
		push_warning("No free markers available for side: " + side)
		return

	var random_marker: Node2D = free_markers.pick_random()
	occupied_markers[random_marker] = true

	var unit = scene.instantiate()
	unit.global_position = random_marker.global_position
	unit.set_direction(OPPOSITE_DIR[side])
	unit.tree_exited.connect(_on_unit_freed.bind(random_marker))
	container.add_child(unit)

func _spawn_blocker(scene: PackedScene, container: Node) -> void:
	var side: String = SIDES.pick_random()
	var group_name := side + "-blocker"
	var all_markers := get_tree().get_nodes_in_group(group_name)
	var free_markers = all_markers.filter(func(m): return not occupied_markers.has(m))

	if free_markers.is_empty():
		push_warning("No free markers available for side: " + group_name)
		return

	var random_marker: Node2D = free_markers.pick_random()
	occupied_markers[random_marker] = true

	var unit = scene.instantiate()
	unit.global_position = random_marker.global_position
	unit.set_direction(OPPOSITE_DIR[side])   # try this first
	# unit.set_direction(DIR_VECTORS[side])  # swap to this if the blocker faces the wrong way
	unit.tree_exited.connect(_on_unit_freed.bind(random_marker))
	container.add_child(unit)

func _on_unit_freed(marker: Node2D) -> void:
	occupied_markers.erase(marker)

func _on_timer_timeout() -> void:
	_spawn_ghost(ghost_scene, ghost_container)

func _on_block_ghost_timer_timeout() -> void:
	_spawn_blocker(blocker_scene, blocker_container)
