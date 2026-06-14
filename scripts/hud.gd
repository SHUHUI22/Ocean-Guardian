extends CanvasLayer

# Heads-Up Display (HUD) for Ocean Guardian.
# Displays score, oxygen bar, dynamic ocean health bar, and contextual educational facts.

@onready var score_label: Label = $Control/ScoreLabel
@onready var oxygen_bar: ProgressBar = $Control/OxygenBar
@onready var health_bar: ProgressBar = $Control/EcosystemBar
@onready var health_status_label: Label = $Control/EcosystemBar/Label if $Control/EcosystemBar.has_node("Label") else null
@onready var fact_panel: PanelContainer = $Control/FactPanel
@onready var fact_label: Label = $Control/FactPanel/FactLabel
@onready var oxygen_overlay: ColorRect = $Control/OxygenOverlay
@onready var timer_label: Label = $Control/TimerLabel


var fact_tween: Tween
var oxygen_warning_label: Label = null

# Throttle: track the last time each message category was shown (key = category string, value = time in msec)
var _last_bubble_times: Dictionary = {}
const BUBBLE_THROTTLE_MS: float = 1500.0 # 1.5 seconds between same-category bubbles
const BUBBLE_MAX_ACTIVE: int = 5           # Never more than 5 bubbles on screen at once
var surge_banner: Control = null    # Single label used during pollution surges

var rescue_indicator: Control = null
const RESCUE_HIDE_DISTANCE: float = 300.0

var pause_overlay: ColorRect = null

