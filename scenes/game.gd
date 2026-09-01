extends Node2D
@onready var ghost_container = $Chars/Ghosts
@onready var blocker_container = $Chars/Blockers
@onready var fatghost_container = $Chars/FatGhosts
@onready var fat_spawn_node = $"fat-spawn"
@onready var player = $Chars/player
@onready var canvas_modulate = $CanvasModulate

var ghost_scene = preload("res://ghost.tscn")
var blocker_scene = preload("res://block_ghost.tscn")
var fat_ghost_scene = preload("res://fat_ghost.tscn")
var diffLevel = 1
var canSpawnFatGhost = false
var canSpawnSandwich = false
var canSpawnBlock = false


var playerLane = 1

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

# Blockers: permanent lock until they die (they don't move)
var occupied_markers := {}  # marker -> true

# Ghosts: short cooldown so two ghosts don't stack on the same marker instantly
var ghost_cooldown := {}  # marker -> true (temporary)
const GHOST_COOLDOWN_TIME := 0.4  # seconds before a marker can be reused by a ghost

# Sandwich: per-lane cooldown so the same Y lane can't sandwich again immediately
var sandwich_lane_cooldown := {}  # lane number -> true (temporary)
const SANDWICH_LANE_COOLDOWN_TIME := 4.0  # seconds before the same lane can sandwich again

func _ready():
	player.died.connect(endGame)

func _get_free_ghost_markers(side: String) -> Array:
	var all_markers := get_tree().get_nodes_in_group(side)
	return all_markers.filter(func(m): 
		return not ghost_cooldown.has(m) and not occupied_markers.has(m)
	)

func _spawn_ghost_at(marker: Node2D, side: String, scene: PackedScene, container: Node) -> void:
	ghost_cooldown[marker] = true
	get_tree().create_timer(GHOST_COOLDOWN_TIME).timeout.connect(func():
		ghost_cooldown.erase(marker)
	)
	var unit = scene.instantiate()
	unit.global_position = marker.global_position
	unit.set_direction(OPPOSITE_DIR[side])
	container.add_child(unit)

func _spawn_ghost(scene: PackedScene, container: Node) -> void:
	var side: String = SIDES.pick_random()
	var free_markers = _get_free_ghost_markers(side)
	if free_markers.is_empty():
		push_warning("No free markers available for side: " + side)
		return
	var random_marker: Node2D = free_markers.pick_random()
	_spawn_ghost_at(random_marker, side, scene, container)

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
	unit.set_direction(OPPOSITE_DIR[side])
	unit.tree_exited.connect(_on_unit_freed.bind(random_marker))
	container.add_child(unit)

func _on_unit_freed(marker: Node2D) -> void:
	occupied_markers.erase(marker)

func _on_timer_timeout() -> void:
	var spawn_count = 1 + int(diffLevel / 5)

	if canSpawnSandwich:
		var sandwich_chance = min(0.3, (diffLevel - 3) * 0.1)  # starts at 10%, +10% per level, capped at 30%
		if randf() < sandwich_chance:
			_sandwich_y()

	if canSpawnBlock and $Timers/BlockGhostTimer.is_stopped():
		$Timers/BlockGhostTimer.start()
		
	
	for i in spawn_count:
		_spawn_ghost(ghost_scene, ghost_container)

func _on_block_ghost_timer_timeout() -> void:
	_spawn_blocker(blocker_scene, blocker_container)

func _on_escalate_timer_timeout() -> void:
	if diffLevel == 1:
		$Timers/BlockGhostTimer.start()
	
	$Timers/MoveGhostTimer.wait_time = max(0.5, $Timers/MoveGhostTimer.wait_time - 0.1 * diffLevel)
	$Timers/BlockGhostTimer.wait_time = max(0.8, $Timers/BlockGhostTimer.wait_time - 0.1 * diffLevel)

	if diffLevel == 2:
		canSpawnFatGhost = true
		$Timers/FatGhostTimer.start()
		print("Difficulty %d: fat ghosts unlocked" % diffLevel)

	if diffLevel == 3:
		canSpawnSandwich = true
		print("Difficulty %d: sandwich pattern unlocked" % diffLevel)

	print("Difficulty %d: move ghost interval now %.2fs, block ghost interval now %.2fs" % [
		diffLevel,
		$Timers/MoveGhostTimer.wait_time,
		$Timers/BlockGhostTimer.wait_time
	])

	if diffLevel < 5:
		diffLevel = diffLevel + 1

func _get_marker_by_name(group: String, marker_name: String) -> Node2D:
	var markers = get_tree().get_nodes_in_group(group)
	for m in markers:
		if m.name == marker_name:
			return m
	return null

# --- Sandwich pattern: pick a free lane (not on cooldown), spawn ghost at upX and downX ---
func _sandwich_y() -> void:
	var available_lanes = [1, 2, 3].filter(func(l): return not sandwich_lane_cooldown.has(l))
	
	if available_lanes.is_empty():
		push_warning("All sandwich lanes on cooldown")
		return
	
	var lane: int = available_lanes.pick_random()
	
	var up_marker = _get_marker_by_name("up", "up" + str(lane))
	var down_marker = _get_marker_by_name("down", "down" + str(lane))
	
	if up_marker == null or down_marker == null:
		push_warning("Sandwich markers not found for lane: " + str(lane))
		return
	if ghost_cooldown.has(up_marker) or ghost_cooldown.has(down_marker) or occupied_markers.has(up_marker) or occupied_markers.has(down_marker):
		push_warning("Sandwich lane busy: " + str(lane))
		return
	
	# Spawn the first ghost immediately
	_spawn_ghost_at(up_marker, "up", ghost_scene, ghost_container)
	
	# Spawn the second ghost after a short delay, giving the player time to react
	var sandwich_delay := 0.6  # tweak to taste — try 0.5-1.0s
	get_tree().create_timer(sandwich_delay).timeout.connect(func():
		_spawn_ghost_at(down_marker, "down", ghost_scene, ghost_container)
	)
	
	sandwich_lane_cooldown[lane] = true
	get_tree().create_timer(SANDWICH_LANE_COOLDOWN_TIME).timeout.connect(func():
		sandwich_lane_cooldown.erase(lane)
	)

func _on_detection_body_entered(body: Node2D) -> void:
	playerLane = 1

func _on_detection_2_body_entered(body: Node2D) -> void:
	playerLane = 2

func _on_detection_3_body_entered(body: Node2D) -> void:
	playerLane = 3

# --- Fat ghost: spawns automatically from a random side (left/right) at a random lane ---
func _spawn_fat_ghost() -> void:
	var side: String = ["left", "right"].pick_random()
	var marker_name = side + str(playerLane)
	
	var marker = fat_spawn_node.get_node_or_null(marker_name)
	
	if marker == null:
		push_warning("Fat ghost marker not found: " + marker_name)
		return
	
	var unit = fat_ghost_scene.instantiate()
	unit.global_position = marker.global_position
	unit.set_direction(OPPOSITE_DIR[side])
	fatghost_container.add_child(unit)
	
func endGame()->void:
	$CanvasLayer/Score/Timer.stop()
	$Timers/MoveGhostTimer.stop()
	$Timers/BlockGhostTimer.stop()
	$Timers/FatGhostTimer.stop()
	$CanvasLayer/GameOver.visible = true
	var tween = create_tween()
	tween.tween_property(canvas_modulate, "color", Color(0.15, 0.15, 0.15), 0.5)

		
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_fat_ghost_timer_timeout() -> void:
	if canSpawnFatGhost:
		_spawn_fat_ghost()
