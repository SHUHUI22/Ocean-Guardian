extends Control

# Handles the main menu screen.
# Dynamically loads the background texture and custom GrapeSoda font on ready,
# then runs entrance animations for all UI elements.

func _ready() -> void:
	GameManager.play_menu_music()
	# ── Background: swap ColorRect for main_menu.png TextureRect ──
	var bg = get_node_or_null("Background")
	if bg:
		var texture_rect = TextureRect.new()
		texture_rect.name = "Background"
		texture_rect.anchor_right = 1.0
		texture_rect.anchor_bottom = 1.0
		texture_rect.offset_right = 0.0
		texture_rect.offset_bottom = 0.0
		texture_rect.layout_mode = 1
		texture_rect.texture = load("res://assets/main_menu.png")
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
		var parent = bg.get_parent()
		var index = bg.get_index()
		parent.remove_child(bg)
		bg.queue_free()
		parent.add_child(texture_rect)
		parent.move_child(texture_rect, index)

	# ── Floating bubble layer (behind all labels) ──
	var bubble_overlay_script = load("res://scripts/bubble_overlay.gd")
	if bubble_overlay_script:
		var bubbles = Control.new()
		bubbles.set_script(bubble_overlay_script)
		add_child(bubbles)
		move_child(bubbles, 1) # Above background, behind labels/buttons


	# ── Apply GrapeSoda font ──
	var grape_soda = load("res://assets/GrapeSoda.ttf")
	var title_label   = get_node_or_null("TitleLabel")
	var story_label   = get_node_or_null("StoryLabel")
	var play_btn      = get_node_or_null("VBoxContainer/PlayButton")
	var how_to_play_btn = get_node_or_null("VBoxContainer/HowToPlayButton")
	var quit_btn      = get_node_or_null("VBoxContainer/QuitButton")
	var vbox          = get_node_or_null("VBoxContainer")

	if title_label:
		title_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85, 0.8))
		if grape_soda:
			title_label.add_theme_font_override("font", grape_soda)
			title_label.add_theme_font_size_override("font_size", 72)
		if story_label:
			story_label.add_theme_font_override("font", grape_soda)
			story_label.add_theme_font_size_override("font_size", 28)
		if play_btn:
			play_btn.add_theme_font_override("font", grape_soda)
			play_btn.add_theme_font_size_override("font_size", 36)
		if how_to_play_btn:
			how_to_play_btn.add_theme_font_override("font", grape_soda)
			how_to_play_btn.add_theme_font_size_override("font_size", 36)
		if quit_btn:
			quit_btn.add_theme_font_override("font", grape_soda)
			quit_btn.add_theme_font_size_override("font_size", 36)

	# ── Create Footer Label ──
	var footer_label = Label.new()
	footer_label.name = "FooterLabel"
	footer_label.text = "Goh Shu Hui | 23004975"
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85, 0.8)) # Semi-transparent light-blue/grey
	footer_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	if grape_soda:
		footer_label.add_theme_font_override("font", grape_soda)
		footer_label.add_theme_font_size_override("font_size", 26)
	else:
		footer_label.add_theme_font_size_override("font_size", 16)
	footer_label.custom_minimum_size = Vector2(400, 30)
	footer_label.size = Vector2(400, 30)
	var view_size = get_viewport().get_visible_rect().size
	footer_label.position = Vector2((view_size.x - 400) / 2.0, view_size.y - 45)
	add_child(footer_label)

	# ── Entrance animations ──
	_animate_entrance(title_label, story_label, play_btn, how_to_play_btn, quit_btn, vbox)
	# Start the idle floating loop after entrance
	await get_tree().create_timer(1.2).timeout
	_start_title_float(title_label)

func _animate_entrance(title_label, story_label, play_btn, how_to_play_btn, quit_btn, vbox) -> void:
	# Hide everything initially
	for node in [title_label, story_label, vbox]:
		if node:
			node.modulate.a = 0.0

	# 1. Title: slides down from above + fades in
	if title_label:
		var origin_y = title_label.position.y
		title_label.position.y = origin_y - 60
		var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(title_label, "position:y", origin_y, 0.7)
		tw.parallel().tween_property(title_label, "modulate:a", 1.0, 0.7)

	# 2. Story text: fades in after title
	if story_label:
		await get_tree().create_timer(0.55).timeout
		var tw2 = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		tw2.tween_property(story_label, "modulate:a", 1.0, 0.6)

	# 3. Buttons VBox: slides up from below + fades in
	if vbox:
		await get_tree().create_timer(0.25).timeout
		var origin_y = vbox.position.y
		vbox.position.y = origin_y + 50
		var tw3 = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw3.tween_property(vbox, "position:y", origin_y, 0.5)
		tw3.parallel().tween_property(vbox, "modulate:a", 1.0, 0.5)

func _start_title_float(title_label) -> void:
	if not is_instance_valid(title_label):
		return
	var base_y = title_label.position.y
	var tw = create_tween().set_loops().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(title_label, "position:y", base_y - 10.0, 2.2)
	tw.tween_property(title_label, "position:y", base_y, 2.2)

func _on_play_button_pressed() -> void:
	GameManager.reset_game()
	GameManager.load_level(1)

func _on_how_to_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/how_to_play.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()
