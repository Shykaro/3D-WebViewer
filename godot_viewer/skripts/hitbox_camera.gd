extends Node3D

@onready var model_container: Node3D = $"../../../../turntable/VignetteSubViewport/model_container"
@onready var main: Node3D = $"../../../.."

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	pass


func _on_area_3d_body_entered(body):
	#print("Collision with: ", body.get_parent())
	if body.get_parent():
		if body.get_parent() in  $"../../../../turntable".exploded_meshes:
			print("Collision with: ", body)
			body.get_parent().visible = false
	#pass # Replace with function body.


func _on_area_3d_body_exited(body):
	body.get_parent().visible = true
	#pass # Replace with function body.
