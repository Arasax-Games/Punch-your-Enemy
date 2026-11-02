extends Control
## Hauptbildschirm: verbindet Zielbild, Statistik, Shop, Ticker und Bild-Import.

const INK := Color("2b2118")
const PAPER := Color("fff8ec")
const AMOUNT_MODES: Array[int] = [1, 10, 100, -1]
const TICKER_INTERVAL := 9.0
const TICKER_LINES: Array[String] = [
	"Nachbarn beschweren sich über Quietschen.",
	"Der Mond sagt, er sei bereit.",
	"Pantoffel-Hersteller meldet Rekordumsatz.",
	"Generalissimo Bombastus bestellt vorsorglich 400 Eisbeutel.",
	"Studie: 9 von 10 Gummihämmern quietschen gern.",
	"Konditorei-Verband warnt vor Tortenknappheit.",
	"Bombastus verleiht sich selbst den Orden für das tapferste Kinn.",
	"Eilmeldung: Schnurrbart wackelt weiterhin.",
	"Versicherung lehnt Antrag „Beule, groß, schon wieder“ ab.",
	"Katapult-Gewerkschaft fordert längere Federn.",
	"Pflaster-Aktie erreicht Allzeithoch.",
	"Augenzeuge: „Es hat sehr laut BOING gemacht.“",
]

@onready var target_area: TargetArea = %TargetArea
@onready var wumms_label: Label = %WummsLabel
@onready var wps_label: Label = %WpsLabel
@onready var click_label: Label = %ClickLabel
@onready var target_label: Label = %TargetLabel
@onready var target_hits_label: Label = %TargetHitsLabel
@onready var total_label: Label = %TotalLabel
@onready var hits_label: Label = %HitsLabel
@onready var upgrade_flow: HFlowContainer = %UpgradeFlow
@onready var no_upgrades_label: Label = %NoUpgradesLabel
@onready var amount_row: HBoxContainer = %AmountRow
@onready var device_list: VBoxContainer = %DeviceList
@onready var ticker_label: Label = %TickerLabel
@onready var toast: Label = %Toast

var _buy_mode := 1
var _device_rows: Dictionary = {}       # id -> {panel, name, info, buy, sell}
var _upgrade_buttons: Dictionary = {}   # id -> Button
var _shown_upgrade_ids: Array[String] = []
var _refresh_timer := 0.0
var _ticker_timer := 0.0
var _ticker_index := 0
var _toast_tween: Tween
var _file_dialog: FileDialog


func _ready() -> void:
	theme = _build_theme()
	_style_labels()
	_build_amount_buttons()
	_build_device_rows()
	_build_file_dialog()
	_connect_ui()

	target_area.hit.connect(_on_target_hit)
	GameState.target_changed.connect(_on_target_changed)
	GameState.device_bought.connect(func(_id: String, _n: int) -> void: Sfx.play("buy", 0.05, -6.0))
	GameState.upgrade_bought.connect(func(_id: String) -> void: Sfx.play("buy", 0.0, -4.0))
	get_window().files_dropped.connect(_on_files_dropped)

	_on_target_changed()
	_refresh()
	_ticker_index = randi() % TICKER_LINES.size()
	_show_ticker()
	if GameState.total_hits == 0:
		show_toast("Hau drauf! Klicken oder Leertaste.")


func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.1
		_refresh()
	_ticker_timer += delta
	if _ticker_timer >= TICKER_INTERVAL:
		_ticker_timer = 0.0
		_ticker_index += 1
		_show_ticker()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode == KEY_SPACE:
		target_area.hit_somewhere()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_V and key.is_command_or_control_pressed():
		_paste_image()
		get_viewport().set_input_as_handled()
	elif key.keycode >= KEY_1 and key.keycode <= KEY_9:
		var index := int(key.keycode - KEY_1)
		if index < GameState.device_defs.size() and GameState.is_device_visible(index):
			_buy(GameState.device_defs[index].id)
		get_viewport().set_input_as_handled()


# =====================================================================
# Aufbau der Oberfläche
# =====================================================================

