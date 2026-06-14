extends Area2D

# moving_turtle.gd - Controls right-to-left moving turtles with slow, gentle bobbing.
# Turtles will seek nearby plastic bags/bottles, get trapped in them, and can be rescued by the player.

@export var speed: float = 50.0 # Turtles are slow swimmers!
@export var bob_amplitude: float = 15.0
@export var bob_frequency: float = 0.8

var start_y: float = 0.0
var elapsed_time: float = 0.0
var is_spawned: bool = false

var is_trapped: bool = false
var is_rescued: bool = false
var is_perishing: bool = false
var target_plastic: Node2D = null
var _last_had_target: bool = false
var trapped_timer: float = 0.0
const TRAP_TIME_LIMIT: float = 15.0 # Perish if not rescued within 15 seconds
var has_entered_screen: bool = false

func _ready() -> void:
	# Add to groups
	add_to_group("turtles")
	
	start_y = position.y
	# Desynchronize wave phases
	elapsed_time = randf_range(0.0, 100.0)
	
	# Connect collision signals
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if not has_entered_screen:
		var viewport = get_viewport()
		if viewport:
			var viewport_rect = viewport.get_visible_rect()
			var screen_pos = get_global_transform_with_canvas().origin
			if viewport_rect.has_point(screen_pos):
				has_entered_screen = true

	# Check if we just lost target (e.g. player collected the plastic we were chasing)
	var has_target = is_instance_valid(target_plastic)
	if _last_had_target and not has_target and not is_trapped and not is_rescued and not is_perishing:
		# Target was lost/intercepted! Reset start_y to prevent Y-axis snapping
		start_y = position.y - sin(elapsed_time * bob_frequency) * bob_amplitude
	_last_had_target = has_target

	if is_perishing:
		# Sink and fade
		position.y += 80.0 * delta
		modulate.a = max(0.0, modulate.a - 0.7 * delta)
		if modulate.a <= 0.0:
			queue_free()
		return

	if is_rescued:
		# Swim away fast and free to the right (flip_h is false to face right)
		position.x += speed * delta
		elapsed_time += delta
		position.y = start_y + sin(elapsed_time * bob_frequency) * (bob_amplitude * 0.5)
		
		# De-spawn when off-screen right
		if position.x > 1800.0:
			queue_free()
		return
		
	if is_trapped:
		trapped_timer += delta
		# Check if we should perish (either time limit exceeded OR drifted off screen)
		if trapped_timer >= TRAP_TIME_LIMIT or position.x <= 150.0:
			is_trapped = false
			is_perishing = true
			# Tragic visual cues
			$Sprite2D.modulate = Color(0.35, 0.35, 0.35, 1.0)
			if has_node("TrappedBag"):
				$TrappedBag.modulate = Color(0.35, 0.35, 0.35, 0.5)
			rotation = PI # upside down
			GameManager.adjust_ocean_health(-15.0)
			return

		# Check if player is near
		var player = get_tree().get_first_node_in_group("player")
		var is_near = false
		if is_instance_valid(player):
			var dist = global_position.distance_to(player.global_position)
			if dist < 250.0:
				is_near = true
				
		var wiggle_speed = 10.0 if is_near else 5.0
		var rotate_amp = 0.25 if is_near else 0.1
		var drift_y_freq = 4.0 if is_near else 2.0
		
		# Bob weakly and drift left with the current
		position.x -= 30.0 * delta
		elapsed_time += delta
		position.y = start_y + sin(elapsed_time * drift_y_freq) * 3.0
		# Oscillate rotation to wiggle
		rotation = sin(elapsed_time * wiggle_speed) * rotate_amp
		return
		
	# Check for nearby plastic bag to approach if we don't have a target
	if not is_instance_valid(target_plastic):
		var closest_dist = 250.0
		for trash in get_tree().get_nodes_in_group("trash_zones"):
			if is_instance_valid(trash) and trash.get("is_plastic_bag") == true:
				var dist = global_position.distance_to(trash.global_position)
				if dist < closest_dist:
					closest_dist = dist
					target_plastic = trash
					
	# Movement logic
	if is_instance_valid(target_plastic):
		# Approaching plastic (food target)
		var dir = (target_plastic.global_position - global_position).normalized()
		global_position += dir * speed * 1.4 * delta
		
		# Bob slightly while heading to food
		elapsed_time += delta
		
		# Orient sprite towards target
		$Sprite2D.flip_h = dir.x < 0
		
		# Check if we reached and got trapped by it
		if global_position.distance_to(target_plastic.global_position) < 25.0:
			is_trapped = true
			start_y = position.y
			$TrappedBag.visible = true
			target_plastic.queue_free()
			target_plastic = null
			
			# Trigger the warning educational message on the HUD (fact removed)
			pass
	else:
		# 1. Move automatically from right to left
		position.x -= speed * delta
		
		# 2. Gentle slow bobbing motion
		elapsed_time += delta
		position.y = start_y + sin(elapsed_time * bob_frequency) * bob_amplitude
		
		# Face left
		$Sprite2D.flip_h = true
		
		# 3. Wrap around to the right side if off-screen left (or queue_free if spawned)
		if position.x < -150.0:
			if is_spawned:
				queue_free()
			else:
				position.x = 1750.0
				start_y = randf_range(100.0, 800.0)
				position.y = start_y
				has_entered_screen = false

func _on_body_entered(body: Node2D) -> void:
	if is_trapped and (body.is_in_group("player") or body.name == "Player"):
		# Rescue the turtle!
		is_trapped = false
		is_rescued = true
		$TrappedBag.visible = false
		rotation = 0.0 # Reset wiggle rotation
		
		# Set exit flight settings
		speed = 180.0 # Swim away fast!
		$Sprite2D.flip_h = false # Face right to swim away
		
		# Grant player rewards
		GameManager.add_creatures_rescued()
		GameManager.adjust_ocean_health(15.0)
		
		# Trigger animal fact
		GameManager.trigger_contextual_fact("turtle")
