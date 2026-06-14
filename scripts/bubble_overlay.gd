extends Control

# BubbleOverlay.gd
# Draws a layer of floating semi-transparent bubbles rising from the bottom.
# Add this as a child of any Control scene and call spawn().
# It should sit above the background but below all other UI (move_child accordingly).

class_name BubbleOverlay

const BUBBLE_COUNT := 22

func _ready() -> void:
	# Stretch to fill parent
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Spawn after one frame so viewport size is settled
	await get_tree().process_frame
	_spawn()

func _spawn() -> void:
	var vp_size = get_viewport_rect().size

	for _i in range(BUBBLE_COUNT):
		var size = randf_range(6.0, 28.0)

		# Panel with circular StyleBox
		var panel = Panel.new()
		panel.custom_minimum_size = Vector2(size, size)
		panel.size = Vector2(size, size)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var style = StyleBoxFlat.new()
		style.bg_color      = Color(1, 1, 1, randf_range(0.04, 0.16))
		style.border_color  = Color(1, 1, 1, randf_range(0.15, 0.35))
		style.set_border_width_all(1)
		style.set_corner_radius_all(int(size * 0.5) + 1)
		panel.add_theme_stylebox_override("panel", style)

		# Random starting position (spread across the full height for immediate variety)
		panel.position = Vector2(
			randf_range(0.0, vp_size.x - size),
			randf_range(0.0, vp_size.y)
		)
		add_child(panel)

		# Stagger the start so they don't all trigger at once
		var delay = randf_range(0.0, 5.0)
		await get_tree().create_timer(delay).timeout
		if is_instance_valid(panel):
			_loop_bubble(panel, vp_size)

func _loop_bubble(bubble: Panel, vp_size: Vector2) -> void:
	if not is_instance_valid(bubble):
		return
	var duration  = randf_range(4.5, 10.0)
	var drift_x   = bubble.position.x + randf_range(-55.0, 55.0)
	drift_x = clamp(drift_x, 0.0, vp_size.x - bubble.size.x)

	var tw = bubble.create_tween()
	tw.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	# Rise upward
	tw.tween_property(bubble, "position:y", -bubble.size.y - 10.0, duration)
	# Gentle horizontal drift
	tw.parallel().tween_property(bubble, "position:x", drift_x, duration)

	tw.tween_callback(func():
		if is_instance_valid(bubble):
			bubble.position.x = randf_range(0.0, vp_size.x - bubble.size.x)
			bubble.position.y = vp_size.y + randf_range(5.0, 40.0)
			_loop_bubble(bubble, vp_size)
	)
