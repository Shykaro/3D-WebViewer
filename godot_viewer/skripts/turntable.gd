extends Node3D

@export var Scale = 2
@export var Zoom_Multiplier = 0.35
@export var transition_duration = 0.5
@export var explosion_distance = 2.0
@export var explosion_duration = 1.0

@onready var model_container: Node3D = $VignetteSubViewport/model_container
@onready var model: Node3D = $VignetteSubViewport/model_container/model

var original_position = Vector3()  # Ursprüngliche Position des Containers
var original_pivot = Vector3()  # Ursprünglicher Pivot
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

func _ready():
	original_position = model_container.position
	original_pivot = calculate_geometric_center(model_container)
	current_pivot = original_pivot
	set_focus_on_object(model_container)
	setup_scaling_based_on_aabb(model_container)

# Beinhaltet die unterschiedlichen Animationen
func _process(delta):
	if is_transitioning:
		transition_elapsed += delta
		var t = clamp(transition_elapsed / transition_duration, 0, 1)
		var new_pivot = current_pivot.lerp(target_pivot, t)
		var offset = new_pivot - current_pivot
		model_container.position -= offset
		current_pivot = new_pivot
		if t >= 1.0:
			is_transitioning = false
			
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
			# Implosion: Zurück von der Explosionsposition zur ursprünglichen Position
			mesh.global_transform.origin = target_pos.lerp(original_pos, t)
		if t >= 1.0:
			is_imploding = false

# Berechnet den geometrischen Mittelpunkt
func calculate_geometric_center(target_node: Node) -> Vector3:
	var total_position = Vector3()
	var count = 0
	for child in target_node.get_children():
		if child is MeshInstance3D and child.visible:
			total_position += child.global_transform.origin
			count += 1
	return total_position / count if count > 0 else target_node.global_transform.origin

func start_explosion(selected_part: MeshInstance3D):
	mesh_original_positions.clear()
	mesh_explosion_targets.clear()
	
	var center_point = calculate_geometric_center(selected_part)
	var mesh_spheres = {}
	var total_volume = 0.0
	is_in_explosion_view = true

	# Loop through all children to set up the explosion
	for child in model.get_child(0).get_children():
		if child is MeshInstance3D and child != selected_part and !is_parent_of(selected_part, child):
			var sphere_radius = calculate_bounding_sphere(child)
			mesh_spheres[child] = sphere_radius
			total_volume += sphere_radius
			mesh_original_positions[child] = child.global_transform.origin
	
	# Calculate explosion targets for remaining parts
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

		# Save the original and target positions for the animation
		mesh_explosion_targets[mesh] = target_position
		direction_index += 1

	# Handle collisions and start the explosion animation
	resolve_collisions(mesh_spheres)
	explosion_elapsed = 0.0
	is_exploding = true


# Startet die Rückkehr zur normalen Ansicht (Implosion)
func start_implosion():
	explosion_elapsed = 0.0
	is_imploding = true
	is_in_explosion_view = false

# Setzt alle Meshes auf die ursprüngliche Position zurück
func reset_explosion():
	for mesh in mesh_original_positions.keys():
		mesh.global_transform.origin = mesh_original_positions[mesh]
	is_exploding = false
	is_imploding = false

# Setzt den Fokus mit sanfter Transition auf das Zielobjekt
func set_focus_on_object(target_node: Node):
	if target_node:
		target_pivot = calculate_geometric_center(target_node)
		transition_elapsed = 0.0
		is_transitioning = true


# Berechnet die AABB
func calc_aabb_simple(n: Node) -> AABB:
	var aabb_ret = AABB()
	if n is MeshInstance3D and n.mesh:
		aabb_ret = n.mesh.get_aabb()
	for child in n.get_children():
		aabb_ret = aabb_ret.merge(calc_aabb_simple(child))
	return aabb_ret

# Berechnet eine Bounding Sphere für das Volumen
func calculate_bounding_sphere(mesh_instance: MeshInstance3D) -> float:
	if not mesh_instance.mesh:
		return 0.0
	var aabb = mesh_instance.mesh.get_aabb()
	return aabb.size.length() / 2.0
	
# Checks if `parent_node` is an ancestor of `child_node`
func is_parent_of(parent_node: Node, child_node: Node) -> bool:
	var current_node = child_node
	while current_node:
		if current_node == parent_node:
			return true
		current_node = current_node.get_parent()
	return false


# Prüft auf Kollisionen und passt Positionen an
func resolve_collisions(mesh_spheres: Dictionary):
	#print("Collision detected, trying to adjust...")
	for mesh_a in mesh_spheres.keys():
		for mesh_b in mesh_spheres.keys():
			if mesh_a != mesh_b:
				var distance = mesh_explosion_targets[mesh_a].distance_to(mesh_explosion_targets[mesh_b])
				var min_distance = mesh_spheres[mesh_a] + mesh_spheres[mesh_b]
				if distance < min_distance:
					#print("Meshes too close together...")
					var push_direction = (mesh_explosion_targets[mesh_a] - mesh_explosion_targets[mesh_b]).normalized()
					var push_amount = (min_distance - distance) / 2.0
					mesh_explosion_targets[mesh_a] += push_direction * push_amount
					mesh_explosion_targets[mesh_b] -= push_direction * push_amount

# Setzt den Container basierend auf der AABB
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
	transition_elapsed = 0.0
	is_transitioning = true

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
