extends CharacterBody2D
class_name Player

# TODO: create a state manager to deal with player movement

@export var MAX_JUMP_TIME: float = 0.1 # variable jump max timing
@export var FALLING_VELOCITY: float = 10.0 # what to increment the falling velocity by since it feels too floaty
var time_jump_held: float = 0.0 # timer for jump
const SPEED: float = 300.0
const JUMP_VELOCITY: float = -400.0

## Add player to the player group so when the player enters an area we know it's them
func _ready() -> void:
	GameManager.spawn_player.connect(spawn)
	add_to_group("player")

## Move the player
func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	jump(delta)

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

# TODO: fix accidental double jump
## Controls the player jump. Allows for variable jump height based on the MAX_JUMP_TIME
func jump(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY # start jump - still not sure I need this
	
	if Input.is_action_pressed("jump") and time_jump_held < MAX_JUMP_TIME:
		velocity.y = JUMP_VELOCITY # jump 
		time_jump_held += delta # start countdown by applying delta to the time held
	
	if not Input.is_action_pressed("jump") and is_on_floor():
		time_jump_held = 0.0 # reset timer once on the ground again
	
	if not is_on_floor():
		velocity.y += FALLING_VELOCITY # apply more gravity so the jump feels less floaty

## Spawns the player at the coordinates given by the GameManager
func spawn() -> void:
	global_position = GameManager.player_spawn_point
	velocity = Vector2.ZERO
	time_jump_held = 0.0
