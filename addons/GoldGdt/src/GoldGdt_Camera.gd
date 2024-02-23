@icon("src/gdticon.png")
class_name GoldGdt_Camera extends Node3D

@export_group("Components")
@export var Parameters : PlayerParameters

@export_group("View Interpolation")
@export var target : Node3D ## The node this function mimics the transform of.
var t_prev : Transform3D
var t_curr : Transform3D
var update : bool = false

@export_group("Camera")
@export var camera_arm : SpringArm3D ## SpringArm3D that has it's rotation and extension distance set automatically.
@export var camera_anchor : Node3D ## Camera anchor node that is automatically rotated to compensate for the camera arm rotation.
@export var camera : Node3D ## Camera node that is automatically rotated to compensate for the camera anchor rotation.

func _ready() -> void:
	set_as_top_level(true) # Detach from pawn node.
	# Initialize interpolation transforms.
	global_transform = target.global_transform
	t_prev = target.global_transform
	t_curr = target.global_transform

func _process(delta_) -> void:
	
	_interpolate()
	# Modify camera nodes to conform with Player Parameters.
	# TODO: I have to make this not run every frame, but as far as I can tell, there is negligible impact on performance, so it stays.
	_handle_camera_settings()

func _physics_process(delta_) -> void:
	# Update the transforms.
	_update_target()
	pass

func _update_target() -> void:
	# Update interpolation transforms.
	t_prev = t_curr
	t_curr = target.global_transform

func _interpolate() -> void:
	# Get the interpolation fraction.
	var f := Engine.get_physics_interpolation_fraction()
	
	# Interpolate camera.
	if _should_interpolate():
		for i in range(3):
			global_transform.origin[i] = lerpf(t_prev.origin[i], t_curr.origin[i], f)
		global_rotation = target.global_rotation
	else:
		global_transform = target.global_transform

func _handle_camera_settings() -> void:
	# Check if we are using third person.
	if (Parameters.THIRD_PERSON_CAMERA):
		# If so, rotate camera parts to "move" the camera.
		camera_arm.spring_length = Parameters.ARM_LENGTH
		camera_arm.rotation_degrees = Vector3(Parameters.ARM_OFFSET_DEGREES.x, Parameters.ARM_OFFSET_DEGREES.y, 0)
		camera_anchor.rotation_degrees.x = -Parameters.ARM_OFFSET_DEGREES.x
		camera.rotation_degrees.y = -Parameters.ARM_OFFSET_DEGREES.y
	else:
		# If not, reset.
		camera_arm.spring_length = 0
		camera_arm.rotation_degrees = Vector3.ZERO
		camera_anchor.rotation_degrees.x = 0
		camera.rotation_degrees.y = 0

func _should_interpolate() -> bool:
	# See if the current rendering FPS is eligible for interpolation. 
	# (Eligible is above physics tick-rate or if the modulus of the tick-rate and rendering FPS is not 0)
	return Engine.get_frames_per_second() > Engine.physics_ticks_per_second || (Engine.physics_ticks_per_second % roundi(Engine.get_frames_per_second())) != 0
