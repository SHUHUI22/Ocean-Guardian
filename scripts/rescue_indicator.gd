extends Control

# Rescue Indicator - Vector-drawn directional pointer for trapped marine animals.
# Rotates and orbits the player to help them locate trapped creatures.

var pulse_time: float = 0.0

func _ready() -> void:
	# Keep indicator size small
	custom_minimum_size = Vector2(30, 30)
	size = Vector2(30, 30)
	# Center pivot offset for rotation
	pivot_offset = Vector2(15, 15)

func _process(delta: float) -> void:
	pulse_time += delta
	# Smooth soft pulse between 0.35 and 0.95
	modulate.a = 0.65 + sin(pulse_time * 3.8) * 0.30

func _draw() -> void:
	# Draw vector arrow pointing to the right (relative to pivot)
	# Coordinates relative to center (15, 15)
	var center = Vector2(15, 15)
	
	# Arrow vertices pointing to the right (offset from center)
	var points = PackedVector2Array([
		center + Vector2(16, 0),       # Tip
		center + Vector2(-2, -9),      # Top wing
		center + Vector2(1, -3),       # Inner top indent
		center + Vector2(-12, -3),     # Stem back top
		center + Vector2(-12, 3),      # Stem back bottom
		center + Vector2(1, 3),        # Inner bottom indent
		center + Vector2(-2, 9)        # Bottom wing
	])
	
	# Vibrant crimson red theme for high visibility
	var fill_color = Color(0.85, 0.15, 0.2, 0.95)
	var outline_color = Color(1.0, 0.9, 0.9, 0.95)
	
	# Draw shadow (offset slightly down/right)
	var shadow_offset = Vector2(1.5, 1.5)
	var shadow_points = PackedVector2Array()
	for p in points:
		shadow_points.append(p + shadow_offset)
	draw_colored_polygon(shadow_points, Color(0.2, 0.0, 0.0, 0.45))
	
	# Draw filled arrow
	draw_colored_polygon(points, fill_color)
	
	# Draw clean crisp outline
	var polyline_points = PackedVector2Array()
	for p in points:
		polyline_points.append(p)
	polyline_points.append(points[0]) # Close path
	
	draw_polyline(polyline_points, outline_color, 1.5, true)
	
	# Draw a small decorative locator arc behind the arrow representing a radar scan
	# Sits at radius of -14 to -18 pixels, spanning about 80 degrees
	draw_arc(center, 18.0, PI - 0.7, PI + 0.7, 10, Color(0.85, 0.15, 0.2, 0.45), 1.5)
