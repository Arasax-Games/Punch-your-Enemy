extends SceneTree
## Headless-Tests für Formeln, Kauf-Logik und Speichern.
## Aufruf: godot --headless --path . --script res://tests/run_tests.gd

var _failures := 0
var _checks := 0


func _initialize() -> void:
	TranslationServer.set_locale("de")
	test_balance()
	test_number_format()
	test_game_state()
	test_save_roundtrip()
	test_save_migration()
	test_data_files()
	test_synergy_and_global()
	test_achievements()
	test_shoes_and_buffs()
	test_offline()
	test_prestige()
	test_laurel_tree()
	test_combo_and_rage()
	test_bump_levels_and_gallery()
	test_migration_v3()
	test_bosses()
	test_quests_and_login()
	test_events()
	test_minigames()
	test_migration_v4()
	test_figures_p5()
	test_cosmetics()
	test_challenges()
	test_market()
	test_slow_motion_and_v5()
	test_english()
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


func new_state(locale: String = "de") -> Node:
	# Der Autoload GameState stellt beim Start die Systemsprache ein – hier bewusst überschreiben.
	TranslationServer.set_locale(locale)
	var gs: Node = load("res://scripts/core/game_state.gd").new()
	gs.persist = false
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
	check_eq(Balance.golden_interval(0.0, 1.0), 300.0, "Goldener Schuh frühestens nach 300 s")
	check_eq(Balance.golden_interval(1.0, 1.0), 600.0, "Goldener Schuh spätestens nach 600 s")
	check_eq(Balance.golden_interval(0.0, 1.2), 250.0, "Kamerateam verkürzt das Intervall")
	check_eq(Balance.blessing(10.0, 1e9, 15.0, 0.15, 13.0), 9013.0, "Segen = 15 min WPS + 13")
	check_eq(Balance.blessing(1e6, 1000.0, 15.0, 0.15, 13.0), 163.0, "Segen max. 15 % des Guthabens")
	check_eq(Balance.offline_gain(10.0, 3600.0), 18000.0, "Offline: halbe WPS")
	check_eq(Balance.offline_gain(10.0, 20.0 * 3600.0), 144000.0, "Offline: max. 8 Stunden")
	check_eq(Balance.synergy_bonus(25, 0.05, 10), 1.1, "Synergie: +5 % je 10")
	check_eq(Balance.laurel_gain(8e12, 1), 1, "Neuanfang bringt nur neue Lorbeeren")
	check_eq(Balance.laurel_gain(5e11, 0), 0, "unter 1 Billion keine Lorbeeren")
	check_eq(Balance.laurel_bonus(25), 1.25, "25 Lorbeeren = +25 %")
	check_eq(Balance.combo_multiplier(0), 1.0, "Combo 0 = ×1")
	check_eq(Balance.combo_multiplier(150), 2.0, "Combo max. ×2")
	check_eq(Balance.bump_level(999), 0, "Beulen-Level 0 unter 1.000")
	check_eq(Balance.bump_level(3500), 3, "Beulen-Level 3")
	check_eq(Balance.bump_level(50000), 10, "Beulen-Level max. 10")
	check_eq(Balance.boss_hp(0), 100.0, "Erster Boss: 100 Treffer")
	check_eq(Balance.boss_hp(3), 800.0, "Vierter Boss: 800 Treffer")
	check_eq(Balance.minigame_reward(23, 8), 2, "Mini-Spiel: je 8 Punkte eine Marke")
	check_eq(Balance.minigame_reward(500, 8), 5, "Mini-Spiel: max. 5 Marken")
	check_eq(Balance.login_day(8), 1, "Login-Serie beginnt nach Tag 7 von vorn")
	check_eq(Balance.login_marken(7), 10, "Tag 7: Hauptgewinn")
	check_eq(Balance.market_step(1.0, 0.0, 0.2), 1.0, "Börse: ohne Zufall bleibt der Kurs")
	check(is_equal_approx(Balance.market_step(2.0, 0.0, 0.2), 1.9), "Börse: Kurs zieht Richtung 1")
	check_eq(Balance.market_step(1.0, 100.0, 0.2), 3.0, "Börse: Kurs max. 3")
	check_eq(Balance.market_price(10.0, 0.0, 1.0), 10.0, "Börsenpreis mit mindestens 1 WPS")


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
	check(is_equal_approx(gs.wumms, 17.1), "15 Klicks = 15 Wumms + Combo-Bonus (17,1)")
	check_eq(gs.total_hits, 15, "Treffer gezählt")
	gs.wumms = 15.0
	gs.combo = 0.0
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
	check_eq(gs.device_defs.size(), 12, "12 Geräte")
	check(gs.upgrade_defs.size() >= 50, "mindestens 50 Upgrades")
	check(gs.achievement_defs.size() >= 50, "mindestens 50 Erfolge")
	for d in gs.device_defs:
		var tiers := 0
		for u in gs.upgrade_defs:
			if u.effect.type == "device_mult" and u.effect.device == d.id:
				tiers += 1
		check_eq(tiers, 3, "3 Geräte-Upgrades für %s" % d.id)
	var ach_ids := {}
	for a in gs.achievement_defs:
		check(not ach_ids.has(a.id), "Erfolg-ID eindeutig: %s" % a.id)
		ach_ids[a.id] = true
		check(gs.condition_progress(a.condition).y > 0.0, "Bedingung lesbar: %s" % a.id)
		if a.condition.type == "device":
			check(not gs.device_def(a.condition.device).is_empty(), "Gerät existiert: %s" % a.id)
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
		if req.has("devices"):
			for id in req.devices:
				check(not gs.device_def(id).is_empty(), "Voraussetzung existiert: %s" % u.id)
	gs.free()


