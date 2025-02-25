extends Node3D

@export var Scale = 2
@export var Zoom_Multiplier = 0.35
@export var transition_duration = 1.0
@export var explosion_distance = 2.0
@export var explosion_duration = 1.0

var start_position = Vector3()
var end_position = Vector3()
var current_position = Vector3()

@onready var model_container: Node3D = $VignetteSubViewport/model_container
@onready var model: Node3D = model_container.get_child(0)

var original_position = Vector3()
var original_pivot = Vector3()
var current_pivot = Vector3()
var target_pivot = Vector3()
var container_offset = Vector3()

var weighted_center = Vector3.ZERO

var transition_elapsed = 0.0
var is_transitioning = false
var is_exploding = false
var is_in_explosion_view = false
var is_imploding = false
var explosion_elapsed = 0.0

var mesh_original_positions: Dictionary = {}
var mesh_explosion_targets: Dictionary = {}
var exploded_meshes: Dictionary = {}
var state_stack: Array = []
var last_state: Dictionary = {}

var current_level: int = 0

var is_animation_active = false


func push_state():
	var current_state = {}
	for mesh in mesh_original_positions.keys():
		current_state[mesh] = mesh_original_positions[mesh]
	state_stack.insert(current_level, current_state)
	current_level += 1
	
	#print("current state added: ", state_stack)
	print("[DEBUG] Zustand gespeichert. Stackgröße:", current_level)

func pop_state():
	if state_stack.size() > 0:
		current_level -= 1
		last_state = state_stack[current_level]
		#print("Last state: ", last_state)
		#for mesh in last_state.keys():
			#mesh.global_transform.origin = last_state[mesh]
		print("[DEBUG] Zustand wiederhergestellt. Stackgröße:", current_level)
	else:
		print("[DEBUG] Stack ist leer. Keine Zustände zum Wiederherstellen.")
		pass

func _ready():
	scale_model_to_fit(model_container.get_child(0))
	pass

func _process(delta):
	if is_transitioning:
		transition_elapsed += delta
		var t = clamp(transition_elapsed / transition_duration, 0, 1)
		current_pivot = start_position.lerp(end_position, t)
		model_container.position = start_position.lerp(end_position, t)

		if t >= 1:
			is_transitioning = false
			model_container.position = end_position

	if is_exploding:
		explosion_elapsed += delta
		var t = clamp(explosion_elapsed / explosion_duration, 0, 1)

		for mesh in mesh_original_positions.keys():
			var original_pos = mesh_original_positions[mesh]
			var target_pos = mesh_explosion_targets[mesh]
			var new_pos = original_pos.lerp(target_pos, t)

			var current_gtf = mesh.global_transform
			current_gtf.origin = new_pos
			mesh.global_transform = current_gtf

		if t >= 1.0:
			is_exploding = false
			is_animation_active = false

	if is_imploding:
		explosion_elapsed += delta
		var t = clamp(explosion_elapsed / explosion_duration, 0, 1)

		for mesh in last_state.keys():
			var original_pos = last_state[mesh]
			var target_pos = mesh_explosion_targets[mesh]
			var new_pos = target_pos.lerp(original_pos, t)

			var current_gtf = mesh.global_transform
			current_gtf.origin = new_pos
			mesh.global_transform = current_gtf

		if t >= 1.0:
			is_imploding = false
			is_animation_active = false

# Berechnet den gewichteten Schwerpunkt des Modells
func calculate_whole_model_center(hierarchy: Dictionary):
	weighted_center = Vector3.ZERO
	var total_volume = collect_weighted_mesh_centers(hierarchy)

	if total_volume > 0:
		var final_center = weighted_center / total_volume
		original_pivot = final_center
		current_pivot = final_center
		model_container.global_transform.origin = -final_center
	else:
		original_pivot = Vector3.ZERO
		current_pivot = Vector3.ZERO
		model_container.position = Vector3.ZERO

func scale_model_to_fit(model_node: Node):
	var aabb = $"../camera_rig".calculate_global_aabb(model_node)
	if aabb.has_volume():
		var max_size = aabb.size[aabb.get_longest_axis_index()]
		var scale_factor = 2.0 / max_size
		print("Scaled by: ", scale_factor)
		model_container.scale = Vector3(scale_factor, scale_factor, scale_factor)
	else:
		print("Das Modell hat kein Volumen")


func collect_weighted_mesh_centers(hierarchy: Dictionary) -> float:
	var total_volume = 0.0
	for node in hierarchy:
		var global_transform = node.global_transform
		var aabb = node.mesh.get_aabb()
		var center = global_transform.origin + (global_transform.basis * aabb.get_center())

		var volume = aabb.size.x * aabb.size.y * aabb.size.z
		weighted_center += center * volume
		total_volume += volume

		total_volume += collect_weighted_mesh_centers(hierarchy[node])
	return total_volume

