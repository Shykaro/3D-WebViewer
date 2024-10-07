extends Node3D

@onready var camera: Camera3D = $camera_rig/camera_arm/camera
@onready var model_container: Node3D = $turntable/model_container
@export var selection_distance = 1000.0  # Maximale Distanz für die Selektion
@export var double_click_time = 0.3  # Maximale Zeit zwischen zwei Klicks für einen Doppelklick (in Sekunden)

var selected_part = null  # Speichert den aktuell ausgewählten Teil
var last_click_time = 0  # Zeit des letzten Klicks

# Funktion zur Verarbeitung der Eingaben
func _input(event):
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		var current_time = Time.get_ticks_msec() / 1000.0  # Zeit in Sekunden

		# Überprüfen, ob der letzte Klick innerhalb der Doppelklick-Zeitspanne liegt
		if current_time - last_click_time <= double_click_time:
			_select_model_part()
			print("double clicked")
		last_click_time = current_time

# Funktion zur Auswahl des Modellteils bei Doppelklick
func _select_model_part():
	# Erstelle einen Raycast von der Kamera zur Mausposition
	var from = camera.project_ray_origin(get_viewport().get_mouse_position())
	var to = from + camera.project_ray_normal(get_viewport().get_mouse_position()) * selection_distance
	
	var ray_query = PhysicsRayQueryParameters3D.new()
	ray_query.from = from
	ray_query.to = to

	var space_state = get_world_3d().direct_space_state
	var result = space_state.intersect_ray(ray_query)

	# Überprüfe, ob der Raycast ein Objekt trifft
	if result and result.collider:
		print("Raycast getroffen: ", result.collider.name)

		# Finde den übergeordneten MeshInstance3D
		var current_node = result.collider
		while current_node:
			print("Übergeordneter Node: ", current_node.name)
			
			# Falls wir den MeshNode (z.B. Cube) finden, verarbeiten wir diesen
			if current_node is MeshInstance3D:
				selected_part = current_node
				print("MeshInstance3D für die Verarbeitung gefunden: ", selected_part.name)
				break  # Abbrechen, wenn das Mesh gefunden wurde

			current_node = current_node.get_parent()

		# Falls wir das Mesh gefunden haben, wechsle in den Sub-Modus
		if selected_part:
			_enter_sub_mode(selected_part)

# Funktion zum Wechsel in den Sub-Modus
func _enter_sub_mode(part: MeshInstance3D):
	print("Sub-Modus betreten mit Teil: ", part.name)
	# Durchlaufe nur die MeshInstance3D-Knoten unter dem model_container
	for child in model_container.get_child(0).get_child(0).get_children():
		#print(child)
		if child is MeshInstance3D:
			if child != part:
				#print("Blende aus: ", child.name)  # Debugging-Ausgabe
				child.visible = false
			else:
				#print("Zeige an: ", child.name)  # Debugging-Ausgabe
				child.visible = true
