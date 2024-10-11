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
		var current_node = result.collider
		while current_node:
			# Falls wir den MeshNode (z.B. Cube) finden, verarbeiten wir diesen
			if current_node is MeshInstance3D:
				# Falls `selected_part` noch nicht gesetzt ist (erste Auswahl)
				if not selected_part:
					selected_part = current_node
					_enter_sub_mode(selected_part)
				# Überprüfe, ob das getroffene Objekt ein direkter Nachkomme des aktuellen `selected_part` ist
				elif _is_direct_child(selected_part, current_node):
					selected_part = current_node  # Setze das getroffene Child als neues `selected_part`
					_enter_sub_mode(selected_part)  # Fokussiere auf dieses Teil
				else:
					# Ein nicht verwandtes Objekt getroffen: Zum Parent wechseln
					_select_parent()
				return  # Abbruch nach dem Setzen der Auswahl

			current_node = current_node.get_parent()

	# Falls nichts getroffen wurde, ebenfalls zum Parent wechseln
	_select_parent()

# Funktion zum Wechsel in den Parent-Node
func _select_parent():
	# Wenn `selected_part` existiert und einen Parent hat, wechseln wir dorthin
	if selected_part and selected_part.get_parent() is MeshInstance3D:
		selected_part = selected_part.get_parent()
		_enter_sub_mode(selected_part)
	else:
		# Höchste Ebene erreicht: Sichtbarkeit aller Teile wiederherstellen und Zoom zurücksetzen
		$turntable.reset_focus()
		selected_part = null  # Setze `selected_part` zurück
		reset_model_visibility()
		_reset_camera_zoom()

# Funktion zum Wechsel in den Sub-Modus
func _enter_sub_mode(part: Node):
	$turntable.set_focus_on_object(part)

	# Verwende die neue AABB-Funktion für das Child-Objekt
	var current_model_max_size = $turntable.calculate_max_width_from_vertices(part)
	if current_model_max_size > 0.0:
		# Setze den Mindestzoom und den Startzoom auf Basis der neuen Breite
		$camera_rig.min_zoom = current_model_max_size * 1.05  # Minimaler Zoom 5% über der größten Modellachse
		$camera_rig.camera_distance = max(current_model_max_size * 1.05, $camera_rig.camera_distance) # Camera distance beibehalten oder minimum nehmen
		$camera_rig.max_zoom = $camera_rig.min_zoom * 5  # Maximaler Zoom ist ein Vielfaches davon
		$camera_rig._handle_zoom()  # Update den Zoom

	# Durchlaufe alle Haupt-Nodes und passe die Materialien an
	for child in model_container.get_child(0).get_child(0).get_children():
		if child is Node3D:
			if child != part:
				# Mache alle anderen Objekte transparent
				make_part_transparent(child)
			else:
				# Aktuell ausgewähltes Teil bleibt unverändert
				pass

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