func test_save_migration() -> void:
	print("Migration v1 → v2")
	var gs := new_state()
	var v1 := {"version": 1, "wumms": 500.0, "total_wumms": 2000.0, "total_hits": 1200,
		"devices": {"faust": 2}, "upgrades": ["boxhandschuh_training"], "revealed_upgrades": [],
		"target_id": "bombastus", "target_names": {}, "target_hits": {"bombastus": 1200},
		"settings": {"reduced_effects": false, "sound_on": true}}
	gs.from_dict(v1)
	check_eq(gs.wumms, 500.0, "v1-Wumms übernommen")
	check_eq(gs.achievement_count(), 0, "noch keine Erfolge")
	check_eq(int(gs.stats.crits), 0, "Statistik angelegt")
	gs.check_achievements()
	check(gs.achievements.has("zappelphilipp"), "Erfolge rückwirkend vergeben")
	check_eq(gs.to_dict().version, gs.SAVE_VERSION, "wird als aktuelle Version gespeichert")
	var code: String = gs.export_save_code()
	var other := new_state()
	check(other.import_save_code(code), "Import ausgeführt")
	check_eq(other.total_hits, 1200, "Textcode-Export und -Import")
	check(not other.import_save_code("kein gültiger code"), "Ungültiger Code wird abgelehnt")
	gs.free()
	other.free()


func test_synergy_and_global() -> void:
	print("Synergien und globale Upgrades")
	var gs := new_state()
	gs.devices = {"faust": 20, "pantoffel": 20}
	var before: float = gs.device_unit_wps("faust")
	gs.upgrades["fuss_hand_koordination"] = true
	check(is_equal_approx(gs.device_unit_wps("faust"), before * 1.1), "20 Pantoffel: Faust +10 %")
	gs.upgrades["milchtuete_der_wut"] = true
	for i in 10:
		gs.achievements["test_%d" % i] = true
	check(is_equal_approx(gs.global_multiplier(), 1.05), "Wutmilch: 10 Erfolge = +5 %")
	gs.upgrades["fanclub"] = true
	check(is_equal_approx(gs.global_multiplier(), 1.05 * 1.05), "Fanclub: +5 % je 10 Erfolge")
	gs.upgrades["kamerateam"] = true
	check(is_equal_approx(gs.golden_luck(), 1.2), "Kamerateam: Glück ×1,2")
	var syn: Dictionary = gs.upgrade_def("fuss_hand_koordination")
	gs.devices = {"faust": 20, "pantoffel": 5}
	check(not gs.upgrade_requirement_met(syn), "Synergie braucht 15 von beiden")
	gs.free()


func test_achievements() -> void:
	print("Erfolge")
	var gs := new_state()
	var unlocked: Array[String] = []
	gs.achievement_unlocked.connect(func(id: String) -> void: unlocked.append(id))
	gs.hit()
	gs.check_achievements()
	check(gs.achievements.has("erstes_aua"), "Erstes Aua nach dem ersten Treffer")
	check(unlocked.has("erstes_aua"), "Signal gesendet")
	var count_before: int = unlocked.size()
	gs.check_achievements()
	check_eq(unlocked.size(), count_before, "Erfolge nur einmal")
	gs.idle_time = 601.0
	gs.check_achievements()
	check(gs.achievements.has("pazifist"), "Pazifist nach 10 Minuten Pause")
	gs.wumms = 1e15
	for d in gs.device_defs:
		gs.buy_device(d.id, 1)
	gs.check_achievements()
	check(gs.achievements.has("komplettset"), "Komplettset mit allen 12 Geräten")
	check(gs.achievements.has("multiversal"), "Erfolg für ein bestimmtes Gerät")
	gs.free()


