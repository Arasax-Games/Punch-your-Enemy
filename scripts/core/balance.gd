class_name Balance
extends RefCounted
## Reine Balancing-Formeln (siehe docs/konzept.md, Abschnitt 11).
## Keine Abhängigkeiten zum Spielzustand, damit sie leicht testbar sind.

const COST_GROWTH := 1.15
const SELL_REFUND := 0.25
const MAX_BULK := 100000


## Preis des nächsten Geräts, wenn man bereits `owned` Stück besitzt.
static func unit_cost(base_cost: float, owned: int) -> float:
	return ceilf(base_cost * pow(COST_GROWTH, owned))


## Gesamtpreis für `amount` weitere Geräte.
static func bulk_cost(base_cost: float, owned: int, amount: int) -> float:
	var total := 0.0
	for i in amount:
		total += unit_cost(base_cost, owned + i)
	return total


## Wie viele Geräte man sich mit `budget` maximal leisten kann.
static func max_affordable(base_cost: float, owned: int, budget: float) -> int:
	var count := 0
	var spent := 0.0
	while count < MAX_BULK:
		var next := unit_cost(base_cost, owned + count)
		if spent + next > budget:
			break
		spent += next
		count += 1
	return count


## Erstattung beim Verkauf eines Geräts (25 % des letzten Kaufpreises).
static func sell_refund(base_cost: float, owned: int) -> float:
	if owned <= 0:
		return 0.0
	return floorf(unit_cost(base_cost, owned - 1) * SELL_REFUND)


## Lorbeeren für den Neuanfang (Phase 3): floor(∛(Gesamt-Wumms ÷ 1 Billion)).
static func laurels_for(total_wumms: float) -> int:
	if total_wumms <= 0.0:
		return 0
	return int(floor(pow(total_wumms / 1e12, 1.0 / 3.0) + 1e-9))
