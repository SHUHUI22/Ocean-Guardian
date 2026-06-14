extends Node2D

# Level.gd - Generic script that acts as the Level Controller and Spawner.
# Spawns drifting garbage, hazards, and rescue nets based on level specifications.
# Also manages the Pollution Surge micro-drama event.

@export var ocean_state: String = "clean"
@export var required_trash: int = 5
@export var required_rescues: int = 1
@export var required_ocean_health: float = 60.0

# Spawner Configuration (now dynamic, kept exports for compatibility)
@export var spawn_types: Array[PackedScene] = []
@export var max_items_on_screen: int = 5
@export var spawn_interval_min: float = 3.0
@export var spawn_interval_max: float = 5.0

@onready var ocean_background: Node2D = $OceanBackground
@onready var spawned_items_container: Node2D = $SpawnedItems

var spawn_timer: float = 0.0
var next_spawn_time: float = 0.0
var current_state: String = ""

# Track all static background fish/turtles
var background_life: Array[Node2D] = []
var ambience_player: AudioStreamPlayer

# Pollution Surge Event Variables
var is_pollution_surge: bool = false
var surge_timer: float = 0.0
var next_surge_timer: float = 40.0 # First surge triggers around 40 seconds into the game

func _ready() -> void:
	# Play background ambience loop
	ambience_player = AudioStreamPlayer.new()
	ambience_player.stream = load("res://assets/audio/underwater-ambiencewav-14428.mp3")
	if ambience_player.stream is AudioStreamMP3:
		ambience_player.stream.loop = true
	add_child(ambience_player)
	ambience_player.play()

	# Initialize state based on current health
	var health = GameManager.ocean_health
	if health >= 80.0:
		current_state = "clean"
	elif health >= 40.0:
		current_state = "polluted"
	else:
		current_state = "deep"
		

	# 1. Configure Background State
	if ocean_background:
		ocean_background.set_ocean_state(current_state)
		
	# 2. Setup Container for Spawned items if it doesn't exist
	if not has_node("SpawnedItems"):
		spawned_items_container = Node2D.new()
		spawned_items_container.name = "SpawnedItems"
		add_child(spawned_items_container)
		
	# 3. Collect static background life
	background_life.clear()
	for child in get_children():
		if str(child.name).contains("MovingFish"): # Exclude turtles so they are always visible for the encounter!
			if child is Node2D:
				background_life.append(child)
				
	# 4. Initialize spawner configuration
	update_spawner_config(current_state)
	
	# 5. Set background life density immediately
	update_background_life(health, true)
	
	# 6. Pre-populate screen with some starting items immediately!
	spawn_initial_items()
		
	# 7. Schedule first spawn
	set_next_spawn_time()

func update_spawner_config(state: String) -> void:
	# Ignore state config changes during a pollution surge
	if is_pollution_surge:
		return
		
	match state:
		"clean":
			max_items_on_screen = 5
			spawn_interval_min = 3.0
			spawn_interval_max = 5.0
		"polluted":
			max_items_on_screen = 10
			spawn_interval_min = 2.0
			spawn_interval_max = 3.0
		"deep":
			max_items_on_screen = 18
			spawn_interval_min = 1.0
			spawn_interval_max = 2.0

func update_background_life(health: float, immediate: bool = false) -> void:
	var target_density: float = 1.0
	if health >= 80.0:
		target_density = 1.0
	elif health >= 40.0:
		target_density = 0.5
	else:
		target_density = 0.15 # very few fish
		
	for i in range(background_life.size()):
		var life = background_life[i]
		if is_instance_valid(life):
			var should_be_visible = (float(i) / background_life.size()) < target_density
			
			if immediate:
				life.visible = should_be_visible
			else:
				if should_be_visible:
					if not life.visible:
						# Show it off-screen so it swims in from the right
						if life.position.x > 1600.0 or life.position.x < -140.0:
							life.visible = true
				else:
					if life.visible:
						# Hide it once it goes off-screen left
						if life.position.x < 0.0:
							life.visible = false

