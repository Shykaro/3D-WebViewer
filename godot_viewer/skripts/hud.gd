extends Control

@onready var camera: Camera3D = $"../../camera_rig/camera_arm/camera" # Referenz zur Camera3D Node

@onready var light_btn = $ViewMenu/HBoxContainer/PopupMenu/VBoxContainer/MarginContainer2/VBoxContainer/GridContainer/HBoxContainer/Light_BG
@onready var grey_btn = $ViewMenu/HBoxContainer/PopupMenu/VBoxContainer/MarginContainer2/VBoxContainer/GridContainer/HBoxContainer/Half_BG
@onready var dark_btn = $ViewMenu/HBoxContainer/PopupMenu/VBoxContainer/MarginContainer2/VBoxContainer/GridContainer/HBoxContainer/Dark_BG


var counter: int = 0

func _ready():
	#if not check_button.is_connected("toggled", Callable(self, "_on_check_button_toggled")):
		#check_button.toggled.connect(_on_check_button_toggled)
	change_camera_background_color(Color.html("#E6E0D4"))  # Hellgra, wenn aktiviert
	pass

func update_info_name(name: String):
	get_node("InfoPanel/MarginContainer/HBoxContainer/VBoxContainer/Name").text = str(name)

func update_info_count(count: String):
	get_node("InfoPanel/MarginContainer/HBoxContainer/VBoxContainer/VerticeCount").text = str(count)

func change_camera_background_color(color: Color):
	# Camera nach environment Source checken
	if camera.environment == null:
		camera.environment = Environment.new()
		#print("Created new environment")
	camera.environment.background_mode = Environment.BG_COLOR
	camera.environment.background_color = color  # Setze die Hintergrundfarbe
	#print("Color: ", color)
	return

#func _on_backgroundcolor_pressed() -> void:
	#match counter:
		#0:
			#change_camera_background_color(Color.html("#17191C"))  # Dunkelgrau, wenn deaktiviert
			#counter += 1
		#1:
			#change_camera_background_color(Color.html("#7f7f7f"))  # 50%grau, wenn deaktiviert
			#counter += 1
		#2:
			#change_camera_background_color(Color.html("#E6E0D4"))  # Hellgrau, wenn aktiviert
			#counter = 0


#func _on_light_bg_pressed():
	#change_camera_background_color(Color.html("#E6E0D4"))
	#pass # Replace with function body.
#
#
#func _on_half_bg_pressed():
	#change_camera_background_color(Color.html("#7f7f7f"))
	#pass # Replace with function body.
#
#
#func _on_dark_bg_pressed():
	#change_camera_background_color(Color.html("#17191C"))
	#pass # Replace with function body.
#

func _on_light_bg_toggled(toggled_on):
	if toggled_on:
		change_camera_background_color(Color.html("#E6E0D4"))
		#grey_btn.button_pressed = false
		#dark_btn.button_pressed = false
		#grey_btn.toggled
		#dark_btn.toggled
	else:
		change_camera_background_color(Color.html("#E6E0D4"))
	pass # Replace with function body.


func _on_half_bg_toggled(toggled_on):
	if toggled_on:
		change_camera_background_color(Color.html("#7f7f7f"))
		#light_btn.button_pressed = false
		#dark_btn.button_pressed = false
		#light_btn.toggled
		#dark_btn.toggled
	else:
		change_camera_background_color(Color.html("#E6E0D4"))
	pass # Replace with function body.


func _on_dark_bg_toggled(toggled_on):
	if toggled_on:
		change_camera_background_color(Color.html("#17191C"))
		#light_btn.button_pressed = false
		#grey_btn.button_pressed = false
		#light_btn.toggled
		#grey_btn.toggled
	else:
		change_camera_background_color(Color.html("#E6E0D4"))
	pass # Replace with function body.
