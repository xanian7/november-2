extends TileMapLayer
class_name RoomTileMap

## Doorway centers in local tile coordinates, on the outermost wall cells.
## Keep at least two tiles from corners. Each coordinate can be connected once.
@export var hallway_coords: Array[Vector2i] = []

## Takes an input telling which tiles it should place and where and places them
func place_tiles() -> void:
	pass

## Saves the tilemap data to be used for later/recreated
func save() -> void:
	pass
