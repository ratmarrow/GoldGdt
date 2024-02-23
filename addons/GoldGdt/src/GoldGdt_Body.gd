	# The trace class, the tracing function, and the stair detection function were created by Btan2, and expanded upon by Sinewave,
	# with ***slight*** modification by me (ratmarrow) to make it play nice with move_and_slide().
	#
	# You can find the repositories here:
	# Godot-Math-Lib (Sinewave): https://github.com/sinewavey/Godot-Math-Lib/tree/main
	# Q_Move (Btan2): https://github.com/Btan2/Q_Move/tree/main

@icon("src/gdticon.png")
class_name GoldGdt_Body extends CharacterBody3D

@export_group("Components")
@export var Parameters : PlayerParameters
@export var View : GoldGdt_View

@export_group("Player View")
var offset : float = 0.711 # Current offset from player's origin.

@export_group("Collision")
var BBOX_STANDING = BoxShape3D.new() # Cached hull for standing.
var BBOX_DUCKING = BoxShape3D.new() # Cached hull for ducking.
var BBOX_STEP = BoxShape3D.new() # Cached hull for step detection.
var BBOX_NEAR_WALL = BoxShape3D.new() # Cached hull for nearby wall detection.
var BBOX_INTO_WALL = BoxShape3D.new() # Cached hull for wall collision.

@export var MIN_TRACE_MARGIN_AMOUNT : float = -0.065 ## How much the step detection shape should shrink on the X and Z axes.
@export var MAX_TRACE_MARGIN_AMOUNT : float = 0.1 ## How much the step detection shape should shrink on the X and Z axes.
var trace_margin : float = 0.0
var trace_dir_add : float = 1.0
var wall_normal : Vector3 = Vector3.ZERO

@export var collision_hull : CollisionShape3D ## Player collision shape/hull, make sure it's a box unless you edit the script to use otherwise!

@export_group("Ducking")
@export var duck_timer : Timer ## Timer used for ducking animation and collision hull swapping. Time is set in [method _duck] to 1 second.
var ducked : bool = false # True if you are fully ducked.
var ducking : bool = false # True if you are currently between ducked and normal standing.

# Identifier for wall proximity.
enum WallCollision {
	NONE,
	NEAR,
	ON
}

# Base class for collision shape tracing.
class Trace extends RefCounted:
	var end_pos: Vector3
	var fraction: float
	var normal: Vector3
	var surface_flags: Array
	
	@warning_ignore("shadowed_variable")
	func _init(end_pos: Vector3, fraction: float = 1.0,  normal: Vector3 = Vector3.UP) -> void:
		self.end_pos = end_pos
		self.fraction = fraction
		self.normal = normal
		return

# Initialize collision shapes & detach from Pawn node.
func _ready() -> void:
	# Detach the body from the pawn node.
	set_as_top_level(true)
	
	# Set bounding box dimensions.
	_set_shape_bounds(BBOX_STANDING, Parameters.HULL_STANDING_BOUNDS)
	_set_shape_bounds(BBOX_DUCKING, Parameters.HULL_DUCKING_BOUNDS)
	
	# Set hull and head position to default.
	collision_hull.shape = BBOX_STANDING

func _physics_process(delta) -> void:
	# Position the horizontal_view.
	View.horizontal_view.transform.origin.y = offset
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= Parameters.GRAVITY * delta
	
	
	_handle_step_trace_values()
	
	# Create deformed collision hull for use in _move_step()
	_set_shape_bounds(BBOX_STEP, collision_hull.shape.size + Vector3(trace_margin, 0, trace_margin))
	
	# Run body movement and collision logic.
	_check_for_step()
	_move_body()

# Function for changing shape bounds, only here for when I add collision shape changing.
func _set_shape_bounds(shape: BoxShape3D, size: Vector3) -> void:
	shape.size = size

