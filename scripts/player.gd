extends CharacterBody2D

# Player controller for Amir (the diver).
# Handles 8-way swimming movement, oxygen consumption, hazards, and animation states.

@export var base_speed: float = 250.0
@export var oxygen_drain_rate: float = 3.5 # Oxygen lost per second

var current_speed_modifier: float = 1.0
var is_active: bool = true
var elapsed_time: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Connect to the ocean health signal to dynamically update oxygen drain rate
	GameManager.ocean_health_changed.connect(_on_ocean_health_changed)
	_on_ocean_health_changed(GameManager.ocean_health)

func _on_ocean_health_changed(health: float) -> void:
	if health >= 80.0:
		# Clean state: very slow drain (tutorial friendly)
		oxygen_drain_rate = 1.8
	elif health >= 40.0:
		# Polluted state: medium drain
		oxygen_drain_rate = 3.0
	else:
		# Critical state: faster drain (creates urgency)
		oxygen_drain_rate = 5.5

func _physics_process(delta: float) -> void:
	if not is_active:
		return
		
	# 1. Handle Movement Input — joystick takes priority over keyboard
	var input_vector = Vector2.ZERO

	# Try to read from virtual joystick (added to 'joystick' group by HUD)
	var joysticks = get_tree().get_nodes_in_group("joystick")
	if joysticks.size() > 0 and joysticks[0].has_method("get_input_vector"):
		input_vector = joysticks[0].get_input_vector()

	# Fallback: keyboard / gamepad input
	if input_vector == Vector2.ZERO:
		input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
		input_vector = input_vector.normalized()
		
	# Calculate speed with active modifiers and check for algal bloom penalty
	var speed = base_speed * current_speed_modifier
	if GameManager.ocean_health < 30.0:
		speed *= 0.75 # Slow speed due to thick algal bloom growth
		
	velocity = input_vector * speed
	move_and_slide()

	
	# Clamp position so the diver cannot swim off-screen (ocean boundary is 1600x900)
	global_position.x = clamp(global_position.x, 32.0, 1568.0)
	global_position.y = clamp(global_position.y, 32.0, 868.0)
	
	# 3. Handle Sprite Flipping, Animation Playback, and Idle Floating
	elapsed_time += delta
	if velocity.length() > 0:
		sprite.play("swim")
		if velocity.x < 0:
			sprite.flip_h = true
		elif velocity.x > 0:
			sprite.flip_h = false
		# Smoothly align sprite position back to center when moving
		sprite.position.y = lerp(sprite.position.y, 0.0, 10.0 * delta)
		
	else:
		sprite.pause()
		# Gentle up-and-down floating motion when idle (static)
		sprite.position.y = sin(elapsed_time * 2.0) * 8.0
		
	# 2. Oxygen System
	if global_position.y <= 120.0:
		# Refill oxygen rapidly when at the surface, scaling with ocean health
		var refill_rate = 50.0
		var health = GameManager.ocean_health
		if health >= 80.0:
			refill_rate = 90.0
		elif health < 40.0:
			refill_rate = 25.0
				
		GameManager.adjust_oxygen(refill_rate * delta)
	else:
		# Drain oxygen over time
		GameManager.adjust_oxygen(-oxygen_drain_rate * delta)

# Apply speed reduction when entering microplastics
func slow_down(factor: float) -> void:
	current_speed_modifier = factor

# Reset speed to normal
func restore_speed() -> void:
	current_speed_modifier = 1.0

# Disable movement (e.g., during level transitions or game over)
func deactivate() -> void:
	is_active = false
	velocity = Vector2.ZERO