# Berechnet den Mittelpunkt eines Meshes
func calculate_mesh_center(mesh_instance: MeshInstance3D) -> Vector3:
	if mesh_instance and mesh_instance.mesh:
		var gtf = mesh_instance.global_transform
		var aabb = mesh_instance.mesh.get_aabb()
		return gtf.origin + (gtf.basis * aabb.get_center())
	return Vector3.ZERO


func start_explosion(selected_part: MeshInstance3D):
	if is_animation_active:
		return
	is_animation_active = true
	mesh_original_positions.clear() #WICHTIG
	#mesh_explosion_targets.clear()	#WICHTIG, näher anschauen

	var current_hierarchy = $"..".model_hierarchy
	var center_point = calculate_mesh_center(selected_part)

	is_in_explosion_view = true
	var parent_branch = find_parent_branch(current_hierarchy, selected_part)

	var selected_radius = calculate_bounding_sphere(selected_part)

	for mesh in parent_branch.keys():
		if mesh != selected_part:
			var mesh_center = calculate_mesh_center(mesh)
			var direction = (mesh_center - center_point).normalized()

			# Dynamische Distanz
			var own_radius = calculate_bounding_sphere(mesh)
			var total_dist = explosion_distance + own_radius + selected_radius

			var target_pos = mesh_center + direction * total_dist

			mesh_original_positions[mesh] = mesh.global_transform.origin
			mesh_explosion_targets[mesh] = target_pos
			exploded_meshes[mesh] = true
			#print("Mesh in explosiontargets: ", mesh_explosion_targets)
			
	push_state()
	resolve_collisions(mesh_explosion_targets)
	explosion_elapsed = 0.0
	is_exploding = true

# Startet die Implosion, um die Objekte zurückzubewegen
func start_implosion():
	pop_state()
	exploded_meshes.clear()
	if is_animation_active:
		return
	is_animation_active = true
	explosion_elapsed = 0.0
	is_imploding = true
	is_in_explosion_view = false
	

# Behebt Kollisionen zwischen Mesh-Zielpositionen
func resolve_collisions(explosion_targets: Dictionary):
	for mesh_a in explosion_targets.keys():
		for mesh_b in explosion_targets.keys():
			if mesh_a != mesh_b:
				var dist = explosion_targets[mesh_a].distance_to(explosion_targets[mesh_b])
				var min_dist = calculate_bounding_sphere(mesh_a) + calculate_bounding_sphere(mesh_b)
				if dist < min_dist:
					var push_dir = (explosion_targets[mesh_a] - explosion_targets[mesh_b]).normalized()
					var push_amount = (min_dist - dist) / 2.0

					explosion_targets[mesh_a] += push_dir * push_amount
					explosion_targets[mesh_b] -= push_dir * push_amount

# Berechnet die Bounding-Sphere eines Meshes
func calculate_bounding_sphere(mesh_instance: MeshInstance3D) -> float:
	if not mesh_instance.mesh:
		return 0.0
	var aabb = mesh_instance.mesh.get_aabb()
	return aabb.size.length() / 2.0

# Findet die Hierarchie eines Elternteils
func find_parent_branch(hierarchy: Dictionary, selected_part: MeshInstance3D) -> Dictionary:
	for mesh in hierarchy.keys():
		if mesh == selected_part:
			return hierarchy
		elif hierarchy[mesh].size() > 0:
			var result = find_parent_branch(hierarchy[mesh], selected_part)
			if result.size() > 0:
				return result
	return Dictionary()

## Skaliert das Modell basierend auf seinem AABB
#func setup_scaling_based_on_aabb(model_node: Node):
	#var aabb = calc_aabb_simple(model_node)
	#if aabb.has_volume():
		#var max_size = aabb.size[aabb.get_longest_axis_index()]
		#Scale = 2 / max_size
		#Zoom_Multiplier = 0.35 * Scale
		#model_container.scale = Vector3(Scale, Scale, Scale)
#
#func calc_aabb_simple(n: Node) -> AABB:
	#var aabb_ret = AABB()
	#if n is MeshInstance3D and n.mesh:
		#aabb_ret = n.mesh.get_aabb()
	#for child in n.get_children():
		#aabb_ret = aabb_ret.merge(calc_aabb_simple(child))
	#return aabb_ret

# Setzt den Fokus auf ein Zielobjekt
func set_focus_on_object(target_node: Node3D):
	if target_node:
		if target_node == model:
			target_pivot = original_pivot
			start_position = model_container.position
			end_position = -target_pivot
		else:
			target_pivot = calculate_mesh_center(target_node)
			start_position = model_container.position
			end_position = model_container.position - target_pivot

		transition_elapsed = 0.0
		is_transitioning = true
