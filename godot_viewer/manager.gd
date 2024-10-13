extends Node3D

@onready var camera: Camera3D = $camera_rig/camera_arm/camera
@onready var model_container: Node3D = $turntable/model_container
@export var selection_distance = 1000.0  # Maximale Distanz für die Selektion
@export var double_click_time = 0.3  # Maximale Zeit zwischen zwei Klicks für einen Doppelklick (in Sekunden)

var selected_part = null  # Speichert den aktuell ausgewählten Teil
var last_click_time = 0  # Zeit des letzten Klicks

# Funktion zum Aufruf des Traverse-Prozesses beim Start
func _ready():
	# Starte die Traversierung von der höchsten Ebene
	find_all_meshes_in_node(model_container)

# Funktion zur dynamischen Erkennung von MeshInstance3D-Knoten
func find_all_meshes_in_node(node: Node) -> Array:
	var meshes = []
	for child in node.get_children():
		if child is MeshInstance3D:
			meshes.append(child)
		elif child.get_child_count() > 0:
			# Rekursiv durchlaufen, um alle Child-Meshes zu finden
			meshes.append_array(find_all_meshes_in_node(child))  # Verwende append_array anstatt extend
	return meshes


# Funktion zur Verarbeitung der Eingaben
func _input(event):
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		var current_time = Time.get_ticks_msec() / 1000.0  # Zeit in Sekunden

		# Überprüfen, ob der letzte Klick innerhalb der Doppelklick-Zeitspanne liegt
		if current_time - last_click_time <= double_click_time:
			_select_model_part()
		last_click_time = current_time

# Funktion zur Auswahl des Modellteils bei Doppelklick
# Funktion zur Auswahl des Modellteils bei Doppelklick (dynamisch für verschiedene Modelle)
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
		var current_node = result.collider
		while current_node:
			if current_node is MeshInstance3D:
				if not selected_part:
					selected_part = current_node
					_enter_sub_mode(selected_part)
				elif _is_direct_child(selected_part, current_node):
					selected_part = current_node
					_enter_sub_mode(selected_part)
				else:
					_select_parent()
				return
			current_node = current_node.get_parent()
	_select_parent()

func _select_parent():
	if selected_part and selected_part.get_parent() is MeshInstance3D:
		selected_part = selected_part.get_parent()
		_enter_sub_mode(selected_part)
	else:
		# Setze den Pivot zurück auf den ursprünglichen Pivot-Punkt des gesamten Modells
		$turntable.reset_focus_with_animation()
		selected_part = null
		reset_model_visibility()
		_reset_camera_zoom()


# Funktion zum Wechsel in den Sub-Modus
func _enter_sub_mode(part: Node):
	$turntable.set_focus_on_object(part)  # Starte die Animation zur neuen Position

	# Verwende die neue AABB-Funktion für das Child-Objekt
	var current_model_max_size = $turntable.calculate_max_width_from_vertices(part)
	if current_model_max_size > 0.0:
		# Setze den Mindestzoom und den Startzoom auf Basis der neuen Breite
		$camera_rig.min_zoom = current_model_max_size * 1.05  # Minimaler Zoom 5% über der größten Modellachse
		$camera_rig.camera_distance = max(current_model_max_size * 1.05, $camera_rig.camera_distance)  # Camera distance beibehalten oder minimum nehmen
		$camera_rig.max_zoom = $camera_rig.min_zoom * 5  # Maximaler Zoom ist ein Vielfaches davon
		$camera_rig._handle_zoom()  # Update den Zoom
	set_transparency_for_all_meshes_in_node(model_container, part)


# Funktion zum Zurücksetzen des Kamerazooms bei Rückkehr zum Parent oder höchster Ebene
func _reset_camera_zoom():
	var model_size = $camera_rig.calculate_model_dimensions(model_container)
	$camera_rig.min_zoom = model_size * 1.05
	$camera_rig.camera_distance = max(model_size * 1.05, $camera_rig.camera_distance)
	$camera_rig.max_zoom = $camera_rig.min_zoom * 5
	$camera_rig._handle_zoom()

# Funktion zum Einstellen der Transparenz für nicht ausgewählte Teile
func make_part_transparent(part: MeshInstance3D):
	if part.mesh:
		for i in range(part.mesh.get_surface_count()):
			var material = part.get_surface_override_material(i)
			if not material:
				material = part.mesh.surface_get_material(i)
				if material:
					material = material.duplicate()  # Dupliziere das Material, um eine instanzierte Kopie zu haben

			if material:
				material.set_transparency(BaseMaterial3D.TRANSPARENCY_ALPHA)  # Transparenzmodus auf Alpha setzen
				material.alpha_scissor_threshold = 0.0  # Deaktiviere Alpha-Scissor
				material.albedo_color.a = 0.2  # Setze die Albedo-Farbe auf 20% Sichtbarkeit (80% transparent)
				part.set_surface_override_material(i, material)
				
# Dynamisches Setzen der Transparenz für alle Meshes in einem Knoten
func set_transparency_for_all_meshes_in_node(node: Node, except_part: MeshInstance3D):
	var meshes = find_all_meshes_in_node(node)
	for mesh in meshes:
		if mesh != except_part:
			make_part_transparent(mesh)


# Funktion zum vollständigen Zurücksetzen der Sichtbarkeit aller Modellteile
func reset_model_visibility():
	for child in model_container.get_child(0).get_child(0).get_children():
		if child is MeshInstance3D:
			for i in range(child.mesh.get_surface_count()):
				var material = child.get_surface_override_material(i)
				if not material:
					material = child.mesh.surface_get_material(i)
					if material:
						material = material.duplicate()

				if material:
					material.albedo_color.a = 1.0  # Setze den Alpha-Wert auf 100% Sichtbarkeit zurück
					material.set_transparency(BaseMaterial3D.TRANSPARENCY_DISABLED)  # Deaktiviere den Transparenzmodus
					child.set_surface_override_material(i, material)

# Funktion zur Überprüfung, ob `current_node` ein direktes Child von `parent_node` ist
func _is_direct_child(parent_node: Node, current_node: Node) -> bool:
	return current_node.get_parent() == parent_node
