extends Node

## Emit when the game needs to create a new room 
signal generate_new_room

## Start
func _ready() -> void:
	start_game()

## Pauses the game, freezes user movement, opens pause menu
func pause() -> void:
	pass

## Quits, and closes the game, returns the user to desktop
func quit_to_desktop() -> void:
	pass

## Resumes the game after being paused, undos what pause() did
func play() -> void:
	pass

## Saves the game
func save() -> void: 
	pass

## Starts the game by generating a new room
func start_game() -> void:
	# NOTE: if this signal is connected to prior to the GameManager being created it will not signal to that class
	# TODO: Create methods that can be called to emit this signal so other classes can connect to it without having to reference eachother
	generate_new_room.emit()
	
