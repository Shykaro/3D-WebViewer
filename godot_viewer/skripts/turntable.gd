###### NEW? Sphere working, but not the flyback
extends Node3D

@export var Scale = 2
@export var Zoom_Multiplier = 0.35
@export var transition_duration = 2.5
@export var explosion_distance = 5.0
@export var explosion_duration = 1.0

@onready var model_container: Node3D = $VignetteSubViewport/model_container
@onready var model: Node3D = model_container.get_child(0)

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

var is_animation_active = false

func _ready():
	#original_position = model_container.position
	#original_pivot = calculate_geometric_center(model)
	#print("Model aabb size: ", model.global_transform * model.get_aabb().get_center())
	setup_scaling_based_on_aabb(model)
	
	

func _process(delta):
	if is_transitioning:
		transition_elapsed += delta
		var t = clamp(transition_elapsed / transition_duration, 0, 1)
		# Interpolierter Pivot-Übergang
		current_pivot = current_pivot.lerp(target_pivot, t)
		# Setzt die Position des Containers so, dass `target_pivot` den Fokuspunkt darstellt
		model_container.position = original_position - (current_pivot - original_pivot)
		#print("Current MC position: ", model_container.position)
		if t >= 0.4:
			is_transitioning = false  # Übergang beendet

	if is_exploding:
		explosion_elapsed += delta
		var t = clamp(explosion_elapsed / explosion_duration, 0, 1)
	
		for mesh in mesh_original_positions.keys():
			var original_pos = mesh_original_positions[mesh]
			var target_pos = mesh_explosion_targets[mesh]
		
		# Berechne die Position relativ zur Bewegung des Containers
			mesh.transform.origin = original_pos.lerp(target_pos, t)
	
		if t >= 1.0:
			is_exploding = false
			is_animation_active = false  # Entsperren nach Abschluss der Explosion

	if is_imploding:
		explosion_elapsed += delta
		var t = clamp(explosion_elapsed / explosion_duration, 0, 1)

		for mesh in mesh_original_positions.keys():
			var original_pos = mesh_original_positions[mesh]
			var target_pos = mesh_explosion_targets[mesh]

			# Bewegt jedes Mesh zurück zur ursprünglichen Position relativ zur aktuellen Containerbewegung
			var adjusted_original_pos = model_container.to_global(original_pos)
			mesh.transform.origin = target_pos.lerp(adjusted_original_pos, t)

		if t >= 1.0:
		# Implosion beendet
			is_imploding = false
			is_animation_active = false  # Entsperren nach Abschluss der Implosion



# Hauptfunktion zur Berechnung des geometrischen Mittelpunkts THIS FINALLY WORKS JAAAAAAAAAAAAAAAAAAAAAAAA
func calculate_whole_model_center(hierarchy: Dictionary):
	var weighted_center = Vector3.ZERO
	var total_volume = 0.0  # Summe aller AABB-Volumen

	# Rekursive Funktion, die alle Mittelpunkte sammelt und gewichtet
	total_volume = collect_weighted_mesh_centers(hierarchy, weighted_center)

	print("Total volume: ", total_volume )
	if total_volume > 0:
		# Berechnung des gewichteten Mittelpunkts
		var final_center = weighted_center / total_volume
		print("Calculated weighted center: ", final_center)
		original_pivot = final_center
		current_pivot = final_center
		model_container.global_transform.origin = final_center
	else:
		# Falls keine Meshes vorhanden sind
		print("No meshes found, setting pivot to (0, 0, 0).")
		original_pivot = Vector3.ZERO
		current_pivot = Vector3.ZERO
		model_container.position = Vector3.ZERO

# Rekursive Hilfsfunktion zum Sammeln der gewichteten Mittelpunkte
func collect_weighted_mesh_centers(hierarchy: Dictionary, weighted_center: Vector3) -> float:
	var total_volume = 0.0
	for node in hierarchy:
		# Berechnung des globalen AABB-Mittelpunkts
		var global_transform = node.global_transform
		var aabb = node.mesh.get_aabb()
		var center = global_transform.origin + (global_transform.basis * aabb.get_center())
		
		# Berechnung des AABB-Volumens
		var volume = aabb.size.x * aabb.size.y * aabb.size.z

		# Gewichtung des Mittelpunkts
		weighted_center += center * volume
		total_volume += volume

		# Rekursiver Aufruf für Kinder
		total_volume += collect_weighted_mesh_centers(hierarchy[node], weighted_center)
	
	return total_volume

# Funktion zur Berechnung des geometrischen Mittelpunkts eines einzelnen Meshes
func calculate_mesh_center(mesh_instance: MeshInstance3D) -> Vector3:
	if mesh_instance and mesh_instance.mesh:
		# Holen des globalen Transform und AABB-Mittelpunkts
		var global_transform = mesh_instance.global_transform
		var aabb = mesh_instance.mesh.get_aabb()
		var center = global_transform.origin + (global_transform.basis * aabb.get_center())
		#print("Calculated center for MeshInstance3D: ", mesh_instance.name, " -> ", center)
		return center
	else:
		print("Invalid MeshInstance3D or no mesh available")
		return Vector3.ZERO

