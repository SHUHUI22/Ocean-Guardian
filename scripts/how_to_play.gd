extends Control

func _ready() -> void:
	# Keep menu music playing
	GameManager.play_menu_music()

	# Swap ColorRect background for main_menu.png TextureRect
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

	# Add floating bubble overlay (matching main menu style)
	var bubble_overlay_script = load("res://scripts/bubble_overlay.gd")
	if bubble_overlay_script:
		var bubbles = Control.new()
		bubbles.set_script(bubble_overlay_script)
		add_child(bubbles)
		move_child(bubbles, 1) # Behind panel, above background

	# Style the Panel container as a premium glassy container
	var panel = get_node_or_null("Panel")
	if panel:
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.02, 0.08, 0.15, 0.8) # Glassy dark blue
		panel_style.border_color = Color(0.6, 0.85, 1.0, 0.8)
		panel_style.set_border_width_all(3)
		panel_style.set_corner_radius_all(12)
		panel_style.content_margin_left = 35
		panel_style.content_margin_right = 35
		panel_style.content_margin_top = 25
		panel_style.content_margin_bottom = 25
		panel.add_theme_stylebox_override("panel", panel_style)

	# Apply GrapeSoda font
	var grape_soda = load("res://assets/GrapeSoda.ttf")
	var title = get_node_or_null("Panel/VBoxContainer/Title")
	if title and grape_soda:
		title.add_theme_font_override("font", grape_soda)
		title.add_theme_font_size_override("font_size", 54)
		title.add_theme_color_override("font_color", Color.WHITE)
		title.add_theme_color_override("font_outline_color", Color.BLACK)
		title.add_theme_constant_override("outline_size", 4)
		
	# Apply GrapeSoda font and split emojis from headers to ensure visibility on mobile
	var headers = [
		get_node_or_null("Panel/VBoxContainer/ScrollContainer/ScrollVBox/ObjectiveHeader"),
		get_node_or_null("Panel/VBoxContainer/ScrollContainer/ScrollVBox/GameplayHeader"),
		get_node_or_null("Panel/VBoxContainer/ScrollContainer/ScrollVBox/DiveHeader"),
		get_node_or_null("Panel/VBoxContainer/ScrollContainer/ScrollVBox/ControlsHeader"),
		get_node_or_null("Panel/VBoxContainer/ScrollContainer/ScrollVBox/AwarenessHeader")
	]
	
	for header in headers:
		if header:
			split_header_emoji_and_text(header, grape_soda)
				
	# Content (body texts) use default system font for comfortable reading as requested
	var body_texts = [
		get_node_or_null("Panel/VBoxContainer/ScrollContainer/ScrollVBox/ObjectiveText"),
		get_node_or_null("Panel/VBoxContainer/ScrollContainer/ScrollVBox/GameplayText"),
		get_node_or_null("Panel/VBoxContainer/ScrollContainer/ScrollVBox/DiveText"),
		get_node_or_null("Panel/VBoxContainer/ScrollContainer/ScrollVBox/ControlsText"),
		get_node_or_null("Panel/VBoxContainer/ScrollContainer/ScrollVBox/AwarenessText")
	]
	for body in body_texts:
		if body:
			body.add_theme_font_size_override("font_size", 18)
			body.add_theme_color_override("font_color", Color(0.85, 0.92, 0.95, 1.0)) # Soft light-blue/grey

	# Style and wire the Back Button
	var back_btn = get_node_or_null("Panel/VBoxContainer/BackButton")
	if back_btn:
		back_btn.text = "Back to Menu"
		if grape_soda:
			back_btn.add_theme_font_override("font", grape_soda)
			back_btn.add_theme_font_size_override("font_size", 32)
		style_menu_button(back_btn)
		back_btn.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func style_menu_button(btn: Button) -> void:
	btn.custom_minimum_size = Vector2(240, 50)
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.08, 0.32, 0.58, 0.5)
	style_normal.border_color = Color(0.6, 0.85, 1.0, 0.8)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(8)
	style_normal.content_margin_top = 8
	style_normal.content_margin_bottom = 8
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.12, 0.45, 0.78, 0.8)
	style_hover.border_color = Color(0.7, 0.95, 1.0, 1.0)
	style_hover.set_border_width_all(2)
	style_hover.set_corner_radius_all(8)
	style_hover.content_margin_top = 8
	style_hover.content_margin_bottom = 8
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", Color.WHITE)

func split_header_emoji_and_text(header: Label, grape_soda: Font) -> void:
	var raw_text = header.text
	var first_letter_idx = -1
	for i in range(raw_text.length()):
		var code = raw_text.unicode_at(i)
		if (code >= 65 and code <= 90) or (code >= 97 and code <= 122):
			first_letter_idx = i
			break
			
	if first_letter_idx == -1:
		# Fallback: style the entire text block if no alphabet character is found
		if grape_soda:
			header.add_theme_font_override("font", grape_soda)
		header.add_theme_font_size_override("font_size", 28)
		header.add_theme_color_override("font_color", Color(1.0, 0.78, 0.15, 1.0))
		header.add_theme_color_override("font_outline_color", Color.BLACK)
		header.add_theme_constant_override("outline_size", 3)
		return

	var text_part = raw_text.substr(first_letter_idx).strip_edges()

	# Map header node name to a corresponding local game asset texture
	var texture_path = ""
	var icon_size = Vector2(32, 32)
	match header.name:
		"ObjectiveHeader":
			texture_path = "res://assets/goal.png"
		"GameplayHeader":
			texture_path = "res://assets/fish_icon.png"
			icon_size = Vector2(42, 42) # Compensate for smaller visual proportions of the fish asset
		"DiveHeader":
			texture_path = "res://assets/health.png"
		"ControlsHeader":
			texture_path = "res://assets/control.png"
		"AwarenessHeader":
			texture_path = "res://assets/awareness.png"
		_:
			texture_path = "res://assets/fish_icon.png"

	var hbox = HBoxContainer.new()
	hbox.name = header.name + "_Container"
	hbox.add_theme_constant_override("separation", 12)

	# Inline icon using local game texture to guarantee mobile display compatibility
	var icon_rect = TextureRect.new()
	icon_rect.texture = load(texture_path)
	icon_rect.custom_minimum_size = icon_size
	icon_rect.size = icon_size
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var text_label = Label.new()
	text_label.text = text_part
	if grape_soda:
		text_label.add_theme_font_override("font", grape_soda)
	text_label.add_theme_font_size_override("font_size", 28)
	text_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.15, 1.0)) # Vibrant Gold
	text_label.add_theme_color_override("font_outline_color", Color.BLACK)
	text_label.add_theme_constant_override("outline_size", 3)

	hbox.add_child(icon_rect)
	hbox.add_child(text_label)

	var parent = header.get_parent()
	var index = header.get_index()
	parent.remove_child(header)
	header.queue_free()
	parent.add_child(hbox)
	parent.move_child(hbox, index)
