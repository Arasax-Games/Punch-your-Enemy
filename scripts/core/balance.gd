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


## Abstand bis zum nächsten Goldenen Schuh in Sekunden: zufall(300, 600) ÷ glück. `roll` liegt in 0..1.
static func golden_interval(roll: float, luck: float) -> float:
	return lerpf(300.0, 600.0, clampf(roll, 0.0, 1.0)) / maxf(luck, 0.01)


## Abstand bis zum nächsten Silbernen Pantoffel (häufiger, schwächer).
static func silver_interval(roll: float, luck: float) -> float:
	return lerpf(90.0, 240.0, clampf(roll, 0.0, 1.0)) / maxf(luck, 0.01)


## Wumms-Segen: `minutes` Minuten Produktion, höchstens `bank_share` des Guthabens, plus ein kleiner Sockel.
static func blessing(wps: float, bank: float, minutes: float, bank_share: float, floor_amount: float) -> float:
	return minf(wps * minutes * 60.0, bank * bank_share) + floor_amount


## Offline-Fortschritt: `rate` der WPS für höchstens `cap_seconds`.
static func offline_gain(wps: float, seconds: float, rate: float = 0.5, cap_seconds: float = 8.0 * 3600.0) -> float:
	if seconds <= 0.0:
		return 0.0
	return wps * rate * minf(seconds, cap_seconds)


## Synergie-Bonus: +`percent` je `per` Geräte der Quelle.
static func synergy_bonus(source_count: int, percent: float, per: int) -> float:
	return 1.0 + percent * floorf(float(source_count) / float(maxi(per, 1)))


## Ab so viel insgesamt erzeugtem Wumms ist ein Neuanfang möglich.
const PRESTIGE_THRESHOLD := 1e12


## Wie viele Lorbeeren ein Neuanfang jetzt zusätzlich bringen würde.
static func laurel_gain(lifetime_wumms: float, laurels_already: int) -> int:
	return maxi(0, laurels_for(lifetime_wumms) - laurels_already)


## Dauerhafter Bonus durch Lorbeeren: +1 % je Lorbeer.
static func laurel_bonus(laurels: int) -> float:
	return 1.0 + 0.01 * laurels


## Combo-Bonus auf den Klick-Wert: 0 → ×1, 100 → ×2.
static func combo_multiplier(combo: float) -> float:
	return 1.0 + clampf(combo, 0.0, 100.0) / 100.0


## Beulen-Level eines Opfers: alle 1.000 Treffer eins, höchstens 10.
static func bump_level(hits: int) -> int:
	return mini(10, int(hits / 1000))


## Lebenspunkte des n-ten Bosses (n = bisher besiegte Bosse): 100 × 2^n Klick-Äquivalente.
static func boss_hp(defeated: int, base_hp: float = 100.0) -> float:
	return base_hp * pow(2.0, defeated)


## Belohnung eines Mini-Spiels in Beulen-Marken (höchstens `cap` pro Spiel und Tag).
static func minigame_reward(score: int, points_per_marke: int, cap: int = 5) -> int:
	return clampi(score / maxi(points_per_marke, 1), 0, cap)


## Login-Serie: Tag 1–7 im Kreis, Belohnung = Tag in Beulen-Marken (Tag 7: +3 extra).
static func login_day(streak: int) -> int:
	return ((maxi(streak, 1) - 1) % 7) + 1


static func login_marken(streak: int) -> int:
	var day := login_day(streak)
	return day + (3 if day == 7 else 0)


## Börsenkurs: wandert zufällig, zieht aber immer wieder Richtung 1 (Normalpreis). `noise` ~ N(0, 1).
static func market_step(factor: float, noise: float, volatility: float) -> float:
	return clampf(factor + (1.0 - factor) * 0.1 + noise * volatility, 0.3, 3.0)


## Preis einer Börsenware: so viele Sekunden Produktion × Kursfaktor (mindestens 1 WPS als Basis).
static func market_price(seconds: float, wps_scale: float, factor: float) -> float:
	return ceilf(seconds * maxf(wps_scale, 1.0) * factor)


## Geräte-Meilensteine: ab so vielen Stück bekommt ein Gerät eine neue Optik.
const MILESTONES: Array[int] = [1, 5, 25, 50, 100, 150, 200]


## Meilenstein-Stufe (0 = keins, 1 = ab 1 Stück … 7 = ab 200 Stück).
static func milestone_tier(count: int) -> int:
	var tier := 0
	for m in MILESTONES:
		if count >= m:
			tier += 1
	return tier


## Lorbeeren für den Neuanfang: floor(∛(Gesamt-Wumms ÷ 1 Billion)).
static func laurels_for(total_wumms: float) -> int:
	if total_wumms <= 0.0:
		return 0
	return int(floor(pow(total_wumms / 1e12, 1.0 / 3.0) + 1e-9))
