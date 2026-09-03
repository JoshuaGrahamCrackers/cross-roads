extends Node2D

# --- Node references ---
@onready var ghost_container = $Chars/Ghosts
@onready var blocker_container = $Chars/Blockers
@onready var fatghost_container = $Chars/FatGhosts
@onready var fat_spawn_node = $"fat-spawn"
@onready var player = $Chars/player
@onready var canvas_modulate = $CanvasModulate

# --- Preloaded scenes ---
var ghost_scene = preload("res://ghost.tscn")
var blocker_scene = preload("res://block_ghost.tscn")
var fat_ghost_scene = preload("res://fat_ghost.tscn")

# --- Difficulty / spawn flags ---
var diffLevel = 0
var canSpawnFatGhost = false
var canSpawnBlock = false
var playerLane = 1

# --- Side groupings ---
const SIDES := ["left", "right"]                    # used for horizontal ghost spawns
const BLOCKER_SIDES := ["left", "right", "bottom"]   # used for blocker spawns

# --- Direction vectors ---
const OPPOSITE_DIR := {
	"left":  Vector2.RIGHT,
	"right": Vector2.LEFT,
	"up":    Vector2.DOWN,
	"down":  Vector2.UP,
}
const BLOCKER_FACING := {
	"left":   Vector2.LEFT,
	"right":  Vector2.RIGHT,
	"bottom": Vector2.DOWN,
}

# --- Vertical lane state ---
var lane_direction := {1: "up", 2: "up", 3: "up"}  # lane -> "up" or "down"
var lane_switch_cooldown := {}  # lane -> true (temporary, blocks spawns after a direction flip)
const LANE_SWITCH_COOLDOWN_TIME := 5.0  # seconds to wait after the flush-spawn before this lane can spawn again

# --- Marker occupancy tracking ---
var occupied_markers := {}  # marker -> true (blockers: permanent lock until they die)
var ghost_cooldown := {}    # marker -> true (temporary, short cooldown so ghosts don't stack)
const GHOST_COOLDOWN_TIME := 0.4  # seconds before a marker can be reused by a ghost


func _ready():
	player.died.connect(endGame)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().change_scene_to_file("res://scenes/game.tscn")


# =========================
# Ghost spawning
# =========================

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

func _spawn_ghost_vertical(scene: PackedScene, container: Node) -> void:
	var lane: int = [1, 2, 3].pick_random()
	var side: String = lane_direction[lane]
	var marker: Node2D = _get_marker_by_name(side, side + str(lane))
	if marker == null:
		push_warning("Vertical marker not found for lane: " + str(lane))
		return
	if ghost_cooldown.has(marker) or occupied_markers.has(marker):
		push_warning("Vertical lane busy: " + str(lane))
		return
	_spawn_ghost_at(marker, side, scene, container)


# =========================
# Blocker spawning
# =========================

func _spawn_blocker(scene: PackedScene, container: Node) -> void:
	var side: String = BLOCKER_SIDES.pick_random()
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
	unit.set_direction(BLOCKER_FACING[side])
	unit.tree_exited.connect(_on_unit_freed.bind(random_marker))
	container.add_child(unit)

func _on_unit_freed(marker: Node2D) -> void:
	occupied_markers.erase(marker)


# =========================
# Fat ghost spawning
# =========================

func _spawn_fat_ghost() -> void:
	var side: String = ["left", "right"].pick_random()
	var marker_name = side + str(playerLane)
	var marker = fat_spawn_node.get_node_or_null(marker_name)
	$fatGhostSpawnHorn.play()
	var unit = fat_ghost_scene.instantiate()
	unit.global_position = marker.global_position
	unit.set_direction(OPPOSITE_DIR[side])
	fatghost_container.add_child(unit)


# =========================
# Timer callbacks
# =========================

