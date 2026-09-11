extends CharacterBody2D
class_name Player

# TODO: create a state manager to deal with player movement
# TODO: create a variable height jump

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

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
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

## Spawns the player at the coordinates given by the GameManager
func spawn() -> void:
	position = GameManager.player_spawn_point