func test_shoes_and_buffs() -> void:
	print("Goldener Schuh und Buffs")
	var gs := new_state()
	gs.devices = {"pantoffel": 10}
	gs.wumms = 1e9
	var base: float = gs.wps()
	var r: Dictionary = gs.claim_shoe("golden", 0.6)
	check_eq(r.title, "Raserei!", "Roll 0,6 = Raserei")
	check(is_equal_approx(gs.wps(), base * 7.0), "Raserei: WPS ×7")
	gs.tick(78.0)
	check(is_equal_approx(gs.wps(), base), "Raserei endet nach 77 s")
	var before: float = gs.wumms
	r = gs.claim_shoe("golden", 0.3)
	check_eq(r.title, "Wumms-Segen!", "Roll 0,3 = Segen")
	check(is_equal_approx(gs.wumms - before, base * 900.0 + 13.0), "Segen = 15 min WPS + 13")
	r = gs.claim_shoe("golden", 0.01)
	check(not r.good, "Roll 0,01 = Pech-Schuh")
	check_eq(gs.beulen_marken, 3, "Pech-Schuh gibt Beulen-Marken")
	check(is_equal_approx(gs.wps(), base * 0.5), "Pech-Schuh halbiert WPS")
	gs.tick(67.0)
	r = gs.claim_shoe("golden", 0.85)
	check(is_equal_approx(gs.click_value(), 777.0), "Klick-Raserei ×777")
	check_eq(int(gs.stat("golden_shoes")), 4, "Goldene Schuhe gezählt")
	check_eq(int(gs.stat("frenzies")), 2, "Rasereien gezählt")
	r = gs.claim_shoe("silver", 0.9)
	check_eq(int(gs.stat("silver_slippers")), 1, "Silberne Pantoffel gezählt")
	gs.free()


func test_offline() -> void:
	print("Offline-Fortschritt")
	var gs := new_state()
	gs.devices = {"pantoffel": 10}
	var gain: float = gs.apply_offline_progress(3600.0)
	check(is_equal_approx(gain, 10.0 * 0.5 * 3600.0), "1 h offline = halbe Produktion")
	check_eq(gs.pending_offline.is_empty(), false, "Willkommen-Dialog vorgemerkt")
	check_eq(gs.apply_offline_progress(30.0), 0.0, "Unter einer Minute zählt nicht")
	gs.apply_offline_progress(90000.0)
	check_eq(int(gs.stat("long_return")), 1, "Wieder zuhause nach 24 h")
	gs.free()


func test_prestige() -> void:
	print("Neuanfang")
	var gs := new_state()
	gs.wumms = 5e11
	gs.earn(5e11)
	check(not gs.can_prestige(), "Unter 1 Billion kein Neuanfang")
	gs.earn(8e12)
	check(gs.can_prestige(), "Neuanfang ab 1 Billion möglich")
	gs.devices = {"faust": 50}
	gs.upgrades = {"boxhandschuh_training": true}
	gs.achievements = {"erstes_aua": true}
	var marken: int = gs.beulen_marken
	var gain: int = gs.perform_prestige()
	check_eq(gain, 2, "8,5 Billionen = 2 Lorbeeren")
	check_eq(gs.laurels_total, 2, "Lorbeeren gutgeschrieben")
	check_eq(gs.wumms, 0.0, "Wumms zurückgesetzt")
	check_eq(gs.device_count("faust"), 0, "Geräte zurückgesetzt")
	check(not gs.has_upgrade("boxhandschuh_training"), "Upgrades zurückgesetzt")
	check(gs.achievements.has("erstes_aua"), "Erfolge bleiben")
	check_eq(gs.beulen_marken, marken, "Beulen-Marken bleiben")
	check_eq(int(gs.stat("prestiges")), 1, "Neuanfänge gezählt")
	check(not gs.can_prestige(), "Direkt danach kein zweiter Neuanfang")
	gs.devices = {"pantoffel": 10}
	check(is_equal_approx(gs.base_wps(), 10.0 * 1.02), "2 Lorbeeren = +2 % WPS")
	check(is_equal_approx(gs.base_click_value(), 1.02), "2 Lorbeeren = +2 % Klick")
	check(gs.time_warp_unlocked(), "Zeitraffer nach dem ersten Neuanfang")
	gs.time_warp = true
	var before: float = gs.wumms
	gs.tick(10.0)
	check(is_equal_approx(gs.wumms - before, 10.0 * 1.02 * 20.0), "Zeitraffer: doppelte Produktion")
	gs.free()


