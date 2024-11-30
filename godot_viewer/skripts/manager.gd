extends Node3D

@onready var camera: Camera3D = $camera_rig/camera_arm/camera
@onready var model_container: Node3D = $turntable/VignetteSubViewport/model_container
@onready var view_menu: Control = $CanvasLayer/Hud/ViewMenu
@onready var model: Node3D = $turntable/VignetteSubViewport/model_container/model

@export var selection_distance = 1000.0
@export var double_click_time = 0.3

var selected_part = null
var last_click_time = 0
var meshes = []

# Starte die Traversierung von der höchsten Ebene
func _ready():
	#find_all_meshes_in_node(model) #versucht die Hierarchie mit allen Mesh instanzen auszumachen, gibt array zurück
	generate_colliders(model)
	#for i in range(meshes.size()):
		##meshes[i].create_trimesh_collision() #ERSTELLT COLLIDERS FÜR ALLE MESHES DES MODELLS BEI INITIAL LOADUP
		#print(meshes[i])
	
func generate_colliders(node: Node):
	if node is MeshInstance3D:
		node.create_trimesh_collision()
		print("Generated collider for: ", node)
	
	for child in node.get_children():
		generate_colliders(child)
		print("running...")
		
		
#func generate_colliders(node: Node): #Geht das auch optimierter? FutureMe: Ja. Rekursion above
	#for childsLvl1 in node.get_children():
		#if childsLvl1 is MeshInstance3D:
			#childsLvl1.create_trimesh_collision()
			#print("Level 1 Childs: ", childsLvl1)
		#if childsLvl1.get_child_count() > 0:
			#for childsLvl2 in childsLvl1.get_children():
				#if childsLvl2 is MeshInstance3D:
					#childsLvl2.create_trimesh_collision()
					#print("Level 2 Childs: ", childsLvl2)
				#if childsLvl2.get_child_count() > 0:
					#for childsLvl3 in childsLvl2.get_children():
						#if childsLvl3 is MeshInstance3D:
							#childsLvl3.create_trimesh_collision()
							#print("Level 3 Childs: ", childsLvl3)
						#if childsLvl3.get_child_count() > 0:
							#for childsLvl4 in childsLvl3.get_children():
								#if childsLvl4 is MeshInstance3D:
									#childsLvl4.create_trimesh_collision()
									#print("Level 4 Childs: ", childsLvl4)
								#if childsLvl4.get_child_count() > 0:
									#for childsLvl5 in childsLvl4.get_children():
										#if childsLvl5 is MeshInstance3D:
											#childsLvl5.create_trimesh_collision()
											#print("Level 5 Childs: ", childsLvl5)

# Dynamische Erkennung von MeshInstance3D-Knoten MUSS ANGEPASST WERDEN DAMIT BELIEBIGE MODELLHIERARCHIEN ERKANNT WERDEN
func find_all_meshes_in_node(node: Node) -> Array:
	for child in node.get_children():
		if child is MeshInstance3D:
			meshes.append(child)
			pass
		elif child.get_child_count() > 0:
			#meshes.append_array(find_all_meshes_in_node(child))
			meshes.append_array(child.get_children())
			pass
	return meshes

func _input(event):
	# Überprüfen, ob Menü geöffnet ist und Maus über einem UI-Element schwebt
	if view_menu.menu_open and (view_menu.menu_button.is_hovered() or view_menu.popup_menu.get_global_rect().has_point(get_viewport().get_mouse_position())):
		return  # Ignoriere das Event, wenn Maus über dem Menü schwebt

	# Modellbewegung nur zulassen, wenn kein UI-Element aktiv ist
	if !$turntable.is_animation_active and event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
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
					print("exploding...")
					$turntable.start_explosion(selected_part)
					_enter_sub_mode(selected_part)
				elif _is_direct_child(selected_part, current_node):
					selected_part = current_node
					$turntable.start_explosion(selected_part)
					_enter_sub_mode(selected_part)
					#print("Version2")
				else:
					_select_parent()
					print("imploding...")
					$turntable.start_implosion()
				return
			current_node = current_node.get_parent()

	# Nur aufrufen, wenn wir nicht schon auf der obersten Ebene sind
	if selected_part != null:
		_select_parent()
		print("imploding...")
		$turntable.start_implosion()