func get_weighted_spawn_scene(force_waste: bool = false) -> PackedScene:
	var health = GameManager.ocean_health
	var pool = []
	
	var bottle = load("res://scenes/plastic_bottle.tscn")
	var bag = load("res://scenes/plastic_bag.tscn")
	var net_rescue = load("res://scenes/rescue_net.tscn")
	var net_hazard = load("res://scenes/ghost_net_hazard.tscn")
	var fish = load("res://scenes/moving_fish.tscn")
	var turtle = load("res://scenes/moving_turtle.tscn")
	
	if force_waste:
		# Build a pool of only waste items (no free animals)
		if health >= 80.0:
			# Clean state: only plastic bottles and bags
			pool = [
				{"scene": bottle, "weight": 50},
				{"scene": bag, "weight": 50}
			]
		elif health >= 40.0:
			# Polluted state: bottles, bags, nets, hazards
			pool = [
				{"scene": bottle, "weight": 30},
				{"scene": bag, "weight": 30},
				{"scene": net_rescue, "weight": 25},
				{"scene": net_hazard, "weight": 15}
			]
		else:
			# Critical state: bottles, bags, nets, hazards
			pool = [
				{"scene": bottle, "weight": 35},
				{"scene": bag, "weight": 35},
				{"scene": net_rescue, "weight": 15},
				{"scene": net_hazard, "weight": 15}
			]
	else:
		if health >= 80.0:
			# Clean state: mostly fish/turtles, rare plastic
			pool = [
				{"scene": fish, "weight": 40},
				{"scene": turtle, "weight": 30},
				{"scene": bottle, "weight": 15},
				{"scene": bag, "weight": 15}
			]
		elif health >= 40.0:
			# Polluted state: moderate trash/nets/fish/turtles
			pool = [
				{"scene": bottle, "weight": 25},
				{"scene": bag, "weight": 25},
				{"scene": net_rescue, "weight": 20},
				{"scene": net_hazard, "weight": 10},
				{"scene": fish, "weight": 10},
				{"scene": turtle, "weight": 10}
			]
		else:
			# Critical state: heavy plastic, nets, almost no fish
			pool = [
				{"scene": bottle, "weight": 30},
				{"scene": bag, "weight": 30},
				{"scene": net_rescue, "weight": 15},
				{"scene": net_hazard, "weight": 15},
				{"scene": fish, "weight": 5},
				{"scene": turtle, "weight": 5}
			]
			
	# During a pollution surge, we override to only spawn garbage/hazards
	if is_pollution_surge:
		pool = [
			{"scene": bottle, "weight": 35},
			{"scene": bag, "weight": 35},
			{"scene": net_hazard, "weight": 30}
		]
		
	var total_weight = 0
	for item in pool:
		if item["scene"] != null:
			total_weight += item["weight"]
		
	if total_weight == 0:
		return null
		
	var roll = randf() * total_weight
	var current_sum = 0
	for item in pool:
		if item["scene"] != null:
			current_sum += item["weight"]
			if roll <= current_sum:
				return item["scene"]
				
	return null

func spawn_initial_items() -> void:
	# Pre-spawn half of the maximum capacity across the screen
	var initial_count = max(1, max_items_on_screen / 2)
	for i in range(initial_count):
		var scene_to_spawn = get_weighted_spawn_scene()
		if scene_to_spawn:
			var instance = scene_to_spawn.instantiate()
			if instance:
				# Alternate left and right for initial items, scattering them off-screen
				var spawn_left = (i % 2 == 0)
				var spawn_x = 0.0
				if spawn_left:
					spawn_x = -150.0 - i * randf_range(250.0, 450.0)
				else:
					spawn_x = 1450.0 + i * randf_range(250.0, 450.0)
					
				instance.position = Vector2(spawn_x, randf_range(100.0, 800.0))
				if "is_spawned" in instance:
					instance.set("is_spawned", true)
				if "spawned_on_left" in instance:
					instance.set("spawned_on_left", spawn_left)
				spawned_items_container.add_child(instance)
				
				# If we spawned a RescueNet, automatically spawn a MovingFish on top of it
				if str(instance.name).contains("RescueNet") or instance.scene_file_path.contains("rescue_net"):
					var fish_scene = load("res://scenes/moving_fish.tscn")
					if fish_scene:
						var fish_instance = fish_scene.instantiate()
						if fish_instance:
							fish_instance.position = instance.position
							if "is_spawned" in fish_instance:
								fish_instance.set("is_spawned", true)
							if "is_injured" in fish_instance:
								fish_instance.set("is_injured", true)
							spawned_items_container.add_child(fish_instance)