func _ready() -> void:
	# Set HUD process mode to process even when the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Add HUD to a group so other systems can find it
	add_to_group("hud")
	
	# Connect signals from GameManager
	GameManager.stats_changed.connect(_on_stats_changed)
	GameManager.oxygen_changed.connect(_on_oxygen_changed)
	GameManager.ocean_health_changed.connect(_on_ocean_health_changed)
	GameManager.fact_triggered.connect(show_fact)
	
	# Initialize UI values
	_on_stats_changed(GameManager.trash_cleaned, GameManager.creatures_rescued)
	_on_oxygen_changed(GameManager.current_oxygen)
	_on_ocean_health_changed(GameManager.ocean_health)
	
	if oxygen_bar:
		oxygen_bar.max_value = GameManager.max_oxygen
		
	if health_bar:
		health_bar.max_value = GameManager.max_ocean_health
		
	# Hide fact panel initially
	fact_panel.modulate.a = 0.0
	fact_panel.visible = false
	
		
	# Hide oxygen overlay initially
	if oxygen_overlay:
		oxygen_overlay.visible = false
		oxygen_overlay.color = Color(1, 0, 0, 0)
		
	# ── Joystick setup ──
	# Attach joystick.gd to the Joystick node and register it in the 'joystick' group
	# so player.gd can poll it. Always visible; it is semi-transparent when idle.
	var joystick_node = get_node_or_null("Control/Joystick")
	if joystick_node:
		var joy_script = load("res://scripts/joystick.gd")
		if joy_script:
			joystick_node.set_script(joy_script)
			joystick_node.add_to_group("joystick")
			joystick_node.modulate.a = 0.45  # idle transparency


	# Create dynamic Oxygen Warning Label (uses default system font for clarity)
	var warning_label = Label.new()
	warning_label.name = "OxygenWarningLabel"
	warning_label.text = "⚠ LOW OXYGEN — SWIM TO SURFACE FOR AIR ⚠"
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning_label.add_theme_color_override("font_color", Color.WHITE)
	warning_label.add_theme_color_override("font_outline_color", Color(0.6, 0, 0, 1))
	warning_label.add_theme_constant_override("outline_size", 6)
	warning_label.add_theme_font_size_override("font_size", 32)
	
	warning_label.custom_minimum_size = Vector2(800, 60)
	warning_label.size = Vector2(800, 60)
	
	var viewport_width = get_viewport().get_visible_rect().size.x
	warning_label.position = Vector2((viewport_width - 800) / 2.0, 120)
	warning_label.visible = false
	
	$Control.add_child(warning_label)
	oxygen_warning_label = warning_label

	# Instance the RescueIndicator
	var indicator_script = load("res://scripts/rescue_indicator.gd")
	if indicator_script:
		rescue_indicator = Control.new()
		rescue_indicator.set_script(indicator_script)
		rescue_indicator.visible = false
		$Control.add_child(rescue_indicator)

	# ── Create Pause Button ──
	var view_size = get_viewport().get_visible_rect().size
	var pause_btn = Button.new()
	pause_btn.name = "PauseButton"
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(45, 45)
	pause_btn.size = Vector2(45, 45)
	pause_btn.position = Vector2(24, 138)
	
	# Circular high-contrast theme for pause button (grey transparent style)
	var pause_normal = StyleBoxFlat.new()
	pause_normal.bg_color = Color(0.2, 0.22, 0.25, 0.65) # Dark grey semi-transparent
	pause_normal.border_color = Color(0.9, 0.92, 0.95, 0.9) # Bright silver/white border
	pause_normal.set_border_width_all(2.5)
	pause_normal.set_corner_radius_all(22)
	pause_normal.shadow_color = Color(0, 0, 0, 0.35)
	pause_normal.shadow_size = 4
	
	var pause_hover = StyleBoxFlat.new()
	pause_hover.bg_color = Color(0.3, 0.32, 0.35, 0.85) # Brighter/more opaque on hover
	pause_hover.border_color = Color(1.0, 1.0, 1.0, 1.0) # Solid white border
	pause_hover.set_border_width_all(2.5)
	pause_hover.set_corner_radius_all(22)
	pause_hover.shadow_color = Color(0, 0, 0, 0.45)
	pause_hover.shadow_size = 5
	
	pause_btn.add_theme_stylebox_override("normal", pause_normal)
	pause_btn.add_theme_stylebox_override("hover", pause_hover)
	pause_btn.add_theme_stylebox_override("pressed", pause_hover)
	pause_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	pause_btn.add_theme_font_size_override("font_size", 20)
	pause_btn.add_theme_color_override("font_color", Color.WHITE) # Clean white symbol
	pause_btn.add_theme_color_override("font_outline_color", Color.BLACK) # Black outline for maximum contrast
	pause_btn.add_theme_constant_override("outline_size", 4)
	$Control.add_child(pause_btn)
	pause_btn.pressed.connect(toggle_pause)

	# ── Create Pause Overlay ──
	pause_overlay = ColorRect.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.color = Color(0, 0, 0, 0) # Base transparent
	pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.visible = false
	$Control.add_child(pause_overlay)
	
	# Add background image matching Main Menu
	var bg_tex = TextureRect.new()
	bg_tex.name = "PauseBackground"
	bg_tex.texture = load("res://assets/main_menu.png")
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_SCALE
	bg_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(bg_tex)
	
	# Add dark overlay for readability
	var dark_overlay = ColorRect.new()
	dark_overlay.color = Color(0.02, 0.08, 0.15, 0.55) # Dimmed dark blue overlay
	dark_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(dark_overlay)
	
	# Add floating bubble layer matching Main Menu
	var bubble_overlay_script = load("res://scripts/bubble_overlay.gd")
	if bubble_overlay_script:
		var bubbles = Control.new()
		bubbles.set_script(bubble_overlay_script)
		pause_overlay.add_child(bubbles)
	
	# VBoxContainer to align elements in the center
	var vbox = VBoxContainer.new()
	vbox.name = "PauseVBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.custom_minimum_size = Vector2(320, 400)
	vbox.size = Vector2(320, 400)
	vbox.add_theme_constant_override("separation", 20) # gap between buttons
	
	vbox.position = (view_size - Vector2(320, 400)) / 2.0
	pause_overlay.add_child(vbox)
	
	# Title Label
	var title = Label.new()
	title.text = "GAME PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var grape_soda = load("res://assets/GrapeSoda.ttf")
	if grape_soda:
		title.add_theme_font_override("font", grape_soda)
		title.add_theme_font_size_override("font_size", 72)
	else:
		title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	vbox.add_child(title)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)
	
	# Create Resume Button
	var btn_resume = Button.new()
	btn_resume.text = "Resume Game"
	style_menu_button(btn_resume)
	btn_resume.pressed.connect(toggle_pause)
	vbox.add_child(btn_resume)
	
	# Create Restart Button
	var btn_restart = Button.new()
	btn_restart.text = "Restart"
	style_menu_button(btn_restart)
	btn_restart.pressed.connect(func():
		toggle_pause()
		GameManager.reset_game()
		get_tree().reload_current_scene()
	)
	vbox.add_child(btn_restart)
	
	# Create Main Menu Button
	var btn_menu = Button.new()
	btn_menu.text = "Main Menu"
	style_menu_button(btn_menu)
	btn_menu.pressed.connect(func():
		toggle_pause()
		GameManager.reset_game()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	vbox.add_child(btn_menu)

	# Style the 4 top HUD labels to improve their appearance (using clean default system font)
	var top_labels = []
	if is_instance_valid(score_label):
		score_label.offset_right = 700.0 # Prevent clipping of stats text
		top_labels.append({"node": score_label, "size": 32})
	if is_instance_valid(timer_label):
		timer_label.offset_right = 450.0
		top_labels.append({"node": timer_label, "size": 28})
	
	var oxy_label = $Control/OxygenBar/Label if $Control/OxygenBar.has_node("Label") else null
	if is_instance_valid(oxy_label):
		top_labels.append({"node": oxy_label, "size": 18})
		
	if is_instance_valid(health_status_label):
		top_labels.append({"node": health_status_label, "size": 17})
		
	for item in top_labels:
		var lbl = item["node"]
		var size = item["size"]
		# Remove custom font override to ensure we use the default system font
		lbl.remove_theme_font_override("font")
		lbl.add_theme_font_size_override("font_size", size)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 4)
		# Premium drop shadow styling
		lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
		lbl.add_theme_constant_override("shadow_offset_x", 2)
		lbl.add_theme_constant_override("shadow_offset_y", 2)
		lbl.add_theme_constant_override("shadow_outline_size", 2)

