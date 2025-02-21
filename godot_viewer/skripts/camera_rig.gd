extends Node3D

@export var rotation_speed = 180
@export var zoom_speed = 0.5

var camera_distance = 4
#var min_zoom = 2
var max_zoom = 100

@onready var model_container = $"../turntable/VignetteSubViewport/model_container"
@onready var turntable = $"../turntable"
@onready var view_menu: Control = $"../CanvasLayer/Hud/ViewMenu"

var rot_y = 0
var rot_x = 0

func _ready():
	if model_container == null:
		print("Fehler: 'model_container' konnte nicht gefunden werden.")
		return

	var global_aabb = calculate_global_aabb(model_container.get_child(0))
	var dimensions = global_aabb.size

	var fov = deg_to_rad($camera_arm/camera.fov)
	var aspect_ratio = $camera_arm/camera.get_viewport().size.x / $camera_arm/camera.get_viewport().size.y

	#camera_distance = calculate_camera_distance(dimensions, fov, aspect_ratio) #Passt Cameradistanz an Modellgröße an, ist allerdings durch besserbefundene Modellskalierung obsolet geworden
	# min_zoom = camera_distance * 0.8
	#max_zoom = camera_distance * 3.0

	_handle_zoom()

#func _unhandled_input(event):
	#if event is InputEventKey:
		#if event.pressed and event.keycode == KEY_ESCAPE:
			#get_tree().quit()

func _process(delta):
	var lr_axis = -Input.get_axis("turntable_left", "turntable_right")
	if lr_axis != 0:
		rot_y = rotation_speed * lr_axis * delta * PI / 180

	var ud_axis = Input.get_axis("turntable_down", "turntable_up")
	if ud_axis != 0:
		rot_x = rotation_speed * ud_axis * delta * PI / 180

	#Mausbewegung für Rotation
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mousePos = get_viewport().get_mouse_position()
		var is_mouse_over_view_menu = $"../CanvasLayer/Hud/ViewMenu/HBoxContainer/PopupMenu".get_global_rect().has_point(mousePos) or $"../CanvasLayer/Hud/ViewMenu/HBoxContainer/ArrowPanel".get_global_rect().has_point(mousePos)
		if !is_mouse_over_view_menu:
			var mouse_vel = Input.get_last_mouse_velocity()
			rot_y = rotation_speed * (-mouse_vel.x / 400) * delta * PI / 180
			rot_x = rotation_speed * (-mouse_vel.y / 800) * delta * PI / 180

	rotate_y(rot_y)
	$camera_arm.rotate_x(rot_x)

	rot_y *= 0.950
	rot_x *= 0.950

#func _on_mouse_exited():
	#if not Rect2(Vector2(), size).has_point(get_local_mouse_position()):

func calculate_camera_distance(dimensions: Vector3, fov: float, aspect_ratio: float) -> float:
	var height = dimensions.y
	var width = dimensions.x
	if width / aspect_ratio > height:
		height = width / aspect_ratio
	return height / (2.0 * tan(fov / 2.0))

#rekursiver Aufruf um die AABBs zusammenzufügen
func calculate_global_aabb(node: Node) -> AABB:
	var global_aabb = AABB()
	var initialized = false

	for child in node.get_children():
		if child is MeshInstance3D and child.mesh:
			var local_aabb = child.mesh.get_aabb()
			var global_min = child.global_transform.origin + child.global_transform.basis * local_aabb.position
			var global_max = global_min + child.global_transform.basis * local_aabb.size

			var child_aabb = AABB(global_min, global_max - global_min)

			if initialized:
				global_aabb = global_aabb.merge(child_aabb.abs())
			else:
				global_aabb = child_aabb
				initialized = true

		var child_aabb = calculate_global_aabb(child)
		if initialized:
			global_aabb = global_aabb.merge(child_aabb.abs())
		else:
			global_aabb = child_aabb
			initialized = true

	return global_aabb

func _input(event):
	if event.is_action_pressed("zoom_in"):
		camera_distance -= zoom_speed
	elif event.is_action_pressed("zoom_out"):
		camera_distance += zoom_speed
	_handle_zoom()

func _handle_zoom():
	#camera_distance = clamp(camera_distance, -INF, max_zoom)
	camera_distance = clamp(camera_distance, 0.01, max_zoom)

	$camera_arm/camera.position.z = camera_distance
