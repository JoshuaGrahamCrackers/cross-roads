extends CharacterBody2D

const SPEED = 300.0
const friction = 100
var last_dir := Vector2.DOWN

func _physics_process(delta: float) -> void:

	var anim := ""
	var direction := Input.get_vector("left","right","up","down")

	if direction != Vector2.ZERO:
		last_dir = direction
		velocity = direction * SPEED
		anim = get_anim("walk", last_dir)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction)

		anim = get_anim("idle", last_dir)

	animate(anim)
	move_and_slide()


func get_anim(prefix: String, dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return prefix + ("-right" if dir.x > 0 else "-left")
	else:
		return prefix + ("-front" if dir.y > 0 else "-back")


func animate(anim):
	if $AnimationPlayer.current_animation != anim:
		$AnimationPlayer.play(anim)
