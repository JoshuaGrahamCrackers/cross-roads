extends Node2D

func _ready():
	$Label.pivot_offset = $Label.size / 2
	swing($Label)
	swing($Label2)

func swing(label: Label):
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(label, "rotation_degrees", 8, 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "rotation_degrees", -8, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "rotation_degrees", 0, 0.3).set_trans(Tween.TRANS_SINE)
