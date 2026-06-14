extends Node

# Ocean Guardian - Game Manager (Global Autoload)
# Manages the Ocean Health System, Oxygen levels, and contextual educational facts.

signal score_changed(new_score)
signal oxygen_changed(new_oxygen)
signal ocean_health_changed(new_health)
signal fact_triggered(fact_text)
signal stats_changed(trash, rescues)

var score: int = 0
var max_oxygen: float = 100.0
var current_oxygen: float = 100.0

# Stats tracking
var trash_cleaned: int = 0
var creatures_rescued: int = 0
var impact_score: int:
	get:
		return trash_cleaned * 10 + creatures_rescued * 20
var dive_time: float = 0.0
var survey_completed: bool = false

# Ocean Health System (0-100)
var ocean_health: float = 50.0 # Starts at 50% (Polluted state)
var max_ocean_health: float = 100.0

# Contextual Facts Databases (Ocean salvation themed message pools)
var plastic_bag_facts: Array[String] = [
	"Sea turtles often mistake plastic bags for food as it mimics a jellyfish.",
	"Plastic bags can block digestion and harm marine wildlife.",
	"We shouldn't throw plastic into ocean to protect marine life"
]

var plastic_bottle_facts: Array[String] = [
	"Plastic should not remain in the ocean for centuries.",
	"Sunlight breaks plastic into microplastics that enter marine food chains.",
	"Removing plastic waste early prevents it from spreading through the ecosystem."
]

var fish_facts: Array[String] = [
	"This animal can now return to its natural habitat.",
	"Every rescue helps restore balance to the ecosystem."
]

var net_facts: Array[String] = [
	"Ghost nets continue trapping marine life even after being abandoned.",
	"Removing entanglements gives marine animals a chance to survive."
]

var turtle_facts: Array[String] = [
	"You prevented a turtle from swallowing harmful plastic.",
	"Early cleanup reduces risks to marine wildlife.",
	"One less piece of plastic means one less threat."
]

# Track the last shown fact for each category (anti-repetition logic)
var last_fact_per_category: Dictionary = {}
var last_triggered_category: String = ""

var has_won: bool = false
var dead_zone_fact_shown: bool = false
var low_life_played: bool = false
var menu_music_player: AudioStreamPlayer = null
var _is_ending_dive: bool = false

func _ready() -> void:
	setup_input_actions()
	reset_game()

func setup_input_actions() -> void:
	var actions = {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN]
	}
	
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for keycode in actions[action]:
				var event = InputEventKey.new()
				event.physical_keycode = keycode
				InputMap.action_add_event(action, event)

func reset_game() -> void:
	stop_menu_music()
	stop_sound("res://assets/audio/low-life.mp3")
	score = 0
	trash_cleaned = 0
	creatures_rescued = 0
	current_oxygen = max_oxygen
	ocean_health = 50.0
	dive_time = 0.0
	survey_completed = false
	has_won = false
	dead_zone_fact_shown = false
	low_life_played = false
	_is_ending_dive = false
	Engine.time_scale = 1.0
	stats_changed.emit(trash_cleaned, creatures_rescued)
	
	# Reset facts repetition memory
	last_fact_per_category.clear()
	last_triggered_category = ""

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)

func add_trash_cleaned() -> void:
	trash_cleaned += 1
	score += 10
	stats_changed.emit(trash_cleaned, creatures_rescued)
	score_changed.emit(score)

func add_creatures_rescued() -> void:
	creatures_rescued += 1
	score += 20
	stats_changed.emit(trash_cleaned, creatures_rescued)
	score_changed.emit(score)
	play_sound("res://assets/audio/rescue_twinklesparkle.mp3")

func adjust_ocean_health(amount: float) -> void:
	ocean_health = clamp(ocean_health + amount, 0.0, max_ocean_health)
	ocean_health_changed.emit(ocean_health)

func adjust_oxygen(amount: float) -> void:
	current_oxygen = clamp(current_oxygen + amount, 0.0, max_oxygen)
	oxygen_changed.emit(current_oxygen)
	if current_oxygen <= 0.0:
		end_dive()