func test_laurel_tree() -> void:
	print("Lorbeer-Baum")
	var gs := new_state()
	check_eq(gs.laurel_defs.size(), 20, "20 Knoten")
	for n in gs.laurel_defs:
		for r in n.get("requires", []):
			check(not gs.laurel_def(r).is_empty(), "Voraussetzung existiert: %s" % n.id)
		check(n.branch in ["handwerk", "glueck", "komfort", "show"], "Zweig gültig: %s" % n.id)
	gs.laurels_total = 3
	check(not gs.buy_laurel_node("grosseinkauf"), "Gesperrt ohne Werkzeugkiste")
	check(gs.buy_laurel_node("werkzeugkiste"), "Werkzeugkiste kaufbar")
	check_eq(gs.laurels_available(), 2, "Lorbeer ausgegeben")
	check_eq(gs.laurels_total, 3, "Bonus bleibt beim Ausgeben")
	check_eq(gs.device_cost("faust", 1), ceilf(15.0 * 0.95), "Geräte 5 % günstiger")
	check(gs.buy_laurel_node("starthilfe"), "Starthilfe kaufbar")
	gs.earn(7e13)  # bei 3 Lorbeeren braucht der nächste 4³ = 64 Billionen
	check_eq(gs.perform_prestige(), 1, "Vierter Lorbeer ab 64 Billionen")
	check_eq(gs.device_count("faust"), 10, "Starthilfe: 10 Fäuste nach Neuanfang")
	check(not gs.buy_laurel_node("goldene_faust"), "Show-Zweig kostet Beulen-Marken")
	gs.beulen_marken = 3
	check(gs.buy_laurel_node("goldene_faust"), "Goldene Faust mit Marken kaufbar")
	check_eq(gs.fist_skin, "gold", "Goldene Faust sofort aktiv")
	check_eq(gs.beulen_marken, 0, "Marken abgezogen")
	gs.laurel_nodes = {"nachtwaechter": true, "langschlaefer": true}
	check(is_equal_approx(gs.offline_rate(), 0.75), "Nachtwächter: 75 % offline")
	check(is_equal_approx(gs.offline_cap(), 24.0 * 3600.0), "Langschläfer: 24 h")
	gs.laurel_nodes = {"dauerfeuer_abo": true}
	check(gs.has_autofire(), "Dauerfeuer-Abo ohne Upgrade")
	gs.laurel_nodes = {"gluecksinstinkt": true}
	check(is_equal_approx(gs.crit_chance(), 0.03) and gs.crit_factor() == 10.0, "Glücksinstinkt: 3 % ×10")
	gs.laurel_nodes = {"autokauf": true}
	gs.wumms = 1000.0
	gs.revealed_upgrades = {}
	gs.tick(1.1)
	check(gs.has_upgrade("boxhandschuh_training"), "Automatischer Einkauf kauft Upgrades")
	gs.free()


func test_combo_and_rage() -> void:
	print("Combo und Wutmodus")
	var gs := new_state()
	for i in 60:
		gs.hit()
	check_eq(gs.combo, 100.0, "Combo max. 100")
	check(is_equal_approx(gs.click_value(), 2.0), "Combo 100 = Klick ×2")
	check_eq(int(gs.stat("max_combo")), 100, "Höchste Combo gemerkt")
	gs.tick(1.0)
	check_eq(gs.combo, 100.0, "Combo hält 2 s")
	gs.tick(1.5)
	check(gs.combo < 100.0, "Combo fällt nach Pause")
	check(not gs.rage_ready(), "Wut-Leiste noch nicht voll")
	for i in 100:
		gs.hit()
	check(gs.rage_ready(), "Wut-Leiste nach 150 Treffern voll")
	gs.devices = {"pantoffel": 10}
	var base: float = gs.wps()
	check(gs.start_rage(), "Wutmodus startet")
	check(is_equal_approx(gs.wps(), base * 3.0), "Wutmodus: WPS ×3")
	check_eq(gs.rage_meter, 0.0, "Leiste geleert")
	gs._shoe_timers["golden"] = 0.5
	gs._update_shoes(1.0)
	check(not gs._shoe_active.get("golden", false), "Im Wutmodus keine Goldenen Schuhe")
	gs.tick(10.5)
	check(not gs.rage_active(), "Wutmodus endet nach 10 s")
	check(is_equal_approx(gs.wps(), base), "WPS wieder normal")
	gs.free()


func test_bump_levels_and_gallery() -> void:
	print("Beulen-Level und Galerie")
	var gs := new_state()
	var levels: Array[int] = []
	gs.bump_level_up.connect(func(_t: String, level: int) -> void: levels.append(level))
	gs.target_hits = {"bombastus": 999}
	gs.hit()
	check_eq(levels, [1] as Array[int], "Level 1 nach 1.000 Treffern")
	check_eq(gs.beulen_marken, 1, "Beulen-Level gibt eine Marke")
	check_eq(gs.mood_index(3), 0, "Mimik gelassen bis Level 3")
	check_eq(gs.mood_index(4), 1, "Mimik genervt ab Level 4")
	check_eq(gs.mood_index(8), 2, "Mimik am Ende ab Level 8")
	check(gs.target_figure().anchors.has("eye_left"), "Bombastus hat Anker")
	check_eq(gs.figure_def("img_123").id, "_custom", "Eigene Bilder nutzen Standard-Anker")
	var entries: Array = gs.gallery_entries()
	check_eq(entries[0].id, "bombastus", "Bombastus steht in der Galerie")
	check(not gs.rename_target("bombastus", "X"), "Bombastus kann nicht umbenannt werden")
	gs.target_names = {"img_1": "Alt"}
	check(gs.rename_target("img_1", "  Neuer Name  "), "Eigenes Bild umbenennen")
	check_eq(gs.target_names.img_1, "Neuer Name", "Name gekürzt und gespeichert")
	gs.free()


