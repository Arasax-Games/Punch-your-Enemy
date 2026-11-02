extends Control
## Hauptbildschirm: verbindet Zielbild, Statistik, Shop, Ticker, Ereignisse, Erfolge und Bild-Import.

const INK := Color("2b2118")
const PAPER := Color("fff8ec")
const AMOUNT_MODES: Array[int] = [1, 10, 100, -1]
const TICKER_INTERVAL := 9.0
const MAX_ACHIEVEMENT_TOASTS := 3
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
	"Sichtung: Goldener Schuh in der Innenstadt. Bitte Ruhe bewahren.",
	"Wetterbericht: Heute vereinzelt Ambosse, gegen Abend Torten.",
	"Boxroboter bestehen den Turing-Test nicht. Und wollen es auch nicht.",
	"Astronomen bestätigen: Der Mond hat Muskelkater.",
]
const MENU_SAVE := 0
const MENU_EXPORT := 1
const MENU_IMPORT := 2
const MENU_RESET := 3

@onready var target_area: TargetArea = %TargetArea
@onready var wumms_label: Label = %WummsLabel
@onready var wps_label: Label = %WpsLabel
@onready var click_label: Label = %ClickLabel
@onready var marken_label: Label = %MarkenLabel
@onready var buff_box: VBoxContainer = %BuffBox
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
@onready var shoe_layer: Control = %ShoeLayer
@onready var achievement_toasts: VBoxContainer = %AchievementToasts

var _buy_mode := 1
var _device_rows: Dictionary = {}       # id -> {panel, info, buy, sell, index}
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
	_build_menu()
	_connect_ui()

	target_area.hit.connect(_on_target_hit)
	GameState.target_changed.connect(_on_target_changed)
	GameState.device_bought.connect(func(_id: String, _n: int) -> void: Sfx.play("buy", 0.05, -6.0))
	GameState.upgrade_bought.connect(func(_id: String) -> void: Sfx.play("buy", 0.0, -4.0))
	GameState.achievement_unlocked.connect(_on_achievement_unlocked)
	GameState.shoe_spawned.connect(_spawn_shoe)
	get_window().files_dropped.connect(_on_files_dropped)

	_on_target_changed()
	_refresh()
	_ticker_index = randi() % TICKER_LINES.size()
	_show_ticker()
	if not GameState.pending_offline.is_empty():
		_show_welcome_back.call_deferred(GameState.pending_offline)
		GameState.pending_offline = {}
	elif GameState.total_hits == 0:
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
	if _modal_open():
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


func _modal_open() -> bool:
	for child in get_children():
		if child is Modal:
			return true
	return false


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

	for type in ["Label", "Button", "CheckButton", "MenuButton", "TooltipLabel", "PopupMenu", "LineEdit"]:
		t.set_color("font_color", type, INK)
	for state in ["font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		for type in ["Button", "CheckButton", "MenuButton"]:
			t.set_color(state, type, INK)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.45))

	t.set_stylebox("panel", "PanelContainer", _box(PAPER, 14, 3, 12))
	t.set_stylebox("panel", "TooltipPanel", _box(Color("fffdf7"), 10, 2, 10))
	t.set_stylebox("panel", "PopupMenu", _box(Color("fffdf7"), 10, 3, 8))
	t.set_stylebox("hover", "PopupMenu", _box(Color("ffe066"), 6, 0, 4))
	for type in ["Button", "MenuButton"]:
		t.set_stylebox("normal", type, _box(Color("ffd43b"), 10, 3, 8))
		t.set_stylebox("hover", type, _box(Color("ffe066"), 10, 3, 8))
		t.set_stylebox("pressed", type, _box(Color("fab005"), 10, 3, 8))
		t.set_stylebox("hover_pressed", type, _box(Color("fab005"), 10, 3, 8))
		t.set_stylebox("disabled", type, _box(Color("eee3d0"), 10, 3, 8, Color(INK, 0.35)))
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("normal", "LineEdit", _box(Color.WHITE, 8, 2, 8))
	t.set_stylebox("focus", "LineEdit", _box(Color.WHITE, 8, 3, 8, Color("3bc9db")))
	t.set_stylebox("background", "ProgressBar", _box(Color("eee3d0"), 6, 2, 0))
	t.set_stylebox("fill", "ProgressBar", _box(Color("69db7c"), 6, 2, 0))
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
	marken_label.add_theme_color_override("font_color", Color("c2255c"))
	%HelpLabel.add_theme_font_size_override("font_size", 14)
	%HelpLabel.add_theme_color_override("font_color", Color(INK, 0.65))
	%HelpLabel.text = "Klick oder Leertaste: hauen\n1–9: Gerät kaufen\nStrg+V: Bild einfügen\nBild ins Fenster ziehen: neues Opfer\nGoldene Schuhe anklicken!"


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
		badge.text = str(i + 1) if i < 9 else "•"
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
		name_label.add_theme_font_size_override("font_size", 17)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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