# Triggers a fact dynamically based on the event category without repeating twice in a row
func trigger_contextual_fact(category: String) -> void:
	if category.to_lower() == last_triggered_category.to_lower():
		return
		
	var pool: Array[String] = []
	
	match category.to_lower():
		"plastic_bag":
			pool = plastic_bag_facts
		"plastic_bottle":
			pool = plastic_bottle_facts
		"fish":
			pool = fish_facts
		"net":
			pool = net_facts
		"turtle":
			pool = turtle_facts
			
	if pool.is_empty():
		return
		
	var available_facts = pool.duplicate()
	
	# Prevent showing the same fact twice in a row for this category
	if pool.size() > 1 and last_fact_per_category.has(category):
		var last_fact = last_fact_per_category[category]
		available_facts.erase(last_fact)
		
	var selected_fact = available_facts[randi() % available_facts.size()]
	last_fact_per_category[category] = selected_fact
	last_triggered_category = category
	
	fact_triggered.emit(selected_fact)

# Handles main menu click transitions (backwards compatible to your guides)
func load_level(_level_num: int) -> void:
	reset_game()
	get_tree().change_scene_to_file("res://scenes/main_level.tscn")

# Triggered when oxygen runs out or the 90s timer finishes
func end_dive() -> void:
	if _is_ending_dive:
		return
	_is_ending_dive = true
	
	stop_sound("res://assets/audio/low-life.mp3")

	var win_lose_player: AudioStreamPlayer = null
	if current_oxygen <= 0.0:
		# Ran out of oxygen early (early end)
		has_won = false
		survey_completed = false
		win_lose_player = play_sound("res://assets/audio/losing-or-failing.wav")
	else:
		# Timer finished (completed run)
		survey_completed = true
		# Won if completed run, impact score is at least 150, and ocean health is above 70%
		if impact_score >= 150 and ocean_health > 70.0:
			has_won = true
			win_lose_player = play_sound("res://assets/audio/level-win.mp3")
		else:
			has_won = false
			win_lose_player = play_sound("res://assets/audio/losing-or-failing.wav")

	if is_instance_valid(win_lose_player):
		win_lose_player.finished.connect(func():
			# Delay menu music check to ensure scene change has processed
			var current_scene = get_tree().current_scene
			if current_scene and current_scene.scene_file_path.contains("game_over"):
				play_menu_music()
		)
	else:
		play_menu_music()

	get_tree().change_scene_to_file("res://scenes/game_over.tscn")

# Play a sound dynamically without cutoffs by instantiating a player on GameManager autoload.
# Supports custom volume adjustments and duration limits (stopping/fading the sound after max_duration).
func play_sound(stream_path: String, volume_db: float = 0.0, max_duration: float = 0.0) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	var stream = load(stream_path)
	
	# Loop low-life warning programmatically if it is an MP3 stream
	if stream_path.contains("low-life") and stream is AudioStreamMP3:
		stream.loop = true
		
	player.stream = stream
	player.volume_db = volume_db
	player.set_meta("stream_path", stream_path) # Store path as meta for robust lookup
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	
	if max_duration > 0.0:
		get_tree().create_timer(max_duration).timeout.connect(func():
			if is_instance_valid(player) and player.playing:
				var tween = create_tween()
				tween.tween_property(player, "volume_db", -80.0, 0.15)
				tween.tween_callback(player.queue_free)
		)
	return player

func play_menu_music() -> void:
	if is_instance_valid(menu_music_player) and menu_music_player.playing:
		return
	if not is_instance_valid(menu_music_player):
		menu_music_player = AudioStreamPlayer.new()
		menu_music_player.stream = load("res://assets/audio/menu.mp3")
		if menu_music_player.stream is AudioStreamMP3:
			menu_music_player.stream.loop = true
		add_child(menu_music_player)
	menu_music_player.play()

func stop_menu_music() -> void:
	if is_instance_valid(menu_music_player):
		menu_music_player.stop()

# Stops and frees all AudioStreamPlayer nodes playing the specified stream path.
func stop_sound(stream_path: String) -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			var meta_path = child.get_meta("stream_path", "")
			if meta_path == stream_path or (child.stream and child.stream.resource_path == stream_path):
				child.stop()
				child.queue_free()