func test_migration_v3() -> void:
	print("Migration v2 → v3")
	var gs := new_state()
	gs.from_dict({"version": 2, "wumms": 10.0, "total_wumms": 3e12, "achievements": ["erstes_aua", "warm_up"],
		"beulen_marken": 3, "stats": {"golden_shoes": 2}})
	check_eq(gs.lifetime_wumms, 3e12, "Lebenszeit-Wumms aus total_wumms")
	check_eq(gs.beulen_marken, 5, "Marken für bisherige Erfolge nachgezahlt")
	check_eq(gs.laurels_total, 0, "Noch keine Lorbeeren")
	check(gs.can_prestige(), "Alter Spielstand kann sofort neu anfangen")
	var again := new_state()
	again.from_dict(JSON.parse_string(JSON.stringify(gs.to_dict())))
	check_eq(again.beulen_marken, 5, "v3-Spielstand wird nicht doppelt migriert")
	gs.free()
	again.free()


func test_bosses() -> void:
	print("Boss-Kämpfe")
	var gs := new_state()
	var results: Array = []
	gs.boss_finished.connect(func(won: bool, reward: Dictionary) -> void: results.append([won, reward]))
	gs.total_hits = 99999
	check(not gs.boss_active, "Kein Boss vor 100.000 Treffern")
	gs.hit()
	check(gs.boss_active, "Boss bei 100.000 Treffern")
	check_eq(gs.boss_max_hp, 100.0, "Erster Boss hat 100 Lebenspunkte")
	check_eq(gs.boss_gimmick.id, "ducken", "Erster Boss duckt sich")
	for i in 19:
		gs.boss_damage(5.0)
	check(gs.boss_active, "Boss lebt nach 95 Schaden noch")
	gs.boss_damage(5.0)
	check(not gs.boss_active, "Boss besiegt")
	check(results[0][0], "Sieg gemeldet")
	check_eq(results[0][1].marken, 5, "Erster Boss: 5 Beulen-Marken")
	check_eq(gs.trophies.size(), 1, "Pokal in der Vitrine")
	check_eq(gs.next_boss_at, gs.total_hits + 100000, "Nächster Boss in 100.000 Treffern")
	gs.total_hits = gs.next_boss_at - 1
	gs.hit()
	check_eq(gs.boss_max_hp, 200.0, "Zweiter Boss: doppelte Lebenspunkte")
	check_eq(gs.boss_gimmick.id, "pappschild", "Zweiter Boss hat ein Pappschild")
	gs.tick(31.0)
	check(not gs.boss_active, "Boss entkommt nach 30 s")
	check(not results[1][0], "Niederlage gemeldet")
	check_eq(gs.next_boss_at, gs.total_hits + 10000, "Neuer Versuch in 10.000 Treffern")
	gs.free()


func test_quests_and_login() -> void:
	print("Tagesaufträge und Login-Serie")
	check_eq(load("res://scripts/core/game_state.gd").previous_day("2026-03-01"), "2026-02-28", "Vortag über Monatsgrenze")
	var gs := new_state()
	gs._today_override = "2026-11-02"
	gs.check_new_day()
	check_eq(gs.quests.size(), 3, "3 Aufträge pro Tag")
	var first: Array = gs.quests.map(func(q: Dictionary) -> String: return q.id)
	var other := new_state()
	other._today_override = "2026-11-02"
	other.check_new_day()
	check_eq(other.quests.map(func(q: Dictionary) -> String: return q.id), first, "Gleicher Tag = gleiche Aufträge")
	check_eq(gs.login_streak, 1, "Erster Login")
	check_eq(gs.beulen_marken, 1, "Tag 1: eine Marke")
	gs._today_override = "2026-11-03"
	gs.check_new_day()
	check_eq(gs.login_streak, 2, "Login am Folgetag zählt weiter")
	gs._today_override = "2026-11-06"
	gs.check_new_day()
	check_eq(gs.login_streak, 1, "Lücke setzt die Serie zurück")
	check_eq(int(gs.stat("best_streak")), 2, "Beste Serie gemerkt")
	# Auftrag erfüllen
	gs.quests = [{"id": "hits", "amount": 10, "reward": 2, "start": gs.total_hits, "claimed": false}]
	check_eq(gs.claim_quest(0), 0, "Unerledigt nicht abholbar")
	for i in 10:
		gs.hit()
	check(gs.quest_done(gs.quests[0]), "Nach 10 Treffern erledigt")
	check_eq(gs.claimable_quests(), 1, "Ein Auftrag abholbar")
	var marken: int = gs.beulen_marken
	check_eq(gs.claim_quest(0), 2, "Belohnung abgeholt")
	check_eq(gs.beulen_marken, marken + 2, "Marken gutgeschrieben")
	check_eq(gs.claim_quest(0), 0, "Nur einmal abholbar")
	check_eq(gs.quest_text(gs.quests[0]), "Verhaue 10 Mal ein Opfer", "Auftragstext")
	gs.free()
	other.free()


