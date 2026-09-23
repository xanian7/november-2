extends Node2D
class_name RoomGenerator

@export var room_tile_map : RoomTileMap
@export var custom_seed: int
@export var frequency: float = 0.05 # This will more than likely never be changed (lower the value the less noise)
@export var room_range: Vector2i = Vector2i(50, 50) # Determines the size of the room
@export var desired_spawn_point: Vector2i = Vector2i(1, room_range.y - 4) # bottom left of the room
@export var example_tile_map: TileMapLayer

# Wave function collapse
const WFC_DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const NUM_ATTEMPTS: int = 30
const WFC_AIR : Vector2i = Vector2i(-1, -1)

# TODO: put more COORDS for tiles here once they are created
const TEST_COORD = Vector2i(0,0)

func _ready() -> void: 
	GameManager.generate_new_room.connect(wfc)

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


func wfc(tilemap: TileMapLayer = null) -> void: 
	if tilemap == null:
		tilemap = example_tile_map
	
	var rules: Dictionary[Vector2i, TilePossibilities] = {} # Vector2i is the tile type and TilePossibilities is the allowed neighboring tiles
	var sample_rect := tilemap.get_used_rect() # get the used tiles in the tilemap
	
	# if the sample tilemap has nothing then do nothing
	if sample_rect.size == Vector2i.ZERO:
		return
	
	for x in range(sample_rect.position.x, sample_rect.end.x):
		for y in range(sample_rect.position.y, sample_rect.end.y):
			var coords := Vector2i(x, y)
			var tile_type : Vector2i = wfc_tile_type(tilemap, coords) # get what type of tile is at the coords
			
			# instantiate a new tile and its possible neighbors in the dictionary if it doesnt already exist
			if not rules.has(tile_type):
				rules[tile_type] = TilePossibilities.new()
			
			# go through each direction to get the allowed neighbors for each tile
			for direction in WFC_DIRECTIONS:
				var neighbor_position: Vector2i = coords + direction
				
				# skip points outside the example tilemap area instead of assigning it to an air tile
				if not sample_rect.has_point(neighbor_position):
					continue
				
				var neighbor_type : Vector2i = wfc_tile_type(tilemap, neighbor_position)
				var allowed : Array[Vector2i] = wfc_allowed(rules[tile_type], direction) # get the allowed tiles
				
				# check if the allowed array already has the neighbor, if not add it to the array
				if not allowed.has(neighbor_type):
					allowed.append(neighbor_type)
	
	for attempt in range(NUM_ATTEMPTS):
		var wave : Dictionary = wfc_solve(rules) # returns the tiles to place after it's been solved 
		
		# restart the solution
		if wave.is_empty():
			continue
		
		room_tile_map.clear() # figure out why tf this works
		
		# place the tiles 
		for coords in wave: 
			var tile_type: Vector2i = wave[coords][0]
			
			if tile_type != WFC_AIR:
				room_tile_map.set_cell(coords, 1, tile_type)
		
		return
		
	push_warning("WFC did not find a solution") # debug, TODO: remove once reworked 

## returns the tile's atlas coords at the coords designated by @coords
func wfc_tile_type(tilemap: TileMapLayer, coords: Vector2i) -> Vector2i:
	if tilemap.get_cell_source_id(coords) == -1:
		return WFC_AIR # no tile placed which means it's an air tile
		
	return tilemap.get_cell_atlas_coords(coords) # return the altas coords of tile at the coords designated

## returns the allowed tiles at the given direction
func wfc_allowed(possibilites: TilePossibilities, direction: Vector2i) -> Array[Vector2i]:
	match direction:
		Vector2i.LEFT:
			return possibilites.left
		Vector2i.RIGHT:
			return possibilites.right
		Vector2i.UP:
			return possibilites.up
		Vector2i.DOWN:
			return possibilites.down
	return []
	
func wfc_solve(rules: Dictionary[Vector2i, TilePossibilities]) -> Dictionary:
	var wave: Dictionary = {} 
	var all_types : Array[Vector2i] = rules.keys()
	var pending: Array[Vector2i] = []
	
	for x in range(room_range.x):
		for y in range(room_range.y):
			var coords := Vector2i(x, y)
			
			wave[coords] = all_types.duplicate()
			pending.append(coords)
			
	while true:
		if not wfc_propagate(wave, rules, pending):
			return {}
		
		var smallest_count: int = all_types.size() + 1
		var candidates: Array[Vector2i] = []
		
		for coords in wave:
			var count: int = wave[coords].size()
			
			if count == 0:
				return {}
			if count == 1:
				continue
			if count < smallest_count:
				smallest_count = count
				candidates.clear() 
				candidates.append(coords)
			elif count == smallest_count:
				candidates.append(coords)
				
		if candidates.is_empty():
			return wave
			
		var chosen_position: Vector2i = candidates.pick_random()
		var chosen_type: Vector2i = wave[chosen_position].pick_random()
		
		wave[chosen_position] = [chosen_type]
		pending.append(chosen_position)
		
	return {}
	
func wfc_propagate(wave: Dictionary, rules: Dictionary[Vector2i, TilePossibilities], pending: Array[Vector2i]) -> bool:
	while not pending.is_empty():
		var coords: Vector2i = pending.pop_back()
		
		for direction in WFC_DIRECTIONS:
			var neighbor_position: Vector2i = coords + direction
			
			if not wave.has(neighbor_position):
				continue
				
			var supported: Array[Vector2i] = []
			for tile_type in wave[coords]:
				var allowed : Array[Vector2i] = wfc_allowed(rules[tile_type], direction)
				
				for neighbor_type in allowed:
					if not supported.has(neighbor_type):
						supported.append(neighbor_type)
			
			var remaining: Array[Vector2i] = []
			
			for neighbor_type in wave[neighbor_position]:
				if supported.has(neighbor_type):
					remaining.append(neighbor_type)
					
			if remaining.is_empty():
				return false
				
			if remaining.size() < wave[neighbor_position].size():
				wave[neighbor_position] = remaining
				
				if not pending.has(neighbor_position):
					pending.append(neighbor_position)
	
	return true


## Saves the room data so the room can be recreated at any given time
func save_room() -> void:
	pass
	
## Changes the current room to the new room declared
func change_room() -> void: 
	pass
