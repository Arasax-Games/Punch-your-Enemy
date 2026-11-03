class_name Modal
extends Control
## Einfacher Dialog im Spielstil: abgedunkelter Hintergrund, Panel mit Titel, Inhalt und Knöpfen.
## Verwendung: Modal.open(self, "Titel", "Text oder Control", ["OK"]).closed.connect(...)

signal closed(button_index: int)

const MAIN := preload("res://scripts/ui/main.gd")


static func open(parent: Node, title: String, content: Variant, buttons: Array = ["OK"], min_width: float = 520.0) -> Modal:
	var m := Modal.new()
	parent.add_child(m)
	m._build(title, content, buttons, min_width)
	return m


func _build(title: String, content: Variant, buttons: Array, min_width: float) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Dialoge sind helle Karten über der dunklen Bühne.
	theme = MAIN.dialog_theme()
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.09, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(min_width, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", MAIN.heading_font())
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", MAIN.GOLD)
	title_label.add_theme_color_override("font_outline_color", MAIN.LINE)
	title_label.add_theme_constant_override("outline_size", 9)
	box.add_child(title_label)

	if content is Control:
		box.add_child(content)
	else:
		var body := Label.new()
		body.text = str(content)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.custom_minimum_size = Vector2(min_width - 60.0, 0)
		box.add_child(body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	for i in buttons.size():
		var b := Button.new()
		b.text = str(buttons[i])
		b.custom_minimum_size = Vector2(130, 0)
		b.focus_mode = Control.FOCUS_NONE
		if i == 0:
			MAIN.style_primary(b)
		var index := i
		b.pressed.connect(func() -> void: close(index))
		row.add_child(b)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)


func close(index: int = -1) -> void:
	closed.emit(index)
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close(-1)


func _gui_input(event: InputEvent) -> void:
	# Klicks auf den Hintergrund nicht ans Spiel durchreichen.
	accept_event()
