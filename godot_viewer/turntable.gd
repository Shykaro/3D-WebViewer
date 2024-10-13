extends Node3D

@export var Scale = 2  # Basis-Skalierungswert
@export var Zoom_Multiplier = 0.35  # Multiplikator für die Kameraentfernung (kleinere Werte erhöhen die Distanz)
@export var transition_duration = 0.5  # Dauer des Schwenk-Übergangs in Sekunden

var original_position = Vector3()  # Speichert die ursprüngliche Position des `model_container`
var original_pivot = Vector3()  # Speichert den ursprünglichen Pivot-Punkt
var current_pivot = Vector3()  # Speichert den aktuellen Drehmittelpunkt des Modells

var target_pivot = Vector3()  # Zielpivot für die Animation
var transition_elapsed = 0.0  # Zeit, die für den Übergang bisher vergangen ist
var is_transitioning = false  # Gibt an, ob ein Übergang aktiv ist

# Speichert die ursprüngliche Position und den Pivot-Punkt beim Start des Programms
func _ready():
	# Speichere die ursprüngliche Position des `model_container`
	original_position = $model_container.position
	# Berechne den aktuellen Pivot-Punkt basierend auf dem gesamten Modell
	original_pivot = calculate_geometric_center($model_container)
	current_pivot = original_pivot  # Initialisieren des aktuellen Pivot-Punkts
	#print("Ursprünglicher Mittelpunkt des Modells berechnet: ", original_pivot)
	# Setze den Mittelpunkt initial auf das gesamte Modell
	set_focus_on_object($model_container)
	# Führe die dynamische Skalierung basierend auf der Modellgröße durch
	setup_scaling_based_on_aabb($model_container)

# Wird im Prozess-Callback aufgerufen, um den Übergang zu animieren
func _process(delta):
	if is_transitioning:
		# Erhöhe die verstrichene Zeit
		transition_elapsed += delta

		# Berechne, wie weit der Übergang fortgeschritten ist (zwischen 0 und 1)
		var t = clamp(transition_elapsed / transition_duration, 0, 1)

		# Verwende lerp für einen fließenden Übergang zwischen current_pivot und target_pivot
		var new_pivot = current_pivot.lerp(target_pivot, t)

		# Berechne den Offset zwischen dem alten und dem neuen Pivot
		var offset = new_pivot - current_pivot

		# Verschiebe das Modell entsprechend
		$model_container.position -= offset
		current_pivot = new_pivot  # Aktualisiere den aktuellen Pivot

		# Beende den Übergang, wenn t = 1 erreicht ist
		if t >= 1.0:
			is_transitioning = false


# Berechnet den geometrischen Mittelpunkt aller sichtbaren Meshes innerhalb des Modells
func calculate_geometric_center(target_node: Node) -> Vector3:
	var total_position = Vector3()
	var count = 0

	# Durchlaufe alle sichtbaren Meshes des Zielknotens
	for child in target_node.get_children():
		if child is MeshInstance3D and child.visible:
			# Addiere die Position des sichtbaren Meshes
			total_position += child.global_transform.origin
			count += 1

	# Überprüfe, ob Meshes gefunden wurden, um eine Division durch 0 zu vermeiden
	if count > 0:
		return total_position / count  # Berechne den geometrischen Durchschnitt
	else:
		return target_node.global_transform.origin  # Standard: Ursprung des Knotens

# Setzt den Fokus auf das aktuelle Zielobjekt, animiert den Übergang
func set_focus_on_object(target_node: Node):
	if not target_node:
		return

	# Berechne die neue geometrische Mitte basierend auf dem Zielknoten
	var new_center = calculate_geometric_center(target_node)

	# Setze die Zielposition des Pivot-Points
	target_pivot = new_center
	transition_elapsed = 0.0  # Zurücksetzen des Übergangs-Timers
	is_transitioning = true  # Starte die Animation


# Berechnet die Axis-Aligned Bounding Box (AABB) für einen MeshNode ohne zusätzliche Transformationen
func calc_aabb_simple(n: Node) -> AABB:
	var aabb_ret = AABB()
	#print("n: ", n)
	# Nur wenn es sich um einen MeshInstance3D handelt und ein Mesh vorhanden ist
	if n is MeshInstance3D and n.mesh:
		aabb_ret = n.mesh.get_aabb()  # Hole die lokale AABB des Meshes
		
	for child in n.get_children():
		aabb_ret = aabb_ret.merge(calc_aabb_simple(child))  # Rekursiv die AABBs der Kinder hinzufügen

	return aabb_ret

# Dynamische AABB-Berechnung für nur das ausgewählte Mesh
func calc_aabb_single_mesh(n: Node) -> AABB:
	var aabb_ret = AABB()

	if n is MeshInstance3D and n.mesh:
		# Berechne AABB nur für das spezifische Mesh
		aabb_ret = n.mesh.get_aabb().transformed(n.transform)
	
	return aabb_ret


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

	# Finde die Extrempunkte
	var min_point = vertices[0]
	var max_point = vertices[0]
	for vertex in vertices:
		min_point = min_point.min(vertex)
		max_point = max_point.max(vertex)

	var size = max_point - min_point
	return size.length()


func setup_scaling_based_on_aabb(model_node: Node):
	var aabb = calc_aabb_simple(model_node)
	
	if aabb.has_volume():
		var max_size = aabb.size[aabb.get_longest_axis_index()]
		Scale = 2 / max_size
		Zoom_Multiplier = 0.35 * Scale
		
		$model_container.scale = Vector3(Scale, Scale, Scale)
		$model_container.position = -Scale * aabb.get_center()

func reset_focus():
	$model_container.position = original_position
	current_pivot = original_pivot

# Setzt den Pivot zurück auf den ursprünglichen Punkt mit einer Animation
func reset_focus_with_animation():
	# Setze die Zielposition auf den ursprünglichen Pivot-Punkt (zentriert auf das gesamte Modell)
	target_pivot = original_pivot
	transition_elapsed = 0.0  # Setze den Übergangs-Timer zurück
	is_transitioning = true  # Starte die Animation
