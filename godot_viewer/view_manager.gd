extends Node

# Referenzen auf das Hauptmodell und die Kamera
@export var model_node: MeshInstance3D
@export var camera_node: Camera3D

# Aktuelle Ansicht
var current_view = "shaded"

# Materialreferenzen
var original_materials = []
var wireframe_material = preload("res://materials/WireframeMaterial.tres")
var normals_material = preload("res://materials/NormalsMaterial.tres")
var textured_material = preload("res://materials/TexturedMaterial.tres")

func _ready():
	# Sicherstellen, dass alle originalen Materialien gespeichert werden
	if model_node:
		_store_original_materials()

# Speichert die Originalmaterialien des Modells
func _store_original_materials():
	original_materials.clear()
	for surface in model_node.mesh.get_surface_count():
		original_materials.append(model_node.mesh.surface_get_material(surface))

# Setzt die Ansicht (Aufruf durch das Signal aus `view_menu.gd`)
func set_view_mode(mode: String):
	current_view = mode
	match mode:
		"wireframe":
			_apply_material(wireframe_material)
		"normals":
			_apply_material(normals_material)
		"textured":
			_apply_material(textured_material)
		"shaded":
			_restore_original_materials()
		_:
			print("Unbekannter Modus: %s" % mode)

# Wendet ein Material auf alle Oberflächen des Modells an
func _apply_material(material: Material):
	if model_node:
		for surface in model_node.mesh.get_surface_count():
			model_node.mesh.surface_set_material(surface, material)

# Stellt die Originalmaterialien des Modells wieder her
func _restore_original_materials():
	if model_node and original_materials.size() == model_node.mesh.get_surface_count():
		for surface in range(original_materials.size()):
			model_node.mesh.surface_set_material(surface, original_materials[surface])

# Debugging (zum Testen in der Ausgabe)
func print_current_view():
	print("Aktuelle Ansicht: %s" % current_view)
