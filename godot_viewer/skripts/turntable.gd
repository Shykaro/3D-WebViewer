extends Node3D

@export var Scale = 2
@export var Zoom_Multiplier = 0.35
@export var transition_duration = 2.5
@export var explosion_distance = 2.0
@export var explosion_duration = 1.0

@onready var model_container: Node3D = $VignetteSubViewport/model_container
@onready var model: Node3D = $VignetteSubViewport/model_container/model

var original_position = Vector3()  # Ursprüngliche Position des Containers
var original_pivot = Vector3()  # Ursprünglicher Pivot
var current_pivot = Vector3()
var target_pivot = Vector3()
var container_offset = Vector3()


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
	setup_scaling_based_on_aabb(model_container)

func _process(delta):
	if is_transitioning:
		transition_elapsed += delta
		var t = clamp(transition_elapsed / transition_duration, 0, 1)
		# Interpolierter Pivot-Übergang
		current_pivot = current_pivot.lerp(target_pivot, t)
		# Setzt die Position des Containers so, dass `target_pivot` den Fokuspunkt darstellt
		#model_container.position = original_position - (current_pivot - original_pivot)
		#print("Current MC position: ", model_container.position)
		if t >= 1.0:
			is_transitioning = false  # Übergang beendet

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
			$"..".reset_model_visibility
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

# Startet eine Explosion, bei der die Teile entlang ihrer relativen Vektoren zum center_point wegfliegen
func start_explosion(selected_part: MeshInstance3D):
	mesh_original_positions.clear()
	mesh_explosion_targets.clear()
	
	# Setze den Mittelpunkt der Explosion auf das ausgewählte Teilmodell
	var center_point = calculate_geometric_center(selected_part)
	var mesh_spheres = {}
	is_in_explosion_view = true

	# Schleife zur Einrichtung der Explosion
	for child in model.get_child(0).get_children():
		if child is MeshInstance3D and child != selected_part and !is_parent_of(selected_part, child):
			# Berechne die relative Richtung vom `center_point` zum `child`-Mesh
			var direction = (child.global_transform.origin - center_point).normalized()
			# Festlegung der Explosionsentfernung basierend auf dem `explosion_distance`-Parameter und ggf. der Größe des Objekts
			var total_distance = explosion_distance + calculate_bounding_sphere(child) * 0.1
			# Setze die Zielposition für die Explosion entlang dieser Richtung
			var target_position = child.global_transform.origin + direction * total_distance
			# Speichere die Start- und Zielposition für die Animation
			mesh_original_positions[child] = child.global_transform.origin
			mesh_explosion_targets[child] = target_position
			mesh_spheres[child] = calculate_bounding_sphere(child)

	# Kollisionsprüfung anwenden
	resolve_collisions(mesh_spheres)
	
	# Explosion starten
	explosion_elapsed = 0.0
	is_exploding = true


# Startet die Implosion und bewegt alle Meshes zurück zu ihrer ursprünglichen Position
func start_implosion():
	explosion_elapsed = 0.0
	is_imploding = true
	is_in_explosion_view = false

# Setzt den Fokus auf ein neues Submodell
func set_focus_on_object(target_node: MeshInstance3D):
	if target_node:
		target_pivot = calculate_geometric_center(target_node)
		#print("target pivot set focus: ", target_pivot)
		transition_elapsed = 0.0
		is_transitioning = true

# Zurücksetzen
func reset_focus():
	model_container.position = original_position
	current_pivot = original_pivot

func reset_focus_with_animation():
	target_pivot = original_pivot
	transition_elapsed = 0.0
	is_transitioning = true

# Berechnet die AABB und skaliert das Modell
func setup_scaling_based_on_aabb(model_node: Node):
	var aabb = calc_aabb_simple(model_node)
	if aabb.has_volume():
		var max_size = aabb.size[aabb.get_longest_axis_index()]
		Scale = 2 / max_size
		Zoom_Multiplier = 0.35 * Scale
		model_container.scale = Vector3(Scale, Scale, Scale)
		model_container.position = -Scale * aabb.get_center()

# Berechnet eine einfache AABB für das Modell
func calc_aabb_simple(n: Node) -> AABB:
	var aabb_ret = AABB()
	if n is MeshInstance3D and n.mesh:
		aabb_ret = n.mesh.get_aabb()
	for child in n.get_children():
		aabb_ret = aabb_ret.merge(calc_aabb_simple(child))
	return aabb_ret

# Berechnet eine Bounding Sphere
func calculate_bounding_sphere(mesh_instance: MeshInstance3D) -> float:
	if not mesh_instance.mesh:
		return 0.0
	var aabb = mesh_instance.mesh.get_aabb()
	return aabb.size.length() / 2.0

# Prüft, ob parent_node ein Vorfahre von child_node ist
func is_parent_of(parent_node: Node, child_node: Node) -> bool:
	var current_node = child_node
	while current_node:
		if current_node == parent_node:
			return true
		current_node = current_node.get_parent()
	return false

# Prüft auf Kollisionen und passt Positionen an
func resolve_collisions(mesh_spheres: Dictionary):
	for mesh_a in mesh_spheres.keys():
		for mesh_b in mesh_spheres.keys():
			if mesh_a != mesh_b:
				var distance = mesh_explosion_targets[mesh_a].distance_to(mesh_explosion_targets[mesh_b])
				var min_distance = mesh_spheres[mesh_a] + mesh_spheres[mesh_b]
				if distance < min_distance:
					var push_direction = (mesh_explosion_targets[mesh_a] - mesh_explosion_targets[mesh_b]).normalized()
					var push_amount = (min_distance - distance) / 2.0
					mesh_explosion_targets[mesh_a] += push_direction * push_amount
					mesh_explosion_targets[mesh_b] -= push_direction * push_amount

# Berechnet die maximale Breite eines Mesh-Objekts basierend auf den Vertex-Positionen
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
