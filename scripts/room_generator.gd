extends Node2D
class_name RoomGenerator

@export var room_tile_map : RoomTileMap
@export var custom_seed: int
@export var frequency: float = 0.05 # This will more than likely never be changed (lower the value the less noise)
@export var room_range: Vector2i = Vector2i(100, 100) # Determines the size of the room
@export var desired_spawn_point: Vector2i = Vector2i(1, room_range.y - 4) # bottom left of the room
@export var example_tile_map: TileMapLayer

# Wave function collapse
const WFC_DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const NUM_ATTEMPTS: int = 30
const WFC_AIR : Vector2i = Vector2i(-1, -1)

# Procedural
@export var room_presets : Array[PackedScene]
const MAX_ROOMS: int = 10
const MIN_ROOMS: int = 4
const MIN_SPACING: int = 5

# TODO: put more COORDS for tiles here once they are created
const TEST_COORD = Vector2i(0,0)

func _ready() -> void: 
	GameManager.generate_new_room.connect(procedural_generation)

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
	
## Finds supported, empty space inside a room, preferring its bottom-left area.
func generate_spawn(bounds: Array[Rect2i] = []) -> bool:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		push_warning("Cannot find a player to spawn.")
		return false
	var collider := player.get_node("CollisionShape2D") as CollisionShape2D
	var shape_to_map := room_tile_map.global_transform.affine_inverse() * collider.global_transform
	var body_bounds: Rect2 = shape_to_map * collider.shape.get_rect()
	body_bounds.position -= room_tile_map.to_local(player.global_position)
	var search_bounds: Array[Rect2i] = bounds.duplicate()
	if search_bounds.is_empty():
		search_bounds.append(room_tile_map.get_used_rect())
	for room in search_bounds:
		var interior := room.grow(-2)
		if not interior.has_area():
			continue
		for y in range(room.end.y - 1, room.position.y, -1):
			for x in range(interior.position.x, interior.end.x):
				var floor_cell := Vector2i(x, y)
				if not is_spawn_floor(floor_cell, player.collision_mask):
					continue
				var position := room_tile_map.map_to_local(floor_cell)
				position.x -= body_bounds.get_center().x
				position.y -= room_tile_map.tile_set.tile_size.y * 0.5 + body_bounds.end.y + 0.5
				# Include a small margin around the player's actual collision shape.
				var occupied := Rect2(position + body_bounds.position, body_bounds.size).grow(0.25)
				var first := room_tile_map.local_to_map(occupied.position)
				var last := room_tile_map.local_to_map(occupied.end - Vector2(0.001, 0.001))
				if not interior.has_point(first) or not interior.has_point(last):
					continue
				var safe := true
				for column in range(first.x, last.x + 1):
					if not is_spawn_floor(Vector2i(column, y), player.collision_mask):
						safe = false
					for row in range(first.y, last.y + 1):
						if room_tile_map.get_cell_source_id(Vector2i(column, row)) != -1:
							safe = false
				if safe:
					GameManager.player_spawn_point = room_tile_map.to_global(position)
					# Ladder entry occurs during physics; move after its callback finishes.
					GameManager.spawn_player_at_coords.call_deferred()
					return true
	push_warning("No safe player spawn found inside the generated rooms.")
	return false


## Current room tiles have full-cell collision polygons on their floor tiles.
func is_spawn_floor(cell: Vector2i, collision_mask: int) -> bool:
	var tile := room_tile_map.get_cell_tile_data(cell)
	if tile == null:
		return false
	for layer in range(room_tile_map.tile_set.get_physics_layers_count()):
		if room_tile_map.tile_set.get_physics_layer_collision_layer(layer) & collision_mask:
			if tile.get_collision_polygons_count(layer) > 0:
				return true
	return false


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

## takes premade levels and puts them into a single tile map, drawing lines to each to act as hallways
func procedural_generation() -> void:
	# randomly select rooms to copy into tilemap
	
	room_tile_map.clear()
	
	var placed_bounds: Array[Rect2i] = []
	var room_doors: Array = []
	var num_rooms: int = randi_range(MIN_ROOMS, MAX_ROOMS)
	# loop through number of rooms and select a random room for each number
	for i in range(num_rooms):
		var scene: PackedScene = room_presets.pick_random()
		var preset: RoomTileMap = scene.instantiate() 
		var source_bounds: Rect2i = preset.get_used_rect()
		
		var placed: bool = false
		for attempt in range(100):
			var room_position := Vector2i(
				randi_range(0, room_range.x - source_bounds.size.x),
				randi_range(0, room_range.y - source_bounds.size.y)
			)
			
			#var room_position := Vector2i.ZERO
			
			var candidate := Rect2i(room_position, source_bounds.size)
			var too_close := false
			
			for existing in placed_bounds:
				if candidate.grow(MIN_SPACING).intersects(existing):
					too_close = true
					break
					
			if too_close:
				continue # try another random position
				
			# store bounds
			placed_bounds.append(candidate)
			room_doors.append(get_room_doors(preset, source_bounds, room_position))
			
			# copy the room's tiles into the generated map
			for cell in preset.get_used_cells():
				var destination := room_position + cell - source_bounds.position
				room_tile_map.set_cell(
					destination,
					preset.get_cell_source_id(cell),
					preset.get_cell_atlas_coords(cell),
					preset.get_cell_alternative_tile(cell)
				)

			placed = true
			break 

		# clear the instance from memory to preserve framerate
		preset.free()
	
	# draw lines between each room with enough space the player can get through
	var connected_rooms := connect_room_doors(placed_bounds, room_doors)
	var spawn_rooms: Array[Rect2i] = []
	for index in connected_rooms:
		spawn_rooms.append(placed_bounds[index])
	if not spawn_rooms.is_empty():
		generate_spawn(spawn_rooms)