func test_events() -> void:
	print("Saison-Events")
	var gs := new_state()
	gs._today_override = "2026-11-02"
	check_eq(gs.active_event().get("id", ""), "halloween", "Anfang November: Halloween")
	check(gs.figure_available("hexe"), "Hexe während des Events verfügbar")
	check(not gs.figure_available("muffel"), "Weihnachtsmuffel noch nicht")
	var ids: Array = gs.gallery_entries().map(func(e: Dictionary) -> String: return e.id)
	check(ids.has("hexe"), "Hexe in der Galerie")
	gs.select_target("hexe")
	check_eq(gs.target_id, "hexe", "Hexe auswählbar")
	check_eq(gs.target_name(), "Halloween-Hexe Hildegard", "Name der Hexe")
	gs.event_progress[gs.event_key(gs.active_event())] = 4999
	var done: Array = []
	gs.event_completed.connect(func(e: Dictionary) -> void: done.append(e.id))
	gs.hit()
	check_eq(done, ["halloween"], "Event nach 5.000 Treffern geschafft")
	check(gs.trophies.has("Kürbis-Pokal"), "Kürbis-Pokal in der Vitrine")
	gs._today_override = "2026-12-24"
	check_eq(gs.active_event().get("id", ""), "weihnachten", "Heiligabend: Weihnachtsmuffel")
	check(gs.figure_available("hexe"), "Geschaffte Event-Figur bleibt verfügbar")
	gs._today_override = "2026-07-01"
	check(gs.active_event().is_empty(), "Im Juli kein Event")
	check(not gs.figure_available("muffel"), "Muffel außerhalb des Events weg")
	gs.free()


func test_minigames() -> void:
	print("Mini-Spiele")
	var gs := new_state()
	gs._today_override = "2026-11-02"
	check(not gs.minigame_unlocked("dojo"), "Dojo gesperrt am Anfang")
	gs.total_hits = 5000
	check(gs.minigame_unlocked("dojo"), "Dojo ab 5.000 Treffern")
	gs.check_new_day()  # Login-Bonus des Tages vorab, damit er hier nicht mitzählt
	var start: int = gs.beulen_marken
	check_eq(gs.record_minigame("dojo", 17), 2, "17 Punkte = 2 Marken")
	check_eq(gs.record_minigame("dojo", 10), 0, "Schlechteres Spiel bringt nichts extra")
	check_eq(gs.record_minigame("dojo", 60), 3, "Bis 5 Marken pro Tag aufgefüllt")
	check_eq(gs.record_minigame("dojo", 99), 0, "Tageslimit erreicht")
	check_eq(gs.beulen_marken, start + 5, "Insgesamt 5 Marken")
	check_eq(int(gs.stat("dojo_best")), 99, "Rekord gemerkt")
	gs._today_override = "2026-11-03"
	check_eq(gs.record_minigame("dojo", 40), 5, "Neuer Tag, neues Glück")
	gs.free()


func test_migration_v4() -> void:
	print("Migration v3 → v4")
	var gs := new_state()
	gs.from_dict({"version": 3, "total_hits": 250000, "total_wumms": 10.0})
	check_eq(gs.next_boss_at, 300000, "Alter Spielstand: nächster Boss beim nächsten Hunderttausend")
	check_eq(gs.trophies.size(), 0, "Noch keine Pokale")
	var again := new_state()
	again.from_dict(JSON.parse_string(JSON.stringify(gs.to_dict())))
	check_eq(again.next_boss_at, 300000, "Boss-Zähler bleibt beim Speichern erhalten")
	check_eq(load("res://scripts/core/steam_service.gd").api_name("erstes_aua"), "ERSTES_AUA", "Steam-API-Name")
	gs.free()
	again.free()


func test_figures_p5() -> void:
	print("Neue Standardfiguren")
	var gs := new_state()
	for id in ["dieter", "baron", "fiesling"]:
		var f: Dictionary = gs.figure_def(id)
		check_eq(f.id, id, "Figur vorhanden: %s" % id)
		check_eq((f.moods as Array).size(), 3, "3 Mimik-Stufen: %s" % id)
		for m in f.moods:
			check(ResourceLoader.exists(m), "Grafik existiert: %s" % m)
		check(gs.figure_available(id), "Immer verfügbar: %s" % id)
	var ids: Array = gs.gallery_entries().map(func(e: Dictionary) -> String: return e.id)
	check(ids.has("baron"), "Baron in der Galerie")
	gs.select_target("fiesling")
	check_eq(gs.target_name(), "Sir Fiesling der Dritte", "Fiesling auswählbar")
	for f in ["bombastus", "dieter", "baron", "fiesling"]:
		gs.target_hits[f] = 99
	check(not gs.achievement_met(gs.achievement_def("promi_galerie")), "Promi-Galerie erst ab 100 je Figur")
	for f in ["bombastus", "dieter", "baron", "fiesling"]:
		gs.target_hits[f] = 100
	check(gs.achievement_met(gs.achievement_def("promi_galerie")), "Promi-Galerie geschafft")
	gs.free()