func start_explosion(selected_part: MeshInstance3D):
	if is_animation_active:
		return  # Verhindert das Starten einer neuen Explosion während einer Animation
	is_animation_active = true
	mesh_original_positions.clear()
	mesh_explosion_targets.clear()

	# Hole die aktuelle Hierarchie
	var current_hierarchy = $"..".model_hierarchy

	# Setze den Mittelpunkt der Explosion auf das ausgewählte Teilmodell
	var center_point = calculate_mesh_center(selected_part)
	print("Starting explosion. Selected part: ", selected_part.name, " Center point: ", center_point)

	var mesh_spheres = {}
	is_in_explosion_view = true

	# Bestimme den Parent-Ast der aktuellen Hierarchie
	var parent_branch = find_parent_branch(current_hierarchy, selected_part)
	#print("Parent branch for explosion: ", parent_branch.keys())

	# Füge die Explosion für alle Meshes ein, die nicht im Parent-Ast sind
	for mesh in parent_branch.keys():
		if mesh != selected_part:
			var mesh_center = calculate_mesh_center(mesh)
			var direction = (mesh_center - center_point).normalized()
			var total_distance = explosion_distance + calculate_bounding_sphere(mesh) * 0.1
			var target_position = mesh_center + direction * total_distance

			# Speichern der relativen Start- und Zielpositionen
			mesh_original_positions[mesh] = mesh.global_transform.origin
			mesh_explosion_targets[mesh] = target_position
			mesh_spheres[mesh] = calculate_bounding_sphere(mesh)

			#print("Mesh: ", mesh.name, " Original position: ", mesh_center, 
			#	  " Target position: ", target_position, " Direction: ", direction)

	resolve_collisions(mesh_spheres)
	explosion_elapsed = 0.0
	is_exploding = true
	#print("Explosion initialized. Mesh original positions: ", mesh_original_positions)
	#print("Explosion initialized. Mesh target positions: ", mesh_explosion_targets)



func calculate_bounding_sphere(mesh_instance: MeshInstance3D) -> float:
	if not mesh_instance.mesh:
		print("This isn't correct")
		return 0.0
	var aabb = mesh_instance.mesh.get_aabb()
	return aabb.size.length() / 2.0

# Prüft auf Kollisionen und passt Positionen an
func resolve_collisions(mesh_spheres: Dictionary):
	print("Resolving Collision...")
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


# Sucht den Parent-Ast, der das ausgewählte Teilmodell enthält
func find_parent_branch(hierarchy: Dictionary, selected_part: MeshInstance3D) -> Dictionary:
	for mesh in hierarchy.keys():
		if mesh == selected_part:
			# Das aktuelle Mesh ist das ausgewählte, also zurückgeben
			return hierarchy
		elif hierarchy[mesh].size() > 0:
			# Rekursiver Aufruf auf den Unterhierarchien
			var result = find_parent_branch(hierarchy[mesh], selected_part)
			if result.size() > 0:  # Prüfen, ob ein gültiges Dictionary zurückgegeben wurde
				return result
	return Dictionary()  # Rückgabe eines leeren Dictionaries statt null

func start_implosion():
	if is_animation_active:
		#print("[DEBUG] Implosion already active. Skipping.")
		return
	#print("[DEBUG] Starting implosion.")
	is_animation_active = true
	explosion_elapsed = 0.0
	is_imploding = true
	is_in_explosion_view = false

	#print("[DEBUG] Implosion original positions: ", mesh_original_positions)
	#print("[DEBUG] Implosion target positions: ", mesh_explosion_targets)


# Setzt den Fokus auf ein neues Submodell
func set_focus_on_object(target_node: Node3D):
	if target_node:
		if target_node == model:
			target_pivot = original_pivot
			#print("setting original pivot")
		else:
			target_pivot = calculate_mesh_center(target_node)
			#print("setting focussed pivot")
		#print("target pivot set focus: ", target_pivot)
		transition_elapsed = 0.0
		is_transitioning = true

## Zurücksetzen
#func reset_focus():
	#model_container.position = original_position
	#current_pivot = original_pivot
#
#func reset_focus_with_animation():
	#target_pivot = original_pivot
	#transition_elapsed = 0.0
	#is_transitioning = true

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


## Prüft, ob parent_node ein Vorfahre von child_node ist
#func is_parent_of(parent_node: Node, child_node: Node) -> bool:
	#var current_node = child_node
	#while current_node:
		#if current_node == parent_node:
			#return true
		#current_node = current_node.get_parent()
	#return false
#
#
## Berechnet die maximale Breite eines Mesh-Objekts basierend auf den Vertex-Positionen
#func calculate_max_width_from_vertices(mesh_instance: MeshInstance3D) -> float:
	#if not mesh_instance.mesh:
		#return 0.0
	#var vertices = []
	#for i in range(mesh_instance.mesh.get_surface_count()):
		#var array = mesh_instance.mesh.surface_get_arrays(i)
		#if array.size() > Mesh.ARRAY_VERTEX:
			#var surface_vertices = array[Mesh.ARRAY_VERTEX]
			#for vertex in surface_vertices:
				#vertices.append(mesh_instance.transform.origin + mesh_instance.transform.basis * vertex)
#
	#var min_point = vertices[0]
	#var max_point = vertices[0]
	#for vertex in vertices:
		#min_point = min_point.min(vertex)
		#max_point = max_point.max(vertex)
#
	#var size = max_point - min_point
	#return size.length()
