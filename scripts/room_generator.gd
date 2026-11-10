#extends Node2D
#class_name RoomGenerator
#
#@export var room_tile_map : RoomTileMap
#@export var custom_seed: int
#@export var frequency: float = 0.05 # This will more than likely never be changed (lower the value the less noise)
#@export var room_range: Vector2i = Vector2i(100, 100) # Determines the size of the room
#@export var desired_spawn_point: Vector2i = Vector2i(1, room_range.y - 4) # bottom left of the room
#@export var example_tile_map: TileMapLayer
#
## Wave function collapse
#const WFC_DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
#const NUM_ATTEMPTS: int = 30
#const WFC_AIR : Vector2i = Vector2i(-1, -1)
#
## Procedural
#@export var room_presets : Array[PackedScene]
#@export var ladder_room_preset: PackedScene
#const MAX_ROOMS: int = 10
#const MIN_ROOMS: int = 4
#const MIN_SPACING: int = 5
#
## TODO: put more COORDS for tiles here once they are created
#const TEST_COORD = Vector2i(0,0)
#
#func _ready() -> void: 
	#GameManager.generate_new_room.connect(procedural_generation)
	#
### Finds supported, empty space inside a room, preferring its bottom-left area
#func generate_spawn(bounds: Array[Rect2i] = []) -> bool:
	#var player := get_tree().get_first_node_in_group("player") as Player
	#if player == null:
		#push_warning("Cannot find a player to spawn.")
		#return false
	#var collider := player.get_node("CollisionShape2D") as CollisionShape2D
	#var shape_to_map := room_tile_map.global_transform.affine_inverse() * collider.global_transform
	#var body_bounds: Rect2 = shape_to_map * collider.shape.get_rect()
	#body_bounds.position -= room_tile_map.to_local(player.global_position)
	#var search_bounds: Array[Rect2i] = bounds.duplicate()
	#if search_bounds.is_empty():
		#search_bounds.append(room_tile_map.get_used_rect())
	#for room in search_bounds:
		#var interior := room.grow(-2)
		#if not interior.has_area():
			#continue
		#for y in range(room.end.y - 1, room.position.y, -1):
			#for x in range(interior.position.x, interior.end.x):
				#var floor_cell := Vector2i(x, y)
				#if not is_spawn_floor(floor_cell, player.collision_mask):
					#continue
				#var position := room_tile_map.map_to_local(floor_cell)
				#position.x -= body_bounds.get_center().x
				#position.y -= room_tile_map.tile_set.tile_size.y * 0.5 + body_bounds.end.y + 0.5
				## Include a small margin around the player's actual collision shape
				#var occupied := Rect2(position + body_bounds.position, body_bounds.size).grow(0.25)
				#var first := room_tile_map.local_to_map(occupied.position)
				#var last := room_tile_map.local_to_map(occupied.end - Vector2(0.001, 0.001))
				#if not interior.has_point(first) or not interior.has_point(last):
					#continue
				#var safe := true
				#for column in range(first.x, last.x + 1):
					#if not is_spawn_floor(Vector2i(column, y), player.collision_mask):
						#safe = false
					#for row in range(first.y, last.y + 1):
						#if room_tile_map.get_cell_source_id(Vector2i(column, row)) != -1:
							#safe = false
				#if safe:
					#GameManager.player_spawn_point = room_tile_map.to_global(position)
					## Ladder entry occurs during physics; move after its callback finishes
					#GameManager.spawn_player_at_coords.call_deferred()
					#return true
	#push_warning("No safe player spawn found inside the generated rooms.")
	#return false
#
#
### Current room tiles have full-cell collision polygons on their floor tiles.
#func is_spawn_floor(cell: Vector2i, collision_mask: int) -> bool:
	#var tile := room_tile_map.get_cell_tile_data(cell)
	#if tile == null:
		#return false
	#for layer in range(room_tile_map.tile_set.get_physics_layers_count()):
		#if room_tile_map.tile_set.get_physics_layer_collision_layer(layer) & collision_mask:
			#if tile.get_collision_polygons_count(layer) > 0:
				#return true
	#return false
