extends Node3D

@export var interact_text: String = 'Ride: "E"'
@export var eject_text: String = 'Get off: "E"'
@export var lever_text: String = 'Turn lever: "LMB"' #change later idk
@export var handcar_direction: bool = true #true: forward, false: back
@export var accum_acceleration: float = 0

#make a signal to update the handcar direction when its changed in lever scene
