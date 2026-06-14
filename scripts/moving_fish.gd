extends Area2D

# moving_fish.gd - Moving fish that can be trapped by Ghost Nets and rescued by the player.
# Trapped fish become injured, and rescued fish recover and swim left-to-right.

@export var speed: float = 150.0

var is_trapped: bool = false
var net_ref: Node2D = null
var is_escaping: bool = false
var is_moving_right: bool = false
var escape_time: float = 0.0
var base_scale: Vector2
var is_spawned: bool = false
var is_perishing: bool = false
var has_entered_screen: bool = false
var is_injured: bool = false

func _ready() -> void:
	# Add to the "fish" group so nets can identify it
	add_to_group("fish")
	base_scale = scale

func _process(delta: float) -> void:
	if not has_entered_screen:
		var viewport = get_viewport()
		if viewport:
			var viewport_rect = viewport.get_visible_rect()
			var screen_pos = get_global_transform_with_canvas().origin
			if viewport_rect.has_point(screen_pos):
				has_entered_screen = true

	if is_trapped:
		if is_instance_valid(net_ref):
			if is_perishing:
				global_position = net_ref.global_position
				rotation = PI
				return
				
			# Check if player is near
			var player = get_tree().get_first_node_in_group("player")
			var is_near = false
			if is_instance_valid(player):
				var dist = global_position.distance_to(player.global_position)
				if dist < 250.0:
					is_near = true
					
			var wiggle_speed = 0.03 if is_near else 0.015
			var shake_offset = 6.0 if is_near else 3.5
			
			# Lock position to the net + a gentler, smoother wiggling offset
			var shake_x = sin(Time.get_ticks_msec() * 0.01) * shake_offset
			var shake_y = cos(Time.get_ticks_msec() * 0.012) * shake_offset
			global_position = net_ref.global_position + Vector2(shake_x, shake_y)
			
			# Struggle rotation wiggle: rotate back and forth smoothly
			rotation = sin(Time.get_ticks_msec() * wiggle_speed) * (0.35 if is_near else 0.20)
			# Slowly drain health when trapped
			GameManager.adjust_ocean_health(-1.0 * delta)
			return
		else:
			# Safety fallback: if the net is destroyed but the fish was not freed,
			# free it now so it doesn't get stuck!
			is_trapped = false
			is_escaping = true
			is_moving_right = true
			escape_time = 0.0
			rotation = 0.0
			$Sprite2D.flip_h = true
		
	if is_escaping:
		# Escape animation: swim away fast to the right with a rapid tail-flap wiggle
		position.x += speed * 1.5 * delta
		escape_time += delta
		rotation = sin(escape_time * 20.0) * 0.15
		if escape_time > 1.5:
			is_escaping = false
			rotation = 0.0
		return
		
	# Dynamic steering: avoidance and schooling (only when not trapped and not escaping)
	var avoid_vector = Vector2.ZERO
	var has_avoided = false
	
	# Avoid trash zones
	for trash in get_tree().get_nodes_in_group("trash_zones"):
		if is_instance_valid(trash):
			var dist = global_position.distance_to(trash.global_position)
			if dist < 200.0:
				# Steer away: push force is stronger the closer we are
				var push = (global_position - trash.global_position).normalized() * (200.0 - dist)
				avoid_vector += push
				has_avoided = true
				
	# Apply avoidance primarily to vertical motion (swim up/down to dodge trash)
	if has_avoided:
		position.y += avoid_vector.y * 0.5 * delta
		position.y = clamp(position.y, 100.0, 800.0)
	else:
		# If NOT avoiding trash, we are in a "clean area" and can gather/school with other fish
		var nearby_fish_count = 0
		var avg_position = Vector2.ZERO
		var school_range = 300.0
		
		for other_fish in get_tree().get_nodes_in_group("fish"):
			if is_instance_valid(other_fish) and other_fish != self and not other_fish.is_trapped and not other_fish.is_escaping:
				# Only school with fish swimming in the same direction
				if other_fish.get("is_moving_right") == is_moving_right:
					var dist = global_position.distance_to(other_fish.global_position)
					if dist < school_range:
						# Check if the other fish is also clean (not avoiding trash)
						var other_near_trash = false
						for trash in get_tree().get_nodes_in_group("trash_zones"):
							if is_instance_valid(trash) and other_fish.global_position.distance_to(trash.global_position) < 200.0:
								other_near_trash = true
								break
						if not other_near_trash:
							avg_position += other_fish.global_position
							nearby_fish_count += 1
						
		if nearby_fish_count > 0:
			avg_position /= nearby_fish_count
			# Schooling Cohesion: steer towards average position of clean neighbors
			var steer = (avg_position - global_position).normalized()
			# Gently adjust vertical position to school together
			position.y += steer.y * 45.0 * delta
			position.y = clamp(position.y, 100.0, 800.0)
		
	# Check swim direction
	if is_moving_right:
		# Swim left to right
		position.x += speed * delta
		# Rescued fish swim away and are deleted off-screen right
		if position.x > 1800.0:
			queue_free()
	else:
		# Swim right to left (normal state)
		position.x -= speed * delta
		# Wrap around to the right if off-screen left (or queue_free if spawned)
		if position.x < -150.0:
			if is_spawned:
				queue_free()
			else:
				position.x = 1750.0
				position.y = randf_range(100.0, 800.0)
				has_entered_screen = false

# Called by the net when it traps the fish
func get_trapped(net: Node2D) -> bool:
	if is_escaping or is_moving_right or is_perishing or is_trapped:
		return false
	is_trapped = true
	net_ref = net
	
	if is_injured:
		# Swap visual to the injured fish asset while trapped
		$Sprite2D.texture = load("res://assets/injured_fish.png")
	
	# If the net spawned on the left side, it drifts to the right, so face right (flip_h = true)
	if is_instance_valid(net_ref) and net_ref.get("spawned_on_left") == true:
		$Sprite2D.flip_h = true
	else:
		$Sprite2D.flip_h = false # Reset orientation in net
	return true

# Called when the player rescues the fish by touching the net
func free_from_net() -> void:
	if is_perishing:
		return
	is_trapped = false
	net_ref = null
	is_escaping = true
	is_moving_right = true # Change permanent swim direction
	escape_time = 0.0
	rotation = 0.0 # Reset rotation!
	
	# Flip it horizontally to face right (direction of travel)
	$Sprite2D.flip_h = true
	
	# Trigger contextual fact
	GameManager.trigger_contextual_fact("fish")
	
	# Visual feedback: scale pop animation using Tween
	var tween = create_tween()
	tween.tween_property(self, "scale", base_scale * 1.5, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", base_scale, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func perish() -> void:
	is_perishing = true
	rotation = PI
	$Sprite2D.texture = load("res://assets/injured_fish.png")
	# Modulate the sprite grey
	$Sprite2D.modulate = Color(0.35, 0.35, 0.35, 1.0)
