extends Control

# Zustand des Menüs
var is_menu_open = false

# Nodes
@onready var popup_menu = $PopupMenu
@onready var burger_button = $BurgerButton

func _ready():
	# Standardzustand: Menü geschlossen
	popup_menu.visible = false

	# Verbindungen der Signale
	burger_button.connect("pressed", Callable(self, "_on_burger_button_pressed"))
	for button in popup_menu.get_children():
		button.connect("pressed", Callable(self, "_on_view_button_pressed"))

# Öffnen/Schließen des Menüs
func _on_burger_button_pressed():
	is_menu_open = !is_menu_open
	if is_menu_open:
		_open_menu()
	else:
		_close_menu()

# Öffnet das Popup-Menü mit Animation
func _open_menu():
	popup_menu.visible = true
	# Tween für sanftes Einblenden
	popup_menu.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(popup_menu, "modulate:a", 1, 0.3)

# Schließt das Popup-Menü mit Animation
func _close_menu():
	var tween = create_tween()
	tween.tween_property(popup_menu, "modulate:a", 0, 0.3)
	tween.tween_callback(Callable(self, "hide_menu"))

func hide_menu():
	popup_menu.visible = false

# Behandelt die Buttons für die verschiedenen Ansichtsmodi
func _on_view_button_pressed(button: Button):
	# Identifiziert den Button und sendet ein Signal zur Ansichtsumstellung
	match button.name:
		"WireframeButton":
			emit_signal("change_view", "wireframe")
		"NormalsButton":
			emit_signal("change_view", "normals")
		"TexturedButton":
			emit_signal("change_view", "textured")
		"ShadedButton":
			emit_signal("change_view", "shaded")
