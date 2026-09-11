extends Node2D
class_name RoomGenerator

@export var room_tile_map : RoomTileMap
@export var custom_seed: int
@export var frequency: float = 0.05 # This will more than likely never be changed (lower the value the less noise)
@export var room_range: Vector2i = Vector2i(64, 64) # Determines the size of the room
@export var desired_spawn_point: Vector2i = Vector2i(1, room_range.y) # bottom right of the room

# TODO: put more COORDS for tiles here once they are created
const TEST_COORD = Vector2i(0,0)

func _ready() -> void: 
	GameManager.generate_new_room.connect(generate_room)

## Randomly generates a room based on arguments
## (ex. type of room, room size, etc.)
func generate_room() -> void:
	# TODO: Create a way to randomly generate rooms using noise, then place those here using the following line as an example
	room_tile_map.set_cell(Vector2i(0, 0), 0, Vector2i(0, 0))
	
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	
	# use seed if it's filled out, otherwise generate a new one
	if !custom_seed:
		noise.seed = randi()
	else:
		noise.seed = custom_seed
	GameManager.curren_room_seed = noise.seed # save current room seed to the GameManager
	noise.frequency = frequency
	
	# go through x and y maxes and place tiles within that area
	for x in range(room_range.x):
		# place outside border on the y axis
		room_tile_map.set_cell(Vector2i(x, -1), 0, TEST_COORD)
		room_tile_map.set_cell(Vector2i(x, room_range.y), 0, TEST_COORD)
		for y in range(room_range.y):
			# place outside border on the x axis
			room_tile_map.set_cell(Vector2i(-1, y), 0, TEST_COORD)
			room_tile_map.set_cell(Vector2i(room_range.x, y), 0, TEST_COORD)
			
			var value = noise.get_noise_2d(float(x), float(y)) # gets a value between -1 and 1, set different tiles based on them 
			
			# eventually there will be more values to check but for now we only have 1 type of tile
			if value > 0:
				room_tile_map.set_cell(Vector2i(x, y), 0, TEST_COORD) # place tile at designated coordinate
			else:
				pass # air space
	
	generate_spawn()
	
## Generate a spawn point for the player. It will usually be the closest spot to the bottom left of the room
## TODO: fix spawn point. currently it will spawn in the top left no matter if there is an open space or not
func generate_spawn() -> void:
	var used_cells = room_tile_map.get_used_cells()
	var found_spawn = false
	var spawn_point = desired_spawn_point
	while !found_spawn:
		if !used_cells.has(spawn_point):
			found_spawn = true
			GameManager.player_spawn_point = spawn_point
			GameManager.spawn_player.emit()
		else:
			spawn_point = Vector2i(spawn_point.x + 1, spawn_point.y)
	
## Saves the room data so the room can be recreated at any given time
func save_room() -> void:
	pass
	
## Changes the current room to the new room declared
func change_room() -> void: 
	pass