func _process(delta: float) -> void:
	# Passive health drain based on active pollution on screen and track dive time
	if GameManager.current_oxygen > 0.0:
		GameManager.dive_time += delta
		
		# Low-life oxygen trigger (oxygen < 30%)
		if GameManager.current_oxygen < 30.0:
			if not GameManager.low_life_played:
				GameManager.low_life_played = true
				GameManager.play_sound("res://assets/audio/low-life.mp3")
				if is_instance_valid(ambience_player):
					var vol_tween = create_tween()
					vol_tween.tween_property(ambience_player, "volume_db", -20.0, 1.5)
		else:
			# Restore ambience volume if player refilled oxygen at the surface
			if GameManager.low_life_played:
				GameManager.low_life_played = false
				GameManager.stop_sound("res://assets/audio/low-life.mp3")
				if is_instance_valid(ambience_player):
					var vol_tween = create_tween()
					vol_tween.tween_property(ambience_player, "volume_db", 0.0, 1.5)
			
		if GameManager.dive_time >= 90.0:
			GameManager.survey_completed = true
			GameManager.end_dive()
			return
		var health_drain = 0.2 # Base drain rate
		if is_instance_valid(spawned_items_container):
			for item in spawned_items_container.get_children():
				if is_instance_valid(item):
					if str(item.name).contains("Plastic") or item.scene_file_path.contains("plastic"):
						health_drain += 0.1
					elif str(item.name).contains("GhostNetHazard") or item.scene_file_path.contains("ghost_net_hazard"):
						health_drain += 0.25
					elif str(item.name).contains("MovingTurtle") or item.scene_file_path.contains("moving_turtle"):
						if item.get("is_trapped") == true:
							health_drain += 0.8
		GameManager.adjust_ocean_health(-health_drain * delta)
		
	var health = GameManager.ocean_health
	
	# Handle Pollution Surge Event Timers
	if is_pollution_surge:
		surge_timer -= delta
		if surge_timer <= 0.0:
			end_pollution_surge()
	else:
		# Only allow surges to trigger in the middle of the game (before 70 seconds elapsed)
		if GameManager.dive_time < 70.0:
			next_surge_timer -= delta
			if next_surge_timer <= 0.0:
				trigger_pollution_surge()
	
	# Dynamically check/update state
	var target_state = "polluted"
	if health >= 80.0:
		target_state = "clean"
	elif health >= 40.0:
		target_state = "polluted"
	else:
		target_state = "deep"
		
	if target_state != current_state:
		var old_state = current_state
		current_state = target_state
		if ocean_background:
			ocean_background.set_ocean_state(current_state)
		update_spawner_config(current_state)
		

		
	# Always keep background life density in sync smoothly
	update_background_life(health, false)
		
	# Dynamic spawner pacing: speed up next spawn when screen is empty/low on waste/rescue targets
	var active_waste = get_active_waste_count()
	if active_waste == 0:
		next_spawn_time = min(next_spawn_time, 0.3)
	elif active_waste < 2:
		next_spawn_time = min(next_spawn_time, 1.2)
		
	spawn_timer += delta
	if spawn_timer >= next_spawn_time:
		spawn_timer = 0.0
		set_next_spawn_time()
		spawn_item()

func get_active_screen_item_count() -> int:
	if not is_instance_valid(spawned_items_container):
		return 0
	var count = 0
	for item in spawned_items_container.get_children():
		if is_instance_valid(item) and not item.is_queued_for_deletion():
			# Check if the item is within active screen area or about to enter
			if item.position.x >= -50.0 and item.position.x <= 1350.0:
				if not item.get("is_perishing") == true:
					count += 1
	return count

func get_active_waste_count() -> int:
	if not is_instance_valid(spawned_items_container):
		return 0
	var count = 0
	for item in spawned_items_container.get_children():
		if is_instance_valid(item) and not item.is_queued_for_deletion():
			if item.position.x >= -50.0 and item.position.x <= 1350.0:
				if not item.get("is_perishing") == true:
					var path = item.scene_file_path
					if path.contains("plastic_bottle") or path.contains("plastic_bag") or path.contains("rescue_net") or path.contains("ghost_net_hazard"):
						count += 1
					elif path.contains("moving_turtle") and item.get("is_trapped") == true:
						count += 1
	return count

func set_next_spawn_time() -> void:
	next_spawn_time = randf_range(spawn_interval_min, spawn_interval_max)