#
### takes premade levels and puts them into a single tile map, drawing lines to each to act as hallways
#func procedural_generation() -> void:
	## randomly select rooms to copy into tilemap
	#
	#room_tile_map.clear()
	#
	#var placed_bounds: Array[Rect2i] = []
	#var room_doors: Array = []
	#var num_rooms: int = randi_range(MIN_ROOMS, MAX_ROOMS)
	## loop through number of rooms and select a random room for each number
	#for i in range(num_rooms):
		#var scene: PackedScene
		#if i == 0: 
			#scene = ladder_room_preset
		#else:
			#scene = room_presets.pick_random()
		#
		#var preset: RoomTileMap = scene.instantiate() 
		#var source_bounds: Rect2i = preset.get_used_rect()
		#
		#var placed: bool = false
		#for attempt in range(100):
			#var room_position := Vector2i(
				#randi_range(0, room_range.x - source_bounds.size.x),
				#randi_range(0, room_range.y - source_bounds.size.y)
			#)
			#
			##var room_position := Vector2i.ZERO
			#
			#var candidate := Rect2i(room_position, source_bounds.size)
			#var too_close := false
			#
			#for existing in placed_bounds:
				#if candidate.grow(MIN_SPACING).intersects(existing):
					#too_close = true
					#break
					#
			#if too_close:
				#continue # try another random position
				#
			## store bounds
			#placed_bounds.append(candidate)
			#room_doors.append(get_room_doors(preset, source_bounds, room_position))
			#
			## copy the room's tiles into the generated map
			#for cell in preset.get_used_cells():
				#var destination := room_position + cell - source_bounds.position
				#room_tile_map.set_cell(
					#destination,
					#preset.get_cell_source_id(cell),
					#preset.get_cell_atlas_coords(cell),
					#preset.get_cell_alternative_tile(cell)
				#)
#
			#placed = true
			#break 
#
		## clear the instance from memory to preserve framerate
		#preset.free()
	#
	## draw lines between each room with enough space the player can get through
	#var connected_rooms := connect_room_doors(placed_bounds, room_doors)
	#var spawn_rooms: Array[Rect2i] = []
	#for index in connected_rooms:
		#spawn_rooms.append(placed_bounds[index])
	#if not spawn_rooms.is_empty():
		#generate_spawn(spawn_rooms)
#
#
### Converts preset doorway coordinates to generated-map coordinates.
#func get_room_doors(preset: RoomTileMap, bounds: Rect2i, position: Vector2i) -> Array:
	#var doors: Array = []
	#var seen: Array[Vector2i] = []
	#for cell in preset.hallway_coords:
		#if seen.has(cell):
			#continue
		#seen.append(cell)
		#var direction := Vector2i.ZERO
		#if cell.y >= bounds.position.y + 2 and cell.y < bounds.end.y - 2:
			#if cell.x == bounds.position.x:
				#direction = Vector2i.LEFT
			#elif cell.x == bounds.end.x - 1:
				#direction = Vector2i.RIGHT
		#if cell.x >= bounds.position.x + 2 and cell.x < bounds.end.x - 2:
			#if cell.y == bounds.position.y:
				#direction = Vector2i.UP
			#elif cell.y == bounds.end.y - 1:
				#direction = Vector2i.DOWN
		#if direction == Vector2i.ZERO:
			#push_warning("Invalid hallway coordinate %s in %s: use an outer wall, away from corners." % [cell, preset.name])
			#continue
		#doors.append({"cell": position + cell - bounds.position, "direction": direction})
	#if doors.is_empty():
		#push_warning("Room %s has no valid hallway_coords." % preset.name)
	#return doors
