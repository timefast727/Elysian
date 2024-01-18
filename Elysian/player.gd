extends CharacterBody3D

@export var health: int = 100
@export var sensitivity : float = 0.1
@export var is_riding : bool = false

#mask: what it can collide with
#layer: what can detect it

const JUMP_VELOCITY = 4.5
const DEFAULT_SPEED = 3.5
const SPRINT_SPEED = 6.0
const CROUCH_SPEED = 2.0 #Maybe make lower?
const LERP_SPEED = 20.0
const ITEM_INTERACT_TEXT = 'Pick up: "E"'

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var current_speed = DEFAULT_SPEED
var direction = Vector3.ZERO

var is_walking = true
var is_crouching = false 
var is_sprinting = false

var handcar_node

# Head bob
const head_bobbing_walking_speed = 10.0
const head_bobbing_crouching_speed = 10.0
const head_bobbing_sprinting_speed = 15.0

const head_bobbing_walking_intensity = 0.04
const head_bobbing_crouching_intensity = 0.03
const head_bobbing_sprinting_intensity = 0.06

var head_bobbing_vector = Vector2.ZERO
var head_bobbing_index = 0.0
var head_bobbing_current_intensity = 0.0
var tool_lerp_speed = LERP_SPEED

# Name, mesh, scene
var item_dict = {"RailroadHammer": [preload("res://Items/RailroadHammer/railroad_hammer.obj"), preload("res://Items/RailroadHammer/railroad_hammer.tscn")]}
var item_drop_rot_dict = {"RailroadHammer": Vector3(0, 0, deg_to_rad(90))}

@onready var test_world := $".."
@onready var player := $"."
@onready var neck := $Neck
@onready var head := $Neck/Head
@onready var hand := $Neck/Head/Camera3D/Hand
@onready var current_tool_mesh := $Neck/Head/Camera3D/Hand/CurrentToolMesh
@onready var camera := $Neck/Head/Camera3D
@onready var shapecast := $ShapeCast3D
@onready var raycast := $Neck/Head/Camera3D/RayCast3D
@onready var animation_player := $AnimationPlayer
@onready var standing_collision := $StandingCollisionShape
@onready var crouching_collision := $CrouchingCollisionShape
@onready var drop := $Drop 

#PlayerUI
@onready var interact_label := $PlayerUI/InteractLabel
@onready var crosshair := $PlayerUI/Crosshair

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Camera
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * sensitivity))
		head.rotate_x(deg_to_rad(-event.relative.y * sensitivity))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-75), deg_to_rad(75))
	
	# Sprint
	if Input.is_action_pressed("sprint"):
		if player.is_on_floor():
			if is_crouching == false:
				is_walking = false
				is_sprinting = true
				movement_state_change("sprint")
	elif Input.is_action_just_released("sprint"):
		if is_crouching == false:
			is_sprinting = false
			is_walking = true
			movement_state_change("sprint")
	
	# Crouch
	if Input.is_action_just_pressed("crouch"):
		if player.is_on_floor():
			movement_state_change("crouch")
		
	# Drop item
	if Input.is_action_just_pressed("drop"):
		if player.is_on_floor():
			if current_tool_mesh.current_item_name != "":
				drop_item(current_tool_mesh.current_item_name)
				
	# Change item/Move handcar
	if Input.is_action_just_released("scroll_wheel_up"): #>
		if is_riding == true:
			handcar_move("scroll_wheel_up")
		else:
			pass
	if Input.is_action_just_released("scroll_wheel_down"): #<
		if is_riding == true:
			handcar_move("scroll_wheel_down")
		else:
			pass
	
	if Input.is_action_just_pressed("eject"): #rmb
		if is_riding == true: #riding the handcar
			handcar_eject()
			

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# bunny hopping lol
	if (Input.is_action_just_pressed("ui_accept") or Input.is_action_pressed("ui_accept")) and is_on_floor():
		velocity.y += JUMP_VELOCITY
		
	var input_dir = Input.get_vector("right", "left", "back", "forward")
	direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * LERP_SPEED)
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		
	# Head bob
	if is_walking:
		head_bobbing_current_intensity = head_bobbing_walking_intensity
		head_bobbing_index += head_bobbing_walking_speed * delta
	elif is_crouching:
		head_bobbing_current_intensity = head_bobbing_crouching_intensity
		head_bobbing_index += head_bobbing_crouching_speed * delta
	elif is_sprinting:
		head_bobbing_current_intensity = head_bobbing_sprinting_intensity
		head_bobbing_index += head_bobbing_sprinting_speed * delta
		
	if is_on_floor() && input_dir != Vector2.ZERO:
		head_bobbing_vector.y = sin(head_bobbing_index)
		head_bobbing_vector.x = sin(head_bobbing_index / 2) + 0.5
		
		if is_crouching:
			if tool_lerp_speed == LERP_SPEED:
				tool_lerp_speed *= 0.5
		else:
			tool_lerp_speed = LERP_SPEED
		
		if current_tool_mesh.mesh:
			hand.position.y = lerp(hand.position.y, (head_bobbing_vector.y * (head_bobbing_current_intensity / 2.0)) + hand.idle_position.y, delta * (tool_lerp_speed/4))
			hand.position.x = lerp(hand.position.x, (head_bobbing_vector.x * head_bobbing_current_intensity) + hand.idle_position.x, delta * (tool_lerp_speed/4))
		
		head.position.y = lerp(head.position.y, (head_bobbing_vector.y * (head_bobbing_current_intensity / 2.0)), delta * (LERP_SPEED/4))
		head.position.x = lerp(head.position.x, (head_bobbing_vector.x * head_bobbing_current_intensity), delta * (LERP_SPEED/4))
	else:
		if current_tool_mesh.mesh:
			hand.position.y = lerp(hand.position.y, hand.idle_position.y, delta * (LERP_SPEED/4))
			hand.position.x = lerp(hand.position.x, hand.idle_position.x, delta * (LERP_SPEED/4))
		
		head.position.y = lerp(head.position.y, 0.0, delta * (LERP_SPEED/4))
		head.position.x = lerp(head.position.x, 0.0, delta * (LERP_SPEED/4))
		
	# Collided
	if raycast.is_colliding() && raycast.get_collider() && raycast.get_collider().is_in_group("interactable"):
		on_raycast_collided(raycast.get_collider())
	else:
		crosshair.visible = false
		if is_riding == false:
			interact_label.visible = false
	
	move_and_slide()