func test_cosmetics() -> void:
	print("Kosmetik-Laden")
	var gs := new_state()
	for c in gs.cosmetic_defs:
		if c.slot == "fist" and c.value != "standard":
			check(ResourceLoader.exists("res://assets/cursor/fist_open_%s.svg" % c.value), "Cursor offen: %s" % c.value)
			check(ResourceLoader.exists("res://assets/cursor/fist_hit_%s.svg" % c.value), "Cursor zu: %s" % c.value)
	check(gs.has_cosmetic("fist_standard"), "Standard-Faust immer da")
	check(not gs.buy_cosmetic("fist_boxhandschuh"), "Ohne Marken nicht kaufbar")
	gs.beulen_marken = 10
	check(gs.buy_cosmetic("fist_boxhandschuh"), "Boxhandschuh kaufbar")
	check_eq(gs.beulen_marken, 4, "6 Marken abgezogen")
	check_eq(gs.fist_skin, "boxhandschuh", "Sofort angelegt")
	check(gs.cosmetic_equipped("fist_boxhandschuh"), "Als angelegt erkannt")
	check(not gs.buy_cosmetic("fist_gold"), "Goldene Faust nur über den Lorbeer-Baum")
	gs.apply_cosmetic("fist_standard")
	check_eq(gs.fist_skin, "standard", "Wieder zur normalen Faust")
	gs.apply_cosmetic("bg_arena")
	check_eq(gs.background, "standard", "Nicht gekaufter Hintergrund lässt sich nicht anlegen")
	gs.free()


func test_challenges() -> void:
	print("Herausforderungen")
	var gs := new_state()
	check(not gs.start_challenge("nur_faeuste"), "Erst nach dem ersten Neuanfang")
	gs.stats["prestiges"] = 1
	gs.laurels_total = 1
	gs.laurel_nodes = {"starthilfe": true}
	gs.wumms = 1e6
	check(gs.start_challenge("nur_faeuste"), "Nur Fäuste startet")
	check_eq(gs.wumms, 0.0, "Durchlauf beginnt von vorn")
	check_eq(gs.device_count("faust"), 0, "Keine Startgeräte bei Nur Fäuste")
	gs.wumms = 1e5
	check(not gs.buy_device("faust", 1), "Geräte verboten")
	check(gs.buy_upgrade("boxhandschuh_training"), "Upgrades erlaubt")
	check(not gs.start_challenge("inflation"), "Nur eine Herausforderung gleichzeitig")
	gs.earn(1e6)
	gs.tick(0.1)
	check_eq(gs.challenge_active, "", "Ziel erreicht – Herausforderung beendet")
	check_eq(gs.laurels_total, 2, "+1 Extra-Lorbeer")
	check_eq(gs.laurels_extra, 1, "Als Extra-Lorbeer gemerkt")
	check(not gs.start_challenge("nur_faeuste"), "Jede Herausforderung nur einmal")
	gs.lifetime_wumms = 1e12
	check_eq(gs.prestige_gain(), 0, "Extra-Lorbeeren verringern den Neuanfang-Gewinn nicht doppelt")
	gs.lifetime_wumms = 8e12
	check_eq(gs.prestige_gain(), 1, "Neuanfang zählt nur Neuanfang-Lorbeeren")
	check(gs.start_challenge("inflation"), "Inflation startet")
	check_eq(gs.device_cost("faust", 1), Balance.unit_cost(45.0, 10), "Inflation: dreifacher Preis (10 Startfäuste)")
	gs.abort_challenge()
	check_eq(gs.device_cost("faust", 1), Balance.unit_cost(15.0, 10), "Nach Abbruch normale Preise")
	check(gs.start_challenge("ohne_upgrades"), "Ohne Upgrades startet")
	gs.wumms = 1e6
	check(not gs.buy_upgrade("boxhandschuh_training"), "Upgrades verboten")
	gs.free()


