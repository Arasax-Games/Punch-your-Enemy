extends SceneTree
## Balancing-Simulation: Ein gieriger Spieler kauft immer das Angebot mit der kürzesten Amortisation.
## Prüft die Tempo-Zielwerte aus docs/konzept.md (Abschnitt 11.2). Goldene Schuhe werden ignoriert.
## Aufruf: godot --headless --path . --script res://tests/simulate.gd
##
## Spielermodell: in der ersten Stunde 4 Klicks/s, danach 1 Klick/s im Schnitt.

const HOURS := 24.0

var gs: Node
var _first_owned: Dictionary = {}
var _log: Array[String] = []


func _initialize() -> void:
	gs = load("res://scripts/core/game_state.gd").new()
	gs.load_data()
	var t := 0.0
	var next_report := [60.0, 600.0, 3600.0, 4 * 3600.0, 12 * 3600.0, 24 * 3600.0]
	while t < HOURS * 3600.0:
		var step := 1.0 if t < 600.0 else (5.0 if t < 3600.0 else 30.0)
		var cps := _clicks_per_second(t)
		gs.earn(gs.click_value() * cps * step)
		gs.total_hits += int(cps * step)
		gs.tick(step)
		t += step
		_buy_greedy(t)
		gs.check_achievements()
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
			gs.buy_device(best.id, 1)
			if not _first_owned.has(best.id):
				_first_owned[best.id] = t
		else:
			gs.buy_upgrade(best.id)


func _best_option() -> Dictionary:
	var base := _income()
	var best := {}
	var best_score := INF
	for i in gs.device_defs.size():
		if not gs.is_device_visible(i):
			continue
		var id: String = gs.device_defs[i].id
		var cost: float = gs.device_cost(id, 1)
		var gain: float = gs.device_unit_wps(id)
		var score := cost / maxf(gain, 1e-9) + cost / maxf(base, 1e-9)
		if score < best_score:
			best_score = score
			best = {"kind": "device", "id": id, "cost": cost}
	for u in gs.visible_upgrades():
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
	_log.append("%-8s Wumms gesamt %-12s WPS %-12s Gerätetypen %2d (höchstes: %2d)  Upgrades %2d  Erfolge %2d  Lorbeeren bei Neuanfang %d" % [
		Num.duration(at), Num.fmt(gs.total_wumms), Num.fmt(gs.wps()), types, highest,
		gs.upgrades.size(), gs.achievement_count(), Balance.laurels_for(gs.total_wumms)])
