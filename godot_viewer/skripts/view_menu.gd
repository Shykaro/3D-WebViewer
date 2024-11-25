extends Node

# Materialien für die verschiedenen Ansichten
@export var wireframe_material: Resource = preload("res://materials/WireframeMaterial.tres")
@export var textured_material: Resource = preload("res://materials/TexturedMaterial.tres")
@export var normals_material: Resource = preload("res://materials/NormalsMaterial.tres")
@export var active_material: Resource
@onready var model_container: Node3D = $"../../../turntable/VignetteSubViewport/model_container"

# Referenzen für Popup-Menü und Button
@onready var menu_button: TextureButton = $BurgerButton
@onready var popup_menu: VBoxContainer = $PopupMenu

# Originalmaterialien speichern
var original_materials = {}
@export var menu_open = false  # Status des Menüs

func _ready():
	_save_original_materials()  # Speichert die Originalmaterialien des Modells
	_update_menu_visibility()  # Menü initial ausblenden
	

# Blockiere Eingaben, während Menü interagiert wird
func _on_burger_button_pressed():
	menu_open = not menu_open
	_update_menu_visibility()

# Aktualisiert die Sichtbarkeit des Popup-Menüs basierend auf `menu_open`
func _update_menu_visibility():
	popup_menu.visible = menu_open

# --- Material-Logik ---
# Callback-Funktion: Wireframe-Ansicht aktivieren
func _on_wire_frame_pressed():
	_set_model_material(wireframe_material)
	menu_open = false  # Menü schließen nach Auswahl
	_update_menu_visibility()

# Callback-Funktion: Texturierte Ansicht aktivieren
func _on_textured_pressed():
	_set_model_material(textured_material)
	menu_open = false  # Menü schließen nach Auswahl
	_update_menu_visibility()

# Callback-Funktion: Normalen-Ansicht aktivieren
func _on_normals_pressed():
	_set_model_material(normals_material)
	menu_open = false  # Menü schließen nach Auswahl
	_update_menu_visibility()

# Callback-Funktion: Schattierte Ansicht (Standard) aktivieren
func _on_shaded_pressed():
	_reset_to_original_material()
	menu_open = false  # Menü schließen nach Auswahl
	_update_menu_visibility()

# Speichert die Originalmaterialien des Modells
func _save_original_materials():
	original_materials.clear()
	var meshes = _find_all_meshes_in_node(model_container)
	for mesh in meshes:
		if mesh.mesh:
			var surfaces = []
			for i in range(mesh.mesh.get_surface_count()):
				var material = mesh.get_surface_override_material(i)
				if not material:
					material = mesh.mesh.surface_get_material(i)
				surfaces.append(material)
			original_materials[mesh] = surfaces

# Setzt ein bestimmtes Material für das gesamte Modell
func _set_model_material(material: Resource):
	active_material = material  # Speichere das aktive Material
	var meshes = _find_all_meshes_in_node(model_container)
	for mesh in meshes:
		if mesh.mesh:
			for i in range(mesh.mesh.get_surface_count()):
				mesh.set_surface_override_material(i, material)

func _reset_to_original_material():
	var meshes = _find_all_meshes_in_node(model_container)
	for mesh in meshes:
		reset_material_to_original(mesh)


# Findet alle MeshInstance3D-Knoten im gegebenen Node
func _find_all_meshes_in_node(node: Node) -> Array:
	var meshes = []
	for child in node.get_children():
		if child is MeshInstance3D:
			meshes.append(child)
		elif child.get_child_count() > 0:
			meshes.append_array(_find_all_meshes_in_node(child))
	return meshes
	
func reset_material_to_original(part: MeshInstance3D):
	if part in original_materials:
		var surfaces = original_materials[part]
		for i in range(len(surfaces)):
			part.set_surface_override_material(i, surfaces[i])
			# Transparenz beibehalten, falls aktiv
			var material = surfaces[i]
			if material and material is BaseMaterial3D and material.albedo_color.a < 1.0:
				material.set_transparency(BaseMaterial3D.TRANSPARENCY_ALPHA)
				material.albedo_color.a = 0.2