func _on_stats_changed(trash: int, rescues: int) -> void:
	score_label.text = "Trash Cleaned: " + str(trash) + " | Creatures Rescued: " + str(rescues)

func _on_oxygen_changed(new_oxygen: float) -> void:
	if oxygen_bar:
		oxygen_bar.value = new_oxygen
		# Turn progress bar red when oxygen is low
		if new_oxygen < 30.0:
			oxygen_bar.modulate = Color.RED
		else:
			oxygen_bar.modulate = Color.WHITE
			
		var label_node = oxygen_bar.get_node_or_null("Label")
		if label_node and label_node is Label:
			label_node.text = "OXYGEN SUPPLY: %d%%" % int(new_oxygen)

func _on_ocean_health_changed(new_health: float) -> void:
	if health_bar:
		health_bar.value = new_health
		
		# Dynamically color-code the health bar and update label text based on state thresholds
		var status_text: String = ""
		if new_health >= 80.0:
			health_bar.modulate = Color.GREEN_YELLOW
			status_text = "CLEAN OCEAN (%d%%)" % int(new_health)
		elif new_health >= 40.0:
			health_bar.modulate = Color.GOLD
			status_text = "POLLUTED OCEAN (%d%%)" % int(new_health)
		else:
			health_bar.modulate = Color.CRIMSON
			status_text = "CRITICAL OCEAN (%d%%)" % int(new_health)
			
		# Update status label inside the progress bar if it exists
		var status_node = health_bar.get_node_or_null("Label")
		if status_node and status_node is Label:
			status_node.text = status_text

