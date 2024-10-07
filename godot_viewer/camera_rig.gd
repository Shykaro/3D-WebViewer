extends Node3D

@export var rotation_speed = 180
@export var camera_distance = 4  # Startabstand der Kamera
@export var zoom_speed = 0.5  # Wie schnell die Zoom-Geschwindigkeit ist
@export var min_zoom = 1  # Minimaler Zoom-Wert (nah)
@export var max_zoom = 10  # Maximaler Zoom-Wert (weit)

var rot_y = 0
var rot_x = 0

func _ready():
	pass

func _input(event):
	# Überprüfe, ob das Mausrad nach oben oder unten bewegt wurde
	if event.is_action_pressed("zoom_in"):
		camera_distance -= zoom_speed
		#print("Zoom in detected")
	elif event.is_action_pressed("zoom_out"):
		camera_distance += zoom_speed
		#print("Zoom out detected")
		
	# Begrenze den Zoom auf die min und max Werte
	camera_distance = clamp(camera_distance, min_zoom, max_zoom)
	$camera_arm/camera.position.z = camera_distance

# Wird in jedem Frame aufgerufen
func _process(delta):
	
	# Rotation um das Modell
	var lr_axis = -Input.get_axis("turntable_left", "turntable_right")
	if lr_axis != 0:
		rot_y = rotation_speed * lr_axis * delta * PI / 180
	
	var ud_axis = Input.get_axis("turntable_down", "turntable_up")
	if ud_axis != 0:
		rot_x = rotation_speed * ud_axis * delta * PI / 180
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mouse_vel = Input.get_last_mouse_velocity()
		rot_y = rotation_speed * (-mouse_vel.x / 400) * delta * PI / 180
		rot_x = rotation_speed * (-mouse_vel.y / 800) * delta * PI / 180

	rotate_y(rot_y)
	$camera_arm.rotate_x(rot_x)

	rot_y *= 0.965
	rot_x *= 0.965
