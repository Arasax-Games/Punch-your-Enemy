extends SceneTree
## Schreibt build/LICENSES.md: Lizenzen von Godot (inkl. aller Bestandteile) und der Schrift.
## Muss jedem ausgelieferten Build beiliegen (MIT-Lizenz von Godot verlangt den Hinweis).
## Aufruf: godot --headless --path . --script res://tools/third_party_licenses.gd

func _initialize() -> void:
	var out := PackedStringArray()
	out.append("# Lizenzen / Licenses\n")
	out.append("## Punch your Enemy\n\n© 2026 Arasax Games\n")
	out.append("## Schrift / Font: Poppins\n\nCopyright 2020 The Poppins Project Authors (https://github.com/itfoundry/Poppins)\n" +
		"SIL Open Font License 1.1 – siehe / see OFL-Poppins.txt\n")
	out.append("## Godot Engine\n\n```\n" + Engine.get_license_text() + "\n```\n")
	out.append("## Bestandteile der Godot Engine / Godot Engine third-party components\n")
	for component in Engine.get_copyright_info():
		out.append("### " + component.name)
		for part in component.parts:
			for c in part.copyright:
				out.append("- © " + c)
			out.append("- License: " + part.license + "\n")
	out.append("## Lizenztexte / License texts\n")
	var texts := Engine.get_license_info()
	for key in texts:
		out.append("### " + key + "\n\n```\n" + texts[key] + "\n```\n")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var f := FileAccess.open("res://build/LICENSES.md", FileAccess.WRITE)
	f.store_string("\n".join(out))
	f.close()
	print("build/LICENSES.md geschrieben.")
	quit()