# Returns what the proximity to a wall is.
func _wall_check() -> WallCollision:
	_set_shape_bounds(BBOX_NEAR_WALL, collision_hull.shape.size + Vector3(0.3, -Parameters.STEP_HEIGHT, 0.25))
	_set_shape_bounds(BBOX_INTO_WALL, collision_hull.shape.size + Vector3(0.05, -Parameters.STEP_HEIGHT, 0.05))
	
	var _near = _cast_static_trace(self, BBOX_NEAR_WALL, global_position + Vector3.UP * (Parameters.STEP_HEIGHT / 2))
	var _on = _cast_static_trace(self, BBOX_INTO_WALL, global_position + Vector3.UP * (Parameters.STEP_HEIGHT / 2))
	
	if !_near and !_on:
		wall_normal = Vector3.UP
		return WallCollision.NONE
	
	if _on:
		_near = false
		wall_normal = _on.normal
		return WallCollision.ON
	
	if _near:
		wall_normal = _near.normal
		return WallCollision.NEAR
	
	
	return WallCollision.NONE

# Use a test move_and_collide to check if we should try stepping up something.
func _check_for_step() -> void:
	var delta := get_physics_process_delta_time()
	
	var collision := move_and_collide(velocity * delta, true, 0.001)

	if collision:
		var normal := collision.get_normal()
		
		if is_on_floor() and normal.y < 0.7:
			_move_step(normal)

# Deforms step trace info based on wall proximity
func _handle_step_trace_values() -> void:
	# FIXME: I am so, so, so, so, so sorry about the magic numbers.
	
	match _wall_check():
		WallCollision.NONE:
			trace_dir_add = 1.0
			trace_margin = MAX_TRACE_MARGIN_AMOUNT
		WallCollision.NEAR:
			trace_dir_add = 1.05
			trace_margin = 0.05
		WallCollision.ON:
			trace_dir_add = 1.45
			trace_margin = MIN_TRACE_MARGIN_AMOUNT

# Hacks move_and_slide() to make slopes behave a little more like GoldSrc.
func _move_body() -> void:
	var collided := move_and_slide()
	if collided and not get_floor_normal():
		var slide_direction := get_last_slide_collision().get_normal()
		velocity = velocity.slide(slide_direction)
		floor_block_on_wall = false
	else: # Hacky McHack to restore wallstrafing behaviour which doesn't work unless 'floor_block_on_wall' is true
		floor_block_on_wall = true
	
	floor_stop_on_slope = false if velocity.length() > 0.001 else true

# Handles crouching logic.
func _duck(duck_on: bool) -> void:
	var time : float
	var frac : float
	var crouch_dist := Parameters.HULL_DUCKING_BOUNDS.y / 2
	
	# If we aren't ducking, but are holding the "pm_duck" input...
	if duck_on:
		if !ducked and !ducking:
			ducking = true
			duck_timer.start(1.0)
		
		time = max(0, (1.0 - duck_timer.time_left))
		
		if ducking:
			if duck_timer.time_left <= 0.6 or !is_on_floor():
				# Set the collision hull and view offset to the ducking counterpart.
				collision_hull.shape = BBOX_DUCKING
				offset = Parameters.DUCK_VIEW_OFFSET
				ducked = true
				ducking = false
				
			# Move our character down in order to stop them from "falling" after crouching, but ONLY on the ground.
				if is_on_floor():
					# Get half of standing box height and introduce a little margin to prevent clipping.
					position.y -= crouch_dist - 0.001
			else:
				frac = _spline_fraction(time, 2.5)
				offset = ((Parameters.DUCK_VIEW_OFFSET - crouch_dist ) * frac) + (Parameters.VIEW_OFFSET * (1-frac))
	
	# Check for if we are ducking and if we are no longer holding the "pm_duck" input...
	if !duck_on and (ducking or ducked):
		# ... And try to get back up to standing height.
		_unduck()

# Checks to make sure uncrouching won't clip us into a ceiling.
func _unduck() -> void:
	var crouch_dist := Parameters.HULL_DUCKING_BOUNDS.y / 2
	
	if _unduck_trace(position + Vector3.UP * (crouch_dist + 0.005), BBOX_STANDING, self) == true:
		# If there is a ceiling above the player that would cause us to clip into it when unducking, stay ducking.
		ducked = true
		return
	else: # Otherwise, unduck.
		ducked = false
		ducking = false
		if is_on_floor(): position.y += crouch_dist + 0.001
		collision_hull.shape = BBOX_STANDING
		offset = Parameters.VIEW_OFFSET