# Spawns a floating underwater thought bubble containing the educational fact
# Spawns a floating underwater thought bubble containing the educational fact.
# Positioned on the right side of the screen to avoid overlapping active gameplay / trapped fish,
# and dynamically stacked to prevent bubbles from overlapping each other.
func show_fact(fact_text: String) -> void:
	# ── Improve 1: Hard cap — discard if 3+ bubbles already on screen ──
	var active_count_pre = get_tree().get_nodes_in_group("eco_bubbles").size()
	if active_count_pre >= BUBBLE_MAX_ACTIVE:
		return
	
	# ── Improve 2: Category throttle — suppress same-category repeats within 5s ──
	var lower_text = fact_text.to_lower()
	var category = "info"
	if "interception" in lower_text or "rescued" in lower_text or "restored" in lower_text or "recovering" in lower_text:
		category = "restore"
	elif "perished" in lower_text or "warning" in lower_text or "ingested" in lower_text or "trapped" in lower_text or "dead zone" in lower_text:
		category = "alert"
	elif "bottle" in lower_text:
		category = "bottle"
	elif "bag" in lower_text:
		category = "bag"
	elif "net" in lower_text:
		category = "net"
	elif "removed" in lower_text or "cleared" in lower_text or "collected" in lower_text:
		category = "cleanup"
	
	var now_ms = Time.get_ticks_msec()
	if _last_bubble_times.has(category):
		if (now_ms - _last_bubble_times[category]) < BUBBLE_THROTTLE_MS:
			return
	_last_bubble_times[category] = now_ms

	# 1. Base glassy blue bubble colors (forced all-blue theme)
	var bg_color = Color(0.05, 0.25, 0.45, 0.75) # filled glassy blue
	var border_color = Color(0.6, 0.85, 1.0, 0.9) # shiny glowing border

	# 2. Create the PanelContainer dynamically
	var bubble = PanelContainer.new()
	
	# Override StyleBoxFlat for a rounded bubble theme
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = bg_color
	style_box.border_color = border_color
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(110) # wobbly circular ocean bubble look (half of 220 size)
	style_box.shadow_color = Color(0, 0, 0, 0.45) # dark drop shadow for high readability
	style_box.shadow_size = 8
	style_box.content_margin_left = 22
	style_box.content_margin_right = 22
	style_box.content_margin_top = 22
	style_box.content_margin_bottom = 22
	
	bubble.add_theme_stylebox_override("panel", style_box)
	
	# 3. Create Label inside bubble
	var label = Label.new()
	label.text = fact_text # Raw message text (no tag prefixes)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(176, 0) # compact width to fit circular bubble
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1)) # dark outline
	label.add_theme_constant_override("outline_size", 4) # outline size for high legibility
	
	bubble.add_child(label)
	
	# 4. Add bubble to HUD Control root
	$Control.add_child(bubble)
	
	# Set bubble size and pivot for wobble animation (perfect circle 220x220)
	bubble.size = Vector2(220, 220)
	bubble.pivot_offset = Vector2(110, 110)
	
	# Wobble animation (squish and stretch) to mimic real underwater bubbles
	var wobble_tween = bubble.create_tween().set_loops()
	wobble_tween.tween_property(bubble, "scale", Vector2(1.03, 0.97), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wobble_tween.tween_property(bubble, "scale", Vector2(0.97, 1.03), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# 5. Position bubble dynamically on the right side of the screen
	var viewport_size = get_viewport().get_visible_rect().size
	var spawn_x = viewport_size.x - bubble.size.x - 24.0
	
	# Default spawn Y is near the bottom (lower down for longer read time)
	var default_spawn_y = viewport_size.y - bubble.size.y - 60.0
	var spawn_y = default_spawn_y
	
	var active_bubbles = get_tree().get_nodes_in_group("eco_bubbles")
	var lowest_active_y = -1.0
	
	for active in active_bubbles:
		if is_instance_valid(active) and active != bubble and active.visible:
			var active_y = active.global_position.y
			if active_y > lowest_active_y:
				lowest_active_y = active_y
				
	if lowest_active_y != -1.0:
		# If the lowest active bubble is low, stack this bubble below it (spacing of 15px)
		var min_y = lowest_active_y + bubble.size.y + 15.0
		if min_y > spawn_y:
			spawn_y = min_y
			
	bubble.global_position = Vector2(spawn_x, spawn_y)
	
	# 6. Animate bubble floating upward, swaying, and fading out
	bubble.modulate.a = 0.0
	
	var float_speed = 100.0
	var target_y = 180.0
	var float_distance = spawn_y - target_y
	var float_duration = max(0.1, float_distance / float_speed)
	
	# Main tween: handles fade in and float up (parallel)
	var main_tween = bubble.create_tween().set_parallel(true)
	# Fast and snappy fade in (0.1 seconds)
	main_tween.tween_property(bubble, "modulate:a", 1.0, 0.1)
	
	# Float upwards slowly and smoothly all the way to target Y = 180.0
	main_tween.tween_property(bubble, "global_position:y", target_y, float_duration).set_trans(Tween.TRANS_LINEAR)
	
	# Sway tween: handles gentle left-and-right bobbing sways (looping)
	var start_x = bubble.global_position.x
	var sway_tween = bubble.create_tween()
	sway_tween.set_loops(int(ceil(float_duration))) # sway for the entire float duration
	sway_tween.tween_property(bubble, "global_position:x", start_x - 12.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sway_tween.tween_property(bubble, "global_position:x", start_x + 12.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Out tween: handles the exact fade-out timing (starts at Y=230, finishes at Y=180)
	var distance_to_230 = spawn_y - 230.0
	var time_to_reach_230 = max(0.01, distance_to_230 / float_speed)
	# Fade duration is the time to float the remaining 50 pixels (from Y=230 to Y=180)
	var fade_duration = 50.0 / float_speed # approx 1.54 seconds
	
	var out_tween = bubble.create_tween()
	out_tween.tween_interval(time_to_reach_230)
	out_tween.tween_property(bubble, "modulate:a", 0.0, fade_duration)
	out_tween.tween_callback(bubble.queue_free)
	
	# Add to group only after position and layout are fully initialized to avoid Y=0 race conditions
	bubble.add_to_group("eco_bubbles")


# Helper methods for standard Button-based mobile controls
func _on_mobile_button_down(action: String) -> void:
	Input.action_press(action)

func _on_mobile_button_up(action: String) -> void:
	Input.action_release(action)

func _process(delta: float) -> void:
	# Update Survey Time countdown
	if timer_label:
		var time_left = max(0.0, 90.0 - GameManager.dive_time)
		timer_label.text = "Time Remaining: %d s" % int(ceil(time_left))
		
		# Make timer red and pulse when time is running out (< 15 seconds)
		if time_left <= 15.0 and time_left > 0.0:
			timer_label.modulate = Color.RED
			timer_label.modulate.a = sin(Time.get_ticks_msec() * 0.008) * 0.4 + 0.6
		else:
			timer_label.modulate = Color.WHITE
			
	# Low oxygen pulsing overlay warning feedback
	if oxygen_overlay:
		var oxygen = GameManager.current_oxygen
		if oxygen < 30.0:
			oxygen_overlay.visible = true
			if oxygen < 15.0:
				# Very low oxygen: rapid, heavy pulse
				var pulse_speed = 12.0
				var max_alpha = 0.45
				oxygen_overlay.color.a = (sin(Time.get_ticks_msec() * 0.001 * pulse_speed) * 0.5 + 0.5) * max_alpha
			else:
				# Low oxygen: slow, gentle pulse
				var pulse_speed = 5.0
				var max_alpha = 0.22
				oxygen_overlay.color.a = (sin(Time.get_ticks_msec() * 0.001 * pulse_speed) * 0.5 + 0.5) * max_alpha
		else:
			oxygen_overlay.visible = false

	# Update dynamic Oxygen Warning Label visibility and pulsing effect
	if oxygen_warning_label:
		var oxygen = GameManager.current_oxygen
		if oxygen < 30.0:
			oxygen_warning_label.visible = true
			oxygen_warning_label.modulate.a = sin(Time.get_ticks_msec() * 0.01) * 0.4 + 0.6
		else:
			oxygen_warning_label.visible = false

	# Update Rescue Indicator
	if is_instance_valid(rescue_indicator):
		var player = get_tree().get_first_node_in_group("player")
		var nearest_animal = null
		if is_instance_valid(player):
			nearest_animal = get_nearest_trapped_animal(player.global_position)
			
		if is_instance_valid(player) and is_instance_valid(nearest_animal):
			var player_screen_pos = player.get_global_transform_with_canvas().origin
			var animal_screen_pos = nearest_animal.get_global_transform_with_canvas().origin
			
			var direction = (nearest_animal.global_position - player.global_position).normalized()
			
			# Orbit the player at 70 pixels (offset by 15 pixels to align the 30x30 pivot center)
			rescue_indicator.global_position = player_screen_pos + direction * 70.0 - Vector2(15, 15)
			rescue_indicator.rotation = direction.angle()
			
			# Check visibility bounds and distance
			var viewport_rect = get_viewport().get_visible_rect()
			var is_on_screen = viewport_rect.has_point(animal_screen_pos)
			var dist_to_player = player.global_position.distance_to(nearest_animal.global_position)
			
			if is_on_screen and dist_to_player < RESCUE_HIDE_DISTANCE:
				rescue_indicator.visible = false
			else:
				rescue_indicator.visible = true
		else:
			rescue_indicator.visible = false



# ── Improve 3: Pollution surge banner ──
# Shows a single, prominent label matching the oxygen-warning style — no box, just white text with dark red outline.
func show_surge_banner(message: String) -> void:
	# Dismiss any existing banner first
	if is_instance_valid(surge_banner):
		surge_banner.queue_free()
		surge_banner = null

	var label = Label.new()
	surge_banner = label

	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0.6, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_font_size_override("font_size", 32)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(1100, 80)
	label.size = Vector2(1100, 80)
	
	var view_width = get_viewport().get_visible_rect().size.x
	label.position.x = (view_width - label.size.x) / 2.0
	label.position.y = 190.0
	label.modulate.a = 0.0

	$Control.add_child(label)

	var tween = label.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(4.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.tween_callback(label.queue_free)

func get_nearest_trapped_animal(player_pos: Vector2) -> Node2D:
	var trapped_animals: Array = []
	
	# Find trapped fish
	var fish_nodes = get_tree().get_nodes_in_group("fish")
	for fish in fish_nodes:
		if is_instance_valid(fish) and fish.get("is_trapped") == true and fish.get("is_perishing") == false:
			trapped_animals.append(fish)
			
	# Find trapped turtles
	var turtle_nodes = get_tree().get_nodes_in_group("turtles")
	for turtle in turtle_nodes:
		if is_instance_valid(turtle) and turtle.get("is_trapped") == true and turtle.get("is_perishing") == false:
			trapped_animals.append(turtle)
			
	if trapped_animals.is_empty():
		return null
		
	var nearest: Node2D = null
	var min_dist = INF
	
	for animal in trapped_animals:
		var dist = player_pos.distance_to(animal.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = animal
			
	return nearest

func toggle_pause() -> void:
	var new_paused = not get_tree().paused
	get_tree().paused = new_paused
	if is_instance_valid(pause_overlay):
		pause_overlay.visible = new_paused
		if new_paused:
			GameManager.play_menu_music()
		else:
			GameManager.stop_menu_music()

func style_menu_button(btn: Button) -> void:
	btn.custom_minimum_size = Vector2(280, 50)
	var grape_soda = load("res://assets/GrapeSoda.ttf")
	if grape_soda:
		btn.add_theme_font_override("font", grape_soda)
		btn.add_theme_font_size_override("font_size", 36)
	else:
		btn.add_theme_font_size_override("font_size", 20)
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.08, 0.32, 0.58, 0.5)
	style_normal.border_color = Color(0.6, 0.85, 1.0, 0.8)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(8)
	style_normal.content_margin_top = 10
	style_normal.content_margin_bottom = 10
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.12, 0.45, 0.78, 0.8)
	style_hover.border_color = Color(0.7, 0.95, 1.0, 1.0)
	style_hover.set_border_width_all(2)
	style_hover.set_corner_radius_all(8)
	style_hover.content_margin_top = 10
	style_hover.content_margin_bottom = 10
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	
	var style_empty = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("focus", style_empty)
	btn.add_theme_color_override("font_color", Color.WHITE)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		var player = get_tree().get_first_node_in_group("player")
		if is_instance_valid(player) and player.get("is_active") == true:
			toggle_pause()
