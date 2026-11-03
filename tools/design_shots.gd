extends SceneTree
## Erzeugt die Bilder der Design-Vorlage in docs/design/bilder/ aus dem echten Spiel:
## Hauptbildschirm, Upgrades, Dialog, Wutmodus sowie Tafeln für Farben, Komponenten und Schrift.
## Aufruf (nicht headless, es wird gerendert): godot --path . --script res://tools/design_shots.gd
## Der Spielstand wird nicht angefasst (persist = false).

const OUT_DIR := "res://docs/design/bilder"

var frames := 0
var main: Control
var gs: Node
var _sheet: Control


func _initialize() -> void:
	gs = root.get_node("GameState")
	gs.persist = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	match frames:
		5:
			_set_up_progress()
		56:
			_shot("01_hauptbildschirm.png")
		58:
			_open_tab("%UpgradesTab")
		66:
			_shot("02_shop_upgrades.png")
			_open_tab("%DevicesTab")
		70:
			main._show_achievements()
		82:
			_shot("04_dialog.png")
			_close_modals()
		86:
			_sheet = _colors_sheet()
		94:
			_shot("05_farben.png")
			_sheet.queue_free()
		96:
			_sheet = _components_sheet()
		104:
			_shot("06_komponenten.png")
			_sheet.queue_free()
		106:
			_sheet = _type_sheet()
		114:
			_shot("07_schrift.png")
			_sheet.queue_free()
		116:
			gs.rage_meter = gs.RAGE_MAX
			main._try_rage()
		134:
			_shot("03_wutmodus.png")
	if (frames >= 40 and frames <= 54 and frames % 2 == 0) or (frames >= 118 and frames <= 132 and frames % 2 == 0):
		main.target_area.hit_somewhere()
	return frames > 136


func _set_up_progress() -> void:
	gs.wumms = 5000000.0
	for pair in [["faust", 28], ["pantoffel", 7], ["gummihammer", 8], ["katapult", 1]]:
		gs.buy_device(pair[0], pair[1])
	gs.wumms = 2050000.0
	gs.total_hits = 1946


func _shot(file: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT_DIR.path_join(file)))
	print("Bild gespeichert: ", file)


func _open_tab(unique: String) -> void:
	var tab: Button = main.get_node(unique)
	tab.button_pressed = true
	tab.pressed.emit()


func _close_modals() -> void:
	for child in main.get_children():
		if child is Modal:
			child.close()


# ---------------------------------------------------------------------
# Tafeln
# ---------------------------------------------------------------------

func _new_sheet(title: String) -> VBoxContainer:
	var sheet := Panel.new()
	sheet.theme = main.theme
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.add_theme_stylebox_override("panel", main._box(main.NIGHT, 0, 0, 0))
	root.add_child(sheet)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	sheet.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)
	var head := Label.new()
	head.text = title
	main._comic(head, 40, main.GOLD)
	box.add_child(head)
	return box


func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", main.MUTED)
	return l


func _colors_sheet() -> Control:
	var box := _new_sheet("Farben")
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	box.add_child(grid)
	var colors := [
		["NIGHT", main.NIGHT, "Fenstergrund"],
		["PANEL", main.PANEL, "Kopfleiste, Shop-Spalte"],
		["CARD", main.CARD, "Shop-Seite, Knöpfe, Toasts"],
		["ROW", main.ROW, "Geräte-/Upgrade-Zeile"],
		["ROW_HOVER", main.ROW_HOVER, "Zeile/Knopf unter der Maus"],
		["LINE", main.LINE, "Konturen, Leisten-Grund, Ticker"],
		["TEXT", main.TEXT, "Text auf Dunkel"],
		["MUTED", main.MUTED, "Nebeninfos, Beschriftungen"],
		["GOLD", main.GOLD, "NUR: kaufen / leistbar, Zähler, Combo"],
		["RAGE", main.RAGE, "NUR: Wut, kritische Treffer, Titel"],
		["Bühne", Color("231a4a"), "Hintergrund Standard"],
		["Podest", Color("3b2f7a"), "Podest unter dem Opfer"],
		["Lorbeer", Color("63e6be"), "Lorbeeren, Neuanfang"],
		["INK", main.INK, "Kontur in Figuren und Dialogen"],
		["PAPER", main.PAPER, "Dialog-Karten (hell)"],
		["Klick-Upgrade", Color("74c0fc"), "Punkt bei Klick-Upgrades"],
	]
	for c in colors:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 12)
		var swatch := Panel.new()
		swatch.custom_minimum_size = Vector2(64, 64)
		swatch.add_theme_stylebox_override("panel", main._box(c[1], 12, 2, 0, Color(1, 1, 1, 0.25)))
		cell.add_child(swatch)
		var text := VBoxContainer.new()
		text.custom_minimum_size = Vector2(250, 0)
		text.add_theme_constant_override("separation", 0)
		var name_label := Label.new()
		name_label.text = "%s  #%s" % [c[0], (c[1] as Color).to_html(false)]
		name_label.add_theme_font_override("font", main.heading_font())
		name_label.add_theme_font_size_override("font_size", 16)
		text.add_child(name_label)
		text.add_child(_caption(c[2]))
		cell.add_child(text)
		grid.add_child(cell)
	return box.get_parent().get_parent()


