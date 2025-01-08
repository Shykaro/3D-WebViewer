extends Node3D

@onready var camera: Camera3D = $camera_rig/camera_arm/camera
@onready var model_container: Node3D = $turntable/VignetteSubViewport/model_container
@onready var view_menu: Control = $CanvasLayer/Hud/ViewMenu
@onready var model: Node3D = model_container.get_child(0)

@export var selection_distance = 1000.0
@export var double_click_time = 0.3

var selected_part = null
var parent_node = null
var current_level = []
var model_hierarchy = {}
var last_click_time = 0

var current_node

var EV_active = true
@export var highlight_material: Resource = preload("res://materials/highlight_material.tres")


var hovered_mesh: MeshInstance3D = null
var original_materials = {}

func _ready():
	generate_colliders(model)  # Erstelle Collider für das Modell
	model_hierarchy = build_hierarchy(model)  # Baue die Modellhierarchie
	#set_focus_on_level(model)  # HIER LIEGT DAS PROBLEM MIT DEM TURNTABLE VERSATZ, WEIL DOPPELT BERECHNET WIRD
	$turntable.calculate_whole_model_center(model_hierarchy)
	selected_part = model
	current_node = model
	#print("- - - - - - - Model Hierarchy - - - - - - - ")  
	#print_hierarchy(model_hierarchy)# Debugging: Hierarchie ausgeben

func _process(delta):
	var mouse_vel = Input.get_last_mouse_velocity()
	if mouse_vel.length() > 0:
		if EV_active:
			var from = camera.project_ray_origin(get_viewport().get_mouse_position())
			var to = from + camera.project_ray_normal(get_viewport().get_mouse_position()) * selection_distance

			var ray_query = PhysicsRayQueryParameters3D.new()
			ray_query.from = from
			ray_query.to = to

			var result = get_world_3d().direct_space_state.intersect_ray(ray_query)

			# 1) Finde das Objekt, falls eines gehittet wird
			var new_hovered = null
			if result and result.collider:
				if result.collider.get_parent() is MeshInstance3D: #geht leider davon aus dass Godot immer StaticMesh als Child an Meshinstance wirft
					new_hovered = result.collider.get_parent()

			# 2) Wenn das hovered Objekt sich ändert
			if new_hovered != hovered_mesh:
				# Entferne Highlight vom alten
				if hovered_mesh:
					remove_highlight(hovered_mesh)

				# Setze Highlight beim neuen
				if new_hovered:
					apply_highlight(new_hovered)

			hovered_mesh = new_hovered

func apply_highlight(mesh: MeshInstance3D):
	var surfaces = mesh.mesh.get_surface_count()
	for i in range(surfaces):
		# Überschreibe Material mit EINEM globalen highlight_material
		mesh.set_surface_override_material(i, highlight_material)

func remove_highlight(mesh: MeshInstance3D):
	var surfaces = mesh.mesh.get_surface_count()
	for i in range(surfaces):
		# Entferne Override => Originalmaterial kommt zurück
		mesh.set_surface_override_material(i, null)

#func apply_highlight(mesh: MeshInstance3D):
	#if not mesh.mesh:
		#return
	## Speichere Originalmaterialien
	#var surfaces = mesh.mesh.get_surface_count()
	#original_materials[mesh] = []
	#for i in range(surfaces):
		#var mat = mesh.mesh.surface_get_material(i)
		#original_materials[mesh].append(mat)
		#if mat:
			#var highlight_mat = mat.duplicate()
			#if highlight_mat is BaseMaterial3D:
				#highlight_mat.emission_enabled = true
				#highlight_mat.emission = Color.YELLOW
				#highlight_mat.emission_energy = 2.0
			#mesh.set_surface_override_material(i, highlight_mat)

func restore_original_material(mesh: MeshInstance3D):
	if mesh not in original_materials:
		return
	var surfaces = mesh.mesh.get_surface_count()
	for i in range(surfaces):
		mesh.set_surface_override_material(i, null)
	original_materials.erase(mesh)

# Generiert Trimesh-Collider für alle relevanten Meshes
func generate_colliders(node: Node):
	if node is MeshInstance3D:
		node.create_trimesh_collision()
		#print("Generated collider for:", node)
	for child in node.get_children():
		generate_colliders(child)

# Rekursive Funktion zum Aufbau der Hierarchie nur mit MeshInstance3D
func build_hierarchy(node: Node) -> Dictionary:
	var hierarchy = {}
	for child in node.get_children():
		if child is MeshInstance3D:
			# Füge das MeshInstance3D zur Hierarchie hinzu
			hierarchy[child] = build_hierarchy(child)
		else:
			# Suche weiter, falls kein MeshInstance3D
			var sub_hierarchy = build_hierarchy(child)
			# Füge alle gefundenen MeshInstances direkt in die aktuelle Hierarchie ein
			for mesh_instance in sub_hierarchy.keys():
				hierarchy[mesh_instance] = sub_hierarchy[mesh_instance]
	return hierarchy

func print_hierarchy(hierarchy: Dictionary, prefix: String = ""):
	for node in hierarchy.keys():
		if node is MeshInstance3D:
			print(prefix, "- MeshInstance3D:", node.name)
		else:
			print(prefix, "- Node:", node.name)
		# Rekursiver Aufruf mit erweitertem Prefix für die Hierarchieebene
		print_hierarchy(hierarchy[node], prefix + "  ")

func _input(event):
	#if view_menu.menu_open:
		#return

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT and !$turntable.is_transitioning:
		if EV_active:
			var current_time = Time.get_ticks_msec() / 1000.0
			if current_time - last_click_time <= double_click_time:
				#print("[DEBUG] Double-click detected.")
				_select_model_part()
			last_click_time = current_time

