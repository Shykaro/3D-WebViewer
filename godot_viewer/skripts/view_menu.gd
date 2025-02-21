extends Control

# --- Material-Resourcen ---
@export var wireframe_material: Resource = preload("res://materials/WireframeMaterial.tres")
@export var textured_material: Resource = preload("res://materials/UVGridTexture.tres")
@export var normals_material: Resource = preload("res://materials/NormalsMaterial.tres")
@export var metallic_material: Resource = preload("res://materials/MetallicMatCap.tres")
@export var matcap_material: Resource = preload("res://materials/MatCapMaterial.tres")
@export var active_material: Resource

var original_material_on: bool = true

@onready var model_container: Node3D = $"../../../turntable/VignetteSubViewport/model_container"
@onready var main: Node3D = $"../../.."

@export var panel_width = 300
@export var animation_time = 0.3
var is_expanded = false
var tween

@onready var side_container: Control = $HBoxContainer
@onready var menu_button: TextureButton = $HBoxContainer/ArrowPanel/MarginContainer/BurgerButton
@onready var popup_menu: Control = $HBoxContainer/PopupMenu

var side_container_OG_position

@export var menu_open = false

var mouse_currently_over_menu

var original_materials = {}

func _ready():
	side_container_OG_position = side_container.position.x 
	side_container.position.x = side_container.position.x + popup_menu.size.x
	is_expanded = false
	#_save_original_materials()


# -------------------------------------------------------------------------
# AUSKLAPP- / EINKLAPP-LOGIK
# -------------------------------------------------------------------------

func _on_burger_button_pressed():
	#print("Burger Button Pressed!")
	is_expanded = not is_expanded
	animate_container(is_expanded)

func animate_container(expanded: bool):
	if tween and tween.is_valid():
		tween.kill()
	
	var menu_width = popup_menu.size.x 
	# EndX=0 wenn expanded, sonst -menu_width
	var end_x = side_container_OG_position if expanded else (side_container.position.x + popup_menu.size.x)
	var final_scale_x = -1 if expanded else 1

	tween = get_tree().create_tween()
	tween.tween_property(side_container, "position:x", end_x, animation_time) \
		.set_trans(Tween.TRANS_EXPO) \
		.set_ease(Tween.EASE_OUT)


	tween.parallel().tween_property($HBoxContainer/ArrowPanel/MarginContainer, "scale:x", final_scale_x, animation_time)

# -------------------------------------------------------------------------
# Popup / Menü-Logik
# -------------------------------------------------------------------------

func _update_menu_visibility():
	popup_menu.visible = menu_open

#func _on_wire_frame_pressed():
	#_set_model_material(wireframe_material)
	##_close_popup()
#
#func _on_uv_grid_pressed():
	#_set_model_material(textured_material)
	##_close_popup()
#
#func _on_normals_pressed():
	#_set_model_material(normals_material)
	##_close_popup()
#
#func _on_metallic_pressed():
	#_set_model_material(metallic_material)
	##_close_popup()
#
#func _on_mat_cap_pressed():
	#_set_model_material(matcap_material)
	##_close_popup()
#
func _on_shaded_pressed():
	_reset_to_original_material()
	#_close_popup()
#
#func _on_ev_active_pressed():
	#main.EV_active = not main.EV_active

func _on_wire_frame_toggled(toggled_on):
	if toggled_on:
		_set_model_material(wireframe_material)
	else:
		_reset_to_original_material()
	pass


func _on_normals_toggled(toggled_on):
	if toggled_on:
		_set_model_material(normals_material)
	else:
		_reset_to_original_material()
	pass 


func _on_uv_grid_toggled(toggled_on):
	if toggled_on:
		_set_model_material(textured_material)
	else:
		_reset_to_original_material()
	pass


func _on_metallic_toggled(toggled_on):
	if toggled_on:
		_set_model_material(metallic_material)
	else:
		_reset_to_original_material()
	pass


func _on_mat_cap_toggled(toggled_on):
	if toggled_on:
		_set_model_material(matcap_material)
	else:
		_reset_to_original_material()
	pass


func _on_ev_active_toggled(toggled_on):
	main.EV_active = not main.EV_active
	pass



func _close_popup():
	menu_open = false
	_update_menu_visibility()

# -------------------------------------------------------------------------
# Material / Modell-Funktionen
# -------------------------------------------------------------------------

func _set_model_material(material: Resource):
	original_material_on = false
	active_material = material
	var meshes = _find_all_meshes_in_hierarchy(main.model_hierarchy)
	for mesh in meshes:
		if mesh.mesh:
			for i in range(mesh.mesh.get_surface_count()):
				mesh.set_surface_override_material(i, material)

# Originalmaterialien wiederherstellen
func _reset_to_original_material():
	original_material_on = true
	var meshes = _find_all_meshes_in_hierarchy(main.model_hierarchy)
	for mesh in meshes:
		reset_material_to_original(mesh)

# Speichert die Originalmaterialien des Modells
func _save_original_materials():
	original_materials.clear()
	var meshes = _find_all_meshes_in_hierarchy(main.model_hierarchy)
	for mesh in meshes:
		if mesh.mesh:
			var surfaces = []
			for i in range(mesh.mesh.get_surface_count()):
				var material = mesh.get_surface_override_material(i)
				if not material:
					material = mesh.mesh.surface_get_material(i)
				surfaces.append(material)
			original_materials[mesh] = surfaces
			#print("original materials: ", original_materials)

func _find_all_meshes_in_hierarchy(hierarchy: Dictionary) -> Array:
	var meshes = []
	for mesh_instance in hierarchy.keys():
		if mesh_instance is MeshInstance3D:
			meshes.append(mesh_instance)
			var child_hierarchy = hierarchy[mesh_instance]
			if child_hierarchy.size() > 0:
				meshes += _find_all_meshes_in_hierarchy(child_hierarchy)
	return meshes

func reset_material_to_original(part: MeshInstance3D):
	if part in original_materials:
		var surfaces = original_materials[part]
		for i in range(len(surfaces)):
			part.set_surface_override_material(i, surfaces[i])
			var material = surfaces[i]
			if material and material is BaseMaterial3D and material.albedo_color.a < 1.0:
				material.set_transparency(BaseMaterial3D.TRANSPARENCY_ALPHA)
				material.albedo_color.a = 0.2

#func _on_arrow_panel_mouse_entered():
	#mouse_currently_over_menu = true
	#print("Set mouse entered: ", mouse_currently_over_menu)
	#pass
#
#
#func _on_arrow_panel_mouse_exited():
	#mouse_currently_over_menu = false
	#print("Set mouse entered: ", mouse_currently_over_menu)
	#pass
#
#
#func _on_menu_panel_mouse_entered():
	#mouse_currently_over_menu = true
	#print("Set mouse entered: ", mouse_currently_over_menu)
	#pass
#
#
#func _on_menu_panel_mouse_exited():
	#mouse_currently_over_menu = false
	#print("Set mouse entered: ", mouse_currently_over_menu)
	#pass