func _components_sheet() -> Control:
	var box := _new_sheet("Komponenten")
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 48)
	box.add_child(columns)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.custom_minimum_size = Vector2(620, 0)
	columns.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.custom_minimum_size = Vector2(440, 0)
	columns.add_child(right)

	left.add_child(_caption("Knöpfe: Standard · ausgewählt · gesperrt"))
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	left.add_child(row1)
	for state in ["normal", "pressed", "disabled"]:
		var b := Button.new()
		b.text = {"normal": "×10", "pressed": "×1", "disabled": "Max"}[state]
		b.custom_minimum_size = Vector2(70, 0)
		b.toggle_mode = state == "pressed"
		b.button_pressed = state == "pressed"
		b.disabled = state == "disabled"
		row1.add_child(b)

	left.add_child(_caption("Kaufen-Knopf: leistbar · zu teuer   |   WUT-Knopf: bereit · lädt"))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	left.add_child(row2)
	for affordable in [true, false]:
		var b := Button.new()
		b.text = "751" if affordable else "130.000"
		b.custom_minimum_size = Vector2(100, 46)
		b.disabled = not affordable
		main._style_buy_button(b, 14)
		row2.add_child(b)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(30, 0)
	row2.add_child(spacer)
	for ready in [true, false]:
		var rage: Button = main._rage_button.duplicate()
		rage.text = "WUT!"
		rage.disabled = not ready
		row2.add_child(rage)

	left.add_child(_caption("Leisten: Combo (Gold) · Wut (Rot)"))
	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", 16)
	left.add_child(bars)
	for spec in [[main.GOLD, 0.35], [main.RAGE, 0.72]]:
		var bar: ProgressBar = main._bar(spec[0])
		bar.custom_minimum_size = Vector2(250, 14)
		bar.max_value = 1.0
		bar.value = spec[1]
		bars.add_child(bar)

	left.add_child(_caption("Plakette (Kopfleiste) · Namensschild (Bühne)"))
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 12)
	left.add_child(chips)
	var chip: Control = main.get_node("%MarkenChip").duplicate()
	chip.visible = true
	chips.add_child(chip)
	chips.add_child(main.get_node("%NamePlate").duplicate())

	left.add_child(_caption("Erfolgs-Hinweis (Toast)"))
	var toast := PanelContainer.new()
	toast.custom_minimum_size = Vector2(340, 0)
	toast.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	toast.add_theme_stylebox_override("panel", main._box(main.CARD, 12, 3, 10, main.GOLD))
	var tb := VBoxContainer.new()
	tb.add_theme_constant_override("separation", 2)
	toast.add_child(tb)
	var th := _caption("Erfolg freigeschaltet!")
	tb.add_child(th)
	var tt := Label.new()
	tt.text = "Erstes Aua"
	main._comic(tt, 22, main.GOLD)
	tb.add_child(tt)
	var td := Label.new()
	td.text = "Der erste Treffer. Es wird nicht der letzte sein."
	td.add_theme_font_size_override("font_size", 14)
	tb.add_child(td)
	left.add_child(toast)

	right.add_child(_caption("Shop-Reiter (aktiv · inaktiv)"))
	right.add_child(main.get_node("%DevicesTab").get_parent().duplicate())
	right.add_child(_caption("Geräte-Zeile"))
	var device_row: Control = main.device_list.get_child(0).duplicate()
	right.add_child(device_row)
	right.add_child(_caption("Upgrade-Zeile"))
	if main.upgrade_list.get_child_count() > 1:
		right.add_child(main.upgrade_list.get_child(1).duplicate())
	return box.get_parent().get_parent()


func _type_sheet() -> Control:
	var box := _new_sheet("Schrift")
	var samples := [
		["2,05 Mio.", 72, "Zähler · Überschrift-Schrift, Kontur LINE, GOLD", "comic", main.GOLD],
		["Punch your Enemy", 30, "Spieltitel · Überschrift-Schrift, Kontur, RAGE", "comic", main.RAGE],
		["Geräte", 21, "Shop-Reiter · Überschrift-Schrift", "heading", main.GOLD],
		["Tortenwurf-Kanone", 16, "Name in Zeilen · Überschrift-Schrift", "heading", main.TEXT],
		["pro Sekunde: 121", 16, "Kennzahlen · Poppins Medium", "body", main.TEXT],
		["je 260 WPS · Einmal kaufen, für immer stärker.", 13, "Nebeninfo · Poppins Medium, MUTED", "body", main.MUTED],
		["+16", 34, "Treffer-Zahl · Überschrift-Schrift, dicke Kontur, Weiß", "comic", Color.WHITE],
		["KRITISCH!", 44, "Krit / Comic-Wort · Überschrift-Schrift, schräg, RAGE", "comic", main.RAGE],
	]
	for s in samples:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 24)
		var sample := Label.new()
		sample.text = s[0]
		sample.custom_minimum_size = Vector2(560, 0)
		match s[3]:
			"comic":
				main._comic(sample, s[1], s[4])
			"heading":
				sample.add_theme_font_override("font", main.heading_font())
				sample.add_theme_font_size_override("font_size", s[1])
				sample.add_theme_color_override("font_color", s[4])
			_:
				sample.add_theme_font_size_override("font_size", s[1])
				sample.add_theme_color_override("font_color", s[4])
		row.add_child(sample)
		var info := _caption("%d px · %s" % [s[1], s[2]])
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(info)
		box.add_child(row)
	return box.get_parent().get_parent()
