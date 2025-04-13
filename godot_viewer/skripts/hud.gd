extends Control

@onready var camera: Camera3D = $"../../camera_rig/camera_arm/camera"
@onready var camera_light = $"../../camera_rig/stage_light"

@onready var light_btn = $ViewMenu/HBoxContainer/PopupMenu/VBoxContainer/MarginContainer2/VBoxContainer/GridContainer/HBoxContainer/Light_BG
@onready var grey_btn = $ViewMenu/HBoxContainer/PopupMenu/VBoxContainer/MarginContainer2/VBoxContainer/GridContainer/HBoxContainer/Half_BG
@onready var dark_btn = $ViewMenu/HBoxContainer/PopupMenu/VBoxContainer/MarginContainer2/VBoxContainer/GridContainer/HBoxContainer/Dark_BG

var counter: int = 0

func _ready():
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var diagonal: float = screen_size.length()
	var multiplier: float = 0.03
	var square_size: float = diagonal * multiplier
	$ViewMenu/HBoxContainer/ArrowPanel.custom_minimum_size = Vector2(square_size, square_size)
	$ViewMenu/HBoxContainer/ArrowPanel/MarginContainer.pivot_offset = Vector2(square_size * 0.5, (square_size * 0.5)+1)
	#print("Neue Mindestgröße:", $ViewMenu/HBoxContainer/ArrowPanel.custom_minimum_size)
	#print("Neuer Pivot-Offset:", $ViewMenu/HBoxContainer/ArrowPanel/MarginContainer.pivot_offset)
	change_camera_background_color(Color.html("#E6E0D4"))

func update_info_name(name: String):
	get_node("InfoPanel/MarginContainer/HBoxContainer/VBoxContainer/Name").text = str(name)

func update_info_count(count: String):
	get_node("InfoPanel/MarginContainer/HBoxContainer/VBoxContainer/VerticeCount").text = str(count)

func change_camera_background_color(color: Color):
	if camera.environment == null:
		camera.environment = Environment.new()
	camera.environment.background_mode = Environment.BG_COLOR
	camera.environment.background_color = color  #Hintergrundfarbe
	return

func _on_light_bg_toggled(toggled_on):
	if toggled_on:
		change_camera_background_color(Color.html("#E6E0D4"))
	else:
		change_camera_background_color(Color.html("#E6E0D4"))
	pass

func _on_half_bg_toggled(toggled_on):
	if toggled_on:
		change_camera_background_color(Color.html("#7f7f7f"))
	else:
		change_camera_background_color(Color.html("#E6E0D4"))
	pass

func _on_dark_bg_toggled(toggled_on):
	if toggled_on:
		change_camera_background_color(Color.html("#17191C"))
	else:
		change_camera_background_color(Color.html("#E6E0D4"))
	pass

func _on_h_slider_value_changed(value):
	camera_light.rotation_degrees.x = value
