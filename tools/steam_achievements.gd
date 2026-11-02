extends SceneTree
## Erzeugt docs/steam_achievements.csv aus data/achievements.json – zum Anlegen der Erfolge in Steamworks.
## Aufruf: godot --headless --path . --script res://tools/steam_achievements.gd

func _initialize() -> void:
	var list: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/achievements.json"))
	var lines: PackedStringArray = ["API-Name;Anzeigename;Beschreibung;Versteckt"]
	for a in list:
		lines.append("%s;%s;%s;%s" % [String(a.id).to_upper(), a.name, String(a.description).replace(";", ","),
			"ja" if a.get("hidden", false) else "nein"])
	var file := FileAccess.open("res://docs/steam_achievements.csv", FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("%d Erfolge nach docs/steam_achievements.csv geschrieben." % list.size())
	quit()
