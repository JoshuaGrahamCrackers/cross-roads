extends CharacterBody2D

const SPEED = 300.0
const friction = 100

var last_dir := Vector2.DOWN
var dead := false

var dev_mode := true
var noclip := false


func _ready():

	for ghost in get_tree().get_nodes_in_group("ghost"):
		ghost.player_attacked.connect(die)


func _physics_process(delta: float) -> void:

	if dead:
		return


	# CHEATS / NOCLIP
	if dev_mode and Input.is_action_just_pressed("cheats"):

		noclip = !noclip

		$CollisionShape2D.disabled = noclip

		print("noclip:", noclip)


	var anim := ""
	var direction := Input.get_vector("left", "right", "up", "down")


	if direction != Vector2.ZERO:

		last_dir = direction
		anim = get_anim("walk", last_dir)


		if noclip:

			# move without collisions
			global_position += direction * SPEED * delta

		else:

			velocity = direction * SPEED
			move_and_slide()

	else:

		velocity = velocity.move_toward(Vector2.ZERO, friction)
		anim = get_anim("idle", last_dir)

		if !noclip:
			move_and_slide()


	animate(anim)


func die():

	if dead:
		return

	dead = true
	velocity = Vector2.ZERO

	$AnimationPlayer.play(get_anim("die", last_dir))


func get_anim(prefix: String, dir: Vector2) -> String:

	if abs(dir.x) > abs(dir.y):
		return prefix + ("-right" if dir.x > 0 else "-left")

	else:
		return prefix + ("-front" if dir.y > 0 else "-back")


func animate(anim):

	if $AnimationPlayer.current_animation != anim:
		$AnimationPlayer.play(anim)