func _build_menu() -> void:
	var popup: PopupMenu = (%MenuButton as MenuButton).get_popup()
	popup.add_item("Speichern", MENU_SAVE)
	popup.add_item("Spielstand exportieren (Textcode)", MENU_EXPORT)
	popup.add_item("Spielstand importieren …", MENU_IMPORT)
	popup.add_separator()
	popup.add_item("Neu anfangen …", MENU_RESET)
	popup.id_pressed.connect(_on_menu)


func _connect_ui() -> void:
	%ImportButton.pressed.connect(func() -> void: _file_dialog.popup_centered_ratio(0.7))
	%DefaultButton.pressed.connect(GameState.use_default_target)
	%ShowerButton.pressed.connect(func() -> void:
		target_area.effects.clear()
		GameState.add_stat("showers")
		show_toast("Frisch geduscht!"))
	%AchievementsButton.pressed.connect(_show_achievements)
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
	marken_label.visible = GameState.beulen_marken > 0
	marken_label.text = "Beulen-Marken: %d" % GameState.beulen_marken
	target_label.text = "Opfer: %s" % GameState.target_name()
	target_hits_label.text = "Insgesamt verhauen: %s" % Num.whole(GameState.current_target_hits())
	total_label.text = "Insgesamt erzeugt: %s Wumms" % Num.whole(GameState.total_wumms)
	hits_label.text = "Treffer gesamt: %s" % Num.whole(GameState.total_hits)
	%AchievementsButton.text = "Erfolge %d/%d" % [GameState.achievement_count(), GameState.achievement_defs.size()]
	_refresh_buffs()
	_refresh_devices()
	_refresh_upgrades()


func _refresh_buffs() -> void:
	var buffs: Array = GameState.buffs
	while buff_box.get_child_count() < buffs.size():
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_stylebox_override("normal", _box(Color("fff3bf"), 8, 2, 4))
		l.add_theme_font_size_override("font_size", 15)
		buff_box.add_child(l)
	while buff_box.get_child_count() > buffs.size():
		var last := buff_box.get_child(buff_box.get_child_count() - 1)
		buff_box.remove_child(last)
		last.queue_free()
	for i in buffs.size():
		var b: Dictionary = buffs[i]
		var effect := ""
		if not is_equal_approx(float(b.wps_mult), 1.0):
			effect = "WPS ×%s" % Num.fmt(float(b.wps_mult))
		if not is_equal_approx(float(b.click_mult), 1.0):
			effect = "Klick ×%s" % Num.fmt(float(b.click_mult))
		var label: Label = buff_box.get_child(i)
		label.text = "%s · %s · %d s" % [b.name, effect, ceili(float(b.remaining))]
		var bad := float(b.wps_mult) < 1.0
		label.add_theme_color_override("font_color", Color("c92a2a") if bad else INK)


