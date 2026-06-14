extends Control

# joystick.gd — Virtual circular joystick for mobile touch control.
#
# How it works:
#   • _gui_input() catches the initial touch/mouse INSIDE the Control rect.
#   • _input() catches drag/motion events that stray OUTSIDE the rect.
#   • Supports both actual mobile Touch events and Mouse emulation/clicks.
#   • Player reads get_input_vector() every physics frame.

# ── Tunable ──────────────────────────────────────────────────────────────
const OUTER_RADIUS   := 100.0   # px — fixed outer ring (increased for better mobile usability)
const KNOB_RADIUS    := 40.0    # px — movable knob (increased for better mobile usability)
const IDLE_ALPHA     := 0.40    # transparency when idle
const ACTIVE_ALPHA   := 0.85    # transparency while touched
const RETURN_LERP    := 16.0    # knob snap-back speed (higher = snappier)

const COLOR_OUTER_BG     := Color(0.08, 0.45, 0.85, 0.22)
const COLOR_OUTER_BORDER := Color(0.45, 0.88, 1.0,  0.70)
const COLOR_KNOB_FILL    := Color(0.15, 0.65, 1.0,  0.90)
const COLOR_KNOB_BORDER  := Color(1.0,  1.0,  1.0,  0.55)

# ── State ─────────────────────────────────────────────────────────────────
var _touch_index : int     = -1
var _drag        : Vector2 = Vector2.ZERO   # knob offset from center (local px)
var _active      : bool    = false
var _is_mouse    : bool    = false

func _ready() -> void:
	# Enable GUI event processing and ensure processing loops are active
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	set_process_input(true)

# ── Touch & Mouse: initial press must land inside our rect ────────────────
func _gui_input(event: InputEvent) -> void:
	var c := size * 0.5   # center in local coords

	# 1. Screen Touch Input
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			var d: float = event.position.distance_to(c)
			if d <= OUTER_RADIUS + 25.0:
				_touch_index = event.index
				_active      = true
				_is_mouse    = false
				_drag = (event.position - c).limit_length(OUTER_RADIUS)
				modulate.a   = ACTIVE_ALPHA
				queue_redraw()
				accept_event()

		elif not event.pressed and event.index == _touch_index:
			_release()
			accept_event()

	elif event is InputEventScreenDrag and event.index == _touch_index:
		_drag = (event.position - c).limit_length(OUTER_RADIUS)
		queue_redraw()
		accept_event()

	# 2. Mouse Input (for editor testing & desktop support)
	elif event is InputEventMouseButton:
		if event.pressed and _touch_index == -1 and not _active:
			if event.button_index == MOUSE_BUTTON_LEFT:
				var d: float = event.position.distance_to(c)
				if d <= OUTER_RADIUS + 25.0:
					_active      = true
					_is_mouse    = true
					_drag = (event.position - c).limit_length(OUTER_RADIUS)
					modulate.a   = ACTIVE_ALPHA
					queue_redraw()
					accept_event()
		elif not event.pressed and _is_mouse:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_release()
				accept_event()

	elif event is InputEventMouseMotion and _active and _is_mouse:
		_drag = (event.position - c).limit_length(OUTER_RADIUS)
		queue_redraw()
		accept_event()

# ── Drag/Motion that went outside the Control rect ────────────────────────
func _input(event: InputEvent) -> void:
	if not _active:
		return

	# Handle screen touches moving outside the boundary
	if not _is_mouse:
		if event is InputEventScreenTouch and not event.pressed and event.index == _touch_index:
			_release()
			get_viewport().set_input_as_handled()

		elif event is InputEventScreenDrag and event.index == _touch_index:
			var screen_to_local := get_global_transform().affine_inverse()
			var ct := get_canvas_transform()
			var local_pos: Vector2 = screen_to_local * (ct.affine_inverse() * event.position)
			var c := size * 0.5
			_drag = (local_pos - c).limit_length(OUTER_RADIUS)
			queue_redraw()
			get_viewport().set_input_as_handled()

	# Handle mouse drags moving outside the boundary
	else:
		if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_release()
			get_viewport().set_input_as_handled()

		elif event is InputEventMouseMotion:
			var screen_to_local := get_global_transform().affine_inverse()
			var ct := get_canvas_transform()
			var local_pos: Vector2 = screen_to_local * (ct.affine_inverse() * event.position)
			var c := size * 0.5
			_drag = (local_pos - c).limit_length(OUTER_RADIUS)
			queue_redraw()
			get_viewport().set_input_as_handled()

func _release() -> void:
	_touch_index = -1
	_active      = false
	_is_mouse    = false
	_drag        = Vector2.ZERO # Instantly return to center on release
	modulate.a   = IDLE_ALPHA
	queue_redraw()

# ── Knob lerp-back when idle ──────────────────────────────────────────────
func _process(delta: float) -> void:
	# Fallback safety check: if the joystick is active but left click/touch is no longer pressed anywhere, release.
	if _active and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_release()

	if not _active and _drag.length() > 0.5:
		_drag = _drag.lerp(Vector2.ZERO, clamp(RETURN_LERP * delta, 0.0, 1.0))
		queue_redraw()
	elif not _active and _drag.length_squared() > 0.0 and _drag.length() <= 0.5:
		_drag = Vector2.ZERO
		queue_redraw()

# ── Drawing ───────────────────────────────────────────────────────────────
func _draw() -> void:
	var c := size * 0.5

	# Outer ring
	draw_circle(c, OUTER_RADIUS, COLOR_OUTER_BG)
	draw_arc(c, OUTER_RADIUS, 0.0, TAU, 48, COLOR_OUTER_BORDER, 2.5, true)

	# Knob
	var kp := c + _drag
	draw_circle(kp, KNOB_RADIUS, COLOR_KNOB_FILL)
	draw_arc(kp, KNOB_RADIUS, 0.0, TAU, 32, COLOR_KNOB_BORDER, 2.0, true)

# ── Public API ────────────────────────────────────────────────────────────
## Returns a Vector2 scaled by how far the knob is from center [0..1 magnitude].
## Returns Vector2.ZERO when idle.
func get_input_vector() -> Vector2:
	if _drag.length_squared() < 16.0:  # < 4px deadzone
		return Vector2.ZERO
	return _drag / OUTER_RADIUS
