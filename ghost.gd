extends CharacterBody2D

const SPEED = 300.0
const friction = 100
var direction:=Vector2.RIGHT

	
var lifetime := 10.0

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
	velocity = direction * SPEED
	var anim = get_anim('walk', direction)
	move_and_slide()
	animate(anim)

func set_direction(dir: Vector2):
	direction = dir.normalized()
	


func get_anim(prefix: String, dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return prefix + "-right"  # always use right anim for horizontal
	else:
		return prefix + ("-front" if dir.y > 0 else "-back")


func animate(anim):
	# flip when going left
	if direction.x < 0:
		$Sprite2D.flip_h = true
	elif direction.x > 0:
		$Sprite2D.flip_h = false

	if $AnimationPlayer.current_animation != anim:
		$AnimationPlayer.play(anim)
