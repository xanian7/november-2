extends Node2D
class_name Ladder

## Call generate, then go to the generated room
func go_to_room() -> void:
	GameManager.generate_new_room.emit()
	
	# disable the ladder so after the user uses the ladder it can't be called again
	GameManager.disable_ladder = true
	
## Check when there is a body in the area, if its the player then allow them to go to the next room
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and !GameManager.disable_ladder:
		go_to_room()
