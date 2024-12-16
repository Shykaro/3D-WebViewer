extends Node3D

@export var rotation_speed = 180
@export var zoom_speed = 0.5
@export var explosion_trigger_speed = 0.2
@export var explosion_cooldown = 0.7

var camera_distance = 4
var min_zoom = 2
var max_zoom = 100
var last_explosion_time = 0.0

@onready var model_container = $"../turntable/VignetteSubViewport/model_container"
@onready var turntable = $"../turntable"

var rot_y = 0
var rot_x = 0
var current_rotation_speed = 0.0

# Berechnung der längsten Breite des Modells
func calculate_model_dimensions(model_node: Node) -> float:
	var aabb = turntable.calc_aabb_simple(model_node)
	return aabb.size[aabb.get_longest_axis_index()]

# Eingabeverarbeitung für Zoom und Mausrotation
func _input(event):
	if event.is_action_pressed("zoom_in"):
		camera_distance -= zoom_speed
	elif event.is_action_pressed("zoom_out"):
		camera_distance += zoom_speed
	_handle_zoom()

# Zoom anpassen
func _handle_zoom():
	camera_distance = clamp(camera_distance, min_zoom, max_zoom)
	$camera_arm/camera.position.z = camera_distance

# Rotation und Kamerabewegung in jedem Frame
func _process(delta):
	var lr_axis = -Input.get_axis("turntable_left", "turntable_right")
	if lr_axis != 0:
		rot_y = rotation_speed * lr_axis * delta * PI / 180

	var ud_axis = Input.get_axis("turntable_down", "turntable_up")
	if ud_axis != 0:
		rot_x = rotation_speed * ud_axis * delta * PI / 180

	# Mausbewegung für Rotation
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mouse_vel = Input.get_last_mouse_velocity()
		rot_y = rotation_speed * (-mouse_vel.x / 400) * delta * PI / 180
		rot_x = rotation_speed * (-mouse_vel.y / 800) * delta * PI / 180

	rotate_y(rot_y)
	$camera_arm.rotate_x(rot_x)

	# Verlangsamung der Rotation für ein sanfteres Gefühl
	rot_y *= 0.965
	rot_x *= 0.965

	## Berechne die Rotationsgeschwindigkeit und trigger Explosion bei Schwellenwert
	#current_rotation_speed = abs(rot_y) + abs(rot_x)
	#if current_rotation_speed > explosion_trigger_speed and (Time.get_ticks_msec() / 1000.0 - last_explosion_time) > explosion_cooldown:
		#print("Explosion View Triggered!")
		#if !turntable.is_in_explosion_view:
			#turntable.start_explosion()
		#else: 
			#turntable.start_implosion()
		#last_explosion_time = Time.get_ticks_msec() / 1000.0
		##print(Time.get_ticks_msec() / 1500.0)

# Initiales Setup der Kamera
func _ready():
	if model_container == null:
		print("Fehler: 'model_container' konnte nicht gefunden werden.")
		return

	var model_size = calculate_model_dimensions(model_container.get_child(0))
	min_zoom = model_size * 1.05
	camera_distance = min_zoom * 2.5
	max_zoom = min_zoom * 5

	_handle_zoom()
