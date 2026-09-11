extends Node2D
class_name RoomGenerator

@export var room_tile_map : RoomTileMap

func _ready() -> void: 
	GameManager.generate_new_room.connect(generate_room)

## Randomly generates a room based on arguments
## (ex. type of room, room size, etc.)
func generate_room() -> void:
	# TODO: Create a way to randomly generate rooms using noise, then place those here using the following line as an example
	room_tile_map.set_cell(Vector2i(0, 0), 0, Vector2i(0, 0))
	
## Saves the room data so the room can be recreated at any given time
func save_room() -> void:
	pass
	
## Changes the current room to the new room declared
func change_room() -> void: 
	pass
