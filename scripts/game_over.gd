extends Control

# game_over.gd - Handles the ocean outcome reflection screen.
# Evaluates reflections logically based on the player's Ocean Impact Score.
# Uses same main_menu.png background and GrapeSoda font as the main menu.

@onready var title_label: Label = $Panel/TitleLabel
@onready var score_label: Label = $Panel/ScoreLabel
@onready var reflection_label: Label = $Panel/ReflectionLabel

func _ready() -> void:
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

	# ── Floating bubble layer (behind panel) ──
	var bubble_overlay_script = load("res://scripts/bubble_overlay.gd")
	if bubble_overlay_script:
		var bubbles = Control.new()
		bubbles.set_script(bubble_overlay_script)
		add_child(bubbles)
		move_child(bubbles, 1) # Above background, behind panel

	# ── Apply GrapeSoda font ──
	var grape_soda = load("res://assets/GrapeSoda.ttf")
	var panel     = get_node_or_null("Panel")
	var retry_btn = get_node_or_null("Panel/HBoxContainer/RetryButton")
	var menu_btn  = get_node_or_null("Panel/HBoxContainer/MenuButton")

	if retry_btn: retry_btn.text = "Dive Again"
	if menu_btn:  menu_btn.text  = "Main Menu"

	if grape_soda:
		for node in [title_label, retry_btn, menu_btn]:
			if node:
				node.add_theme_font_override("font", grape_soda)
		if title_label:
			title_label.add_theme_font_size_override("font_size", 44)
		if retry_btn:
			retry_btn.add_theme_font_size_override("font_size", 30)
		if menu_btn:
			menu_btn.add_theme_font_size_override("font_size", 30)
	else:
		if title_label: title_label.add_theme_font_size_override("font_size", 36)

	# Score and reflection always use default system font for comfortable reading
	if score_label:
		score_label.add_theme_font_size_override("font_size", 20)
	if reflection_label:
		reflection_label.add_theme_font_size_override("font_size", 17)




	# ── Compute game outcome ──
	var health       = GameManager.ocean_health
	var trash        = GameManager.trash_cleaned
	var rescues      = GameManager.creatures_rescued
	var impact_score = GameManager.impact_score

	var outcome_title  = ""
	var outcome_color  = Color.WHITE
	var reflection_text = ""
	var effort_rating = ""

	if not GameManager.survey_completed:
		# EARLY END (ran out of oxygen before 90s)
		# score < 75  → Low   | 75–180 → Moderate  | >180 → High
		if impact_score < 75 or health <= 0.0:
			outcome_title  = "Dive Ended Early"
			outcome_color  = Color(0.95, 0.4, 0.4, 1.0) # Red
			effort_rating  = "Low"
			reflection_text = (
				"Your dive ended before much could be recovered. Large areas of pollution remain untouched.\n\n" +
				"Marine life in this region continues to struggle with accumulated waste.\n\n" +
				"Even small actions matter, but lasting change requires continued effort."
			)
		elif impact_score <= 180:
			outcome_title  = "Dive Ended Early"
			outcome_color  = Color(0.95, 0.65, 0.4, 1.0) # Orange
			effort_rating  = "Moderate"
			reflection_text = (
				"You managed to remove waste and assist several marine creatures before your dive ended.\n\n" +
				"These actions reduce immediate threats and help stabilize the local ecosystem.\n\n" +
				"Short efforts still provide real relief to affected marine life."
			)
		else:
			outcome_title  = "Dive Ended Early"
			outcome_color  = Color(0.65, 0.85, 0.45, 1.0) # Light Green
			effort_rating  = "High"
			reflection_text = (
				"You achieved significant cleanup and rescued multiple marine animals before running out of oxygen.\n\n" +
				"Your actions directly reduced hazards in this area of the ocean.\n\n" +
				"Even interrupted dives can create meaningful environmental impact."
			)
	else:
		# COMPLETED RUN (full 90s survived)
		# Health check has priority: below 30% always → Under Threat
		# score < 150  → Under Threat  | 150–300 → Improving  | >300 → Healthier
		if health < 30.0:
			outcome_title  = "Ocean Still Under Threat"
			outcome_color  = Color(0.95, 0.4, 0.4, 1.0) # Red
			effort_rating  = "Low" if impact_score < 150 else ("Moderate" if impact_score <= 300 else "High")
			reflection_text = (
				"The dive is complete, but much of the pollution remains in this region.\n\n" +
				"Marine life continues to face pressure from accumulated waste and habitat damage.\n\n" +
				"Ongoing cleanup is required to support long-term ocean recovery."
			)
		elif impact_score < 150:
			outcome_title  = "Ocean Still Under Threat"
			outcome_color  = Color(0.95, 0.4, 0.4, 1.0) # Red
			effort_rating  = "Low"
			reflection_text = (
				"The dive is complete, but much of the pollution remains in this region.\n\n" +
				"Marine life continues to face pressure from accumulated waste and habitat damage.\n\n" +
				"Ongoing cleanup is required to support long-term ocean recovery."
			)
		elif impact_score <= 300:
			outcome_title  = "Ocean Showing Improvement"
			outcome_color  = Color(0.95, 0.85, 0.4, 1.0) # Yellow
			effort_rating  = "Moderate"
			reflection_text = (
				"Your cleanup reduced pollution levels and improved conditions for marine life.\n\n" +
				"The ecosystem shows early signs of recovery, but challenges remain.\n\n" +
				"Sustained conservation efforts are needed to maintain this progress."
			)
		else:
			outcome_title  = "A Healthier Ocean"
			outcome_color  = Color(0.45, 0.85, 0.45, 1.0) # Green
			effort_rating  = "High"
			reflection_text = (
				"You removed large amounts of waste and rescued multiple marine animals across the dive area.\n\n" +
				"These actions significantly improved habitat conditions and reduced environmental stress.\n\n" +
				"Healthy oceans depend on continued protection and responsible human activity."
			)


	title_label.text      = outcome_title
	title_label.modulate  = outcome_color
	score_label.text      = (
		"Impact Score: %d  |  Ocean Health: %d%%  |  Your Effort: %s\nCollected: %d trash  |  Rescued: %d marine creatures"
		% [impact_score, int(health), effort_rating, trash, rescues]
	)
	reflection_label.text = reflection_text

	# ── Panel entrance animation: slide up from below + fade in ──
	if panel:
		panel.modulate.a = 0.0
		var origin_y = panel.position.y
		panel.position.y = origin_y + 80
		var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(panel, "modulate:a", 1.0, 0.65)
		tw.parallel().tween_property(panel, "position:y", origin_y, 0.65)

func _on_retry_button_pressed() -> void:
	GameManager.reset_game()
	GameManager.load_level(1)

func _on_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
