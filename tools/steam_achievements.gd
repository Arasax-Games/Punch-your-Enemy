extends SceneTree
## Erzeugt docs/steam_achievements.csv aus data/achievements.json (Deutsch + Englisch) – zum Anlegen der
## Erfolge in Steamworks. Aufruf: godot --headless --path . --script res://tools/steam_achievements.gd

func _initialize() -> void:
	var list: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/achievements.json"))
	var en: Translation = load("res://locale/en.po")
	var lines: PackedStringArray = ["API-Name;Name (Deutsch);Beschreibung (Deutsch);Name (English);Description (English);Versteckt"]
	for a in list:
		lines.append(";".join([String(a.id).to_upper(), _clean(a.name), _clean(a.description),
			_clean(String(en.get_message(a.name))), _clean(String(en.get_message(a.description))),
			"ja" if a.get("hidden", false) else "nein"]))
	var file := FileAccess.open("res://docs/steam_achievements.csv", FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("%d Erfolge nach docs/steam_achievements.csv geschrieben." % list.size())
	quit()


func _clean(text: String) -> String:
	return text.replace(";", ",")
