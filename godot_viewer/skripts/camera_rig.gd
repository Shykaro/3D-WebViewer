extends Node3D

@export var rotation_speed = 180
@export var zoom_speed = 0.5

var camera_distance = 4
var min_zoom = 2
var max_zoom = 100

@onready var model_container = $"../turntable/VignetteSubViewport/model_container"
@onready var turntable = $"../turntable"

var rot_y = 0
var rot_x = 0

# Initiales Setup der Kamera
func _ready():
	if model_container == null:
		print("Fehler: 'model_container' konnte nicht gefunden werden.")
		return

	# Gesamtabmessungen des Modells berechnen
	var global_aabb = calculate_global_aabb(model_container.get_child(0))
	print("Global AABB: ", global_aabb)
	var dimensions = global_aabb.size
	print("Model dimensions (Width, Height, Depth): ", dimensions)

	# Kamerawerte berechnen
	var fov = deg_to_rad($camera_arm/camera.fov)
	var aspect_ratio = $camera_arm/camera.get_viewport().size.x / $camera_arm/camera.get_viewport().size.y

	# Berechne die Distanz basierend auf Höhe und Breite
	var camera_distance = calculate_camera_distance(dimensions, fov, aspect_ratio)
	min_zoom = camera_distance * 0.8
	max_zoom = camera_distance * 3.0

	_handle_zoom()

# Berechne die Kameradistanz
func calculate_camera_distance(dimensions: Vector3, fov: float, aspect_ratio: float) -> float:
	var height = dimensions.y
	var width = dimensions.x

	# Passe an, ob Breite oder Höhe dominanter ist
	if width / aspect_ratio > height:
		height = width / aspect_ratio

	return height / (2.0 * tan(fov / 2.0))

# Hauptfunktion zur Berechnung der globalen AABB eines Nodes
func calculate_global_aabb(node: Node) -> AABB:
	var global_aabb = AABB()
	var initialized = false

	# Iteriere durch alle relevanten Knoten
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh:
			# Lokale AABB in globale Koordinaten transformieren
			var local_aabb = child.mesh.get_aabb()
			var global_min = child.global_transform.origin + child.global_transform.basis * local_aabb.position
			var global_max = global_min + child.global_transform.basis * local_aabb.size

			var child_aabb = AABB(global_min, global_max - global_min)

			# Merge mit der aktuellen AABB
			if initialized:
				global_aabb = global_aabb.merge(child_aabb)
			else:
				global_aabb = child_aabb
				initialized = true

		# Rekursiver Aufruf für Unterknoten
		var child_aabb = calculate_global_aabb(child)
		if initialized:
			global_aabb = global_aabb.merge(child_aabb)
		else:
			global_aabb = child_aabb
			initialized = true

	return global_aabb


# Berechnet die Dimensionen (Breite, Höhe, Tiefe) des gesamten Modells
func calculate_model_dimensions(model_node: Node) -> Vector3:
	var aabb = turntable.calc_aabb_simple(model_node)
	print("Calculated model dimensions (Width, Height, Depth): ", aabb.size)
	return aabb.size

# Hauptfunktion zur Berechnung der AABB
func calculate_aabb(node: Node) -> AABB:
	var total_aabb = AABB()
	var initialized = false

	# Starte die rekursive Traversierung
	traverse_aabb(node, total_aabb, initialized)
	return total_aabb

# Rekursive Funktion zur Verarbeitung der Kinder
func traverse_aabb(node: Node, total_aabb: AABB, initialized: bool):
	if node is MeshInstance3D and node.mesh:
		var local_aabb = node.mesh.get_aabb()
		# Transformation des lokalen AABB in den globalen Raum
		var global_corners = []
		for corner in local_aabb.get_corners():
			global_corners.append(node.global_transform.origin + node.global_transform.basis.xform(corner))

		# Berechnung des globalen AABB
		var global_aabb = AABB(global_corners[0], Vector3.ZERO)
		for i in range(1, global_corners.size()):
			global_aabb = global_aabb.merge(AABB(global_corners[i], Vector3.ZERO))

		if initialized:
			total_aabb = total_aabb.merge(global_aabb)
		else:
			total_aabb = global_aabb
			initialized = true

	for child in node.get_children():
		traverse_aabb(child, total_aabb, initialized)

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
