@icon("src/gdticon.png")
class_name GoldGdt_Controls extends Node

@export_group("Components")
@export var Parameters : PlayerParameters
@export var Body : GoldGdt_Body
@export var Move : GoldGdt_Move
@export var View : GoldGdt_View

# Inputs
var movement_input : Vector2
var mouse_input : Vector2
var move_dir : Vector3
var jump_on : bool
var duck_on : bool

func _ready() -> void:
	Input.set_use_accumulated_input(false) # Disable accumulated input for precise inputs.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # Capture the mouse.

func _input(event) -> void:
	
	#---------------------
	# Replace with your own implementation of MOUSE_MODE switching!!
	#---------------------
	
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if event is InputEventKey:
			if event.is_action_pressed("ui_cancel"):
				get_tree().quit()
		
		if event is InputEventMouseButton:
			if event.button_index == 1:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return
	
	if event is InputEventKey:
		if event.is_action_pressed("ui_cancel"):
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			# Grab the event data and process it.
			_gather_mouse_input(event) 

func _process(delta) -> void:
	# Reset mouse input to avoid drift.
	mouse_input = Vector2.ZERO

func _physics_process(delta) -> void:
	_gather_input()
	_act_on_input()

func _gather_mouse_input(event: InputEventMouseMotion) -> void:
	# Deform the mouse input to make it viewport size independent.
	var viewport_transform := get_tree().root.get_final_transform()
	mouse_input += event.xformed_by(viewport_transform).relative
	
	var degrees_per_unit : float = 0.0001
	
	# Modify mouse input based on sensitivity and granularity.
	mouse_input *= Parameters.MOUSE_SENSITIVITY
	mouse_input *= degrees_per_unit
	
	# Send it off to the View Control component.
	View._handle_camera_input(mouse_input)

func _gather_input() -> void:
	# Get input strength on the horizontal axes.
	var ix = Input.get_action_raw_strength("pm_moveright") - Input.get_action_raw_strength("pm_moveleft")
	var iy = Input.get_action_raw_strength("pm_movebackward") - Input.get_action_raw_strength("pm_moveforward")
	
	# Collect input.
	movement_input = Vector2(ix, iy).normalized()
	
	# Gather the horizontal speeds.
	var speeds := Vector2(Parameters.SIDE_SPEED, Parameters.FORWARD_SPEED)
	
	# Clamp down the horizontal speeds to MAX_SPEED.
	for i in range(2):
		if speeds[i] > Parameters.MAX_SPEED:
			speeds[i] *= Parameters.MAX_SPEED / speeds[i]
	
	# Create vector that stores speed and direction.
	move_dir = Vector3(movement_input.x * speeds.x, 0, movement_input.y * speeds.y).rotated(Vector3.UP, View.horizontal_view.rotation.y)
	
	# Bring down the move direction to a third of it's speed.
	if Body.ducked:
		move_dir *= Parameters.DUCKING_SPEED_MULTIPLIER
	
	# Clamp desired speed to max speed
	if (move_dir.length() > Parameters.MAX_SPEED):
		move_dir *= Parameters.MAX_SPEED / move_dir.length()
	
	# Gather jumping and crouching input.
	jump_on = Input.is_action_pressed("pm_jump") if Parameters.AUTOHOP else Input.is_action_just_pressed("pm_jump")
	duck_on = Input.is_action_pressed("pm_duck")

func _act_on_input() -> void:
	var delta = get_physics_process_delta_time()
	
	Body._duck(duck_on)
	
	# Check if we are on ground
	if Body.is_on_floor():
		if jump_on:
			# Not running friction on ground if you press jump fast enough allows you to preserve all speed.
			Move._jump(delta)
			# NOTE: This is sort of a band-aid to make bunny-hopping on walkable slopes feel a lot nicer.
			Move._airaccelerate(delta, move_dir.normalized(), move_dir.length(), Parameters.AIR_ACCELERATION)
		else:
			Move._friction(delta, 1.0)
			Move._accelerate(delta, move_dir.normalized(), move_dir.length(), Parameters.ACCELERATION)
	else: 
		Move._airaccelerate(delta, move_dir.normalized(), move_dir.length(), Parameters.AIR_ACCELERATION)
