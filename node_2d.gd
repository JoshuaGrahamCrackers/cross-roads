extends CharacterBody2D


const SPEED = 300.0
const friction =10

func _physics_process(delta: float) -> void:
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_vector("left","right","up","down")
	if direction:
		velocity = direction * SPEED
	else:
		velocity =  velocity.move_toward(Vector2.ZERO,friction)
	move_and_slide()
