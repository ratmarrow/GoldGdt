@icon("src/gdticon.png")
class_name GoldGdt_Body extends CharacterBody3D

@export_group("Components")
@export var Parameters : PlayerParameters
@export var View : GoldGdt_View

@export_group("Collision Hull")
var BBOX_STANDING = BoxShape3D.new() # Cached BoxShape for standing.
var BBOX_DUCKING = BoxShape3D.new() # Cached BoxShape for ducking.
@export var player_hull : CollisionShape3D ## Player collision shape/hull, make sure it's a box unless you edit the script to use otherwise!

@export_group("Ducking")
@export var duck_timer : Timer ## Timer used for ducking animation and collision hull swapping. Time is set in [method _duck] to 1 second.
var ducked : bool = false 
var ducking : bool = false

# Initialize collision shapes & detach from Pawn node.
func _ready():
	# Detach the body from the pawn node.
	set_as_top_level(true)
	
	# Set bounding box dimensions.
	BBOX_STANDING.size = Parameters.HULL_STANDING_BOUNDS
	BBOX_DUCKING.size = Parameters.HULL_DUCKING_BOUNDS
	
	# Set hull and head position to default.
	player_hull.shape = BBOX_STANDING

# Move the body.
func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= Parameters.GRAVITY * delta
	
	# Run body movement and collision logic.
	_move_body()

# Intercepts CharacterBody3D move_and_slide() to make slopes a little more accurate to GoldSrc.
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
					position.y -= 0.456
			else:
				var fmore = 0.457
					
				frac = _spline_fraction(time, 2.5)
				View.offset = ((Parameters.DUCK_VIEW_OFFSET - fmore ) * frac) + (Parameters.VIEW_OFFSET * (1-frac))
	
	# Check for if we are ducking and if we are no longer holding the "pm_duck" input...
	if !duck_on and (ducking or ducked):
		# ... And try to get back up to standing height.
		_unduck()

# Checks to make sure uncrouching won't clip us into a ceiling.
func _unduck():
	if _unduck_trace(position + Vector3.UP * 0.458, BBOX_STANDING, self) == true:
		# If there is a ceiling above the player that would cause us to clip into it when unducking, stay ducking.
		ducked = true
		return
	else: # Otherwise, unduck.
		ducked = false
		ducking = false
		if is_on_floor(): position.y += 0.458
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