func _on_timer_timeout() -> void:
	var spawn_count = 1 + int(diffLevel)

	if canSpawnBlock and $Timers/BlockGhostTimer.is_stopped():
		$Timers/BlockGhostTimer.start()

	for i in spawn_count:
		_spawn_ghost(ghost_scene, ghost_container)
		_spawn_ghost(ghost_scene, ghost_container)

	# Verticals now only spawn some of the time, once per wave at most
	if randf() < 0.25:
		_spawn_ghost_vertical(ghost_scene, ghost_container)

func _on_block_ghost_timer_timeout() -> void:
	_spawn_blocker(blocker_scene, blocker_container)

func _on_fat_ghost_timer_timeout() -> void:
	if canSpawnFatGhost:
		_spawn_fat_ghost()

func _on_escalate_timer_timeout() -> void:
	if diffLevel < 5:
		diffLevel = diffLevel + 1

	if diffLevel == 1:
		$Timers/BlockGhostTimer.start()
		$Timers/MoveGhostTimer.wait_time = $Timers/MoveGhostTimer.wait_time - 0.1

	if diffLevel == 2:
		canSpawnFatGhost = true
		$Timers/FatGhostTimer.start()
		print("Difficulty %d: fat ghosts unlocked" % diffLevel)

	if diffLevel == 3:
		$Timers/MoveGhostTimer.wait_time = $Timers/MoveGhostTimer.wait_time - 0.1

	if diffLevel == 4:
		$Timers/MoveGhostTimer.wait_time = $Timers/MoveGhostTimer.wait_time - 0.1

	print("Difficulty %d: move ghost interval now %.2fs, block ghost interval now %.2fs" % [
		diffLevel,
		$Timers/MoveGhostTimer.wait_time,
		$Timers/BlockGhostTimer.wait_time
	])

func _on_vertical_ghost_direction_timeout() -> void:
	for lane in [1, 2, 3]:
		var old_dir = lane_direction[lane]
		var new_dir = ["up", "down"].pick_random()

		if new_dir != old_dir:
			# Direction is changing for this lane — spawn one last ghost
			# in the OLD direction, then lock the lane for a few seconds
			# before it starts spawning in the new direction.
			var old_marker: Node2D = _get_marker_by_name(old_dir, old_dir + str(lane))
			if old_marker != null and not ghost_cooldown.has(old_marker) and not occupied_markers.has(old_marker):
				_spawn_ghost_at(old_marker, old_dir, ghost_scene, ghost_container)

			lane_switch_cooldown[lane] = true
			get_tree().create_timer(LANE_SWITCH_COOLDOWN_TIME).timeout.connect(func():
				lane_switch_cooldown.erase(lane)
			)

		lane_direction[lane] = new_dir

	# Log where vertical ghosts will now spawn from for each lane
	print("Vertical spawn directions updated -> lane 1: %s, lane 2: %s, lane 3: %s" % [
		lane_direction[1],
		lane_direction[2],
		lane_direction[3]
	])


# =========================
# Player lane detection
# =========================

func _on_detection_body_entered(body: Node2D) -> void:
	playerLane = 1

func _on_detection_2_body_entered(body: Node2D) -> void:
	playerLane = 2

func _on_detection_3_body_entered(body: Node2D) -> void:
	playerLane = 3


# =========================
# Marker lookup helper
# =========================

func _get_marker_by_name(group: String, marker_name: String) -> Node2D:
	var markers = get_tree().get_nodes_in_group(group)
	for m in markers:
		if m.name == marker_name:
			return m
	return null


# =========================
# Game over
# =========================

func endGame() -> void:
	$CanvasLayer/Score/Timer.stop()
	$Timers/MoveGhostTimer.stop()
	$Timers/BlockGhostTimer.stop()
	$Timers/FatGhostTimer.stop()
	$CanvasLayer/GameOver.visible = true
	var tween = create_tween()
	tween.tween_property(canvas_modulate, "color", Color(0.15, 0.15, 0.15), 0.5)
