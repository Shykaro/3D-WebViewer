extends Node3D

@export var Scale = 2  # Basis-Skalierungswert
@export var Zoom_Multiplier = 0.35  # Multiplikator für die Kameraentfernung (niedrigere Werte erhöhen die Distanz)
var current_aabb = AABB()  # Speichert die aktuelle Axis-Aligned Bounding Box
var original_position = Vector3()  # Speichert die ursprüngliche Position des `model_container`
var original_turntable_position = Vector3()  # Speichert die ursprüngliche Position des Turntables

# Berechnet die Axis-Aligned Bounding Box (AABB) für einen MeshNode ohne zusätzliche Transformationen
func calc_aabb_simple(n: Node) -> AABB:
	var aabb_ret = AABB()
	
	# Nur wenn es sich um einen MeshInstance3D handelt und ein Mesh vorhanden ist
	if n is MeshInstance3D and n.mesh:
		aabb_ret = n.mesh.get_aabb()  # Hole die lokale AABB des Meshes

	for child in n.get_children():
		aabb_ret = aabb_ret.merge(calc_aabb_simple(child))  # Rekursiv die AABBs der Kinder hinzufügen

	return aabb_ret

# Setzt den Fokus auf das aktuelle Zielobjekt (z.B. ein neues Teilobjekt)
func set_focus_on_object(target_node: Node):
	if not target_node:
		return

	# Berechne die Axis-Aligned Bounding Box (AABB) für das aktuelle Zielobjekt
	var aabb = calc_aabb_simple(target_node)
	if aabb.has_volume():
		# Speichere den aktuellen AABB für den Fokus
		current_aabb = aabb
		print("Current aabb: ", aabb)
		var max_size = aabb.size[aabb.get_longest_axis_index()]
		
		# Verwende den Zoom-Multiplikator, um die Skalierung zu beeinflussen
		var scale_fac = (Scale / max_size) * Zoom_Multiplier
		#print("Scale_fac:", scale_fac)

		# Setze die neue Skalierung und Position des `model_container` relativ zur Root-Ebene
		$model_container.scale = Vector3(scale_fac, scale_fac, scale_fac)
		$model_container.position = -scale_fac * aabb.get_center()  # Setze die Position relativ zur Mitte

		# Berechne den neuen Drehmittelpunkt des `turntable` direkt aus dem AABB
		self.position = aabb.position + (aabb.size / 2)  # Setze den Drehmittelpunkt auf das Zentrum der AABB
		#print("aabb positions:", aabb.position)
		print("Neuer Pivot-Punkt des Turntables gesetzt auf: ", self.position)
	else:
		print("AABB hat kein Volumen, Fokus nicht gesetzt")

# Wird aufgerufen, wenn das Skript initial geladen wird
func _ready():
	# Speichere die ursprüngliche Position des `model_container` und des `turntable`
	original_position = $model_container.position
	original_turntable_position = self.position

	# Setze den Mittelpunkt initial auf das gesamte Modell
	set_focus_on_object($model_container)

# Setzt den Turntable und den Model Container auf das Root-Objekt zurück
func reset_focus():
	print("Setze Turntable und Model Container zurück auf ursprüngliche Position.")
	$model_container.position = original_position
	$model_container.scale = Vector3(1, 1, 1)  # Setze die Skalierung zurück
	self.position = original_turntable_position  # Setze den Turntable-Pivot zurück
