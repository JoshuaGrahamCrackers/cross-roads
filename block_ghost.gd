extends CharacterBody2D

var direction := Vector2.DOWN

func _ready():
	$CollisionShape2D.disabled = true   # no collision until fade-in completes
	$Sprite2D.modulate.a = 0.0
	$PointLight2D.energy = 0.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property($Sprite2D, "modulate:a", 1.0, 1.5)
	tween.tween_property($PointLight2D, "energy", 1.0, 1.5)
	tween.finished.connect(_on_fade_in_complete)

	update_animation()

func _on_fade_in_complete():
	$CollisionShape2D.disabled = false   # now it can block/collide
	
func set_direction(dir: Vector2):
	direction = dir.normalized()
	update_animation()


func update_animation():

	var shape = $CollisionShape2D.shape

	if direction == Vector2.RIGHT:

		$Sprite2D.flip_h = false
		animate("idle-right")

		# thinner + taller
		shape.size = Vector2(36, 128)


	elif direction == Vector2.LEFT:
		$Sprite2D.flip_h = true
		animate("idle-right")

		# thinner + taller
		shape.size = Vector2(36, 128)


	elif direction == Vector2.UP:

		$Sprite2D.flip_h = false
		animate("idle-back")

		# original
		shape.size = Vector2(60, 46)


	else:

		$Sprite2D.flip_h = false
		animate("idle-front")
		# original
		shape.size = Vector2(60, 46)

func animate(anim):
	if $AnimationPlayer.current_animation != anim:
		$AnimationPlayer.play(anim)


func _on_timer_fade_timeout() -> void:
	var tween = create_tween()
	tween.set_parallel(true)  # let both properties animate at the same time
	tween.tween_property($Sprite2D, "modulate:a", 0.0, 1.0)
	tween.tween_property($PointLight2D, "energy", 0.0, 1.0)
	tween.finished.connect(queue_free)
