extends Node3D

var mouse_mov_horizontal
var mouse_mov_vertical
var sway_threshold = 1
var sway_lerp = 2

@export var sway_left: Vector3
@export var sway_right: Vector3
@export var sway_up: Vector3
@export var sway_down: Vector3
@export var sway_normal: Vector3
@export var idle_position: Vector3 = Vector3(position.x, position.y, position.z)

@onready var player := $"../../../.."
@onready var current_tool_mesh := $CurrentToolMesh

# Called when the node enters the scene tree for the first time.
func _input(event):
	if event is InputEventMouseMotion:
		mouse_mov_horizontal = -event.relative.x
		mouse_mov_vertical = -event.relative.y

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if not current_tool_mesh.mesh:
		return
	if mouse_mov_horizontal != null:
		if mouse_mov_horizontal > sway_threshold:
			rotation = rotation.lerp(sway_left, delta * sway_lerp)
		elif mouse_mov_horizontal < -sway_threshold:
			rotation = rotation.lerp(sway_right, delta * sway_lerp)
		else:
			rotation = rotation.lerp(sway_normal, delta * sway_lerp)
	
	if mouse_mov_vertical != null:
		if mouse_mov_vertical > sway_threshold:
			rotation = rotation.lerp(sway_up, delta * sway_lerp)
		elif mouse_mov_vertical < -sway_threshold:
			rotation = rotation.lerp(sway_down, delta * sway_lerp)
		else:
			rotation = rotation.lerp(sway_normal, delta * sway_lerp)
			