# Zum Parent wechseln
func _select_parent():
	if selected_part and selected_part.get_parent() is MeshInstance3D:
		# Wechselt auf die übergeordnete Ebene, wenn `selected_part` einen Elternknoten hat
		selected_part = selected_part.get_parent()
		_enter_sub_mode(selected_part)
	else:
		# Abbrechen, wenn wir uns auf der obersten Ebene befinden
		if selected_part != null:
			$turntable.reset_focus_with_animation()
			selected_part = null
			_reset_camera_zoom()

func _enter_sub_mode(part: Node):
	$turntable.set_focus_on_object(part)
	var current_model_max_size = $turntable.calculate_max_width_from_vertices(part)
	if current_model_max_size > 0.0:
		$camera_rig.min_zoom = current_model_max_size * 1.05
		$camera_rig.camera_distance = max(current_model_max_size * 1.05, $camera_rig.camera_distance)
		$camera_rig.max_zoom = $camera_rig.min_zoom * 5
		$camera_rig._handle_zoom()

	# Aktualisiere Transparenz und Materialien
	#update_transparency_for_current_view(part)
	#set_transparency_for_all_meshes_in_node(model_container, part)

# Kamerazoom zurücksetzen
func _reset_camera_zoom():
	var model_size = $camera_rig.calculate_model_dimensions(model_container)
	$camera_rig.min_zoom = model_size * 1.05
	$camera_rig.camera_distance = max(model_size * 1.05, $camera_rig.camera_distance)
	$camera_rig.max_zoom = $camera_rig.min_zoom * 5
	$camera_rig._handle_zoom()

func make_part_transparent(part: MeshInstance3D):
	if part.mesh:
		for i in range(part.mesh.get_surface_count()):
			var material = part.get_surface_override_material(i)
			if not material:
				material = part.mesh.surface_get_material(i)
				if material:
					material = material.duplicate()

			# Nur Änderungen vornehmen, wenn Material ein BaseMaterial3D ist
			if material and material is BaseMaterial3D:
				material.set_transparency(BaseMaterial3D.TRANSPARENCY_ALPHA)
				material.albedo_color.a = 0.2
				part.set_surface_override_material(i, material)

func set_transparency_for_all_meshes_in_node(node: Node, except_part: MeshInstance3D):
	meshes = find_all_meshes_in_node(node) #ersetzen!!! GEGEN GESCHEITE UNIVERSALLOGIK
	for mesh in meshes:
		if mesh != except_part:
			make_part_transparent(mesh)


func reset_model_visibility():
	for child in model_container.get_child(0).get_child(0).get_children():
		if child is MeshInstance3D:
			for i in range(child.mesh.get_surface_count()):
				var material = child.get_surface_override_material(i)
				if not material:
					material = child.mesh.surface_get_material(i)
					if material:
						material = material.duplicate()

				if material and material is BaseMaterial3D:
					# Transparenzstatus prüfen und beibehalten
					if material.albedo_color.a < 1.0:
						material.albedo_color.a = 0.2
						material.set_transparency(BaseMaterial3D.TRANSPARENCY_ALPHA)
					else:
						material.albedo_color.a = 1.0
						material.set_transparency(BaseMaterial3D.TRANSPARENCY_DISABLED)
					child.set_surface_override_material(i, material)

func update_transparency_for_current_view(except_part: MeshInstance3D):
	meshes = find_all_meshes_in_node(model_container) #ersetzen für universallogik
	for mesh in meshes:
		if mesh == except_part:
			# Stelle sicher, dass das ausgewählte Teilmodell vollständig sichtbar ist
			view_menu.reset_material_to_original(mesh)
		else:
			# Wende Transparenz oder aktives Material auf die anderen Teile an
			if view_menu.active_material == view_menu.wireframe_material:
				# Im Wireframe-Modus das Wireframe-Material anwenden
				mesh.set_surface_override_material(0, view_menu.active_material.duplicate())
			else:
				# Andernfalls Transparenz anwenden
				make_part_transparent(mesh)


# Überprüfen, ob current_node ein direktes Child von parent_node ist
func _is_direct_child(parent_node: Node, current_node: Node) -> bool:
	return current_node.get_parent() == parent_node
