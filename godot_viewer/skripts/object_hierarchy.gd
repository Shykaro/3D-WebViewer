extends Node

# Struktur zur Verwaltung der Hierarchien
var hierarchy_levels = {}

# Initialisierung der Hierarchie
func initialize_hierarchy(root_node):
	# Rekursive Funktion, um alle Objekte und ihre Ebenen zu durchlaufen
	_collect_hierarchy(root_node, 0)

# Rekursive Funktion zur Erstellung der Hierarchie
func _collect_hierarchy(node, level):
	if not hierarchy_levels.has(level):
		hierarchy_levels[level] = []

	hierarchy_levels[level].append(node)

	# Alle Kinder des aktuellen Knotens durchlaufen und Hierarchie aufbauen
	for child in node.get_children():
		# Weiter in die Tiefe gehen, falls das Kind ebenfalls eine Geometrie besitzt
		if child is Node3D:
			_collect_hierarchy(child, level + 1)
