extends Node2D
class_name Level

@export var LEVELS_LIST: Array[PackedScene]
var SPAWN_COORDS: Vector2i = Vector2i(100, 100)

## really only here to connect to signals on run time
func _ready() -> void:
	GameManager.load_new_room.connect(select_level)

## randomly select a level from our list and then put it in the scene
func select_level() -> void:
	if get_child_count() > 0:
		remove_level()
	
	var selected_level = LEVELS_LIST.pick_random()
	# instantiate the level
	var instance: RoomTileMap = selected_level.instantiate()
	
	# put it in the scene under the Level Node 
	instance.position = SPAWN_COORDS
	call_deferred("add_child", instance)
	
	# call something to deal with placing the player inside
	# this is definitely not the best way of doing this but whatever
	GameManager.player_spawn_point = instance.SPAWN_MARKER.global_position
	GameManager.spawn_player_at_coords()
	
## if there is a level already spawned then we need to remove it before we spawn a new one
## NOTE: this will remove all children under the 'Level' Node
func remove_level() -> void:
	for child in get_children():
		call_deferred("remove_child", child)
		child.queue_free()
