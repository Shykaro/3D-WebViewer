extends Node3D
#DIESES SKRIPT REGELT DIE KAMERA HITBOX ZUM AUSBLENDEN VON TEILEN DES EXPLODIERTEN MODELLS WENN SIE ZWISCHEN KAMERA UND MODELL KOMMEN, 
#COLLISION EVENTS SIND ANSCHEINEND ABER SEHR RESSOURCENAUFREIBEND, UM EINZUSCHALTEN MUSS DAS AREA3D AUF MONITORING UND MONITORABLE AN GESCHALTEN WERDEN.
@onready var model_container: Node3D = $"../../../../turntable/VignetteSubViewport/model_container"
@onready var main: Node3D = $"../../../.."
@onready var turntable: Node3D = $"../../../../turntable"

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_area_3d_body_entered(body):
	#print("Collision with: ", body.get_parent())
	if body.get_parent() in turntable.exploded_meshes:
		#print("Collision with: ", body)
		body.get_parent().visible = false
	#pass # Replace with function body.


func _on_area_3d_body_exited(body):
	if body.get_parent() in turntable.exploded_meshes:
		body.get_parent().visible = true
	#pass # Replace with function body.