func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 17
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Nunito", "Segoe UI", "Helvetica Neue", "Arial", "sans-serif"])
	font.font_weight = 600
	t.default_font = font

	for type in ["Label", "Button", "CheckButton", "TooltipLabel"]:
		t.set_color("font_color", type, INK)
	for state in ["font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, "Button", INK)
		t.set_color(state, "CheckButton", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.45))

	t.set_stylebox("panel", "PanelContainer", _box(PAPER, 14, 3, 12))
	t.set_stylebox("panel", "TooltipPanel", _box(Color("fffdf7"), 10, 2, 10))
	t.set_stylebox("normal", "Button", _box(Color("ffd43b"), 10, 3, 8))
	t.set_stylebox("hover", "Button", _box(Color("ffe066"), 10, 3, 8))
	t.set_stylebox("pressed", "Button", _box(Color("fab005"), 10, 3, 8))
	t.set_stylebox("hover_pressed", "Button", _box(Color("fab005"), 10, 3, 8))
	t.set_stylebox("disabled", "Button", _box(Color("eee3d0"), 10, 3, 8, Color(INK, 0.35)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	var sep := StyleBoxLine.new()
	sep.color = Color(INK, 0.25)
	sep.thickness = 2
	t.set_stylebox("separator", "HSeparator", sep)
	return t


func _box(bg: Color, radius: int, border: int, margin: int, border_color: Color = INK) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = border_color
	sb.content_margin_left = margin + 4
	sb.content_margin_right = margin + 4
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	return sb


func _style_labels() -> void:
	_comic(%Title, 34, Color("ff6fae"))
	_comic(wumms_label, 46, Color("ffd43b"))
	_comic(%UpgradesTitle, 24, Color("3bc9db"))
	_comic(%DevicesTitle, 24, Color("3bc9db"))
	_comic(toast, 26, Color.WHITE)
	wps_label.add_theme_font_size_override("font_size", 19)
	%HelpLabel.add_theme_font_size_override("font_size", 14)
	%HelpLabel.add_theme_color_override("font_color", Color(INK, 0.65))


func _comic(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", maxi(6, font_size / 4))


func _build_amount_buttons() -> void:
	var group := ButtonGroup.new()
	for mode in AMOUNT_MODES:
		var b := Button.new()
		b.text = "Max" if mode < 0 else "×%d" % mode
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = mode == _buy_mode
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func() -> void: _buy_mode = mode)
		amount_row.add_child(b)


func _build_device_rows() -> void:
	for i in GameState.device_defs.size():
		var d: Dictionary = GameState.device_defs[i]
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.add_theme_stylebox_override("panel", _box(Color("fffdf7"), 12, 2, 8))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		panel.add_child(row)

		var badge := Label.new()
		badge.text = str(i + 1)
		badge.custom_minimum_size = Vector2(40, 40)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.add_theme_stylebox_override("normal", _box(Color(d.get("color", "#ffd43b")), 20, 2, 0))
		badge.add_theme_font_size_override("font_size", 20)
		row.add_child(badge)

		var info_box := VBoxContainer.new()
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_box.add_theme_constant_override("separation", 0)
		var name_label := Label.new()
		name_label.text = d.name
		name_label.add_theme_font_size_override("font_size", 18)
		var info_label := Label.new()
		info_label.add_theme_font_size_override("font_size", 13)
		info_label.add_theme_color_override("font_color", Color(INK, 0.7))
		info_box.add_child(name_label)
		info_box.add_child(info_label)
		row.add_child(info_box)

		var sell := Button.new()
		sell.text = "−"
		sell.tooltip_text = "Eins verkaufen (25 % zurück)"
		sell.focus_mode = Control.FOCUS_NONE
		sell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sell.pressed.connect(func() -> void: GameState.sell_device(d.id))
		row.add_child(sell)

		var buy := Button.new()
		buy.custom_minimum_size = Vector2(118, 0)
		buy.focus_mode = Control.FOCUS_NONE
		buy.add_theme_font_size_override("font_size", 15)
		buy.pressed.connect(func() -> void: _buy(d.id))
		row.add_child(buy)

		device_list.add_child(panel)
		_device_rows[d.id] = {"panel": panel, "info": info_label, "buy": buy, "sell": sell, "index": i}


func _build_file_dialog() -> void:
	_file_dialog = FileDialog.new()
	_file_dialog.title = "Neues Opfer wählen – nimm Bilder, bei denen alle Beteiligten Spaß verstehen"
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Bilder"])
	_file_dialog.use_native_dialog = true
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)


func _connect_ui() -> void:
	%ImportButton.pressed.connect(func() -> void: _file_dialog.popup_centered_ratio(0.7))
	%DefaultButton.pressed.connect(GameState.use_default_target)
	%ShowerButton.pressed.connect(func() -> void:
		target_area.effects.clear()
		show_toast("Frisch geduscht!"))
	%SaveButton.pressed.connect(func() -> void:
		if GameState.save_game():
			show_toast("Gespeichert."))
	var sound: CheckButton = %SoundButton
	sound.button_pressed = GameState.sound_on
	sound.toggled.connect(func(on: bool) -> void: GameState.sound_on = on)
	var fx: CheckButton = %EffectsButton
	fx.button_pressed = GameState.reduced_effects
	fx.toggled.connect(func(on: bool) -> void: GameState.reduced_effects = on)


# =====================================================================
# Aktualisierung
# =====================================================================

func _refresh() -> void:
	wumms_label.text = Num.whole(GameState.wumms)
	wps_label.text = "pro Sekunde: %s" % Num.fmt(GameState.wps())
	click_label.text = "pro Klick: %s" % Num.fmt(GameState.click_value())
	target_label.text = "Opfer: %s" % GameState.target_name()
	target_hits_label.text = "Insgesamt verhauen: %s" % Num.whole(GameState.current_target_hits())
	total_label.text = "Insgesamt erzeugt: %s Wumms" % Num.whole(GameState.total_wumms)
	hits_label.text = "Treffer gesamt: %s" % Num.whole(GameState.total_hits)
	_refresh_devices()
	_refresh_upgrades()


func _refresh_devices() -> void:
	var total_wps := GameState.wps()
	for id in _device_rows:
		var row: Dictionary = _device_rows[id]
		var d := GameState.device_def(id)
		var visible_now := GameState.is_device_visible(row.index)
		row.panel.visible = visible_now
		if not visible_now:
			continue
		var owned := GameState.device_count(id)
		var amount := GameState.amount_for_mode(id, _buy_mode)
		var shown_amount := maxi(amount, 1)
		var cost := GameState.device_cost(id, shown_amount)
		var unit_wps := GameState.device_unit_wps(id)
		row.info.text = "Besitz: %s · je %s WPS" % [Num.whole(owned), Num.fmt(unit_wps)]
		var label := "Kaufen" if _buy_mode == 1 else "×%s" % Num.whole(shown_amount)
		row.buy.text = "%s\n%s" % [label, Num.whole(cost)]
		row.buy.disabled = amount <= 0 or GameState.wumms < cost
		row.sell.disabled = owned <= 0
		var share := 0.0 if total_wps <= 0.0 else GameState.device_total_wps(id) / total_wps * 100.0
		var payback := INF if unit_wps <= 0.0 else Balance.unit_cost(float(d.base_cost), owned) / unit_wps
		row.panel.tooltip_text = "%s\n\n%s\nJedes Gerät: %s WPS\nAlle zusammen: %s WPS (%s %% deiner Produktion)\nAmortisation: %s" % [
			d.name, d.description, Num.fmt(unit_wps), Num.fmt(GameState.device_total_wps(id)),
			Num.fmt(share), Num.duration(payback)]


func _refresh_upgrades() -> void:
	var visible_list := GameState.visible_upgrades()
	var ids: Array[String] = []
	for u in visible_list:
		ids.append(u.id)
	if ids != _shown_upgrade_ids:
		_rebuild_upgrades(visible_list)
		_shown_upgrade_ids = ids
	for id in _upgrade_buttons:
		var u := GameState.upgrade_def(id)
		_upgrade_buttons[id].disabled = GameState.wumms < float(u.cost)
	no_upgrades_label.visible = ids.is_empty()


func _rebuild_upgrades(list: Array[Dictionary]) -> void:
	for id in _upgrade_buttons:
		_upgrade_buttons[id].queue_free()
	_upgrade_buttons.clear()
	for u in list:
		var b := Button.new()
		b.text = "%s\n%s" % [u.name, Num.whole(float(u.cost))]
		b.custom_minimum_size = Vector2(170, 0)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_stylebox_override("normal", _box(Color("a5f3fc"), 10, 3, 6))
		b.add_theme_stylebox_override("hover", _box(Color("c5f6fa"), 10, 3, 6))
		b.tooltip_text = "%s\n\n%s\n\nWirkung: %s\nPreis: %s Wumms" % [
			u.name, u.description, GameState.upgrade_effect_text(u), Num.whole(float(u.cost))]
		var id: String = u.id
		b.pressed.connect(func() -> void:
			if GameState.buy_upgrade(id):
				show_toast("Upgrade gekauft: %s" % u.name))
		upgrade_flow.add_child(b)
		_upgrade_buttons[id] = b


func _show_ticker() -> void:
	ticker_label.text = "+++ %s +++" % TICKER_LINES[_ticker_index % TICKER_LINES.size()]


func show_toast(text: String) -> void:
	toast.text = text
	toast.visible = true
	toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void: toast.visible = false)


# =====================================================================
# Aktionen
# =====================================================================

func _buy(id: String) -> void:
	var amount := GameState.amount_for_mode(id, _buy_mode)
	GameState.buy_device(id, amount)


func _on_target_hit(uv: Vector2) -> void:
	var result := GameState.hit()
	target_area.effects.add_hit(uv, result.value, result.crit)
	target_area.squash()
	Sfx.play_hit(result.crit)
	if result.crit:
		target_area.shake()


func _on_target_changed() -> void:
	target_area.set_texture(GameState.target_texture())
	_refresh()


func _on_file_selected(path: String) -> void:
	if GameState.import_image_file(path):
		show_toast("Neues Opfer: %s" % GameState.target_name())
	else:
		show_toast("Dieses Bild konnte nicht geladen werden.")


func _on_files_dropped(files: PackedStringArray) -> void:
	if files.is_empty():
		return
	_on_file_selected(files[0])


func _paste_image() -> void:
	if not DisplayServer.clipboard_has_image():
		show_toast("In der Zwischenablage ist kein Bild.")
		return
	if GameState.import_image(DisplayServer.clipboard_get_image(), "Aus der Zwischenablage"):
		show_toast("Neues Opfer aus der Zwischenablage!")