#
#
### joins new rooms to the connected group through unused doors, shortest route first
#func connect_room_doors(bounds: Array[Rect2i], room_doors: Array) -> Array[int]:
	#if bounds.is_empty():
		#return []
	#if bounds.size() == 1:
		#return [0]
	#var grid := AStarGrid2D.new()
	#var area := bounds[0]
	#for room in bounds:
		#area = area.merge(room)
	#grid.region = area.grow(8)
	#grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	#grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	#grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	#grid.update()
	## Include the wall brush radius so routes cannot graze other rooms.
	#for room in bounds:
		#grid.fill_solid_region(room.grow(2))
#
	#var connected: Array[int] = [0]
	#var used_doors: Dictionary = {}
	#var paths: Array[Vector2i] = []
	#var openings: Array = []
	#while connected.size() < bounds.size():
		#var best_path: Array[Vector2i] = []
		#var best_from := Vector2i(-1, -1)
		#var best_to := Vector2i(-1, -1)
		#for from_room in connected:
			#for to_room in range(bounds.size()):
				#if connected.has(to_room):
					#continue
				#for from_index in range(room_doors[from_room].size()):
					#var from_key := Vector2i(from_room, from_index)
					#if used_doors.has(from_key):
						#continue
					#for to_index in range(room_doors[to_room].size()):
						#var to_key := Vector2i(to_room, to_index)
						#var from_door: Dictionary = room_doors[from_room][from_index]
						#var to_door: Dictionary = room_doors[to_room][to_index]
						#var start: Vector2i = from_door.cell + from_door.direction * 3
						#var finish: Vector2i = to_door.cell + to_door.direction * 3
						#if grid.is_point_solid(start) or grid.is_point_solid(finish):
							#continue
						#var route: Array[Vector2i] = grid.get_id_path(start, finish)
						#if not route.is_empty() and (best_path.is_empty() or route.size() < best_path.size()):
							#best_path = route
							#best_from = from_key
							#best_to = to_key
		#if best_path.is_empty():
			#push_warning("Connected %d of %d rooms. Add usable hallway_coords or leave more space." % [connected.size(), bounds.size()])
			#break
		#paths.append_array(best_path)
		#for key in [best_from, best_to]:
			#used_doors[key] = true
			#var door: Dictionary = room_doors[key.x][key.y]
			#openings.append(door)
			## A straight approach keeps the corridor perpendicular to the wall.
			#for step in range(4):
				#paths.append(door.cell + door.direction * step)
		#connected.append(best_to.x)
	#build_corridors(paths, bounds)
	## Only explicitly selected doorways may alter cells inside a room.
	#for door in openings:
		#var sideways := Vector2i(-door.direction.y, door.direction.x)
		#for depth in range(2):
			#for offset in range(-1, 2):
				#room_tile_map.erase_cell(door.cell - door.direction * depth + sideways * offset)
	#return connected
#
#
### tests room bounds, optionally excluding a border of inset tiles
#func is_inside_room(cell: Vector2i, bounds: Array[Rect2i], inset: int = 0) -> bool:
	#for room_bounds in bounds:
		#var interior := room_bounds.grow(-inset)
		#if interior.has_area() and interior.has_point(cell):
			#return true
	#return false
#
#
### builds tunnels outside rooms and opens doorways through their outer walls
#func build_corridors(path: Array[Vector2i], bounds: Array[Rect2i]) -> void:
	#for cell in path:
		#for x in range(-2, 3):
			#for y in range(-2, 3):
				#var destination := cell + Vector2i(x, y)
				## The wall brush must never add solids inside a premade room.
				#if not is_inside_room(destination, bounds):
					#room_tile_map.set_cell(destination, 0, TEST_COORD)
#
	## clear every interior after building all walls so bends and crossings stay open
	#for cell in path:
		#for x in range(-1, 2):
			#for y in range(-1, 2):
				#var destination := cell + Vector2i(x, y)
				## Doorways are opened separately; all other room cells are protected.
				#if not is_inside_room(destination, bounds):
					#room_tile_map.erase_cell(destination)
#
### Saves the room data so the room can be recreated at any given time
#func save_room() -> void:
	#pass
	#
### Changes the current room to the new room declared
#func change_room() -> void: 
	#pass