func _refresh_devices() -> void:
	var total_wps := GameState.base_wps()
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
		row.panel.tooltip_text = "%s\n\n%s\nJedes Gerät: %s WPS (×%s durch Upgrades)\nAlle zusammen: %s WPS (%s %% deiner Produktion)\nAmortisation: %s" % [
			d.name, d.description, Num.fmt(unit_wps), Num.fmt(GameState.device_multiplier(id)),
			Num.fmt(GameState.device_total_wps(id)), Num.fmt(share), Num.duration(payback)]


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
		b.custom_minimum_size = Vector2(205, 0)
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 13)
		var color := _upgrade_color(u)
		b.add_theme_stylebox_override("normal", _box(color, 10, 3, 5))
		b.add_theme_stylebox_override("hover", _box(color.lightened(0.3), 10, 3, 5))
		b.tooltip_text = "%s\n\n%s\n\nWirkung: %s\nPreis: %s Wumms" % [
			u.name, u.description, GameState.upgrade_effect_text(u), Num.whole(float(u.cost))]
		var id: String = u.id
		b.pressed.connect(func() -> void:
			if GameState.buy_upgrade(id):
				show_toast("Upgrade gekauft: %s" % u.name))
		upgrade_flow.add_child(b)
		_upgrade_buttons[id] = b


## Farbe nach Upgrade-Art: Gerät = Gerätefarbe, Klick = Türkis, Global = Gold.
func _upgrade_color(u: Dictionary) -> Color:
	var e: Dictionary = u.effect
	match e.type:
		"device_mult":
			return Color(GameState.device_def(e.device).get("color", "#a5f3fc")).lightened(0.35)
		"synergy":
			return Color(GameState.device_def(e.target).get("color", "#a5f3fc")).lightened(0.15)
		"click_mult", "click_wps", "crit", "autofire":
			return Color("a5f3fc")
	return Color("ffe8a3")


func _show_ticker() -> void:
	ticker_label.text = "+++ %s +++" % TICKER_LINES[_ticker_index % TICKER_LINES.size()]


func show_toast(text: String) -> void:
	toast.text = text
	toast.visible = true
	toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.6)
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


# =====================================================================
# Goldener Schuh / Silberner Pantoffel
# =====================================================================

func _spawn_shoe(kind: String) -> void:
	var shoe := Shoe.new()
	var area := shoe_layer.size
	var at := Vector2(randf_range(110.0, area.x - 110.0), randf_range(150.0, area.y - 120.0))
	shoe_layer.add_child(shoe)
	shoe.setup(kind, GameState.shoe_lifetime(kind), at)
	shoe.claimed.connect(_on_shoe_claimed.bind(shoe))
	shoe.expired.connect(GameState.shoe_expired)
	Sfx.play("shoe_appear", 0.05, -8.0)


func _on_shoe_claimed(kind: String, shoe: Shoe) -> void:
	var result := GameState.claim_shoe(kind)
	show_toast("%s %s" % [result.title, result.text])
	var center := shoe.position + shoe.size * 0.5
	if result.good:
		Sfx.play("golden", 0.03, -2.0)
		if not GameState.reduced_effects:
			Confetti.burst(self, center, 50 if kind == GameState.SHOE_GOLDEN else 25)
	else:
		Sfx.play("bad", 0.0, -2.0)


# =====================================================================
# Erfolge
# =====================================================================

