extends Node3D

@export var max_player_acceleration = 1.0
@export var friction = 1

var player_acceleration = 0.0
var total_acceleration = 0.0
var speed = 0.0

@onready var handcar := $Path3D/PathFollow3D/HandCar
@onready var path_follow := $Path3D/PathFollow3D

func _ready():
	SignalBus.handcar_signal.connect(increase_acceleration)

func _physics_process(delta):
	# Calculate the total acceleration from all players
	var total_acceleration = handcar.accum_acceleration + player_acceleration
	# Normalize the total acceleration to be in the range [0, 1]
	var normalized_acceleration = total_acceleration / (max_player_acceleration * 4)
	
	# Apply friction to slow down the handcart
	speed = lerp(speed, 0.0, friction * delta)
	# Increase speed based on player acceleration
	speed += normalized_acceleration * max_player_acceleration * delta
	# Update the position of the handcart
	path_follow.progress += speed

	if player_acceleration - 0.1 >= 0:
		player_acceleration -= 0.1
	
func increase_acceleration(direction):
	match direction:
		"scroll_wheel_up":
			if player_acceleration + 0.1 < max_player_acceleration:
				player_acceleration += 0.1
		"scroll_wheel_down":
			if player_acceleration + 0.1 < max_player_acceleration:
				player_acceleration += 0.1
