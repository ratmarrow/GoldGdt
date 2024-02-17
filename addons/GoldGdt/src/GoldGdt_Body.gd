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

@export_group("Collision Hull")
var BBOX_STANDING = BoxShape3D.new() # Cached hull for standing.
var BBOX_DUCKING = BoxShape3D.new() # Cached hull for ducking.
var BBOX_STEP = BoxShape3D.new() # Cached hull for step detection.
const TRACE_SKIN_WIDTH : float = 0.12 # How much the player hull should extrude horizontally to meet with stair steps.

@export var player_hull : CollisionShape3D ## Player collision shape/hull, make sure it's a box unless you edit the script to use otherwise!

@export_group("Ducking")
var ducked : bool = false # True if you are fully ducked.
var ducking : bool = false # True if you are currently between ducked and normal standing.

@export var duck_timer : Timer ## Timer used for ducking animation and collision hull swapping. Time is set in [method _duck] to 1 second.

# Initialize collision shapes & detach from Pawn node.
func _ready() -> void:
	# Detach the body from the pawn node.
	set_as_top_level(true)
	
	# Set bounding box dimensions.
	BBOX_STANDING.size = Parameters.HULL_STANDING_BOUNDS
	BBOX_DUCKING.size = Parameters.HULL_DUCKING_BOUNDS
	
	# Set hull and head position to default.
	player_hull.shape = BBOX_STANDING

# Move the body.
func _physics_process(delta) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= Parameters.GRAVITY * delta
	
	# Create inflated collision hull for use in _move_step()
	BBOX_STEP.size = Vector3(player_hull.shape.size.x + TRACE_SKIN_WIDTH, player_hull.shape.size.y, player_hull.shape.size.z + TRACE_SKIN_WIDTH)
	
	# Run body movement and collision logic.
	var collision := move_and_collide(velocity * delta, true, 0.001)
	
	if collision:
		var normal := collision.get_normal()
		if is_on_floor() and normal.y < 0.7:
			_move_step(self, collision)
	
	# Move the body.
	_move_body()

# Hacks move_and_slide() to make slopes behave a little more like GoldSrc.
func _move_body() -> void:
	var collided := move_and_slide()
	if collided and not get_floor_normal():
		var slide_direction := get_last_slide_collision().get_normal()
		velocity = velocity.slide(slide_direction)
		floor_block_on_wall = false 
	else: # Hacky McHack to restore wallstrafing behaviour which doesn't work unless 'floor_block_on_wall' is true
		floor_block_on_wall = true

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
				player_hull.shape = BBOX_DUCKING
				View.offset = Parameters.DUCK_VIEW_OFFSET
				ducked = true
				ducking = false
				
			# Move our character down in order to stop them from "falling" after crouching, but ONLY on the ground.
				if is_on_floor():
					# Get half of standing box height and introduce a little margin to prevent clipping.
					position.y -= crouch_dist - 0.001
			else:
				frac = _spline_fraction(time, 2.5)
				View.offset = ((Parameters.DUCK_VIEW_OFFSET - crouch_dist ) * frac) + (Parameters.VIEW_OFFSET * (1-frac))
	
	# Check for if we are ducking and if we are no longer holding the "pm_duck" input...
	if !duck_on and (ducking or ducked):
		# ... And try to get back up to standing height.
		_unduck()

# Checks to make sure uncrouching won't clip us into a ceiling.
func _unduck() -> void:
	var crouch_dist := Parameters.HULL_DUCKING_BOUNDS.y / 2
	
	if _unduck_trace(position + Vector3.UP * 0.458, BBOX_STANDING, self) == true:
		# If there is a ceiling above the player that would cause us to clip into it when unducking, stay ducking.
		ducked = true
		return
	else: # Otherwise, unduck.
		ducked = false
		ducking = false
		if is_on_floor(): position.y += crouch_dist + 0.001
		player_hull.shape = BBOX_STANDING
		View.offset = Parameters.VIEW_OFFSET

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

# Casts a collision shape trace and stores the collision data.
func _cast_trace(what: CollisionObject3D, shape: Shape3D, from: Vector3, to: Vector3) -> Trace:
		var _collided: bool = false
		var motion := to - from
	
		var params := PhysicsShapeQueryParameters3D.new()
		params.set_shape(shape)
		params.transform.origin = from
		params.collide_with_bodies = true
		params.set_motion(motion)
		params.exclude = [what.get_rid()]
	
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
func _move_step(shape: CollisionObject3D, collision: KinematicCollision3D) -> bool:
	var vel: Vector3 = velocity.normalized() * Parameters.MAX_SPEED if velocity.length_squared() < Parameters.MAX_SPEED * Parameters.MAX_SPEED else velocity

	var collider := collision.get_collider()
	var norm := collision.get_normal()
#
	# shouldn't happen, but
	if !collider || !norm:
		return false

	var original_pos: Vector3 = shape.global_position
	var step_pos: Vector3 = original_pos

	# TODO: add check for sufficiently small actor velocity
	# Step pos x/z should have a minimum offset
	## WAREYA WAS RIGHT ALL ALONG!
	# This hsould be fixed actually, but I'm leaving this funny comment


	# we desire going this far
	step_pos += (vel * Vector3(1, 0, 1)) * get_physics_process_delta_time()
	step_pos.y += 0.457

	# check upwards to see if we can clear the step
	var up : Trace = _cast_trace(self, BBOX_STEP, shape.global_position, shape.global_position + Vector3.UP * 0.457)

	# if the final distance is less, cap the check height to ensure stairs are reversible
	if up.end_pos.y < step_pos.y:
		step_pos.y = up.end_pos.y

	# now cast forwards to see how far the step goes
	var fwd : Trace = _cast_trace(self, BBOX_STEP, up.end_pos, step_pos)

	# from there we either hit something or again went the full distance
	# at the end of that trace, go back down to find the floor
	var _d := Vector3(fwd.end_pos.x, original_pos.y, fwd.end_pos.z)
	var down : Trace = _cast_trace(self, BBOX_STEP, fwd.end_pos, _d)

	if down.end_pos.y > original_pos.y && down.normal.y > 0.7:
		global_position = down.end_pos
		return true

	return false
