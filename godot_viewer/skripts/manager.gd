extends Node3D

@onready var camera: Camera3D = $camera_rig/camera_arm/camera
@onready var model_container: Node3D = $turntable/VignetteSubViewport/model_container
@export var selection_distance = 1000.0
@export var double_click_time = 0.3

var selected_part = null
var last_click_time = 0

# Starte die Traversierung von der höchsten Ebene
func _ready():
	find_all_meshes_in_node(model_container)

# Dynamische Erkennung von MeshInstance3D-Knoten
func find_all_meshes_in_node(node: Node) -> Array:
	var meshes = []
	for child in node.get_children():
		if child is MeshInstance3D:
			meshes.append(child)
		elif child.get_child_count() > 0:
			meshes.append_array(find_all_meshes_in_node(child))
	return meshes

# Eingabeverarbeitung
func _input(event):
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_click_time <= double_click_time:
			_select_model_part()
		last_click_time = current_time

# Auswahl des Modellteils bei Doppelklick
func _select_model_part():
	var from = camera.project_ray_origin(get_viewport().get_mouse_position())
	var to = from + camera.project_ray_normal(get_viewport().get_mouse_position()) * selection_distance

	var ray_query = PhysicsRayQueryParameters3D.new()
	ray_query.from = from
	ray_query.to = to

	var space_state = get_world_3d().direct_space_state
	var result = space_state.intersect_ray(ray_query)

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

# Zum Parent wechseln
func _select_parent():
	if selected_part and selected_part.get_parent() is MeshInstance3D:
		selected_part = selected_part.get_parent()
		_enter_sub_mode(selected_part)
	else:
		$turntable.reset_focus_with_animation()
		selected_part = null
		reset_model_visibility()
		_reset_camera_zoom()

# Wechsel in den Sub-Modus
func _enter_sub_mode(part: Node):
	$turntable.set_focus_on_object(part)

	var current_model_max_size = $turntable.calculate_max_width_from_vertices(part)
	if current_model_max_size > 0.0:
		$camera_rig.min_zoom = current_model_max_size * 1.05
		$camera_rig.camera_distance = max(current_model_max_size * 1.05, $camera_rig.camera_distance)
		$camera_rig.max_zoom = $camera_rig.min_zoom * 5
		$camera_rig._handle_zoom()

	set_transparency_for_all_meshes_in_node(model_container, part)

# Kamerazoom zurücksetzen
func _reset_camera_zoom():
	var model_size = $camera_rig.calculate_model_dimensions(model_container)
	$camera_rig.min_zoom = model_size * 1.05
	$camera_rig.camera_distance = max(model_size * 1.05, $camera_rig.camera_distance)
	$camera_rig.max_zoom = $camera_rig.min_zoom * 5
	$camera_rig._handle_zoom()

# Transparenz für nicht ausgewählte Teile setzen
func make_part_transparent(part: MeshInstance3D):
	if part.mesh:
		for i in range(part.mesh.get_surface_count()):
			var material = part.get_surface_override_material(i)
			if not material:
				material = part.mesh.surface_get_material(i)
				if material:
					material = material.duplicate()

			if material:
				material.set_transparency(BaseMaterial3D.TRANSPARENCY_ALPHA)
				material.alpha_scissor_threshold = 0.0
				material.albedo_color.a = 0.2
				part.set_surface_override_material(i, material)

# Transparenz dynamisch setzen
func set_transparency_for_all_meshes_in_node(node: Node, except_part: MeshInstance3D):
	var meshes = find_all_meshes_in_node(node)
	for mesh in meshes:
		if mesh != except_part:
			make_part_transparent(mesh)

# Setzt die Sichtbarkeit aller Modellteile zurück
func reset_model_visibility():
	for child in model_container.get_child(0).get_child(0).get_children():
		if child is MeshInstance3D:
			for i in range(child.mesh.get_surface_count()):
				var material = child.get_surface_override_material(i)
				if not material:
					# Verwende surface_get_material statt get_surface_material
					material = child.mesh.surface_get_material(i)
					if material:
						material = material.duplicate()  # Dupliziere das Material, um es zu ändern

				# Wenn ein Material vorhanden ist, stelle es vollständig sichtbar
				if material:
					material.albedo_color.a = 1.0  # Alpha-Wert auf 100% Sichtbarkeit setzen
					material.set_transparency(BaseMaterial3D.TRANSPARENCY_DISABLED)  # Transparenz deaktivieren
					child.set_surface_override_material(i, material)

# Überprüfen, ob current_node ein direktes Child von parent_node ist
func _is_direct_child(parent_node: Node, current_node: Node) -> bool:
	return current_node.get_parent() == parent_node
