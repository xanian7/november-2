extends RigidBody2D

@export var MAX_HEALTH: int = 100 # default to 100, will be more for bosses
var health_remaining: int = MAX_HEALTH # default to MAX_HEALTH until otherwise changed

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("enemy")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	

func move(delta: float) -> void:
	pass
	
	
func take_damage(damage_amount: int) -> void:
	pass

## survey area state
func _state_survey(delta: float) -> void:
	pass
	
## after an attack it has to wait before attacking again
func _state_recharge() -> void:
	pass

## attack state
func _state_attack() -> void:
	pass