func _select_model_part():
	var from = camera.project_ray_origin(get_viewport().get_mouse_position())
	var to = from + camera.project_ray_normal(get_viewport().get_mouse_position()) * selection_distance

	var ray_query = PhysicsRayQueryParameters3D.new()
	ray_query.from = from
	ray_query.to = to

	var result = get_world_3d().direct_space_state.intersect_ray(ray_query)

	if result and result.collider:
		current_node = result.collider

	while current_node:
		#print("current_node: ", current_node)
		if current_node is MeshInstance3D:
			
			var clicked_mesh = current_node

			if selected_part == model:
				
				# -> Wir sind auf Ober-Ebene
				var top_parent = find_top_level_key_including(model_hierarchy, clicked_mesh)
				
				if top_parent != null:
					$turntable.start_explosion(top_parent)
					set_focus_on_level(top_parent)  # => "tiefer" gehen in Ast
					#print("Lolol")
				else:
					# Klick auf etwas, was nicht existiert => z. B. do nothing oder parent?
					print("Kein passender top-level parent gefunden.")
				return
			else:
				# Wir sind auf Mesh-Ebene
				# => subtree = model_hierarchy[selected_part]
				var subtree = model_hierarchy.get(selected_part, null)
				if subtree == null:
					# fallback => wir haben keinen subtree => maybe do parent
					enter_parent_level()
					#print("Ich sollte nicht passieren")
					return

				# => finde dictionary-parent
				var parent_branch = find_parent_branch(subtree, clicked_mesh)
				if parent_branch != null:
					$turntable.start_explosion(parent_branch)
					set_focus_on_level(parent_branch)
				else:
					# => evtl. "enter_sub_level()" oder "enter_parent_level()" 
					print("Kein Parentbranch gefunden, fallback.")
					enter_parent_level()
				
				return
		current_node = current_node.get_parent()
		#print("Ich sollte nicht passieren")
	# Falls wir gar keinen Mesh gefunden haben:
	if selected_part != null:
		print("Ich sollte nicht passieren")
		enter_parent_level()


func find_top_level_key_including(hierarchy: Dictionary, mesh: MeshInstance3D) -> MeshInstance3D:
	for top_mesh in hierarchy.keys():
		if top_mesh == mesh:
			# Mesh ist selber Top-Level
			return top_mesh
		else:
			if find_in_subtree(hierarchy[top_mesh], mesh):
				return top_mesh
	return null

# Hilfsfunktion: Prüft, ob 'mesh' im Dictionary 'subtree' enthalten ist.
func find_in_subtree(subtree: Dictionary, mesh: MeshInstance3D) -> bool:
	for child in subtree.keys():
		if child == mesh:
			return true
		else:
			if find_in_subtree(subtree[child], mesh):
				return true
	return false


func find_parent_branch(subtree: Dictionary, mesh: MeshInstance3D) -> MeshInstance3D:
	for child_mesh in subtree.keys():
		if child_mesh == mesh:
			return null
		else:
			if mesh in subtree[child_mesh].keys():
				# => child_mesh ist direkter Parent
				return child_mesh
			else:
				var found = find_parent_branch(subtree[child_mesh], mesh)
				if found != null:
					return found
	return null

func set_focus_on_level(node: Node):
	print("[DEBUG] Setting focus on level: ", node.name)
	selected_part = node
	current_node = node
	parent_node = node.get_parent()
	current_level = []

	if node.get_child_count() > 0:
		for child in node.get_children():
			if child is MeshInstance3D:
				current_level.append(child)

	update_transparency_for_current_view(node)
	$turntable.set_focus_on_object(node)

# Aktualisiert die Transparenz basierend auf der aktuellen Ebene
func update_transparency_for_current_view(except_node: Node = null):
	for child in parent_node.get_children():
		if child is MeshInstance3D:
			if child == except_node:
				view_menu.reset_material_to_original(child)
			else:
				make_part_transparent(child)

# Wendet Transparenz auf ein Modell an
func make_part_transparent(part: MeshInstance3D):
	if part.mesh:
		for i in range(part.mesh.get_surface_count()):
			var material = part.mesh.surface_get_material(i)
			if material:
				material = material.duplicate()
				if material is BaseMaterial3D:
					material.albedo_color.a = 0.2
					part.set_surface_override_material(i, material)

func enter_parent_level():
	var current_node = selected_part
	if current_node == model:
		print("[DEBUG] Already at root level.")
		return

	var mesh_parent = search_for_mesh_parent(current_node)
	if mesh_parent:
		#print("[DEBUG] Moving to parent level: ", mesh_parent.name)
		set_focus_on_level(mesh_parent)  # Zuerst Fokus setzen
		$turntable.start_implosion()  # Danach Implosion starten
	else:
		#print("[DEBUG] Already at root level.")
		pass

# Rekursive Suche nach dem nächsten MeshInstance3D-Parent
func search_for_mesh_parent(node: Node) -> Node:
	var parent = node.get_parent()
	# Stoppe, wenn wir das Modell selbst erreicht haben oder keinen Parent mehr haben
	if parent == null or parent == model:
		return model
	# Wenn der Parent ein MeshInstance3D ist, gib ihn zurück
	if parent is MeshInstance3D:
		return parent
	# Andernfalls, suche weiter rekursiv nach oben
	return search_for_mesh_parent(parent)	

# Überprüfen, ob current_node ein direktes Child von parent_node ist
func _is_direct_child(parent_node: Node, current_node: Node) -> bool:
	return current_node.get_parent() == parent_node
