extends Area2D

# rescue_net.gd - Traps drifting fish and frees them when touched by the player.

@export var drift_speed: float = 30.0 # Slow drifting speed
var is_perishing: bool = false
var is_rescuing: bool = false
var spawned_on_left: bool = false
var trapped_fish: Node2D = null

# Entanglement properties for empty nets
var player_inside: Node2D = null
var message_triggered: bool = false
var _entangle_tween: Tween = null
var _collecting: bool = false  # guard so the auto-collect only fires once

var fall_from_above: bool = false
var target_y_depth: float = 0.0
var fall_speed: float = 180.0
var is_drifting_randomly: bool = false
var drift_dir: Vector2 = Vector2.ZERO
var drift_float_speed: float = 40.0

var trapped_timer: float = 0.0
const TRAP_TIME_LIMIT: float = 15.0 # Perish after 15 seconds if not rescued

func _ready() -> void:
	# Connect collision signals
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	z_index = 1 # Draw net on top of the trapped fish
	
	drift_speed = randf_range(75.0, 95.0)

func _process(delta: float) -> void:
	if is_perishing:
		# Sink and fade
		position.y += 80.0 * delta
		modulate.a = max(0.0, modulate.a - 0.7 * delta)
		if is_instance_valid(trapped_fish):
			trapped_fish.modulate.a = modulate.a
		if modulate.a <= 0.0:
			if is_instance_valid(trapped_fish):
				trapped_fish.queue_free()
			queue_free()
		return

	# If player is inside the empty net, drain oxygen over time
	if is_instance_valid(player_inside):
		GameManager.adjust_oxygen(-10.0 * delta)

	if fall_from_above:
		if position.y < target_y_depth:
			position.y += fall_speed * delta
			rotation += 1.5 * delta
		else:
			position.y = target_y_depth
			rotation = 0.0
			fall_from_above = false
			is_drifting_randomly = true
			drift_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
			drift_float_speed = randf_range(30.0, 50.0)
	elif is_drifting_randomly:
		position += drift_dir * drift_float_speed * delta
		rotation += 0.3 * delta * (1.0 if drift_dir.x > 0 else -1.0)
		
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
	
	if is_instance_valid(trapped_fish):
		trapped_timer += delta
		
	# Check if we should perish (either time limit exceeded OR drifted off screen)
	var off_screen = false
	if spawned_on_left:
		if not is_drifting_randomly and position.x > 1130.0:
			off_screen = true
	else:
		if position.x <= 150.0:
			off_screen = true
			
	if off_screen or (is_instance_valid(trapped_fish) and trapped_timer >= TRAP_TIME_LIMIT):
		if is_instance_valid(trapped_fish):
			is_perishing = true
			collision_mask = 0
			collision_layer = 0
			if trapped_fish.has_method("perish"):
				trapped_fish.perish()
			GameManager.adjust_ocean_health(-15.0)
			return
		else:
			queue_free()
			return
	
	# Clean up if off-screen (only for drifting items before entering random drift)
	if not fall_from_above and not is_drifting_randomly:
		var exit_screen = false
		if spawned_on_left and position.x > 1800.0:
			exit_screen = true
		elif not spawned_on_left and position.x < -200.0:
			exit_screen = true
			
		if exit_screen:
			if is_instance_valid(trapped_fish):
				trapped_fish.queue_free()
			queue_free()

func _on_area_entered(area: Area2D) -> void:
	if is_rescuing or is_perishing:
		return
	# Trap fish if we don't have one trapped yet and it is a fish
	if trapped_fish == null and area.is_in_group("fish"):
		trapped_fish = area
		if area.has_method("get_trapped"):
			area.get_trapped(self)

func _on_body_entered(body: Node2D) -> void:
	# If the player touches the net, check if we have a trapped fish to rescue
	if body.is_in_group("player") or body.name == "Player":
		if is_instance_valid(trapped_fish):
			rescue()
		else:
			# It's an empty net! Entangle and slow the player!
			entangle_player(body)

func _on_body_exited(body: Node2D) -> void:
	# If player escapes before the 2s timer, restore speed (but net stays)
	if body.is_in_group("player") or body.name == "Player":
		if not _collecting:
			player_inside = null
			body.restore_speed()
			if _entangle_tween:
				_entangle_tween.kill()
				_entangle_tween = null
			rotation_degrees = 0.0
			modulate = Color.WHITE

func entangle_player(body: Node2D) -> void:
	if is_rescuing or is_perishing or _collecting:
		return
	player_inside = body
	body.slow_down(0.1)  # Slow to 10% speed
	
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
	_entangle_tween.tween_property(self, "rotation_degrees", 6.0, 0.18)
	_entangle_tween.tween_property(self, "rotation_degrees", -6.0, 0.18)
	
	# After 2s struggling, auto-collect (remove net, restore speed)
	_collecting = true
	await get_tree().create_timer(2.0).timeout
	_finish_escape(body)

func _finish_escape(player: Node2D) -> void:
	if _entangle_tween:
		_entangle_tween.kill()
		_entangle_tween = null
	rotation_degrees = 0.0
	modulate = Color.WHITE

	if is_instance_valid(player):
		player.restore_speed()

	# Collect the empty net: count as trash cleaned + small health bonus
	GameManager.add_trash_cleaned()
	GameManager.adjust_ocean_health(3.0)

	# Pop scale animation then free
	is_rescuing = true
	var tw = create_tween()
	tw.tween_property(self, "scale", scale * 1.3, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ZERO, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

func rescue() -> void:
	if is_perishing or is_rescuing:
		return
	if is_instance_valid(trapped_fish) and trapped_fish.get("is_perishing") == true:
		return
		
	is_rescuing = true
		
	# Disable collision monitoring immediately to prevent re-trapping during the fadeout tween!
	monitoring = false
	monitorable = false
	
	# Free the fish if it exists
	if is_instance_valid(trapped_fish):
		if trapped_fish.has_method("free_from_net"):
			trapped_fish.free_from_net()
		# Add creatures rescued stats
		GameManager.add_creatures_rescued()
		# Ocean Health updates
		GameManager.adjust_ocean_health(15.0)
		
		# Prevent the net from tracking or calling perish() on this fish while the net is fading/scaling
		trapped_fish = null
	
	# Scale pop effect on the net before freeing
	var tween = create_tween()
	tween.tween_property(self, "scale", scale * 1.3, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func _exit_tree() -> void:
	if is_instance_valid(player_inside):
		player_inside.restore_speed()
