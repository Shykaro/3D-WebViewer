extends Node3D

@export var Scale = 2
@export var Zoom_Multiplier = 0.35
@export var transition_duration = 0.5
@export var explosion_distance = 2.0
@export var explosion_duration = 1.0

var original_position = Vector3()
var original_pivot = Vector3()
var current_pivot = Vector3()
var target_pivot = Vector3()

var transition_elapsed = 0.0
var is_transitioning = false
var is_exploding = false
var is_in_explosion_view = false
var is_imploding = false
var explosion_elapsed = 0.0

var mesh_original_positions = {}
var mesh_explosion_targets = {}

@onready var model_container: Node3D = $VignetteSubViewport/model_container
@onready var model: Node3D = $VignetteSubViewport/model_container/model
@onready var main: Node3D = $".."

var is_in_submodel_focus = false  # Gibt an, ob der Fokus auf einem Sub-Modell liegt

var explosion_target: Node3D

# Speichert die Hierarchie der Objekte
var hierarchy_levels = {}
var current_level = 0

func _ready():
	original_position = model_container.position
	original_pivot = calculate_geometric_center(model_container)
	current_pivot = original_pivot
	setup_scaling_based_on_aabb(model_container)
	initialize_hierarchy(model)
	print("Original position stored as:", original_position)  # Debug-Ausgabe

func _process(delta):
	if is_transitioning:
		transition_elapsed += delta
		var t = clamp(transition_elapsed / transition_duration, 0, 1)
		var new_pivot = current_pivot.lerp(target_pivot, t)
		var offset = new_pivot - current_pivot
		model_container.position -= offset
		current_pivot = new_pivot
		#print("Animating transition: Current pivot:", current_pivot, "Target pivot:", target_pivot)
		if t >= 1.0:
			is_transitioning = false
			#print("Transition to position completed.")
	
	if not is_transitioning and explosion_target and is_in_submodel_focus:
		#print("Starting explosion for target:", explosion_target.name)
		start_explosion(explosion_target)
		explosion_target = null  # Explosion-Target leeren nach Start

		
	if is_exploding:
		explosion_elapsed += delta
		var t = clamp(explosion_elapsed / explosion_duration, 0, 1)
		for mesh in mesh_original_positions.keys():
			var original_pos = mesh_original_positions[mesh]
			var target_pos = mesh_explosion_targets[mesh]
			mesh.global_transform.origin = original_pos.lerp(target_pos, t)
		if t >= 1.0:
			is_exploding = false

	if is_imploding:
		explosion_elapsed += delta
		var t = clamp(explosion_elapsed / explosion_duration, 0, 1)
		for mesh in mesh_original_positions.keys():
			var original_pos = mesh_original_positions[mesh]
			var target_pos = mesh_explosion_targets[mesh]
			mesh.global_transform.origin = target_pos.lerp(original_pos, t)
		if t >= 1.0:
			is_imploding = false

func calculate_geometric_center(target_node: Node) -> Vector3:
	var total_position = Vector3()
	var count = 0
	for child in target_node.get_children():
		if child is MeshInstance3D and child.visible:
			total_position += child.global_transform.origin
			count += 1
	var result = total_position / count if count > 0 else target_node.global_transform.origin
	print("Calculated geometric center for:", target_node.name, "=", result)  # Debug-Ausgabe
	return result


# Initialisiert die Hierarchie der Modelle
func initialize_hierarchy(root_node):
	hierarchy_levels.clear()
	hierarchy_levels = _collect_hierarchy(root_node)

# Eine Funktion, die rekursiv alle Hierarchieebenen sammelt
func _collect_hierarchy(node: Node) -> Dictionary:
	var hierarchy = {}
	
	for child in node.get_children():
		if child is MeshInstance3D:
			hierarchy[child] = _collect_hierarchy(child)  # rekursiv für die Hierarchie
			#print("Added Mesh to hierarchy:", child.name)
		elif child.get_child_count() > 0:
			var child_hierarchy = _collect_hierarchy(child)
			# Manuelles Zusammenführen der Inhalte
			for key in child_hierarchy.keys():
				hierarchy[key] = child_hierarchy[key]
			#print("Exploring deeper in hierarchy:", child.name)
		else:
			#print("Skipping non-MeshInstance3D and leaf child:", child.name)
			pass
	
	return hierarchy


