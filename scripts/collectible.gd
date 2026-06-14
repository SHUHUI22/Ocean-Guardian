extends Area2D

# Represents either plastic waste to collect or a trapped marine animal to rescue.

enum CollectibleType { PLASTIC, FISH }

@export var type: CollectibleType = CollectibleType.PLASTIC
@export var is_plastic_bag: bool = false
@export var score_value: int = 10
@export var custom_fact_message: String = ""

# Drifting parameters
@export var is_drifting: bool = false
@export var drift_speed: float = 40.0
@export var bob_amplitude: float = 15.0
@export var bob_frequency: float = 1.0

var start_y: float = 0.0
var elapsed_time: float = 0.0
var is_spawned: bool = false
var spawned_on_left: bool = false
var fall_from_above: bool = false
var target_y_depth: float = 0.0
var fall_speed: float = 180.0
var is_drifting_randomly: bool = false
var drift_dir: Vector2 = Vector2.ZERO
var drift_float_speed: float = 40.0

# References to nodes or visual effects
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Connect the body_entered signal to check for the player
	body_entered.connect(_on_body_entered)
	
	start_y = position.y
	elapsed_time = randf_range(0.0, 100.0)
	
	if is_drifting:
		drift_speed = randf_range(80.0, 110.0)
	
	# Set default score values if not overridden
	if type == CollectibleType.FISH:
		score_value = 20
		if custom_fact_message == "":
			custom_fact_message = "Sea animals mistake plastic for food and can choke or starve."
	else:
		score_value = 10
		if custom_fact_message == "":
			custom_fact_message = "Over 8 million tons of plastic enter our oceans every single year."
		add_to_group("trash_zones")

func _process(delta: float) -> void:
	if fall_from_above:
		if position.y < target_y_depth:
			position.y += fall_speed * delta
			sprite.rotation += 2.0 * delta
		else:
			position.y = target_y_depth
			sprite.rotation = 0.0
			fall_from_above = false
			is_drifting_randomly = true
			drift_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
			drift_float_speed = randf_range(35.0, 55.0)
	elif is_drifting_randomly:
		position += drift_dir * drift_float_speed * delta
		sprite.rotation += 0.4 * delta * (1.0 if drift_dir.x > 0 else -1.0)
		
		# Screen bounds bounce check (1280x720)
		if position.x < 50.0:
			position.x = 50.0
			drift_dir.x = abs(drift_dir.x)
		elif position.x > 1230.0:
			position.x = 1230.0
			drift_dir.x = -abs(drift_dir.x)
			
		if position.y < 100.0:
			position.y = 100.0
			drift_dir.y = abs(drift_dir.y)
		elif position.y > 680.0:
			position.y = 680.0
			drift_dir.y = -abs(drift_dir.y)
	elif is_drifting:
		# Gentle up and down floating motion
		elapsed_time += delta
		position.y = start_y + sin(elapsed_time * bob_frequency) * bob_amplitude
		
		# Move automatically (right to left, or left to right if spawned on left)
		if spawned_on_left:
			position.x += drift_speed * delta
			# Once it enters the screen area from left, switch to random drifting so it doesn't flow out
			if position.x >= 150.0:
				is_drifting = false
				is_drifting_randomly = true
				# Force initial drift to continue moving to the right (inward)
				drift_dir = Vector2(randf_range(0.2, 1.0), randf_range(-1.0, 1.0)).normalized()
				drift_float_speed = randf_range(35.0, 55.0)
		else:
			position.x -= drift_speed * delta
			# Once it enters the screen area from right, switch to random drifting so it doesn't flow out
			if position.x <= 1130.0:
				is_drifting = false
				is_drifting_randomly = true
				# Force initial drift to continue moving to the left (inward)
				drift_dir = Vector2(randf_range(-1.0, -0.2), randf_range(-1.0, 1.0)).normalized()
				drift_float_speed = randf_range(35.0, 55.0)

func _on_body_entered(body: Node2D) -> void:
	# Check if the colliding body is the player (by checking script or group)
	if body.is_in_group("player") or body.name == "Player":
		# Show the educational fact popup and update stats
		if type == CollectibleType.FISH:
			# Zoom-in effect for rescue moment (simulated on HUD/Camera)
			trigger_rescue_effect()
			GameManager.add_creatures_rescued()
			GameManager.adjust_ocean_health(12.0)
			GameManager.trigger_contextual_fact("fish")
		else:
			GameManager.play_sound("res://assets/audio/item-equip.mp3")
			# Check if any turtle was targeting this plastic bag
			var intercepted = false
			for turtle in get_tree().get_nodes_in_group("turtles"):
				if is_instance_valid(turtle) and turtle.get("target_plastic") == self:
					intercepted = true
					turtle.set("target_plastic", null)
			
			if intercepted:
				GameManager.add_trash_cleaned()
				GameManager.adjust_ocean_health(8.0) # Bonus health reward for prevention
				GameManager.add_score(10) # Bonus score
				GameManager.trigger_contextual_fact("turtle")
			else:
				GameManager.add_trash_cleaned()
				GameManager.adjust_ocean_health(4.0)
				if is_plastic_bag:
					GameManager.trigger_contextual_fact("plastic_bag")
				else:
					GameManager.trigger_contextual_fact("plastic_bottle")
			
		# Play simple collection visual/sound (or just queue_free for simplicity)
		queue_free()

func trigger_rescue_effect() -> void:
	# Signal a zoom effect or display a specific rescue overlay
	# We can also do a temporary camera zoom if a camera exists
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("trigger_zoom"):
		camera.trigger_zoom()

