class_name Num
extends RefCounted
## Zahlenformatierung, abhängig von der Sprache:
## Deutsch: 1.234 · 1,23 Mio. · 4,56 Mrd. · 7,80 Bio. · ab 1e15 wissenschaftlich (1,50e15)
## Englisch: 1,234 · 1.23 M · 4.56 B · 7.80 T · ab 1e15 wissenschaftlich (1.50e15)

const UNITS_DE := [[1e12, "Bio."], [1e9, "Mrd."], [1e6, "Mio."]]
const UNITS_EN := [[1e12, "T"], [1e9, "B"], [1e6, "M"]]


static func _german() -> bool:
	return not TranslationServer.get_locale().begins_with("en")


## Ganze Zahl (abgerundet), z. B. für Wumms-Guthaben und Preise.
static func whole(x: float) -> String:
	return fmt(floorf(x) if absf(x) < 1e6 else x)


## Zahl mit einer Nachkommastelle bei kleinen Werten, z. B. für WPS.
static func fmt(x: float) -> String:
	if is_nan(x) or is_inf(x):
		return "∞" if is_inf(x) else "0"
	var prefix := "-" if x < 0.0 else ""
	var a := absf(x)
	if a >= 1e15:
		var e := int(floor(log(a) / log(10.0)))
		var m := a / pow(10.0, e)
		if m >= 9.995:
			m /= 10.0
			e += 1
		return prefix + _dec(m, 2) + "e" + str(e)
	if a >= 1e6:
		for unit in (UNITS_DE if _german() else UNITS_EN):
			if a >= unit[0]:
				return prefix + _dec(a / unit[0], 2) + " " + unit[1]
	if a >= 100.0 or is_equal_approx(a, roundf(a)):
		return prefix + _group(roundf(a))
	return prefix + _dec(a, 1)


static func _dec(v: float, digits: int) -> String:
	var text := ("%." + str(digits) + "f") % v
	return text.replace(".", ",") if _german() else text


static func _group(v: float) -> String:
	var sep := "." if _german() else ","
	var digits := str(int(v))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = sep + out
	return out


## Sekunden als kurze Dauer, z. B. "45 s", "12 min", "3,5 h".
static func duration(seconds: float) -> String:
	if is_inf(seconds) or seconds > 1e9:
		return TranslationServer.translate("nie")
	if seconds < 60.0:
		return "%d s" % ceili(seconds)
	if seconds < 3600.0:
		return "%d min" % ceili(seconds / 60.0)
	if seconds < 86400.0:
		return _dec(seconds / 3600.0, 1) + " h"
	return _dec(seconds / 86400.0, 1) + " " + TranslationServer.translate("Tage")
