extends Control

@onready var camera: Camera3D = $"../../camera_rig/camera_arm/camera" # Referenz zur Camera3D Node

func _ready():
	#if not check_button.is_connected("toggled", Callable(self, "_on_check_button_toggled")):
		#check_button.toggled.connect(_on_check_button_toggled)
	change_camera_background_color(Color(1, 1, 1))  #Setze StandardEnvironment Color
	pass

func _on_check_button_toggled(button_pressed: bool):
	#if button_pressed:
		#change_camera_background_color(Color.html("#b9b9b9"))  # Hellgra, wenn aktiviert
	#else:
		#change_camera_background_color(Color.html("#313131"))  # Dunkelgrau, wenn deaktiviert
	return

func change_camera_background_color(color: Color):
	# Camera nach environment Source checken
	if camera.environment == null:
		camera.environment = Environment.new()
	camera.environment.background_mode = Environment.BG_COLOR
	camera.environment.background_color = color  # Setze die Hintergrundfarbe
	return
