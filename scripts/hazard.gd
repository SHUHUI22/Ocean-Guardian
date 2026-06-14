extends Area2D

# Handles environmental hazard: Ghost Net.

@export var speed_penalty: float = 0.1 # Reduces speed to 10% of normal (feels like trapped)
@export var drift_speed: float = 30.0 # Slow drifting speed

var fall_from_above: bool = false
var spawned_on_left: bool = false
var target_y_depth: float = 0.0
var fall_speed: float = 180.0
var is_drifting_randomly: bool = false
var drift_dir: Vector2 = Vector2.ZERO
var drift_float_speed: float = 40.0

@onready var sprite: Sprite2D = $Sprite2D

var player_inside: Node2D = null
var message_triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	setup_hazard_visuals()
	add_to_group("trash_zones")
	
	drift_speed = randf_range(75.0, 95.0)

func setup_hazard_visuals() -> void:
	if sprite:
		sprite.texture = load("res://assets/net.png")
		sprite.modulate = Color(0.4, 0.4, 0.4, 0.8) # Dark transparent net
		sprite.scale = Vector2(0.15, 0.15)

func _process(delta: float) -> void:
	if fall_from_above:
		if position.y < target_y_depth:
			position.y += fall_speed * delta
			sprite.rotation += 1.5 * delta
		else:
			position.y = target_y_depth
			sprite.rotation = 0.0
			fall_from_above = false
			is_drifting_randomly = true
			drift_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
			drift_float_speed = randf_range(30.0, 50.0)
	elif is_drifting_randomly:
		position += drift_dir * drift_float_speed * delta
		sprite.rotation += 0.3 * delta * (1.0 if drift_dir.x > 0 else -1.0)
		
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
	else:
		# Move automatically (right to left, or left to right if spawned on left)
		if spawned_on_left:
			position.x += drift_speed * delta
			# Switch to random drift once it enters screen area from left
			if position.x >= 150.0:
				is_drifting_randomly = true
				# Force initial drift to continue moving to the right (inward)
				drift_dir = Vector2(randf_range(0.2, 1.0), randf_range(-1.0, 1.0)).normalized()
				drift_float_speed = randf_range(30.0, 50.0)
		else:
			position.x -= drift_speed * delta
			# Switch to random drift once it enters screen area from right
			if position.x <= 1130.0:
				is_drifting_randomly = true
				# Force initial drift to continue moving to the left (inward)
				drift_dir = Vector2(randf_range(-1.0, -0.2), randf_range(-1.0, 1.0)).normalized()
				drift_float_speed = randf_range(30.0, 50.0)
		
	# Clean up if it moves off-screen (only for drifting items before entering random drift)
	if not fall_from_above and not is_drifting_randomly:
		var exit_screen = false
		if spawned_on_left and position.x > 1800.0:
			exit_screen = true
		elif not spawned_on_left and position.x < -200.0:
			exit_screen = true
			
		if exit_screen:
			queue_free()
		
	# If player is inside the net, drain oxygen over time
	if is_instance_valid(player_inside):
		GameManager.adjust_oxygen(-10.0 * delta)

var _entangle_tween: Tween = null
var _collecting: bool = false  # guard so the auto-collect only fires once

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		if _collecting:
			return
		player_inside = body
		body.slow_down(speed_penalty)  # 35% speed

		# Show HUD warning
		var hud_nodes = get_tree().get_nodes_in_group("hud")
		if hud_nodes.size() > 0 and hud_nodes[0].has_method("show_surge_banner"):
			hud_nodes[0].show_surge_banner("⚠ ENTANGLED IN NET — Struggling free… ⚠")

		# Awareness bubble (once per net instance)
		if not message_triggered:
			message_triggered = true
			GameManager.trigger_contextual_fact("net")

		# Visual: red tint + wobble
		modulate = Color(1.2, 0.45, 0.45, 1.0)
		_entangle_tween = create_tween().set_loops()
		_entangle_tween.tween_property(sprite, "rotation_degrees", 6.0, 0.18)
		_entangle_tween.tween_property(sprite, "rotation_degrees", -6.0, 0.18)

		# After 2s struggling, auto-collect (remove net, restore speed)
		_collecting = true
		await get_tree().create_timer(2.0).timeout
		_finish_escape(body)

func _finish_escape(player: Node2D) -> void:
	if _entangle_tween:
		_entangle_tween.kill()
		_entangle_tween = null
	sprite.rotation_degrees = 0.0

	if is_instance_valid(player):
		player.restore_speed()

	# Collect the net: count as trash cleaned + small health bonus
	GameManager.add_trash_cleaned()
	GameManager.adjust_ocean_health(3.0)

	# Pop scale animation then free
	var tw = create_tween()
	tw.tween_property(self, "scale", scale * 1.25, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ZERO, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

func _on_body_exited(body: Node2D) -> void:
	# If player escapes before the 2s timer, restore speed (but net stays — they didn't fully remove it)
	if body.is_in_group("player") or body.name == "Player":
		if not _collecting:
			player_inside = null
			body.restore_speed()
			if _entangle_tween:
				_entangle_tween.kill()
				_entangle_tween = null
			sprite.rotation_degrees = 0.0
			modulate = Color.WHITE

func _exit_tree() -> void:
	if is_instance_valid(player_inside):
		player_inside.restore_speed()
