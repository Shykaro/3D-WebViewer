extends Node3D

@export var Scale = 2  # Basis-Skalierungswert
@export var Zoom_Multiplier = 0.35  # Multiplikator für die Kameraentfernung (kleinere Werte erhöhen die Distanz)
var original_position = Vector3()  # Speichert die ursprüngliche Position des `model_container`
var original_pivot = Vector3()  # Speichert den ursprünglichen Pivot-Punkt
var current_pivot = Vector3()  # Speichert den aktuellen Drehmittelpunkt des Modells

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

# Setzt den Fokus auf das aktuelle Zielobjekt, indem das Modell relativ verschoben wird
func set_focus_on_object(target_node: Node):
	if not target_node:
		return

	# Berechne die neue geometrische Mitte basierend auf dem Zielknoten
	var new_center = calculate_geometric_center(target_node)

	# Berechne den Verschiebungsvektor (Offset) zwischen der alten Mitte und der neuen
	var offset = new_center - current_pivot

	# Passe die Position des `model_container` relativ an, um die neue Mitte als Drehmittelpunkt zu verwenden
	$model_container.position -= offset  # Verschiebe das gesamte Modell um den Offset
	current_pivot = new_center  # Setze den neuen Mittelpunkt als aktuellen Pivot

	#print("Neuer geometrischer Mittelpunkt gesetzt auf: ", current_pivot, " - Modell verschoben um Offset: ", offset)

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

# Berechnet die Axis-Aligned Bounding Box (AABB) nur für das ausgewählte Mesh (mit Transformation)
func calc_aabb_single_mesh(n: Node) -> AABB:
	var aabb_ret = AABB()

	# Nur wenn es sich um einen MeshInstance3D handelt und ein Mesh vorhanden ist
	if n is MeshInstance3D and n.mesh:
		# Hole die lokale AABB des Meshes
		var local_aabb = n.mesh.get_aabb() #.get_aabb() nimmt NICHT das gewählte Mesh, sondern ALLE... wieso?
		# Wende die Transformation des Nodes auf das AABB an
		aabb_ret = local_aabb.transformed(n.transform)
	
	return aabb_ret


# Berechnet die maximale Breite basierend auf den Vertices eines MeshInstance3D
func calculate_max_width_from_vertices(mesh_instance: MeshInstance3D) -> float:
	if not mesh_instance.mesh:
		return 0.0  # Kein Mesh vorhanden

	var vertices = []
	for i in range(mesh_instance.mesh.get_surface_count()):
		var array = mesh_instance.mesh.surface_get_arrays(i)
		if array.size() > Mesh.ARRAY_VERTEX:
			var surface_vertices = array[Mesh.ARRAY_VERTEX]
			for vertex in surface_vertices:
				# Transformiere jeden Vertex mit der Transform des MeshInstance3D (Matrixmultiplikation)
				vertices.append(mesh_instance.transform.origin + mesh_instance.transform.basis * vertex)

	# Finde die Extrempunkte in den Achsen
	var min_point = vertices[0]
	var max_point = vertices[0]
	for vertex in vertices:
		min_point = min_point.min(vertex)
		max_point = max_point.max(vertex)

	# Berechne die Breite (längste Achse) basierend auf den Extrempunkten
	var size = max_point - min_point
	return size.length()


# Dynamische Anpassung der Skalierung und des Zoom-Verhaltens basierend auf der AABB des Modells
func setup_scaling_based_on_aabb(model_node: Node):
	var aabb = calc_aabb_simple(model_node)
	
	# Überprüfe, ob das AABB Volumen hat (also ein sichtbares Objekt darstellt)
	if aabb.has_volume():
		var max_size = aabb.size[aabb.get_longest_axis_index()]
		
		# Passe die Skalierung basierend auf der größten Dimension des Modells an
		Scale = 2 / max_size  # Passe diesen Wert ggf. je nach gewünschter Grundskalierung an
		
		# Setze einen dynamischen Zoom-Multiplikator basierend auf der Größe
		Zoom_Multiplier = 0.35 * Scale  # Der Zoom-Multiplikator sollte sich ebenfalls an die Modellgröße anpassen
		
		# Setze die initiale Position und Skalierung des Modells
		$model_container.scale = Vector3(Scale, Scale, Scale)
		$model_container.position = -Scale * aabb.get_center()

		#print("Modellgröße angepasst - Max Size: ", max_size)
		#print("Neue Skalierung: ", Scale, ", Neuer Zoom Multiplikator: ", Zoom_Multiplier)
	else:
		print("Fehler: AABB des Modells hat kein Volumen!")

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

# Setzt das Modell auf die ursprüngliche Position zurück
func reset_focus():
	#print("Setze das Modell auf die ursprüngliche Position zurück.")
	$model_container.position = original_position  # Setze die Position des Modells zurück
	current_pivot = original_pivot  # Setze den ursprünglichen Pivot wieder ein
	#print("Modell-Pivot-Punkt auf ursprüngliche Position zurückgesetzt:", current_pivot)
