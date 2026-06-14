extends Sprite2D

# moving_fish_group.gd - Handles slower right-to-left group movement with a gentle sine-wave bobbing effect.

@export var speed: float = 80.0 # Slower than the single fish
@export var bob_amplitude: float = 30.0 # Height of up/down bobbing
@export var bob_frequency: float = 1.5 # Speed of up/down bobbing

var start_y: float = 0.0
var elapsed_time: float = 0.0

func _ready() -> void:
	start_y = position.y
	# Turn on flip_h so they face the left side (moving left with the current)
	flip_h = true
	# Randomize start phase so multiple groups don't bob in perfect unison
	elapsed_time = randf_range(0.0, 100.0)

func _process(delta: float) -> void:
	# 1. Move automatically from right to left
	position.x -= speed * delta
	
	# 2. Gentle up/down floating motion using sine wave
	elapsed_time += delta
	position.y = start_y + sin(elapsed_time * bob_frequency) * bob_amplitude
	
	# 3. Wrap around to the right side if it moves off-screen left
	if position.x < -200.0:
		position.x = 1800.0
		# Randomize vertical anchor position when respawning
		start_y = randf_range(150.0, 750.0)
		position.y = start_y
