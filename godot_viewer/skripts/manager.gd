extends Node3D

@onready var camera: Camera3D = $camera_rig/camera_arm/camera
@onready var model_container: Node3D = $turntable/VignetteSubViewport/model_container
@onready var view_menu: Control = $CanvasLayer/Hud/ViewMenu
@onready var hud: Control = $CanvasLayer/Hud
@onready var model: Node3D = model_container.get_child(0)

@export var selection_distance = 1000.0
@export var double_click_time = 0.3

var current_part = null
var parent_node = null
var current_level = []
var model_hierarchy = {}
var last_click_time = 0
#var state_stack: Array = []

var selected_mesh

var EV_active = true
@export var highlight_material: Resource = preload("res://materials/highlight_material.tres")

var hovered_mesh: MeshInstance3D = null
var original_materials = {}


func _ready():
	generate_colliders(model)  # Erstelle Collider für das Modell
	model_hierarchy = build_hierarchy(model)  # Baue die Modellhierarchie
	#set_focus_on_level(model)  # HIER LIEGT DAS PROBLEM MIT DEM TURNTABLE VERSATZ, WEIL DOPPELT BERECHNET WIRD
	$turntable.calculate_whole_model_center(model_hierarchy)
	#selection_stack.push_back(model)
	current_part = model
	selected_mesh = model
	#print("- - - - - - - Model Hierarchy - - - - - - - ")  
	#print_hierarchy(model_hierarchy)# Debugging
	#print("- - - - - - - END - - - - - - - ")  
	get_stats_for_entire_model()
	view_menu._save_original_materials()
	#push_state()

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

func get_stats_for_entire_model():
	var stats = collect_stats_for_branch(model_hierarchy)
	# Dann HUD updaten
	hud.update_info_count("Vertices: %d   Faces: %d" % [stats["vertices"]/2, stats["faces"]/2])
	hud.update_info_name("Entire Model")


func apply_highlight(mesh: MeshInstance3D):
	var surfaces = mesh.mesh.get_surface_count()
	for i in range(surfaces):
		# Überschreibe Material mit EINEM globalen highlight_material
		mesh.set_surface_override_material(i, highlight_material)

func remove_highlight(mesh: MeshInstance3D):
	var surfaces = mesh.mesh.get_surface_count()
	
	# Hole das derzeit ausgewählte globale Material aus dem ViewMenu.
	# (Achtung: Stelle sicher, dass 'view_menu' ein Skript mit 'active_material' hat!)
	var current_mat
	if view_menu.original_material_on:
		current_mat = null
	else:
		current_mat = view_menu.active_material
	
	for i in range(surfaces):
		# Anstelle von 'null' => setze das globale active_material
		mesh.set_surface_override_material(i, current_mat)


func restore_original_material(mesh: MeshInstance3D):
	if mesh not in original_materials:
		return
	var surfaces = mesh.mesh.get_surface_count()
	for i in range(surfaces):
		mesh.set_surface_override_material(i, null)
	original_materials.erase(mesh)
# In manager.gd

func _select_model_part():
	var from = camera.project_ray_origin(get_viewport().get_mouse_position())
	var to = from + camera.project_ray_normal(get_viewport().get_mouse_position()) * selection_distance

	var ray_query = PhysicsRayQueryParameters3D.new()
	ray_query.from = from
	ray_query.to = to

	var result = get_world_3d().direct_space_state.intersect_ray(ray_query)

	if result and result.collider:
		selected_mesh = result.collider
	else:
		selected_mesh = null

	while selected_mesh:
		if selected_mesh is MeshInstance3D:
			var clicked_mesh = selected_mesh
			#print("Clicked Mesh:", clicked_mesh.name)

			if current_part == model:
				# Wir sind auf der obersten Ebene
				var top_parent = find_top_level_key_including(model_hierarchy, clicked_mesh)

				if top_parent != null:
					#push_state()  # Speichere aktuellen Zustand
					$turntable.start_explosion(top_parent)
					set_focus_on_level(top_parent)  # "tiefer" gehen in den Ast
				else:
					#print("Kein passender top-level parent gefunden.")
					pass
				return
			else:
				# Wir sind auf Mesh-Ebene
				#print("Current part for subtree: ", current_part)
				var subtree = find_subtree(model_hierarchy, current_part)
				#print("Subtree return: ", subtree)

				if subtree.size() == 0:
					# Fallback => wir haben keinen subtree => möglicherweise Parent
					#print("Hier sollten wir nicht reinkommen")
					enter_parent_level()
					return

				# Finde das Dictionary-Parent
				var parent_branch = find_parent_branch(subtree, clicked_mesh)
				#print
				if parent_branch != null:
					#push_state()
					$turntable.start_explosion(parent_branch)
					set_focus_on_level(parent_branch)
				else:
					# Eventuell: "enter_sub_level()" oder "enter_parent_level()"
					#print("Kein Parentbranch gefunden, fallback.")
					enter_parent_level()
					#$turntable.start_explosion(clicked_mesh)
					#set_focus_on_level(clicked_mesh)
				return
		selected_mesh = selected_mesh.get_parent()

	# Falls wir gar keinen Mesh gefunden haben:
	if current_part != null:
		#print("Ich sollte nicht passieren")
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