func _on_achievement_unlocked(id: String) -> void:
	var a := GameState.achievement_def(id)
	Sfx.play("achievement", 0.0, -4.0)
	while achievement_toasts.get_child_count() >= MAX_ACHIEVEMENT_TOASTS:
		var oldest := achievement_toasts.get_child(0)
		achievement_toasts.remove_child(oldest)
		oldest.queue_free()
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _box(Color("fff3bf"), 12, 3, 10))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var head := Label.new()
	head.text = "Erfolg freigeschaltet!"
	head.add_theme_font_size_override("font_size", 13)
	head.add_theme_color_override("font_color", Color(INK, 0.65))
	var title := Label.new()
	title.text = a.get("name", id)
	_comic(title, 22, Color("ffd43b"))
	var desc := Label.new()
	desc.text = a.get("description", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 14)
	box.add_child(head)
	box.add_child(title)
	box.add_child(desc)
	achievement_toasts.add_child(panel)
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_interval(4.5)
	tw.tween_property(panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(panel.queue_free)
	if not GameState.reduced_effects:
		Confetti.burst(self, Vector2(size.x - 200.0, 110.0), 40)


func _show_achievements() -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	var summary := Label.new()
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.text = "%d von %d freigeschaltet" % [GameState.achievement_count(), GameState.achievement_defs.size()]
	if GameState.has_upgrade("milchtuete_der_wut"):
		summary.text += " · Wutmilch: +%s %% WPS" % Num.fmt(GameState.achievement_count() * 0.5)
	content.add_child(summary)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(820, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	for a in GameState.achievement_defs:
		var unlocked := GameState.achievements.has(a.id)
		var hidden := bool(a.get("hidden", false)) and not unlocked
		var tile := PanelContainer.new()
		tile.custom_minimum_size = Vector2(262, 96)
		tile.add_theme_stylebox_override("panel", _box(Color("fff3bf") if unlocked else Color("f1e9dc"), 10, 2, 8,
			INK if unlocked else Color(INK, 0.35)))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		tile.add_child(box)
		var name_label := Label.new()
		name_label.text = "???" if hidden else String(a.name)
		name_label.add_theme_font_size_override("font_size", 16)
		if not unlocked:
			name_label.add_theme_color_override("font_color", Color(INK, 0.55))
		var desc := Label.new()
		desc.text = "Versteckter Erfolg" if hidden else String(a.description)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(236, 0)
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(INK, 0.75 if unlocked else 0.5))
		box.add_child(name_label)
		box.add_child(desc)
		if not unlocked and not hidden and a.condition.type not in ["night", "idle"]:
			var p := GameState.condition_progress(a.condition)
			var bar := ProgressBar.new()
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(0, 10)
			bar.max_value = 1.0
			bar.value = clampf(p.x / maxf(p.y, 0.0001), 0.0, 1.0)
			bar.tooltip_text = "%s / %s" % [Num.whole(p.x), Num.whole(p.y)]
			box.add_child(bar)
		grid.add_child(tile)
	Modal.open(self, "Erfolge", content, ["Schließen"], 860.0)


# =====================================================================
# Menü, Willkommen zurück
# =====================================================================

func _on_menu(id: int) -> void:
	match id:
		MENU_SAVE:
			if GameState.save_game():
				show_toast("Gespeichert.")
		MENU_EXPORT:
			var code := GameState.export_save_code()
			DisplayServer.clipboard_set(code)
			var field := LineEdit.new()
			field.text = code
			field.editable = false
			field.select_all_on_focus = true
			Modal.open(self, "Spielstand exportieren",
				_column(["Der Textcode ist in deiner Zwischenablage. Heb ihn gut auf!"], field), ["OK"])
		MENU_IMPORT:
			var field := LineEdit.new()
			field.placeholder_text = "Textcode hier einfügen"
			if DisplayServer.clipboard_has():
				field.text = DisplayServer.clipboard_get().strip_edges()
			var m := Modal.open(self, "Spielstand importieren",
				_column(["Achtung: Dein aktueller Spielstand wird ersetzt."], field), ["Laden", "Abbrechen"])
			m.closed.connect(func(index: int) -> void:
				if index == 0:
					if GameState.import_save_code(field.text):
						show_toast("Spielstand geladen!")
					else:
						show_toast("Dieser Code funktioniert leider nicht."))
		MENU_RESET:
			var m := Modal.open(self, "Neu anfangen?",
				"Alle Wumms, Geräte, Upgrades und Erfolge werden gelöscht. Deine Bilder bleiben erhalten.",
				["Ja, alles löschen", "Abbrechen"])
			m.closed.connect(func(index: int) -> void:
				if index == 0:
					GameState.reset_progress()
					target_area.effects.clear()
					for shoe in shoe_layer.get_children():
						shoe.queue_free()
					show_toast("Alles auf Anfang. Bombastus atmet auf."))


func _column(texts: Array, extra: Control = null) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	for t in texts:
		var l := Label.new()
		l.text = t
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(460, 0)
		box.add_child(l)
	if extra:
		box.add_child(extra)
	return box


func _show_welcome_back(info: Dictionary) -> void:
	var seconds := float(info.seconds)
	var capped := seconds > GameState.OFFLINE_CAP
	var text := "Du warst %s weg.\nIn der Zeit haben deine Geräte\n%s Wumms\nerwirtschaftet." % [
		Num.duration(seconds), Num.whole(float(info.gain))]
	if capped:
		text += "\n\n(Ohne Aufsicht arbeiten sie höchstens 8 Stunden – und nur halb so fleißig.)"
	Modal.open(self, "Willkommen zurück!", text, ["Weiter hauen!"])
