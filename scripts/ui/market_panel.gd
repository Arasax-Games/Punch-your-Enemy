class_name MarketPanel
extends VBoxContainer
## Inhalt des Börsen-Dialogs: Waren, Kurse, Bestand und Kauf/Verkauf. Aktualisiert sich selbst.
## Kurse ändern sich jede Minute; Preise skalieren mit der höchsten WPS dieses Durchlaufs.

const INK := Color("2b2118")
const COLUMNS: Array[float] = [150.0, 110.0, 120.0, 90.0, 110.0]

var _rows: Dictionary = {}  # id -> {price, trend, held, buy1, buy10, sell}
var _last_prices: Dictionary = {}
var _info: Label
var _timer := 0.0


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(760, 0)
	_info.add_theme_font_size_override("font_size", 14)
	_info.add_theme_color_override("font_color", Color("a99fdc"))
	add_child(_info)
	var header := _row_box()
	for i in COLUMNS.size():
		header.add_child(_cell([tr("Ware"), tr("Kurs"), tr("Trend"), tr("Bestand"), tr("Ø Einkauf")][i], 15, COLUMNS[i], true))
	add_child(header)
	for g in GameState.market_goods():
		var row := _row_box()
		row.add_child(_cell(String(g.name), 17, COLUMNS[0]))
		var price := _cell("", 17, COLUMNS[1])
		var trend := _cell("", 17, COLUMNS[2])
		var held := _cell("", 17, COLUMNS[3])
		var avg := _cell("", 15, COLUMNS[4])
		row.add_child(price)
		row.add_child(trend)
		row.add_child(held)
		row.add_child(avg)
		var id: String = g.id
		var buy1 := _button("+1", func() -> void: GameState.market_buy(id, 1))
		var buy10 := _button("+10", func() -> void: GameState.market_buy(id, 10))
		var sell := _button(tr("Alles verkaufen"), func() -> void: _sell_all(id))
		row.add_child(buy1)
		row.add_child(buy10)
		row.add_child(sell)
		add_child(row)
		_rows[id] = {"price": price, "trend": trend, "held": held, "avg": avg, "buy1": buy1, "buy10": buy10, "sell": sell}
		_last_prices[id] = GameState.market_price(id)
	_refresh()


func _row_box() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	return h


func _cell(text: String, font_size: int, width: float, muted: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(width, 0)
	l.clip_text = true
	l.add_theme_font_size_override("font_size", font_size)
	if muted:
		l.add_theme_color_override("font_color", Color(INK, 0.6))
	return l


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(func() -> void:
		action.call()
		Sfx.play("buy", 0.1, -8.0)
		_refresh())
	return b


func _sell_all(id: String) -> void:
	var profit := GameState.market_sell(id, int(GameState.market_holdings.get(id, 0)))
	var owner := get_tree().current_scene
	if owner and owner.has_method("show_toast"):
		owner.show_toast((tr("Gewinn: +%s Schmerz-Token") if profit >= 0.0 else tr("Verlust: %s Schmerz-Token")) % Num.whole(profit))


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= 0.5:
		_timer = 0.0
		_refresh()


func _refresh() -> void:
	_info.text = tr("Kaufe Ware billig, verkaufe sie teuer. Die Kurse ändern sich jede Minute. Lager: höchstens %d Stück pro Ware. Guthaben: %s Schmerz-Token.\nAchtung: Beim Neuanfang schließt die Börse – nicht verkaufte Ware ist dann weg.") % [
		GameState.market_capacity(), Num.whole(GameState.wumms)]
	for id in _rows:
		var r: Dictionary = _rows[id]
		var price := GameState.market_price(id)
		var factor := GameState.market_factor(id)
		r.price.text = Num.whole(price)
		var last: float = _last_prices.get(id, price)
		r.trend.text = tr("▲ teuer") if factor > 1.3 else (tr("▼ billig") if factor < 0.75 else tr("● normal"))
		r.trend.add_theme_color_override("font_color", Color("c92a2a") if factor > 1.3 else (Color("2f9e44") if factor < 0.75 else Color(INK, 0.6)))
		var held := int(GameState.market_holdings.get(id, 0))
		r.held.text = "%d / %d" % [held, GameState.market_capacity()]
		r.avg.text = "–" if held == 0 else Num.whole(GameState.market_average_price(id))
		r.buy1.disabled = GameState.wumms < price or held >= GameState.market_capacity()
		r.buy10.disabled = r.buy1.disabled
		r.sell.disabled = held == 0
		if not is_equal_approx(last, price):
			_last_prices[id] = price