func spawn_item() -> void:
	if not is_instance_valid(spawned_items_container):
		return
		
	var active_waste = get_active_waste_count()
	var total_children = spawned_items_container.get_child_count()
	
	# If there is no waste on screen, force spawn a waste item even if we are at max items
	var force_waste = (active_waste == 0)
	
	if force_waste or total_children < max_items_on_screen:
		var scene_to_spawn = get_weighted_spawn_scene(force_waste)
		if scene_to_spawn:
			var instance = scene_to_spawn.instantiate()
			if instance:
				if is_pollution_surge:
					# Spawn relative to the current camera screen center (calculated safely from player position & camera limits)
					var player = get_tree().get_first_node_in_group("player")
					var screen_center = Vector2(640, 360) # fallback
					if is_instance_valid(player):
						screen_center.x = clamp(player.global_position.x, 512.0, 1088.0)
						screen_center.y = clamp(player.global_position.y, 288.0, 612.0)
					
					# zoomed screen size: 1024x576
					var half_w = 512.0
					var half_h = 288.0
					
					var rand_x = randf_range(screen_center.x - half_w + 100.0, screen_center.x + half_w - 100.0)
					rand_x = clamp(rand_x, 50.0, 1550.0) # Clamp within level X boundaries
					
					var spawn_y = screen_center.y - half_h - 60.0
					spawn_y = max(-100.0, spawn_y) # Ensure it doesn't go unreasonably high
					
					var rand_y_depth = randf_range(screen_center.y - half_h + 100.0, screen_center.y + half_h - 50.0)
					rand_y_depth = clamp(rand_y_depth, 100.0, 800.0) # Clamp within level Y boundaries
					
					instance.position = Vector2(rand_x, spawn_y)
					if "is_spawned" in instance:
						instance.set("is_spawned", true)
					
					# Set falling properties
					if "fall_from_above" in instance:
						instance.set("fall_from_above", true)
					if "target_y_depth" in instance:
						instance.set("target_y_depth", rand_y_depth)
					if "is_drifting" in instance:
						instance.set("is_drifting", false)
						
					# Play drop sound when items are thrown inside (lowered volume and shortened)
					GameManager.play_sound("res://assets/audio/drop.mp3", -12.0, 0.5)
				else:
					# Normal item: spawn just off-screen right or off-screen left (40% chance left, 60% chance right)
					var spawn_left = (randf() < 0.4)
					var spawn_x = 1750.0
					var player = get_tree().get_first_node_in_group("player")
					if spawn_left:
						spawn_x = -150.0
						if is_instance_valid(player):
							spawn_x = min(-150.0, player.global_position.x - 750.0)
					else:
						spawn_x = 1750.0
						if is_instance_valid(player):
							spawn_x = max(1750.0, player.global_position.x + 750.0)
							
					instance.position = Vector2(spawn_x, randf_range(100.0, 680.0))
					if "is_spawned" in instance:
						instance.set("is_spawned", true)
					if "spawned_on_left" in instance:
						instance.set("spawned_on_left", spawn_left)
						
				spawned_items_container.add_child(instance)
				
				# If we spawned a RescueNet, automatically spawn a MovingFish on top of it so it becomes trapped
				if str(instance.name).contains("RescueNet") or instance.scene_file_path.contains("rescue_net"):
					var fish_scene = load("res://scenes/moving_fish.tscn")
					if fish_scene:
						var fish_instance = fish_scene.instantiate()
						if fish_instance:
							# Align positions so they overlap immediately and trigger trapping
							fish_instance.position = instance.position
							if "is_spawned" in fish_instance:
								fish_instance.set("is_spawned", true)
							if "is_injured" in fish_instance:
								fish_instance.set("is_injured", true)
							
							# If spawned during a surge, fish should not drift horizontally
							if is_pollution_surge:
								if "is_drifting" in fish_instance:
									fish_instance.set("is_drifting", false)
							spawned_items_container.add_child(fish_instance)

func trigger_pollution_surge() -> void:
	is_pollution_surge = true
	GameManager.play_sound("res://assets/audio/drop.mp3", -12.0, 0.5)
	surge_timer = 5.0 # Surge duration: 5 seconds
	
	# Override spawner config for extreme spawning rate
	max_items_on_screen = 18
	spawn_interval_min = 0.3
	spawn_interval_max = 0.5
	
	# Force an instant spawn
	spawn_timer = next_spawn_time 
	
	# Screen Shake
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("trigger_shake"):
		camera.trigger_shake(15.0, 3.0)
			
	# Alert warning text — use the dedicated surge banner (single, prominent, no bubble flood)
	var hud_nodes = get_tree().get_nodes_in_group("hud")
	if hud_nodes.size() > 0 and hud_nodes[0].has_method("show_surge_banner"):
		hud_nodes[0].show_surge_banner("⚠ POLLUTION SURGE — Industrial runoff detected! Clean up fast! ⚠")


func end_pollution_surge() -> void:
	is_pollution_surge = false
	next_surge_timer = randf_range(40.0, 60.0) # Schedule next surge
	
	# Restore normal spawner config for current state
	update_spawner_config(current_state)

func _exit_tree() -> void:
	if is_instance_valid(ambience_player):
		ambience_player.stop()
