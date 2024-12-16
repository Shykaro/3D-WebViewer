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

func _ready():
	generate_colliders(model)  # Erstelle Collider für das Modell
	model_hierarchy = build_hierarchy(model)  # Baue die Modellhierarchie
	set_focus_on_level(model)  # Starte auf der obersten Ebene
	#print_hierarchy(model_hierarchy)  # Debugging: Hierarchie ausgeben

# Generiert Trimesh-Collider für alle relevanten Meshes
func generate_colliders(node: Node):
	if node is MeshInstance3D:
		node.create_trimesh_collision()
		#print("Generated collider for:", node)
	for child in node.get_children():
		generate_colliders(child)

# Rekursive Funktion zum Aufbau der Modellhierarchie
func build_hierarchy(node: Node) -> Dictionary:
	var hierarchy = {}
	for child in node.get_children():
		if child is MeshInstance3D or child.get_child_count() > 0:
			hierarchy[child] = build_hierarchy(child)
	return hierarchy

# Debugging: Gibt die Hierarchie aus
func print_hierarchy(hierarchy: Dictionary, level: int = 0):
	for node in hierarchy.keys():
		print("  ",level,"- ",str(node))
		print_hierarchy(hierarchy[node], level + 1)

# Setzt den Fokus auf die aktuelle Ebene und aktualisiert die Transparenzw
func set_focus_on_level(node: Node):
	selected_part = node
	current_node = node
	parent_node = node.get_parent()
	current_level = []
	if node.get_child_count() > 0:
		for child in node.get_children():
			if child is MeshInstance3D:
				current_level.append(child)
	update_transparency_for_current_view(node)
	#if current_node == model.get_child(0) or selected_part == model.get_child(0):
		#return
	$turntable.set_focus_on_object(node)
	#print("Focused on:", node)
	

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

# Navigation in die Unterebene
func enter_sub_level(node: MeshInstance3D):
	if model_hierarchy.has(node):
		set_focus_on_level(node)
		$turntable.start_explosion(node)
		#print("Entered sub-level:", node)
	else:
		print("No further levels available.")

# Navigation in die obere Ebene
func enter_parent_level():
	# Startpunkt: aktueller Knoten
	var current_node = selected_part
	# Wenn der aktuelle Knoten bereits das Modell ist -> Root-Ebene erreicht
	if current_node == model:
		#print("Already at the root level.")
		return
	# Suche nach dem nächstgelegenen MeshInstance3D-Parent
	var mesh_parent = search_for_mesh_parent(current_node)
	if mesh_parent:
		set_focus_on_level(mesh_parent)
		$turntable.start_implosion()
		#print("Moved to parent level:", mesh_parent)
	else:
		#print("Already at the root level.")
		return

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

	

# Eingabeverarbeitung für Doppelklick und Navigation
func _input(event):
	if view_menu.menu_open:
		return  # Keine Navigation, wenn das Menü geöffnet ist

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT and !$turntable.is_transitioning:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_click_time <= double_click_time:
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

		# Traverse von StaticBody oder anderem Collider hoch zur MeshInstance3D
		while current_node:
			if current_node is MeshInstance3D:
				#print("current node: ", current_node)
				#print("selected part: ", selected_part)
				if selected_part == model:
					selected_part = current_node
					#print("exploding...")
					$turntable.start_explosion(selected_part)
					set_focus_on_level(selected_part)
					print("!!! current_node: ", current_node)
					#$turntable.set_focus_on_object(selected_part)
				elif _is_direct_child(selected_part, current_node):
					selected_part = current_node
					$turntable.start_explosion(selected_part)
					set_focus_on_level(selected_part)
					#$turntable.set_focus_on_object(selected_part)
					print("!!! current_node: ", current_node)
				else:
					enter_parent_level()
					print("!!! current_node: ", current_node)
				return
			current_node = current_node.get_parent()
			#print("!!! current_node: ", current_node)

	# Wenn kein Treffer erzielt wird, navigiere ins höhere Level
	if selected_part != null:
		#print("Sheise is das hier")
		enter_parent_level()


# Überprüfen, ob current_node ein direktes Child von parent_node ist
func _is_direct_child(parent_node: Node, current_node: Node) -> bool:
	return current_node.get_parent() == parent_node
