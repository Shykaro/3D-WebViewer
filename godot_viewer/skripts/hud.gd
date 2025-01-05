extends Control

@onready var camera: Camera3D = $"../../camera_rig/camera_arm/camera" # Referenz zur Camera3D Node

var counter: int = 0

func _ready():
	#if not check_button.is_connected("toggled", Callable(self, "_on_check_button_toggled")):
		#check_button.toggled.connect(_on_check_button_toggled)
	change_camera_background_color(Color.html("#E6E0D4"))  # Hellgra, wenn aktiviert
	pass


func change_camera_background_color(color: Color):
	# Camera nach environment Source checken
	if camera.environment == null:
		camera.environment = Environment.new()
		#print("Created new environment")
	camera.environment.background_mode = Environment.BG_COLOR
	camera.environment.background_color = color  # Setze die Hintergrundfarbe
	#print("Color: ", color)
	return


func _on_backgroundcolor_pressed() -> void:
	match counter:
		0:
			change_camera_background_color(Color.html("#17191C"))  # Dunkelgrau, wenn deaktiviert
			counter += 1
		1:
			change_camera_background_color(Color.html("#7f7f7f"))  # Dunkelgrau, wenn deaktiviert
			counter += 1
		2:
			change_camera_background_color(Color.html("#E6E0D4"))  # Hellgra, wenn aktiviert
			counter = 0
	
