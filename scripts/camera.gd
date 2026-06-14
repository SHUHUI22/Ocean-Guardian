extends Camera2D

# Camera that follows the player smoothly, performs a zoom effect, and handles screen shakes.

var zoom_tween: Tween

var shake_amount: float = 0.0
var shake_decay: float = 5.0

func _ready() -> void:
	# Reset local position to (0,0) to center on the player
	position = Vector2.ZERO
	# Default zoom is 1.25 (moderately zoomed in so objects are clear but screen is not too cramped)
	zoom = Vector2(1.25, 1.25)
	# Make sure this camera is active and current
	enabled = true
	make_current()

func _process(delta: float) -> void:
	# Camera shake logic
	if shake_amount > 0.0:
		offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		# Decay the shake amount (using time scale independent delta so it decays smoothly during slow-mo)
		shake_amount -= shake_decay * (delta / Engine.time_scale)
		if shake_amount <= 0.0:
			offset = Vector2.ZERO

func trigger_zoom() -> void:
	# Cancel previous zoom if running
	if zoom_tween and zoom_tween.is_running():
		zoom_tween.kill()
		
	zoom_tween = create_tween()
	# Smoothly zoom in close to the action (1.6)
	zoom_tween.tween_property(self, "zoom", Vector2(1.6, 1.6), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Wait at zoom level
	zoom_tween.tween_interval(1.5)
	# Smoothly zoom back out to normal (1.25)
	zoom_tween.tween_property(self, "zoom", Vector2(1.25, 1.25), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func trigger_shake(amount: float = 10.0, decay: float = 5.0) -> void:
	shake_amount = amount
	shake_decay = decay
