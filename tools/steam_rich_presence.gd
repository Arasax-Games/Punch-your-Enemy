extends SceneTree
## Erzeugt die Rich-Presence-Dateien für Steamworks (docs/steam_rich_presence_german.vdf / _english.vdf).
## Aufruf: godot --headless --path . --script res://tools/steam_rich_presence.gd
## Eigene Bilder erscheinen nie mit Namen, nur als "ein eigenes Bild".

func _initialize() -> void:
	var figures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/figures.json"))
	var en: Translation = load("res://locale/en.po")
	for lang in ["german", "english"]:
		var t := func(text: String) -> String:
			return text if lang == "german" else String(en.get_message(text))
		var tokens := {
			# {#%target%}: Steam übersetzt den Wert von "target" (z. B. Fig_bombastus) über das Token #Fig_…
			"#Status_Punching": String(t.call("Haut auf %target%")).replace("%target%", "{#%target%}"),
			"#Status_Boss": t.call("Kämpft gegen einen Boss!"),
			"#Fig_custom": t.call("ein eigenes Bild"),
		}
		for f in figures:
			if f.id != "_custom":
				tokens["#Fig_" + f.id] = t.call(f.name)
		var lines: PackedStringArray = ['"lang"', "{", '\t"Language"\t"%s"' % lang, '\t"Tokens"', "\t{"]
		for key in tokens:
			lines.append('\t\t"%s"\t"%s"' % [key, String(tokens[key]).replace('"', "'")])
		lines.append_array(["\t}", "}"])
		var file := FileAccess.open("res://docs/steam_rich_presence_%s.vdf" % lang, FileAccess.WRITE)
		file.store_string("\n".join(lines) + "\n")
		file.close()
	print("Rich-Presence-Dateien geschrieben.")
	quit()
