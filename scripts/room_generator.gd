extends Node2D
class_name RoomGenerator

@export var room_tile_map : RoomTileMap
@export var custom_seed: int
@export var frequency: float = 0.05 # This will more than likely never be changed (lower the value the less noise)
@export var room_range: Vector2i = Vector2i(256, 256) # Determines the size of the room
@export var desired_spawn_point: Vector2i = Vector2i(1, room_range.y - 4) # bottom left of the room
@export var example_tile_map: TileMapLayer

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
# TODO: find a spot to generate a ladder
func generate_spawn() -> void:
	var used_cells = room_tile_map.get_used_cells()
	var found_spawn = false
	var spawn_point = desired_spawn_point
	while !found_spawn:
		if !used_cells.has(spawn_point):
			found_spawn = true
			var local_coords = room_tile_map.map_to_local(spawn_point) # coords of a tilemap don't directly align to coords on the local coordinate plane so convert them to local 
			GameManager.player_spawn_point = room_tile_map.to_global(local_coords) # take the local coords and convert them to the global coordinate plane
			GameManager.spawn_player.emit()
		else:
			spawn_point = Vector2i(spawn_point.x + 1, spawn_point.y)

func wfc(tilemap: TileMapLayer) -> void: 
	# get all different types of tiles in the tileset
	var tiles = tilemap.get_used_cells()
	
	# create a dictionary of tiles where their possible neighbors will be listed
	var possible_tiles: Dictionary[Vector2i, TilePossibilities]
	
	for tile in tiles: 
		#var tile_id = tilemap.get_cell_source_id(tile) # gets the tile id from the coords
		var possible_neighbors = tilemap.get_surrounding_cells(tile) # gets its surrounding compatible friends
		var existing_tile = possible_tiles.get_or_add(tile) # checks if there is an already existing coord in the dictionary for it
		
		var possibility_object: TilePossibilities
		if existing_tile: # if it exists then just append the possbile tiles
			possibility_object = existing_tile
			
		# parse through tilemap and add to the dictionary what the given tiles have as neighbors
		for neighbor in possible_neighbors:
			if neighbor.x > tile.x:
				possibility_object.right.append(neighbor)
			elif neighbor.x < tile.x:
				possibility_object.left.append(neighbor)
			elif neighbor.y > tile.y:
				possibility_object.down.append(neighbor)
			elif neighbor.y < tile.y:
				possibility_object.up.append(neighbor)
			else:
				pass # placeholder for now
				
	var all_tile_ids = possible_tiles.keys()
	
	wfc_find_and_place_tiles(Vector2i(0,0), possible_tiles)
	
	
	# the tilemap to generate should have a size so loop through the x and y values of the size
	for x in room_range.x:
		for y in room_range.y:
			# check potential neighbors
			var surrounding_tiles = room_tile_map.get_surrounding_cells(Vector2i(x, y))
			if not surrounding_tiles.any: # has no neighbors
				# place random tile
				room_tile_map.set_cell(Vector2i(x, y), 0, all_tile_ids[randi_range(0, all_tile_ids.size())])
			else:
				# check every neighbor and place a tile based on the list of possiblilties given after assessing which can be placed
				var possible: TilePossibilities = possible_tiles.get(Vector2i(x, y))
				
				
			# if the tile its about to place has another neighbor then select 
			# one that satisfies both neighboring conditions
		
	pass

func wfc_find_and_place_tiles(coords: Vector2i, possible_tiles: Dictionary[Vector2i, TilePossibilities]) -> void:
	if coords.x > room_range.x and coords.y > room_range.y:
		return 
		
	var surrounding_tiles = room_tile_map.get_surrounding_cells(coords)
	if surrounding_tiles:
		var possible: TilePossibilities = possible_tiles.get(coords)
	else:
		pass
	
	

## Searches for a valid tile to place based on possible neighbors and returns the atlas coordinates of the tile to place
func wfc_valid_tile_search(tile_to_place_coords: Vector2i, possible_tiles: Dictionary[Vector2i, TilePossibilities]) -> Vector2i:
	var possible: TilePossibilities = possible_tiles.get(tile_to_place_coords)
	
	
		
	return Vector2i(0,0)

## Saves the room data so the room can be recreated at any given time
func save_room() -> void:
	pass
	
## Changes the current room to the new room declared
func change_room() -> void: 
	pass