# Funktion zur rekursiven Suche nach dem Subtree für einen gegebenen Node
func find_subtree(hierarchy: Dictionary, target_node: MeshInstance3D) -> Dictionary:
	for key in hierarchy.keys():
		if key == target_node:
			return hierarchy[key]  # Subtree gefunden
		# Rekursiver Aufruf für die Unterhierarchie
		var result = find_subtree(hierarchy[key], target_node)
		if result.size() > 0:
			return result  # Subtree in der Unterhierarchie gefunden
	return {}  # Subtree nicht gefunden


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
		#print("Überprüfe Child:", child_mesh.name)
		if child_mesh == mesh:
			#print("Gefunden das gesuchte Mesh selbst, kein Parent.")
			return child_mesh
		else:
			if subtree[child_mesh].has(mesh):
				#print("Gefunden Parent:", child_mesh.name, "für Mesh:", mesh.name)
				return child_mesh
			else:
				var found = find_parent_branch(subtree[child_mesh], mesh)
				if found != null:
					return found
	return null


func set_focus_on_level(node: Node):
	print("[DEBUG] Setting focus on level: ", node.name)
	current_part = node
	selected_mesh = node
	parent_node = node.get_parent()
	current_level = []

	if node.get_child_count() > 0:
		for child in node.get_children():
			if child is MeshInstance3D:
				current_level.append(child)

	update_transparency_for_current_view(node)
	$turntable.set_focus_on_object(node)

	# --> NUN STATS UPDATEN
	if node == model:
		# Dann haben wir "gesamtes Modell" (Root)
		get_stats_for_entire_model()
	elif node is MeshInstance3D:
		var subtree: Dictionary = model_hierarchy.get(node, {})
		var stats = get_mesh_stats(node)
		var child_stats = collect_stats_for_branch(subtree)
		var total_vertices = stats["vertices"] + child_stats["vertices"]
		var total_faces = stats["faces"] + child_stats["faces"]

		hud.update_info_count("Vertices: %d   Faces: %d" % [total_vertices/2, total_faces/2])
		hud.update_info_name(node.name)


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
	
	if current_part == model:
		#print("[DEBUG] Already at root level.")
		return

	if $turntable.state_stack.size() > 0:
		#pop_state()  # Stelle letzten Zustand wieder her
		var mesh_parent = search_for_mesh_parent(current_part)
		if mesh_parent:
			print("[DEBUG] Moving to parent level:", mesh_parent.name)
			set_focus_on_level(mesh_parent)  # Fokus setzen
			$turntable.start_implosion()  # Implosion starten
	else:
		#print("[DEBUG] Kein Zustand zum Wiederherstellen gefunden.")
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

# Gibt { "vertices": int, "faces": int } zurück
func get_mesh_stats(mesh_instance: MeshInstance3D) -> Dictionary:
	var total_vertices = 0
	var total_faces = 0

	if not mesh_instance.mesh:
		return {"vertices": 0, "faces": 0}

	var surface_count = mesh_instance.mesh.get_surface_count()
	for s in range(surface_count):
		var arrays = mesh_instance.mesh.surface_get_arrays(s)
		if arrays.size() > Mesh.ARRAY_VERTEX:
			# Vertex-Array
			var vertex_array = arrays[Mesh.ARRAY_VERTEX]
			total_vertices += vertex_array.size()

			# Index-Array
			var index_array = arrays[Mesh.ARRAY_INDEX]
			if index_array and index_array.size() > 0:
				total_faces += int(index_array.size() / 3)
			else:
				# Falls kein Index: kannst du Face-Anzahl schätzen (vertex_array.size()/3),
				# aber nur wenn du sicher weißt, es sind Dreiecke.
				pass

	return {"vertices": total_vertices, "faces": total_faces}


# Summiert rekursiv die Stats für alle Meshes im Dictionary-Ast
func collect_stats_for_branch(hierarchy: Dictionary) -> Dictionary:
	var total_vertices = 0
	var total_faces = 0

	for mesh in hierarchy.keys():
		# Stats des Meshes addieren
		var mesh_stats = get_mesh_stats(mesh)
		total_vertices += mesh_stats["vertices"]
		total_faces += mesh_stats["faces"]

		# Rekursiv die Kinder addieren
		var child_stats = collect_stats_for_branch(hierarchy[mesh])
		total_vertices += child_stats["vertices"]
		total_faces += child_stats["faces"]

	return {"vertices": total_vertices, "faces": total_faces}
