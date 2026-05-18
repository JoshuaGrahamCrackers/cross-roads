extends Node2D

@onready var spawn_points = $"Ghost-Spawn".get_children()
@onready var ghost_container = $Chars/Ghosts

var ghost_scene = preload("res://ghost.tscn")

func _on_timer_timeout() -> void:
	var ghost = ghost_scene.instantiate()

	var random_marker = spawn_points.pick_random()

	ghost.global_position = random_marker.global_position
	#opposite direction needed so they go across player
	if random_marker.name.contains("left"):
		ghost.set_direction(Vector2.RIGHT)
		print('left')
	elif random_marker.name.contains("down"):
		ghost.set_direction(Vector2.UP)
		print('down')
	elif random_marker.name.contains("up"):
		ghost.set_direction(Vector2.DOWN)
		print('down')
	else:
		ghost.set_direction(Vector2.LEFT)
		print('right')
	ghost_container.add_child(ghost)
