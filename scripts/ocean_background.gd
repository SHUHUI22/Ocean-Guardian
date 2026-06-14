extends Node2D

# OceanBackground.gd - Controls background environment tints and coral modulation.

@onready var color_rect: ColorRect = $ColorRect
@onready var bg_sprite: Sprite2D = $BackgroundSprite
@onready var bubble_particles: GPUParticles2D = $BubbleParticles

var last_category: int = 1 # 0: Critical (<40), 1: Polluted (40-79), 2: Clean (>=80)
var is_blooming: bool = false

func _ready() -> void:
	GameManager.ocean_health_changed.connect(_on_ocean_health_changed)
	# Set initial category based on starting health (50.0 is polluted)
	var health = GameManager.ocean_health
	if health >= 80.0:
		last_category = 2
	elif health >= 40.0:
		last_category = 1
	else:
		last_category = 0
	_on_ocean_health_changed(health)

func set_ocean_state(_state: String) -> void:
	# Retained for level compatibility but we now drive dynamically via signals
	pass

func _on_ocean_health_changed(health: float) -> void:
	var current_category = 1
	if health >= 80.0:
		current_category = 2
	elif health >= 40.0:
		current_category = 1
	else:
		current_category = 0
		
	# Trigger recovery bloom if category has improved
	if current_category > last_category:
		trigger_recovery_bloom(current_category)
	else:
		if not is_blooming:
			bg_sprite.modulate = get_target_modulate(health)
			
	last_category = current_category
	
	# Update color_rect color
	var target_rect_color = Color()
	if health >= 80.0:
		target_rect_color = Color(0.0, 0.6, 1.0, 0.15)
	elif health >= 40.0:
		var t = (health - 40.0) / 40.0
		target_rect_color = Color(0.38, 0.48, 0.35, 0.4).lerp(Color(0.0, 0.6, 1.0, 0.15), t)
	else:
		var t = health / 40.0
		target_rect_color = Color(0.12, 0.18, 0.10, 0.85).lerp(Color(0.38, 0.48, 0.35, 0.4), t)
		
	var rect_tween = create_tween()
	rect_tween.tween_property(color_rect, "color", target_rect_color, 0.5)

	# Update bubble particle color based on health
	if bubble_particles:
		if health < 40.0:
			bubble_particles.modulate = Color(0.5, 0.6, 0.4, 0.5) # cloudy/dirty particles
		else:
			bubble_particles.modulate = Color(1.0, 1.0, 1.0, 0.35)

func get_target_modulate(health: float) -> Color:
	if health >= 80.0:
		return Color(0.9, 1.0, 1.0)
	elif health >= 40.0:
		var t = (health - 40.0) / 40.0
		return Color(0.85, 0.85, 0.8, 1.0).lerp(Color(0.9, 1.0, 1.0), t)
	else:
		var t = health / 40.0
		return Color(0.4, 0.4, 0.4, 1.0).lerp(Color(0.85, 0.85, 0.8, 1.0), t)

func trigger_recovery_bloom(new_category: int) -> void:
	is_blooming = true
	var flash_tween = create_tween()
	# Bright glowing effect for the bloom transition
	flash_tween.tween_property(bg_sprite, "modulate", Color(1.4, 1.5, 1.4, 1.0), 0.2)
	flash_tween.tween_property(bg_sprite, "modulate", get_target_modulate(GameManager.ocean_health), 1.0)
	flash_tween.tween_callback(func(): is_blooming = false)
