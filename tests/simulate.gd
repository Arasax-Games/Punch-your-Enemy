extends SceneTree
## Balancing-Simulation: Ein gieriger Spieler kauft immer das Angebot mit der kürzesten Amortisation.
## Prüft die Tempo-Zielwerte aus docs/konzept.md (Abschnitt 11.2). Goldene Schuhe werden ignoriert.
## Aufruf: godot --headless --path . --script res://tests/simulate.gd
##        godot --headless --path . --script res://tests/simulate.gd -- --days 7   (mit Neuanfängen)
##
## Spielermodell: in der ersten Stunde jedes Durchlaufs 4 Klicks/s, danach 1 Klick/s im Schnitt.
## Mehrtägig: Neuanfang, sobald er die Lorbeeren mindestens verdoppelt; Lorbeeren werden sofort
## in den günstigsten Knoten des Lorbeer-Baums gesteckt.

var hours := 24.0
var challenge := ""
var _run_start := 0.0

var gs: Node
var _first_owned: Dictionary = {}
var _log: Array[String] = []


func _initialize() -> void:
	TranslationServer.set_locale("de")
	var args := OS.get_cmdline_user_args()
	var days_at := args.find("--days")
	if days_at >= 0 and days_at + 1 < args.size():
		hours = float(args[days_at + 1]) * 24.0
	var ch_at := args.find("--challenge")
	if ch_at >= 0 and ch_at + 1 < args.size():
		challenge = args[ch_at + 1]
	TranslationServer.set_locale("de")
	gs = load("res://scripts/core/game_state.gd").new()
	gs.persist = false
	gs.load_data()
	if challenge != "":
		# Typische Lage: nach dem ersten Neuanfang mit 1 Lorbeer
		gs.stats["prestiges"] = 1
		gs.laurels_total = 1
		gs.start_challenge(challenge)
		_log.append("Herausforderung: %s (Ziel %s Wumms)" % [challenge, Num.fmt(float(gs.challenge_def(challenge).goal_wumms))])
	var t := 0.0
	var next_report := [60.0, 600.0, 3600.0, 4 * 3600.0, 12 * 3600.0]
	for d in range(1, int(ceil(hours / 24.0)) + 1):
		next_report.append(d * 24.0 * 3600.0)
	var multi_day := hours > 24.0
	while t < hours * 3600.0:
		var run_t := t - _run_start
		var step := 1.0 if run_t < 600.0 else (5.0 if run_t < 3600.0 else (30.0 if not multi_day else 60.0))
		var cps := _clicks_per_second(run_t)
		gs.earn(gs.click_value() * cps * step)
		gs.total_hits += int(cps * step)
		gs.tick(step)
		t += step
		_buy_greedy(t)
		gs.check_achievements()
		if challenge != "" and gs.challenges_done.has(challenge):
			_log.append("  → Herausforderung geschafft nach %s" % Num.duration(t))
			challenge = ""
		if multi_day and gs.can_prestige() and gs.prestige_gain() >= maxi(1, gs.laurels_total):
			var gain: int = gs.perform_prestige()
			_run_start = t
			_log.append("  → Neuanfang nach %s: +%d Lorbeeren (gesamt %d)" % [Num.duration(t), gain, gs.laurels_total])
			_spend_laurels()
		if not next_report.is_empty() and t >= next_report[0]:
			_report(next_report.pop_front())
	print("\n".join(_log))
	print("")
	for i in gs.device_defs.size():
		var id: String = gs.device_defs[i].id
		var when: String = Num.duration(_first_owned[id]) if _first_owned.has(id) else "–"
		print("Gerät %2d %-30s zuerst nach %s" % [i + 1, gs.device_defs[i].name, when])
	gs.free()
	quit()


func _spend_laurels() -> void:
	for guard in 50:
		var best := {}
		for n in gs.laurel_defs:
			if gs.has_laurel_node(n.id):
				continue
			if gs.laurel_requirements_met(n) and gs.can_afford_laurel_node(n):
				if best.is_empty() or int(n.cost) < int(best.cost):
					best = n
		if best.is_empty():
			return
		gs.buy_laurel_node(best.id)


func _clicks_per_second(t: float) -> float:
	return 4.0 if t < 3600.0 else 1.0


func _income() -> float:
	return gs.wps() + gs.click_value() * _clicks_per_second(0.0)


func _buy_greedy(t: float) -> void:
	for guard in 200:
		var best := _best_option()
		if best.is_empty() or gs.wumms < best.cost:
			return
		if best.kind == "device":
			if not gs.buy_device(best.id, 1):
				return
			if not _first_owned.has(best.id):
				_first_owned[best.id] = t
		elif not gs.buy_upgrade(best.id):
			return


func _best_option() -> Dictionary:
	var base := _income()
	var best := {}
	var best_score := INF
	var rules: Dictionary = gs.challenge_rules()
	for i in gs.device_defs.size():
		if rules.get("no_devices", false) or not gs.is_device_visible(i):
			continue
		var id: String = gs.device_defs[i].id
		var cost: float = gs.device_cost(id, 1)
		var gain: float = gs.device_unit_wps(id)
		var score := cost / maxf(gain, 1e-9) + cost / maxf(base, 1e-9)
		if score < best_score:
			best_score = score
			best = {"kind": "device", "id": id, "cost": cost}
	for u in ([] if rules.get("no_upgrades", false) else gs.visible_upgrades()):
		var cost := float(u.cost)
		gs.upgrades[u.id] = true
		var gain := _income() - base
		gs.upgrades.erase(u.id)
		if gain <= 0.0:
			gain = base * 0.01  # z. B. Glück oder Dauerfeuer: kleiner Pauschalwert
		var score := cost / gain + cost / maxf(base, 1e-9)
		if score < best_score:
			best_score = score
			best = {"kind": "upgrade", "id": u.id, "cost": cost}
	return best


func _report(at: float) -> void:
	var types := 0
	var highest := 0
	for i in gs.device_defs.size():
		if gs.device_count(gs.device_defs[i].id) > 0:
			types += 1
			highest = i + 1
	_log.append("%-8s Wumms gesamt %-12s WPS %-12s Gerätetypen %2d (höchstes: %2d)  Upgrades %2d  Erfolge %2d  Lorbeeren %d (+%d möglich)  Baum %d/%d  Marken %d" % [
		Num.duration(at), Num.fmt(gs.lifetime_wumms), Num.fmt(gs.wps()), types, highest,
		gs.upgrades.size(), gs.achievement_count(), gs.laurels_total, gs.prestige_gain(),
		gs.laurel_nodes.size(), gs.laurel_defs.size(), gs.beulen_marken])