func movement_state_change(_stateType: String):
	match _stateType:
		"sprint":
			if is_sprinting == true:
				if Input.is_action_just_pressed("sprint"):
					animation_player.play("sprint")
				current_speed = SPRINT_SPEED
			else:
				animation_player.play_backwards("sprint")
				current_speed = DEFAULT_SPEED
		"crouch":
			if is_sprinting == true:
				is_sprinting = false
			if is_crouching == false:
				is_walking = false
				is_crouching = true
				current_speed = CROUCH_SPEED
				animation_player.play("crouch")
				standing_collision.disabled = true
				crouching_collision.disabled = false
			else:
				if not shapecast.is_colliding():
					is_crouching = false
					is_walking = true
					current_speed = DEFAULT_SPEED
					animation_player.play_backwards("crouch")
					crouching_collision.disabled = true
					standing_collision.disabled = false
					
func on_raycast_collided(collider):
	if not collider:
		return
	else:
		if collider.is_in_group("item"):
			var collided_item = collider.get_parent() # Gets node instead of rigid body
			var mesh_ref
			crosshair.visible = true
			interact_label.text = ITEM_INTERACT_TEXT
			interact_label.visible = true
			if Input.is_action_just_pressed("interact"):
				if hand.current_tool_mesh.mesh != item_dict[collided_item.name][0]: # Hand already holding something
					current_tool_mesh.current_item_name = collided_item.name
					mesh_ref = item_dict[collided_item.name][0]
					current_tool_mesh.mesh = mesh_ref
					collided_item.queue_free()
		else:
			#other stuff not sure yet
			match collider.owner.name:
				"Door":
					is_door_collided(collider)
				"HandCar": #make Handcar
					is_handcar_collided(collider)
				"Lever":
					is_lever_collided(collider)
					
func is_door_collided(_collider):
	var door = _collider.owner
	var animation_player_collider = door.find_child("AnimationPlayer")
	
	crosshair.visible = true
	if door.is_open == false:
		interact_label.text = door.interact_text_open
		interact_label.visible = true
		if Input.is_action_just_pressed("interact"):
			door.is_open = true
			animation_player_collider.play("door_open")
	else:
		interact_label.text = door.interact_text_closed
		if Input.is_action_just_pressed("interact"):
			door.is_open = false
			animation_player_collider.play_backwards("door_open")
	
func is_handcar_collided(_collider):
	var handcar = _collider.owner
	handcar_node = handcar
	
	if is_riding == false:
		crosshair.visible = true
		interact_label.text = handcar.interact_text
		interact_label.visible = true
		if Input.is_action_just_pressed("interact"):
			is_riding = true
			crosshair.visible = false
	else:
		interact_label.text = handcar.eject_text
		
func is_lever_collided(_collider):
	var lever = _collider.owner
	var animation_player_collider = lever.find_child("AnimationPlayer")
	
	interact_label.text = lever.interact_text
	interact_label.visible = true
	if Input.is_action_just_pressed("interact"):
		if lever.handcar_direction == true: #forward
			lever.handcar_direction = false
			animation_player_collider.play("lever_back")
		else: #back
			lever.handcar_direction = true
			animation_player_collider.play_backwards("lever_back")
	
func handcar_eject():
	is_riding = false
	interact_label.visible = false
	
func handcar_move(scroll_direction):
	match scroll_direction:
		"scroll_wheel_up": #forward
			SignalBus.handcar_signal.emit(scroll_direction)
		"scroll_wheel_down": #back
			SignalBus.handcar_signal.emit(scroll_direction)

func drop_item(_name: String):
	var scene_ref = item_dict[_name][1].instantiate()
	current_tool_mesh.mesh = null
	if is_crouching == true:
		scene_ref.position = (drop.global_position - Vector3(0, 0.5, 0))
	else:
		scene_ref.position = drop.global_position
		
	scene_ref.rotation = item_drop_rot_dict[_name] + player.rotation
	test_world.add_child(scene_ref)
	current_tool_mesh.current_item_name = ""
	current_tool_mesh.mesh = null