## Converts preset doorway coordinates to generated-map coordinates.
func get_room_doors(preset: RoomTileMap, bounds: Rect2i, position: Vector2i) -> Array:
	var doors: Array = []
	var seen: Array[Vector2i] = []
	for cell in preset.hallway_coords:
		if seen.has(cell):
			continue
		seen.append(cell)
		var direction := Vector2i.ZERO
		if cell.y >= bounds.position.y + 2 and cell.y < bounds.end.y - 2:
			if cell.x == bounds.position.x:
				direction = Vector2i.LEFT
			elif cell.x == bounds.end.x - 1:
				direction = Vector2i.RIGHT
		if cell.x >= bounds.position.x + 2 and cell.x < bounds.end.x - 2:
			if cell.y == bounds.position.y:
				direction = Vector2i.UP
			elif cell.y == bounds.end.y - 1:
				direction = Vector2i.DOWN
		if direction == Vector2i.ZERO:
			push_warning("Invalid hallway coordinate %s in %s: use an outer wall, away from corners." % [cell, preset.name])
			continue
		doors.append({"cell": position + cell - bounds.position, "direction": direction})
	if doors.is_empty():
		push_warning("Room %s has no valid hallway_coords." % preset.name)
	return doors


## Joins new rooms to the connected group through unused doors, shortest route first.
func connect_room_doors(bounds: Array[Rect2i], room_doors: Array) -> Array[int]:
	if bounds.is_empty():
		return []
	if bounds.size() == 1:
		return [0]
	var grid := AStarGrid2D.new()
	var area := bounds[0]
	for room in bounds:
		area = area.merge(room)
	grid.region = area.grow(8)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.update()
	# Include the wall brush radius so routes cannot graze other rooms.
	for room in bounds:
		grid.fill_solid_region(room.grow(2))

	var connected: Array[int] = [0]
	var used_doors: Dictionary = {}
	var paths: Array[Vector2i] = []
	var openings: Array = []
	while connected.size() < bounds.size():
		var best_path: Array[Vector2i] = []
		var best_from := Vector2i(-1, -1)
		var best_to := Vector2i(-1, -1)
		for from_room in connected:
			for to_room in range(bounds.size()):
				if connected.has(to_room):
					continue
				for from_index in range(room_doors[from_room].size()):
					var from_key := Vector2i(from_room, from_index)
					if used_doors.has(from_key):
						continue
					for to_index in range(room_doors[to_room].size()):
						var to_key := Vector2i(to_room, to_index)
						var from_door: Dictionary = room_doors[from_room][from_index]
						var to_door: Dictionary = room_doors[to_room][to_index]
						var start: Vector2i = from_door.cell + from_door.direction * 3
						var finish: Vector2i = to_door.cell + to_door.direction * 3
						if grid.is_point_solid(start) or grid.is_point_solid(finish):
							continue
						var route: Array[Vector2i] = grid.get_id_path(start, finish)
						if not route.is_empty() and (best_path.is_empty() or route.size() < best_path.size()):
							best_path = route
							best_from = from_key
							best_to = to_key
		if best_path.is_empty():
			push_warning("Connected %d of %d rooms. Add usable hallway_coords or leave more space." % [connected.size(), bounds.size()])
			break
		paths.append_array(best_path)
		for key in [best_from, best_to]:
			used_doors[key] = true
			var door: Dictionary = room_doors[key.x][key.y]
			openings.append(door)
			# A straight approach keeps the corridor perpendicular to the wall.
			for step in range(4):
				paths.append(door.cell + door.direction * step)
		connected.append(best_to.x)
	build_corridors(paths, bounds)
	# Only explicitly selected doorways may alter cells inside a room.
	for door in openings:
		var sideways := Vector2i(-door.direction.y, door.direction.x)
		for depth in range(2):
			for offset in range(-1, 2):
				room_tile_map.erase_cell(door.cell - door.direction * depth + sideways * offset)
	return connected


## Tests room bounds, optionally excluding a border of inset tiles.
func is_inside_room(cell: Vector2i, bounds: Array[Rect2i], inset: int = 0) -> bool:
	for room_bounds in bounds:
		var interior := room_bounds.grow(-inset)
		if interior.has_area() and interior.has_point(cell):
			return true
	return false


## Builds tunnels outside rooms and opens doorways through their outer walls.
func build_corridors(path: Array[Vector2i], bounds: Array[Rect2i]) -> void:
	for cell in path:
		for x in range(-2, 3):
			for y in range(-2, 3):
				var destination := cell + Vector2i(x, y)
				# The wall brush must never add solids inside a premade room.
				if not is_inside_room(destination, bounds):
					room_tile_map.set_cell(destination, 0, TEST_COORD)

	# Clear every interior after building all walls so bends and crossings stay open.
	for cell in path:
		for x in range(-1, 2):
			for y in range(-1, 2):
				var destination := cell + Vector2i(x, y)
				# Doorways are opened separately; all other room cells are protected.
				if not is_inside_room(destination, bounds):
					room_tile_map.erase_cell(destination)

## Saves the room data so the room can be recreated at any given time
func save_room() -> void:
	pass
	
## Changes the current room to the new room declared
func change_room() -> void: 
	pass
