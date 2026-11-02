extends SceneTree
## Headless-Tests für Formeln, Kauf-Logik und Speichern.
## Aufruf: godot --headless --path . --script res://tests/run_tests.gd

var _failures := 0
var _checks := 0


func _initialize() -> void:
	test_balance()
	test_number_format()
	test_game_state()
	test_save_roundtrip()
	test_data_files()
	print("")
	if _failures == 0:
		print("OK: %d Prüfungen bestanden." % _checks)
	else:
		print("FEHLER: %d von %d Prüfungen fehlgeschlagen." % [_failures, _checks])
	quit(1 if _failures > 0 else 0)


func check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("  ✗ ", label)


func check_eq(actual: Variant, expected: Variant, label: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		print("  ✗ %s: erwartet %s, erhalten %s" % [label, str(expected), str(actual)])


func new_state() -> Node:
	var gs: Node = load("res://scripts/core/game_state.gd").new()
	gs.load_data()
	return gs


func test_balance() -> void:
	print("Balance")
	check_eq(Balance.unit_cost(15, 0), 15.0, "Faust #1 kostet 15")
	check_eq(Balance.unit_cost(15, 1), 18.0, "Faust #2 kostet ceil(17,25) = 18")
	check_eq(Balance.unit_cost(100, 10), ceilf(100 * pow(1.15, 10)), "Pantoffel #11")
	check_eq(Balance.bulk_cost(15, 0, 2), 33.0, "2 Fäuste kosten 33")
	check_eq(Balance.max_affordable(15, 0, 32), 1, "mit 32 Wumms nur 1 Faust")
	check_eq(Balance.max_affordable(15, 0, 33), 2, "mit 33 Wumms 2 Fäuste")
	check_eq(Balance.sell_refund(15, 1), 3.0, "Verkauf erstattet 25 %")
	check_eq(Balance.sell_refund(15, 0), 0.0, "Nichts zu verkaufen")
	check_eq(Balance.laurels_for(1e12), 1, "1 Billion = 1 Lorbeer")
	check_eq(Balance.laurels_for(8e12), 2, "8 Billionen = 2 Lorbeeren")
	check_eq(Balance.laurels_for(5e11), 0, "unter 1 Billion = 0")


func test_number_format() -> void:
	print("Zahlenformat")
	check_eq(Num.fmt(0), "0", "0")
	check_eq(Num.fmt(0.1), "0,1", "0,1")
	check_eq(Num.fmt(15), "15", "15")
	check_eq(Num.fmt(1234), "1.234", "Tausenderpunkt")
	check_eq(Num.fmt(999999), "999.999", "knapp unter Mio.")
	check_eq(Num.fmt(1230000), "1,23 Mio.", "Millionen")
	check_eq(Num.fmt(4.56e9), "4,56 Mrd.", "Milliarden")
	check_eq(Num.fmt(7.8e12), "7,80 Bio.", "Billionen")
	check_eq(Num.fmt(1.5e15), "1,50e15", "wissenschaftlich ab 1e15")
	check_eq(Num.whole(14.9), "14", "Guthaben wird abgerundet")
	check_eq(Num.duration(30), "30 s", "Dauer Sekunden")


func test_game_state() -> void:
	print("Spielzustand")
	var gs := new_state()
	check_eq(gs.click_value(), 1.0, "Startklick = 1")
	for i in 15:
		gs.hit()
	check_eq(gs.wumms, 15.0, "15 Klicks = 15 Wumms")
	check_eq(gs.total_hits, 15, "Treffer gezählt")
	check(gs.buy_device("faust", 1), "Faust kaufbar")
	check_eq(gs.wumms, 0.0, "Wumms abgezogen")
	check(not gs.buy_device("faust", 1), "Zweite Faust zu teuer")
	check(is_equal_approx(gs.wps(), 0.1), "1 Faust = 0,1 WPS")
	gs.tick(10.0)
	check(is_equal_approx(gs.wumms, 1.0), "10 s Produktion = 1 Wumms")

	gs.wumms = 1000.0
	var u: Dictionary = gs.upgrade_def("boxhandschuh_training")
	check(gs.is_upgrade_visible(u), "Upgrade sichtbar bei genug Wumms")
	check(gs.buy_upgrade("boxhandschuh_training"), "Upgrade kaufbar")
	check_eq(gs.click_value(), 2.0, "Klick-Wert verdoppelt")
	check(not gs.buy_upgrade("boxhandschuh_training"), "Upgrade nicht doppelt kaufbar")
	check(gs.buy_upgrade("knoechelpolster"), "Knöchelpolster nach erster Faust kaufbar")
	check(is_equal_approx(gs.wps(), 0.2), "Faust-Produktion verdoppelt")
	check(not gs.upgrade_requirement_met(gs.upgrade_def("flauschfutter")), "Flauschfutter braucht Pantoffel")
	check(not gs.upgrade_requirement_met(gs.upgrade_def("karate_kurs")), "Karate-Kurs braucht Stahlkappe")

	gs.wumms = 1e9
	gs.upgrades["sponsorenvertrag"] = true
	check(is_equal_approx(gs.wps(), 0.22), "Sponsorenvertrag +10 %")
	var max_amount: int = gs.amount_for_mode("pantoffel", -1)
	check(max_amount > 50, "Max-Kauf berechnet viele Pantoffel")
	check(gs.buy_device("pantoffel", 10), "10 Pantoffel kaufbar")
	check_eq(gs.device_count("pantoffel"), 10, "10 Pantoffel im Besitz")
	check(gs.sell_device("pantoffel"), "Pantoffel verkaufbar")
	check_eq(gs.device_count("pantoffel"), 9, "9 Pantoffel nach Verkauf")
	check(gs.is_device_visible(2), "Gummihammer sichtbar nach Pantoffel")
	gs.free()


func test_save_roundtrip() -> void:
	print("Speichern")
	var a := new_state()
	a.wumms = 1234.5
	a.total_wumms = 99999.0
	a.total_hits = 42
	a.devices = {"faust": 3, "pantoffel": 1}
	a.upgrades = {"boxhandschuh_training": true}
	a.target_hits = {"bombastus": 42}
	a.reduced_effects = true
	var json := JSON.stringify(a.to_dict())
	var b := new_state()
	b.from_dict(JSON.parse_string(json))
	check_eq(b.wumms, 1234.5, "Wumms gespeichert")
	check_eq(b.total_hits, 42, "Treffer gespeichert (als int)")
	check_eq(b.device_count("faust"), 3, "Geräte gespeichert")
	check(b.has_upgrade("boxhandschuh_training"), "Upgrades gespeichert")
	check_eq(b.current_target_hits(), 42, "Treffer pro Bild gespeichert")
	check(b.reduced_effects, "Einstellungen gespeichert")
	check(is_equal_approx(b.wps(), a.wps()), "WPS identisch nach Laden")
	a.free()
	b.free()


func test_data_files() -> void:
	print("Daten")
	var gs := new_state()
	check_eq(gs.device_defs.size(), 5, "5 Geräte im MVP")
	check_eq(gs.upgrade_defs.size(), 10, "10 Upgrades im MVP")
	var ids := {}
	for u in gs.upgrade_defs:
		check(not ids.has(u.id), "Upgrade-ID eindeutig: %s" % u.id)
		ids[u.id] = true
		check(gs.upgrade_effect_text(u) != "", "Wirkungstext vorhanden: %s" % u.id)
		var req: Dictionary = u.get("requires", {})
		if req.has("device"):
			check(not gs.device_def(req.device).is_empty(), "Voraussetzung existiert: %s" % u.id)
		if req.has("upgrade"):
			check(not gs.upgrade_def(req.upgrade).is_empty(), "Voraussetzung existiert: %s" % u.id)
	gs.free()
