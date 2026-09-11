extends Node2D
class_name Ladder

@export var room_generator: RoomGenerator

## Connect generate signal from the Game Manager
func _ready() -> void:
	GameManager.generate_new_room.connect(go_to_room)

## Call generate, then go to the generated room
func go_to_room() -> void:
	room_generator.generate_room()
	
## Check when there is a body in the area, if its the player then allow them to go to the next room
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		go_to_room()