func test_market() -> void:
	print("Börse für Beulen")
	var gs := new_state()
	check(not gs.market_unlocked(), "Börse gesperrt am Anfang")
	gs.lifetime_wumms = 2e7
	check(gs.market_unlocked(), "Börse ab 10 Mio. Wumms")
	gs.devices = {"pantoffel": 100}
	gs.tick(0.01)
	check(is_equal_approx(gs.market_scale, 100.0), "Preisbasis = höchste WPS")
	check_eq(gs.market_price("pflaster"), 500.0, "Pflaster = 5 s Produktion")
	gs.wumms = 1e6
	check_eq(gs.market_buy("pflaster", 10), 10, "10 Pflaster gekauft")
	check(is_equal_approx(gs.wumms, 1e6 - 5000.0), "Bezahlt")
	check_eq(gs.market_buy("pflaster", 100), 40, "Lager begrenzt auf 50")
	gs.market_factors["pflaster"] = 2.0
	var profit: float = gs.market_sell("pflaster", 50)
	check(is_equal_approx(profit, 50.0 * 500.0), "Verkauf zum doppelten Preis = Gewinn")
	check_eq(int(gs.stat("market_wins")), 1, "Gewinn-Verkauf gezählt")
	check_eq(int(gs.market_holdings.get("pflaster", 0)), 0, "Lager leer")
	gs.market_buy("torten", 5)
	gs.stats["prestiges"] = 0
	gs.earn(1e13)
	gs.perform_prestige()
	check_eq(int(gs.market_holdings.get("torten", 0)), 0, "Neuanfang schließt die Börse")
	for i in 20:
		gs.step_market()
	for g in gs.market_goods():
		var f: float = gs.market_factor(g.id)
		check(f >= 0.3 and f <= 3.0, "Kurs im Rahmen: %s" % g.id)
	gs.free()


func test_slow_motion_and_v5() -> void:
	print("Zeitlupe und Migration v4 → v5")
	var gs := new_state()
	var r: Dictionary = gs.claim_shoe("golden", 0.98)
	check_eq(r.title, "Zeitlupe!", "Roll 0,98 = Zeitlupe")
	check(is_equal_approx(gs.buff_click_multiplier(), 3.0), "Zeitlupe: Klick ×3")
	r = gs.claim_shoe("golden", 0.95)
	check_eq(r.title, "Kettenreaktion!", "Roll 0,95 = Kettenreaktion")
	var old := new_state()
	old.from_dict({"version": 4, "wumms": 5.0, "laurels_total": 3})
	check_eq(old.laurels_extra, 0, "Keine Extra-Lorbeeren in alten Spielständen")
	check(old.owned_cosmetics.is_empty(), "Laden leer")
	check_eq(old.to_dict().version, 5, "Gespeichert als v5")
	gs.free()
	old.free()


func test_english() -> void:
	print("Englisch")
	var po: Translation = load("res://locale/en.po")
	check(po != null, "locale/en.po lädt")
	# Alle Anzeigetexte aus den Daten brauchen eine englische Übersetzung.
	var gs := new_state()
	var lists: Array = [gs.device_defs, gs.upgrade_defs, gs.achievement_defs, gs.laurel_defs, gs.figure_defs,
		gs.quest_defs, gs.event_defs, gs.cosmetic_defs, gs.challenge_defs, gs.boss_config.gimmicks, gs.market_config.goods]
	var missing := 0
	for list in lists:
		for entry in list:
			for field in ["name", "description", "text", "intro", "trophy"]:
				if entry.has(field) and String(po.get_message(entry[field])) == "":
					missing += 1
					print("    fehlt: ", entry[field])
	for t in gs.boss_config.trophies:
		if String(po.get_message(t)) == "":
			missing += 1
			print("    fehlt: ", t)
	check_eq(missing, 0, "Alle Daten-Texte übersetzt")
	gs.free()
	TranslationServer.set_locale("en")
	check_eq(Num.fmt(1234), "1,234", "Englisch: Tausender mit Komma")
	check_eq(Num.fmt(1230000), "1.23 M", "Englisch: Millionen")
	check_eq(Num.fmt(7.8e12), "7.80 T", "Englisch: Billionen = trillion")
	check_eq(Num.fmt(0.5), "0.5", "Englisch: Dezimalpunkt")
	var en := new_state("en")
	check_eq(en.device_def("pantoffel").name, "Slipper", "Daten werden beim Laden übersetzt")
	check_eq(en.target_name(), "Generalissimo Bombastus von Megalomania", "Figurenname auf Englisch")
	en.quests = [{"id": "hits", "amount": 3000, "reward": 2, "start": 0, "claimed": false}]
	check_eq(en.quest_text(en.quests[0]), "Punch a target 3,000 times", "Auftragstext auf Englisch")
	check_eq(en.upgrade_effect_text(en.upgrade_def("boxhandschuh_training")), "Click value ×2", "Wirkungstext auf Englisch")
	var r: Dictionary = en.claim_shoe("golden", 0.6)
	check_eq(r.title, "Frenzy!", "Goldener-Schuh-Text auf Englisch")
	en.free()
	TranslationServer.set_locale("de")
	var de := new_state()
	check_eq(de.device_def("pantoffel").name, "Pantoffel", "Zurück auf Deutsch")
	check_eq(Num.fmt(1234), "1.234", "Deutsch: Tausenderpunkt")
	de.free()
