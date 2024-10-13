extends Node3D

@export var rotation_speed = 180
@export var zoom_speed = 0.5  # Wie schnell die Zoom-Geschwindigkeit ist
var camera_distance = 4  # Startabstand der Kamera (dynamisch angepasst)
var min_zoom = 2  # Minimaler Zoom-Wert (dynamisch angepasst)
var max_zoom = 50  # Maximaler Zoom-Wert (für weit entferntes Zoomen)
var model_aabb = AABB()  # Speichert die AABB des Modells

@onready var model_container = $"../turntable/model_container" # Warten, bis der Knoten bereit ist
@onready var turntable = $"../turntable" # Warten, bis der Knoten bereit ist

var rot_y = 0
var rot_x = 0

# Funktion zur Berechnung der längsten Breite (größte Achse) des Modells
func calculate_model_dimensions(model_node: Node) -> float:
	var aabb = turntable.calc_aabb_simple(model_node)  # Verwende die Funktion aus dem Turntable
	var max_size = aabb.size[aabb.get_longest_axis_index()]  # Größte Breite (längste Achse)
	return max_size

func _handle_zoom():
	camera_distance = clamp(camera_distance, min_zoom, max_zoom)
	$camera_arm/camera.position.z = camera_distance


# Eingabeverarbeitung für Zoom und Mausrotation
func _input(event):
	# Zoom über das Mausrad
	if event.is_action_pressed("zoom_in"):
		camera_distance -= zoom_speed  # Näher heranzoomen
	elif event.is_action_pressed("zoom_out"):
		camera_distance += zoom_speed  # Weiter herauszoomen
	
	_handle_zoom()

# Rotation und Kamerabewegung in jedem Frame
func _process(delta):
	# Rotation um das Modell mit den festgelegten Tasten
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

	# Verlangsamt die Rotation, um ein sanfteres Gefühl zu geben
	rot_y *= 0.965
	rot_x *= 0.965

func _ready():
	if model_container == null:
		print("Fehler: 'model_container' konnte nicht gefunden werden.")
		return

	var model_size = calculate_model_dimensions(model_container)
	min_zoom = model_size * 1.05
	camera_distance = min_zoom * 2.5
	max_zoom = min_zoom * 5

	_handle_zoom()