# Creates a smooth interpolation fraction.
func _spline_fraction(_value: float, _scale: float) -> float:
	var valueSquared : float;

	_value = _scale * _value;
	valueSquared = _value * _value;

	return 3 * valueSquared - 2 * valueSquared * _value;

# Casts the collision shape of the player upwards to check if you will clip into geometry.
func _unduck_trace(origin : Vector3, shape : Shape3D, e) -> bool:
	var params
	var space_state
	
	params = PhysicsShapeQueryParameters3D.new()
	params.set_shape(shape)
	params.transform.origin = origin
	params.collide_with_bodies = true
	params.exclude = [e]
	
	space_state = get_world_3d().direct_space_state
	var results : Array[Vector3] = space_state.collide_shape(params, 8)
	
	return results.size() > 0

# Casts a collision shape trace at a specific position with no motion, then stores relevant collision data.
func _cast_static_trace(what: CollisionObject3D, shape: Shape3D, from: Vector3) -> Trace:
	var _collided: bool = false
	
	var params := PhysicsShapeQueryParameters3D.new()
	params.set_shape(shape)
	params.transform.origin = from
	params.collide_with_bodies = true
	params.exclude = [what.get_rid()]
	
	var space_state := what.get_world_3d().direct_space_state
	var results := space_state.collide_shape(params)
	
	_collided = true
	
	var rest := space_state.get_rest_info(params)
	var norm := rest.get(&"normal", Vector3.UP) as Vector3
	
	return Trace.new(from, 1, norm) if results.size() > 0 else null

# Casts a collision shape trace along a motion defined by a start and end, then stores relevant collision data.
func _cast_trace(what: CollisionObject3D, shape: Shape3D, from: Vector3, to: Vector3) -> Trace:
	var _collided: bool = false
	var motion := to - from
	
	var params := PhysicsShapeQueryParameters3D.new()
	params.set_shape(shape)
	params.transform.origin = from
	params.collide_with_bodies = true
	params.set_motion(motion)
	params.exclude = [what.get_rid()]
		#params.set_collision_mask(1)
	
	var space_state := what.get_world_3d().direct_space_state
	var results := space_state.cast_motion(params)
	
	if results[0] == 1.0:
		_collided = false
		return Trace.new(to)
	
	_collided = true
	
	var end_pos := from + motion * results[1]
	
	params.transform.origin = end_pos
	
	var rest := space_state.get_rest_info(params)
	var norm := rest.get(&"normal", Vector3.UP) as Vector3
	
	return Trace.new(end_pos, results[0], norm)

# Casts traces to detect steps to climb.
func _move_step(normal: Vector3) -> bool:
	var dest  : Vector3
	var down  : Vector3
	var up    : Vector3
	var trace : Trace
	
	# Get destination position that is one step-size above the intended move
	var original_pos = global_transform.origin
	var vel = (velocity.normalized() * trace_dir_add).slide(wall_normal)
	var speed = Parameters.MAX_SPEED * trace_dir_add
	var dir: Vector3 = vel * speed if velocity.length_squared() < speed * speed else (velocity * trace_dir_add).slide(wall_normal)
	
	dest = original_pos
	dest[0] += dir[0] * get_physics_process_delta_time()
	dest[1] += Parameters.STEP_HEIGHT
	dest[2] += dir[2] * get_physics_process_delta_time()
	
	# 1st Trace: Check for collisions one stepsize above the original position
	# and along the intended destination
	trace = _cast_trace(self, BBOX_STEP, original_pos + Vector3.UP * Parameters.STEP_HEIGHT, dest)
	
	# 2nd Trace: Check for collisions below the stepsize until 
	# level with original position
	down = Vector3(trace.end_pos[0], original_pos[1], trace.end_pos[2])
	trace = _cast_trace(self, BBOX_STEP, trace.end_pos, down)
	
	# Move to trace collision position if step is higher than original position 
	# and not steep 
	if trace.end_pos[1] > original_pos[1] and trace.normal[1] >= 0.7:
		global_transform.origin = trace.end_pos
		#velocity = velocity.slide(trace.normal)
		return true
	
	return false