# Startet die Explosion und fokussiert auf das ausgewählte Teil
func start_explosion(selected_part: MeshInstance3D):
	mesh_original_positions.clear()
	mesh_explosion_targets.clear()

	var center_point = calculate_geometric_center(model)
	var mesh_spheres = {}
	var total_volume = 0.0
	is_in_explosion_view = true

	# Teile in der Hierarchie durchgehen
	for child in model.get_child(0).get_children():
		if child is MeshInstance3D:
			var mesh = child
			if mesh == selected_part:
				# Fokussiere das Modell auf das ausgewählte Teil, ohne es zu verschieben
				mesh_original_positions[mesh] = mesh.global_transform.origin
				mesh_explosion_targets[mesh] = mesh.global_transform.origin
				continue
			
			# Berechnung für alle anderen Teile
			var sphere_radius = calculate_bounding_sphere(mesh)
			mesh_spheres[mesh] = sphere_radius
			total_volume += sphere_radius

	var num_children = mesh_spheres.size()
	var base_distance = (total_volume / num_children) * 2.0
	var angle_step = 2.0 * PI / num_children
	var direction_index = 0

	for mesh in mesh_spheres.keys():
		var sphere_radius = mesh_spheres[mesh]
		var theta = direction_index * angle_step
		var phi = acos(1.0 - 2.0 * float(direction_index) / num_children)
		var direction = Vector3(
			sin(phi) * cos(theta),
			sin(phi) * sin(theta),
			cos(phi)
		).normalized()
		var total_distance = base_distance + sphere_radius * 0.05
		var target_position = center_point + direction * total_distance

		mesh_original_positions[mesh] = mesh.global_transform.origin
		mesh_explosion_targets[mesh] = target_position
		direction_index += 1

	resolve_collisions(mesh_spheres)
	explosion_elapsed = 0.0
	is_exploding = true

# Rückkehr zur normalen Ansicht (Implosion)
func start_implosion():
	explosion_elapsed = 0.0
	is_imploding = true
	is_in_explosion_view = false

func reset_explosion():
	for mesh in mesh_original_positions.keys():
		mesh.global_transform.origin = mesh_original_positions[mesh]
	main.reset_model_visibility()
	print("Reset explosion and restored visibility.")
	is_exploding = false
	is_imploding = false
	
	# Starte Animation zur ursprünglichen Pivot-Position
	reset_focus_with_animation()


func set_focus_on_object(target_node: MeshInstance3D):
	if target_node and !is_in_submodel_focus:
		print("Setting focus on object:", target_node.name)
		target_pivot = calculate_geometric_center(target_node)
		transition_elapsed = 0.0
		is_transitioning = true
		explosion_target = target_node
		is_in_submodel_focus = true  # Wir befinden uns nun im Submodell-Fokus


# Berechnet die AABB
func calc_aabb_simple(n: Node) -> AABB:
	var aabb_ret = AABB()
	if n is MeshInstance3D and n.mesh:
		aabb_ret = n.mesh.get_aabb()
	for child in n.get_children():
		aabb_ret = aabb_ret.merge(calc_aabb_simple(child))
	return aabb_ret

# Berechnet die Bounding Sphere
func calculate_bounding_sphere(mesh_instance: MeshInstance3D) -> float:
	if not mesh_instance.mesh:
		return 0.0
	var aabb = mesh_instance.mesh.get_aabb()
	return aabb.size.length() / 2.0

# Verhindert Überlappung durch Kollisionslösung
func resolve_collisions(mesh_spheres: Dictionary):
	for mesh_a in mesh_spheres.keys():
		for mesh_b in mesh_spheres.keys():
			if mesh_a != mesh_b:
				var distance = mesh_explosion_targets[mesh_a].distance_to(mesh_explosion_targets[mesh_b])
				var min_distance = mesh_spheres[mesh_a] + mesh_spheres[mesh_b] + 0.5
				if distance < min_distance:
					var push_direction = (mesh_explosion_targets[mesh_a] - mesh_explosion_targets[mesh_b]).normalized()
					var push_amount = (min_distance - distance) / 2.0
					mesh_explosion_targets[mesh_a] += push_direction * push_amount
					mesh_explosion_targets[mesh_b] -= push_direction * push_amount

# Skaliert das Modell basierend auf der AABB
func setup_scaling_based_on_aabb(model_node: Node):
	var aabb = calc_aabb_simple(model_node)
	if aabb.has_volume():
		var max_size = aabb.size[aabb.get_longest_axis_index()]
		Scale = 2 / max_size
		Zoom_Multiplier = 0.35 * Scale
		model_container.scale = Vector3(Scale, Scale, Scale)
		model_container.position = -Scale * aabb.get_center()

# Setzt den Fokus auf die Ursprungsposition
func reset_focus():
	model_container.position = original_position
	current_pivot = original_pivot

func reset_focus_with_animation():
	target_pivot = original_pivot
	model_container.position = original_position
	transition_elapsed = 0.0
	is_transitioning = true
	is_in_submodel_focus = false  # Wir kehren zur Originalansicht zurück
	print("Resetting focus with animation to original pivot:", original_pivot)


	
	# Berechnet die maximale Breite aus den Mesh-Vertices
func calculate_max_width_from_vertices(mesh_instance: MeshInstance3D) -> float:
	if not mesh_instance.mesh:
		return 0.0
	var vertices = []
	for i in range(mesh_instance.mesh.get_surface_count()):
		var array = mesh_instance.mesh.surface_get_arrays(i)
		if array.size() > Mesh.ARRAY_VERTEX:
			var surface_vertices = array[Mesh.ARRAY_VERTEX]
			for vertex in surface_vertices:
				vertices.append(mesh_instance.transform.origin + mesh_instance.transform.basis * vertex)

	var min_point = vertices[0]
	var max_point = vertices[0]
	for vertex in vertices:
		min_point = min_point.min(vertex)
		max_point = max_point.max(vertex)

	var size = max_point - min_point
	return size.length()
