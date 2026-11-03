extends Control
## Hauptbildschirm: verbindet Zielbild, Statistik, Shop, Ticker, Ereignisse, Erfolge und Bild-Import.

const INK := Color("2b2118")
const PAPER := Color("fff8ec")
# Farbsystem „Comic-Arena bei Nacht“ – gilt für Hauptbildschirm und Dialoge (dialog_theme()).
const NIGHT := Color("120d2b")
const PANEL := Color("1b1540")
const CARD := Color("2a2156")
const ROW := Color("231a4a")
const ROW_HOVER := Color("342a68")
const LINE := Color("0f0b24")
const TEXT := Color("f4f1ff")
const MUTED := Color("a99fdc")
const GOLD := Color("ffc929")
const GOLD_HOVER := Color("ffd95e")
const RAGE := Color("ff4d6d")
const AMOUNT_MODES: Array[int] = [1, 10, 100, -1]
const TICKER_INTERVAL := 9.0
const MAX_ACHIEVEMENT_TOASTS := 3
# i18n: Texte werden bei der Anzeige mit tr() übersetzt
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
const MENU_PHOTO := 4
const MENU_LANGUAGE := 5
const MENU_VOLUME := 6
const MENU_SOUND := 10
const MENU_EFFECTS := 11
const MENU_TIME_WARP := 12
const MENU_AUTOBUY := 13
const MENU_AUTO_RAGE := 14
# i18n
const SHOP_SLOTS := [["fist", "Fäuste"], ["background", "Hintergründe"], ["sound", "Sounds"]]
# i18n
const BRANCHES := [["handwerk", "Handwerk"], ["glueck", "Glück"], ["komfort", "Komfort"], ["show", "Show"]]

@onready var target_area: TargetArea = %TargetArea
@onready var wumms_label: Label = %WummsLabel
@onready var wps_label: Label = %WpsLabel
@onready var click_label: Label = %ClickLabel
@onready var marken_label: Label = %MarkenLabel
@onready var buff_box: VBoxContainer = %BuffBox
@onready var target_label: Label = %TargetLabel
@onready var target_hits_label: Label = %TargetHitsLabel
@onready var upgrade_list: VBoxContainer = %UpgradeList
@onready var no_upgrades_label: Label = %NoUpgradesLabel
@onready var amount_row: HBoxContainer = %AmountRow
@onready var device_list: VBoxContainer = %DeviceList
@onready var ticker_label: Label = %TickerLabel
@onready var toast: Label = %Toast
@onready var shoe_layer: Control = %ShoeLayer
@onready var achievement_toasts: VBoxContainer = %AchievementToasts
@onready var boss: BossFight = %BossFight

var _buy_mode := 1
var _device_rows: Dictionary = {}       # id -> {panel, info, buy, sell, index}
var _upgrade_buttons: Dictionary = {}   # id -> Button
var _shown_upgrade_ids: Array[String] = []
var _refresh_timer := 0.0
var _ticker_timer := 0.0
var _ticker_index := 0
var _toast_tween: Tween
var _file_dialog: FileDialog
var _combo_bar: ProgressBar
var _combo_label: Label
var _combo_mult_label: Label
var _rage_bar: ProgressBar
var _rage_label: Label
var _rage_button: Button
var _prestige_button: Button
var _laurel_label: Label
var _rage_tint: ColorRect
var _rage_tween: Tween
var _ticker_override := ""
var _challenge_label: Label
var _challenge_abort: Button


func _ready() -> void:
	theme = _build_theme()
	_style_panels()
	_style_labels()
	_build_amount_buttons()
	_build_device_rows()
	_build_file_dialog()
	_build_menu()
	_build_stats_extras()
	_build_rage_tint()
	_connect_ui()

	target_area.hit.connect(_on_target_hit)
	GameState.target_changed.connect(_on_target_changed)
	GameState.device_bought.connect(_on_device_bought)
	GameState.upgrade_bought.connect(func(_id: String) -> void: Sfx.play("buy", 0.0, -4.0))
	GameState.achievement_unlocked.connect(_on_achievement_unlocked)
	GameState.shoe_spawned.connect(_spawn_shoe)
	GameState.prestiged.connect(_on_prestiged)
	GameState.rage_changed.connect(_on_rage_changed)
	GameState.bump_level_up.connect(_on_bump_level_up)
	GameState.laurel_node_bought.connect(func(_id: String) -> void: _apply_cosmetics())
	GameState.boss_started.connect(_on_boss_started)
	GameState.boss_finished.connect(_on_boss_finished)
	GameState.event_completed.connect(_on_event_completed)
	%QuestsButton.pressed.connect(_show_quests)
	%GamesButton.pressed.connect(_show_games)
	%ShopButton.pressed.connect(_show_shop)
	GameState.cosmetics_changed.connect(_apply_cosmetics)
	GameState.challenge_changed.connect(_on_challenge_changed)
	GameState.buffs_changed.connect(_update_slow_motion)
	get_window().files_dropped.connect(_on_files_dropped)

	_apply_cosmetics()
	for id in GameState.challenges_done:
		_celebrated_challenges[id] = true
	_on_target_changed()
	_refresh()
	_ticker_index = randi() % TICKER_LINES.size()
	_show_ticker()
	if not GameState.pending_offline.is_empty() or (not GameState.pending_login.is_empty() and GameState.total_hits > 0):
		_show_welcome_back.call_deferred(GameState.pending_offline, GameState.pending_login)
	elif GameState.total_hits == 0:
		show_toast(tr("Hau drauf! Klicken oder Leertaste."))
	GameState.pending_offline = {}
	GameState.pending_login = {}
	var event := GameState.active_event()
	if not event.is_empty() and not GameState.events_done.has(GameState.event_key(event)):
		_ticker_override = tr("Saison-Event: %s – zu finden in der Galerie!") % event.name
	if OS.has_feature("editor"):
		_dev_preview.call_deferred()


## Nur im Editor: Vorschau-Schalter für Screenshots und schnelle Tests, z. B.
## godot --path . -- --lang=de --rich --open=achievements --hits=200
## Mit Vorschau-Schaltern wird nie gespeichert.
func _dev_preview() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		return
	GameState.persist = false
	for arg in args:
		if arg.begins_with("--lang=") and not TranslationServer.get_locale().begins_with(arg.get_slice("=", 1)):
			GameState.set_language(arg.get_slice("=", 1))
			get_tree().reload_current_scene.call_deferred()
			return
	for arg in args:
		var key := arg.get_slice("=", 0)
		var value := arg.get_slice("=", 1)
		match key:
			"--rich":
				GameState.lifetime_wumms = 5e12
				GameState.total_wumms = 5e12
				GameState.wumms = 5e12
				GameState.total_hits = 20000
				GameState.laurels_total = 40
				GameState.beulen_marken = 25
				GameState.add_stat("prestiges")
				for d in GameState.device_defs.slice(0, 8):
					GameState.buy_device(d.id, 30)
				GameState.check_achievements()
				_on_target_changed()
			"--hits":
				for i in int(value):
					target_area.hit_somewhere()
					await get_tree().process_frame
			"--bench":
				# Treffer im Dauerfeuer-Tempo (20/s), danach Bildrate ausgeben
				var frames := 0
				var proc := 0.0
				var draws := 0.0
				var start := Time.get_ticks_msec()
				var next_hit := 0.0
				var rate := 20.0
				for a in args:
					if a.begins_with("--benchrate="):
						rate = float(a.get_slice("=", 1))
				while Time.get_ticks_msec() - start < int(value) * 1000:
					var t := (Time.get_ticks_msec() - start) / 1000.0
					while rate > 0.0 and next_hit <= t:
						target_area.try_hit(target_area.uv_to_local(Vector2(randf_range(0.35, 0.65), randf_range(0.35, 0.6))))
						next_hit += 1.0 / rate
					await get_tree().process_frame
					frames += 1
					proc += Performance.get_monitor(Performance.TIME_PROCESS)
					draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
				print("BENCH fps=%.1f process=%.1fms draws=%.0f nodes=%d" % [frames / float(value), proc / frames * 1000.0,
					draws / frames, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
				get_tree().quit()
			"--import":
				GameState.import_image_file(value)
			"--eyes":
				var e := value.split_floats(",")
				GameState.set_face(GameState.target_id, Vector2(e[0], e[1]), Vector2(e[2], e[3]))
			"--level":
				GameState.target_hits[GameState.target_id] = int(value) * 1000
				_on_target_changed()
			"--prof":
				for label in ["tick", "refresh", "achievements", "wps", "upgrades"]:
					var t0 := Time.get_ticks_usec()
					for i in 50:
						match label:
							"tick": GameState.tick(0.016)
							"refresh": _refresh()
							"achievements": GameState.check_achievements()
							"wps": GameState.wps()
							"upgrades": _refresh_upgrades()
					print("PROF %s %.2f ms" % [label, (Time.get_ticks_usec() - t0) / 50000.0])
			"--rage":
				GameState.rage_meter = GameState.RAGE_MAX
				GameState.start_rage()
	for arg in args:
		if arg.begins_with("--open="):
			match arg.get_slice("=", 1):
				"achievements": _show_achievements()
				"quests": _show_quests()
				"games": _show_games()
				"shop": _show_shop()
				"laurels": _show_laurel_tree()
				"gallery": _show_gallery()
				"volume": _show_volume()
				"prestige": _show_prestige()
				"menu": (%MenuButton as MenuButton).show_popup()
				"face": _open_face(GameState.target_id)
				"market": Modal.open(self, tr("Börse für Beulen"), MarketPanel.new(), [tr("Schließen")], 900.0)
				"dojo": MiniGame.open(self, "dojo")
				"pie": MiniGame.open(self, "pie")


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
	elif key.keycode == KEY_R:
		_try_rage()
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

## Dunkles Theme für den Hauptbildschirm: Bühne, Leisten und Shop.
func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 17
	t.default_font = load("res://assets/fonts/Poppins-Medium.ttf")

	for type in ["Label", "Button", "CheckButton", "MenuButton", "TooltipLabel", "PopupMenu", "LineEdit"]:
		t.set_color("font_color", type, TEXT)
	for type in ["Button", "CheckButton", "MenuButton"]:
		t.set_color("font_hover_color", type, TEXT)
		t.set_color("font_focus_color", type, TEXT)
		t.set_color("font_pressed_color", type, LINE)
		t.set_color("font_hover_pressed_color", type, LINE)
		t.set_color("font_disabled_color", type, Color(MUTED, 0.55))
	t.set_color("font_hover_color", "PopupMenu", LINE)
	t.set_color("font_separator_color", "PopupMenu", MUTED)

	t.set_stylebox("panel", "PanelContainer", _box(PANEL, 0, 0, 12))
	t.set_stylebox("panel", "TooltipPanel", _box(CARD, 10, 2, 10, LINE))
	t.set_stylebox("panel", "PopupMenu", _box(CARD, 10, 2, 8, LINE))
	t.set_stylebox("hover", "PopupMenu", _box(GOLD, 6, 0, 4))
	var popup_sep := StyleBoxLine.new()
	popup_sep.color = Color(MUTED, 0.3)
	popup_sep.thickness = 1
	t.set_stylebox("separator", "PopupMenu", popup_sep)
	for type in ["Button", "MenuButton"]:
		t.set_stylebox("normal", type, _box(CARD, 10, 2, 8, LINE))
		t.set_stylebox("hover", type, _box(ROW_HOVER, 10, 2, 8, LINE))
		t.set_stylebox("pressed", type, _box(GOLD, 10, 2, 8, LINE))
		t.set_stylebox("hover_pressed", type, _box(GOLD_HOVER, 10, 2, 8, LINE))
		t.set_stylebox("disabled", type, _box(ROW, 10, 2, 8, LINE))
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("normal", "LineEdit", _box(ROW, 8, 2, 8, LINE))
	t.set_stylebox("focus", "LineEdit", _box(ROW, 8, 2, 8, GOLD))
	t.set_stylebox("background", "ProgressBar", _box(LINE, 7, 0, 0))
	t.set_stylebox("fill", "ProgressBar", _box(GOLD, 7, 0, 0))
	t.set_color("font_color", "ProgressBar", TEXT)
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, _box(Color(LINE, 0.6), 6, 0, 3))
		t.set_stylebox("grabber", bar, _box(Color("4d4196"), 6, 0, 3))
		t.set_stylebox("grabber_highlight", bar, _box(Color("5f52b0"), 6, 0, 3))
		t.set_stylebox("grabber_pressed", bar, _box(GOLD, 6, 0, 3))
	var sep := StyleBoxLine.new()
	sep.color = Color(MUTED, 0.25)
	sep.thickness = 2
	t.set_stylebox("separator", "HSeparator", sep)
	return t


static var _dialog: Theme


## Theme für Dialoge (Modal) und Mini-Spiele: dieselbe „Comic-Arena bei Nacht“ wie der Hauptbildschirm –
## dunkle Karten, helle Schrift, Gold nur für die wichtigste Aktion bzw. „leistbar“.
static func dialog_theme() -> Theme:
	if _dialog != null:
		return _dialog
	var t := Theme.new()
	t.default_font_size = 16
	t.default_font = load("res://assets/fonts/Poppins-Medium.ttf")

	for type in ["Label", "Button", "CheckButton", "CheckBox", "MenuButton", "TooltipLabel", "PopupMenu", "LineEdit"]:
		t.set_color("font_color", type, TEXT)
	for type in ["Button", "CheckButton", "CheckBox", "MenuButton"]:
		t.set_color("font_hover_color", type, TEXT)
		t.set_color("font_focus_color", type, TEXT)
		t.set_color("font_pressed_color", type, LINE)
		t.set_color("font_hover_pressed_color", type, LINE)
		t.set_color("font_disabled_color", type, Color(MUTED, 0.6))
	t.set_color("font_hover_color", "PopupMenu", LINE)
	t.set_color("font_placeholder_color", "LineEdit", Color(MUTED, 0.7))

	var panel := _box(PANEL, 18, 3, 18, LINE)
	panel.shadow_color = Color(0, 0, 0, 0.45)
	panel.shadow_size = 18
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "TooltipPanel", _box(CARD, 10, 2, 10, LINE))
	t.set_stylebox("panel", "PopupMenu", _box(CARD, 10, 2, 8, LINE))
	t.set_stylebox("hover", "PopupMenu", _box(GOLD, 6, 0, 4))
	for type in ["Button", "MenuButton"]:
		t.set_stylebox("normal", type, _box(CARD, 10, 2, 8, LINE))
		t.set_stylebox("hover", type, _box(ROW_HOVER, 10, 2, 8, Color(GOLD, 0.6)))
		t.set_stylebox("pressed", type, _box(GOLD, 10, 2, 8, LINE))
		t.set_stylebox("hover_pressed", type, _box(GOLD_HOVER, 10, 2, 8, LINE))
		t.set_stylebox("disabled", type, _box(ROW, 10, 0, 8, LINE))
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("normal", "LineEdit", _box(ROW, 8, 2, 8, LINE))
	t.set_stylebox("read_only", "LineEdit", _box(ROW, 8, 2, 8, LINE))
	t.set_stylebox("focus", "LineEdit", _box(ROW, 8, 2, 8, GOLD))
	t.set_stylebox("background", "ProgressBar", _box(LINE, 6, 0, 0))
	t.set_stylebox("fill", "ProgressBar", _box(GOLD, 6, 0, 0))
	t.set_color("font_color", "ProgressBar", TEXT)
	t.set_stylebox("slider", "HSlider", _box(LINE, 6, 0, 3))
	t.set_stylebox("grabber_area", "HSlider", _box(GOLD, 6, 0, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(GOLD_HOVER, 6, 0, 3))
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, _box(Color(LINE, 0.6), 6, 0, 3))
		t.set_stylebox("grabber", bar, _box(Color("4d4196"), 6, 0, 3))
		t.set_stylebox("grabber_highlight", bar, _box(Color("5f52b0"), 6, 0, 3))
		t.set_stylebox("grabber_pressed", bar, _box(GOLD, 6, 0, 3))
	var sep := StyleBoxLine.new()
	sep.color = Color(MUTED, 0.25)
	sep.thickness = 2
	t.set_stylebox("separator", "HSeparator", sep)
	_dialog = t
	return t


## Wichtigste Aktion in Dialogen: goldener Knopf wie „Kaufen“ im Shop.
static func style_primary(b: Button) -> void:
	var normal := _box(GOLD, 10, 2, 8, LINE)
	normal.border_width_bottom = 4
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = GOLD_HOVER
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", _box(Color("f0b400"), 10, 2, 8, LINE))
	b.add_theme_stylebox_override("disabled", _box(ROW, 10, 0, 8, LINE))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, LINE)
	b.add_theme_font_override("font", heading_font())


## Kachel in Dialogen: normal dunkel, hervorgehoben (aktiv/erreicht) mit goldenem Rand, gesperrt blasser.
static func tile_box(state: String = "normal", margin: int = 8) -> StyleBoxFlat:
	match state:
		"active":
			return _box(ROW_HOVER, 12, 2, margin, GOLD)
		"locked":
			return _box(Color(ROW, 0.7), 12, 2, margin, Color(LINE, 0.6))
		"good":
			return _box(Color("1f3d3a"), 12, 2, margin, Color("63e6be"))
	return _box(CARD, 12, 2, margin, LINE)


static func _box(bg: Color, radius: int, border: int, margin: int, border_color: Color = INK) -> StyleBoxFlat:
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


func _style_panels() -> void:
	var top := _box(PANEL, 0, 0, 10)
	top.border_width_bottom = 3
	top.border_color = LINE
	top.content_margin_left = 20
	top.content_margin_right = 14
	%TopBar.add_theme_stylebox_override("panel", top)
	var shop := _box(PANEL, 0, 0, 14)
	shop.border_width_left = 3
	shop.border_color = LINE
	%ShopPanel.add_theme_stylebox_override("panel", shop)
	var page := _box(CARD, 0, 0, 12)
	page.corner_radius_bottom_left = 14
	page.corner_radius_bottom_right = 14
	%ShopPage.add_theme_stylebox_override("panel", page)
	%TickerBar.add_theme_stylebox_override("panel", _box(LINE, 0, 0, 8))
	%NamePlate.add_theme_stylebox_override("panel", _box(LINE, 12, 0, 8))
	var chip := _box(CARD, 20, 2, 5, LINE)
	chip.content_margin_left = 14
	chip.content_margin_right = 14
	%MarkenChip.add_theme_stylebox_override("panel", chip)

	# Kopfleiste: jeder Knopf als eigene Plakette mit Luft dazwischen, damit nichts aneinanderklebt.
	(%TopBar.get_node("TopRow") as HBoxContainer).add_theme_constant_override("separation", 8)
	for b in [%ImportButton, %GalleryButton, %ShowerButton, %AchievementsButton, %QuestsButton, %ShopButton,
			%GamesButton, %LaurelButton, %MenuButton]:
		var chip_normal := _box(CARD, 10, 2, 5, LINE)
		chip_normal.content_margin_left = 12
		chip_normal.content_margin_right = 12
		var chip_hover := chip_normal.duplicate() as StyleBoxFlat
		chip_hover.bg_color = ROW_HOVER
		chip_hover.border_color = Color(GOLD, 0.6)
		b.add_theme_stylebox_override("normal", chip_normal)
		b.add_theme_stylebox_override("hover", chip_hover)
		b.add_theme_stylebox_override("pressed", chip_hover)
		b.add_theme_color_override("font_pressed_color", TEXT)
		b.add_theme_font_size_override("font_size", 14)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var menu_normal := (%MenuButton.get_theme_stylebox("normal") as StyleBoxFlat).duplicate() as StyleBoxFlat
	menu_normal.border_color = Color(GOLD, 0.8)
	%MenuButton.add_theme_stylebox_override("normal", menu_normal)

	# Shop-Reiter: aktiver Reiter verschmilzt mit der Seite darunter.
	var tab_group := ButtonGroup.new()
	for b in [%DevicesTab, %UpgradesTab]:
		b.button_group = tab_group
		var active := _box(CARD, 12, 0, 8)
		active.corner_radius_bottom_left = 0
		active.corner_radius_bottom_right = 0
		b.add_theme_stylebox_override("pressed", active)
		b.add_theme_stylebox_override("hover_pressed", active)
		b.add_theme_stylebox_override("normal", _box(Color(CARD, 0.0), 12, 0, 8))
		b.add_theme_stylebox_override("hover", _box(Color(CARD, 0.5), 12, 0, 8))
		b.add_theme_font_override("font", heading_font())
		b.add_theme_font_size_override("font_size", 21)
		b.add_theme_color_override("font_color", MUTED)
		b.add_theme_color_override("font_hover_color", TEXT)
		b.add_theme_color_override("font_pressed_color", GOLD)
		b.add_theme_color_override("font_hover_pressed_color", GOLD)


func _style_labels() -> void:
	_comic(%Title, 27, RAGE)
	_comic(wumms_label, 72, GOLD)
	_comic(toast, 26, Color.WHITE)
	for l in [%UpgradesTitle, %DevicesTitle]:
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", MUTED)
	wps_label.add_theme_font_size_override("font_size", 16)
	click_label.add_theme_font_size_override("font_size", 16)
	click_label.add_theme_color_override("font_color", MUTED)
	marken_label.add_theme_font_size_override("font_size", 14)
	target_label.add_theme_font_override("font", heading_font())
	target_label.add_theme_font_size_override("font_size", 16)
	target_hits_label.add_theme_font_size_override("font_size", 13)
	target_hits_label.add_theme_color_override("font_color", MUTED)
	target_hits_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	no_upgrades_label.add_theme_color_override("font_color", MUTED)
	ticker_label.add_theme_font_size_override("font_size", 14)
	ticker_label.add_theme_color_override("font_color", Color("d6cff7"))
	%HelpLabel.add_theme_font_size_override("font_size", 13)
	%HelpLabel.add_theme_color_override("font_color", MUTED)
	%HelpLabel.text = tr("Klick oder Leertaste: hauen\nR: Wutmodus entfesseln\n1–9: Gerät kaufen\nStrg+V: Bild einfügen\nBild ins Fenster ziehen: neues Opfer\nGoldene Schuhe anklicken!")


## Überschriften-Schrift: assets/fonts/heading.ttf/.otf, falls vorhanden (z. B. eine Comic-Schrift), sonst Poppins Bold.
static func heading_font() -> Font:
	for path in ["res://assets/fonts/heading.ttf", "res://assets/fonts/heading.otf"]:
		if ResourceLoader.exists(path):
			return load(path)
	return load("res://assets/fonts/Poppins-Bold.ttf")


func _comic(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_font_override("font", heading_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", maxi(6, font_size / 4))


func _build_amount_buttons() -> void:
	var group := ButtonGroup.new()
	for mode in AMOUNT_MODES:
		var b := Button.new()
		b.text = tr("Max") if mode < 0 else "×%d" % mode
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
		panel.add_theme_stylebox_override("panel", _box(ROW, 12, 0, 8))
		panel.mouse_entered.connect(func() -> void: panel.add_theme_stylebox_override("panel", _box(ROW_HOVER, 12, 0, 8)))
		panel.mouse_exited.connect(func() -> void: panel.add_theme_stylebox_override("panel", _box(ROW, 12, 0, 8)))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		panel.add_child(row)

		# Symbol-Kachel in Gerätefarbe, Stückzahl als Plakette unten rechts
		var tile := PanelContainer.new()
		tile.custom_minimum_size = Vector2(52, 52)
		tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_theme_stylebox_override("panel", _box(Color(d.get("color", "#ffd43b")), 12, 2, 4, LINE))
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(38, 38)
		if ResourceLoader.exists(String(d.get("icon", ""))):
			icon.texture = load(d.icon)
		tile.add_child(icon)
		var count_label := Label.new()
		count_label.add_theme_font_size_override("font_size", 11)
		count_label.add_theme_stylebox_override("normal", _box(LINE, 9, 0, 1))
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.size_flags_horizontal = Control.SIZE_SHRINK_END
		count_label.size_flags_vertical = Control.SIZE_SHRINK_END
		tile.add_child(count_label)
		row.add_child(tile)

		var info_box := VBoxContainer.new()
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info_box.add_theme_constant_override("separation", 0)
		var name_label := Label.new()
		name_label.text = d.name
		name_label.add_theme_font_override("font", heading_font())
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var info_label := Label.new()
		info_label.add_theme_font_size_override("font_size", 12)
		info_label.add_theme_color_override("font_color", MUTED)
		info_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		info_box.add_child(name_label)
		info_box.add_child(info_label)
		row.add_child(info_box)

		var sell := Button.new()
		sell.text = "−"
		sell.tooltip_text = tr("Eins verkaufen (25 % zurück)")
		sell.focus_mode = Control.FOCUS_NONE
		sell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sell.custom_minimum_size = Vector2(30, 30)
		sell.add_theme_stylebox_override("normal", _box(Color(CARD, 0.0), 8, 0, 2))
		sell.add_theme_stylebox_override("hover", _box(CARD, 8, 0, 2))
		sell.add_theme_stylebox_override("disabled", _box(Color(CARD, 0.0), 8, 0, 2))
		sell.add_theme_color_override("font_color", MUTED)
		sell.pressed.connect(func() -> void: GameState.sell_device(d.id))
		row.add_child(sell)

		var buy := Button.new()
		buy.custom_minimum_size = Vector2(100, 46)
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy.focus_mode = Control.FOCUS_NONE
		_style_buy_button(buy, 14)
		buy.pressed.connect(func() -> void: _buy(d.id))
		row.add_child(buy)

		device_list.add_child(panel)
		_device_rows[d.id] = {"panel": panel, "info": info_label, "count": count_label, "buy": buy, "sell": sell, "index": i}


## Kaufen-Knopf: Gold heißt „leistbar“, alles andere tritt zurück.
func _style_buy_button(b: Button, font_size: int) -> void:
	var normal := _box(GOLD, 12, 2, 6, LINE)
	normal.border_width_bottom = 5
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = GOLD_HOVER
	var pressed := _box(Color("f0b400"), 12, 2, 6, LINE)
	var disabled := _box(Color("3a2f73"), 12, 0, 6)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", LINE)
	b.add_theme_color_override("font_hover_color", LINE)
	b.add_theme_color_override("font_pressed_color", LINE)
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.add_theme_font_override("font", heading_font())
	b.add_theme_font_size_override("font_size", font_size)


func _build_file_dialog() -> void:
	_file_dialog = FileDialog.new()
	_file_dialog.title = tr("Neues Opfer wählen – nimm Bilder, bei denen alle Beteiligten Spaß verstehen")
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray([tr("*.png, *.jpg, *.jpeg, *.webp ; Bilder")])
	_file_dialog.use_native_dialog = true
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)


func _build_menu() -> void:
	var popup: PopupMenu = (%MenuButton as MenuButton).get_popup()
	popup.hide_on_checkable_item_selection = false
	popup.about_to_popup.connect(_fill_menu)
	popup.id_pressed.connect(_on_menu)
	_fill_menu()


## Menü bei jedem Öffnen neu füllen, weil manche Einträge erst freigeschaltet werden.
func _fill_menu() -> void:
	var popup: PopupMenu = (%MenuButton as MenuButton).get_popup()
	popup.clear()
	popup.add_check_item(tr("Ton"), MENU_SOUND)
	popup.set_item_checked(popup.get_item_index(MENU_SOUND), GameState.sound_on)
	popup.add_item(tr("Lautstärke …"), MENU_VOLUME)
	popup.add_check_item(tr("Weniger Effekte"), MENU_EFFECTS)
	popup.set_item_checked(popup.get_item_index(MENU_EFFECTS), GameState.reduced_effects)
	if GameState.time_warp_unlocked():
		popup.add_check_item(tr("Zeitraffer (Geräte ×2 schneller)"), MENU_TIME_WARP)
		popup.set_item_checked(popup.get_item_index(MENU_TIME_WARP), GameState.time_warp)
	if GameState.has_autobuy():
		popup.add_check_item(tr("Upgrades automatisch kaufen"), MENU_AUTOBUY)
		popup.set_item_checked(popup.get_item_index(MENU_AUTOBUY), GameState.autobuy_enabled)
	if GameState.has_auto_rage():
		popup.add_check_item(tr("Wut automatisch entfesseln"), MENU_AUTO_RAGE)
		popup.set_item_checked(popup.get_item_index(MENU_AUTO_RAGE), GameState.auto_rage_enabled)
	popup.add_item("Sprache / Language: %s" % GameState.LANGUAGES[GameState.effective_language()], MENU_LANGUAGE)
	popup.add_separator()
	popup.add_item(tr("Foto speichern"), MENU_PHOTO)
	popup.add_item(tr("Speichern"), MENU_SAVE)
	popup.add_item(tr("Spielstand exportieren (Textcode)"), MENU_EXPORT)
	popup.add_item(tr("Spielstand importieren …"), MENU_IMPORT)
	popup.add_separator()
	popup.add_item(tr("Alles löschen und neu anfangen …"), MENU_RESET)


## Combo- und Wut-Leisten unter dem Opfer, Lorbeer-, Neuanfang- und Herausforderungs-Anzeigen oben links auf der Bühne.
func _build_stats_extras() -> void:
	var progress_row: HBoxContainer = %ProgressRow
	var combo_box := VBoxContainer.new()
	combo_box.custom_minimum_size = Vector2(250, 0)
	combo_box.add_theme_constant_override("separation", 4)
	progress_row.add_child(combo_box)
	var combo_head := HBoxContainer.new()
	combo_box.add_child(combo_head)
	_combo_label = Label.new()
	_combo_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_combo_label.add_theme_font_override("font", heading_font())
	_combo_label.add_theme_font_size_override("font_size", 13)
	combo_head.add_child(_combo_label)
	_combo_mult_label = Label.new()
	_combo_mult_label.add_theme_font_override("font", heading_font())
	_combo_mult_label.add_theme_font_size_override("font_size", 13)
	_combo_mult_label.add_theme_color_override("font_color", GOLD)
	combo_head.add_child(_combo_mult_label)
	_combo_bar = _bar(GOLD)
	_combo_bar.max_value = GameState.COMBO_MAX
	combo_box.add_child(_combo_bar)

	var rage_box := VBoxContainer.new()
	rage_box.custom_minimum_size = Vector2(250, 0)
	rage_box.add_theme_constant_override("separation", 4)
	progress_row.add_child(rage_box)
	var rage_head := HBoxContainer.new()
	rage_box.add_child(rage_head)
	var rage_title := Label.new()
	rage_title.text = tr("WUT")
	rage_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rage_title.add_theme_font_override("font", heading_font())
	rage_title.add_theme_font_size_override("font_size", 13)
	rage_head.add_child(rage_title)
	_rage_label = Label.new()
	_rage_label.add_theme_font_override("font", heading_font())
	_rage_label.add_theme_font_size_override("font_size", 13)
	_rage_label.add_theme_color_override("font_color", Color("ff8fa3"))
	rage_head.add_child(_rage_label)
	_rage_bar = _bar(RAGE)
	_rage_bar.max_value = GameState.RAGE_MAX
	_rage_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	_rage_bar.tooltip_text = tr("Wut-Leiste: füllt sich mit jedem Treffer.\nVoll? Mit R oder dem Knopf 10 s Wutmodus entfesseln:\nalles ×3, aber keine Goldenen Schuhe.")
	rage_box.add_child(_rage_bar)

	_rage_button = Button.new()
	_rage_button.text = tr("WUT!")
	_rage_button.focus_mode = Control.FOCUS_NONE
	_rage_button.custom_minimum_size = Vector2(104, 46)
	_rage_button.size_flags_vertical = Control.SIZE_SHRINK_END
	_rage_button.add_theme_font_override("font", heading_font())
	_rage_button.add_theme_font_size_override("font_size", 20)
	var rage_normal := _box(RAGE, 12, 2, 6, LINE)
	rage_normal.border_width_bottom = 5
	var rage_hover := rage_normal.duplicate() as StyleBoxFlat
	rage_hover.bg_color = Color("ff6b85")
	_rage_button.add_theme_stylebox_override("normal", rage_normal)
	_rage_button.add_theme_stylebox_override("hover", rage_hover)
	_rage_button.add_theme_stylebox_override("pressed", rage_normal)
	_rage_button.add_theme_stylebox_override("disabled", _box(Color("3a2f73"), 12, 0, 6))
	_rage_button.add_theme_color_override("font_color", Color.WHITE)
	_rage_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_rage_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	_rage_button.add_theme_color_override("font_disabled_color", MUTED)
	_rage_button.pressed.connect(_try_rage)
	progress_row.add_child(_rage_button)

	var stage_info: VBoxContainer = buff_box.get_parent()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_info.add_child(box)
	stage_info.move_child(box, buff_box.get_index() + 1)

	_laurel_label = Label.new()
	_laurel_label.add_theme_color_override("font_color", Color("63e6be"))
	_laurel_label.add_theme_font_size_override("font_size", 14)
	box.add_child(_laurel_label)

	_prestige_button = Button.new()
	_prestige_button.focus_mode = Control.FOCUS_NONE
	_prestige_button.add_theme_stylebox_override("normal", _box(Color("63e6be"), 10, 2, 6, LINE))
	_prestige_button.add_theme_stylebox_override("hover", _box(Color("96f2d7"), 10, 2, 6, LINE))
	_prestige_button.add_theme_color_override("font_color", LINE)
	_prestige_button.add_theme_color_override("font_hover_color", LINE)
	_prestige_button.pressed.connect(_show_prestige)
	box.add_child(_prestige_button)

	var challenge_row := HBoxContainer.new()
	challenge_row.add_theme_constant_override("separation", 6)
	_challenge_label = Label.new()
	_challenge_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_challenge_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_challenge_label.add_theme_font_size_override("font_size", 14)
	_challenge_label.add_theme_color_override("font_color", Color("ff8fa3"))
	challenge_row.add_child(_challenge_label)
	_challenge_abort = Button.new()
	_challenge_abort.text = tr("Abbrechen")
	_challenge_abort.focus_mode = Control.FOCUS_NONE
	_challenge_abort.add_theme_font_size_override("font_size", 12)
	_challenge_abort.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_challenge_abort.pressed.connect(func() -> void:
		var m := Modal.open(self, tr("Herausforderung abbrechen?"), tr("Du spielst normal weiter, bekommst aber keine Extra-Lorbeeren."), [tr("Abbrechen"), tr("Weiterkämpfen")])
		m.closed.connect(func(index: int) -> void:
			if index == 0:
				GameState.abort_challenge()))
	challenge_row.add_child(_challenge_abort)
	box.add_child(challenge_row)


func _bar(fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.add_theme_stylebox_override("fill", _box(fill, 7, 0, 0))
	return bar


func _build_rage_tint() -> void:
	_rage_tint = ColorRect.new()
	_rage_tint.color = Color(1.0, 0.1, 0.1, 0.0)
	_rage_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rage_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rage_tint.visible = false
	add_child(_rage_tint)
	move_child(_rage_tint, shoe_layer.get_index())


func _connect_ui() -> void:
	%ImportButton.pressed.connect(func() -> void: _file_dialog.popup_centered_ratio(0.7))
	%GalleryButton.pressed.connect(_show_gallery)
	%LaurelButton.pressed.connect(_show_laurel_tree)
	%ShowerButton.pressed.connect(func() -> void:
		target_area.effects.clear()
		GameState.add_stat("showers")
		show_toast(tr("Frisch geduscht!")))
	%AchievementsButton.pressed.connect(_show_achievements)
	%DevicesTab.pressed.connect(func() -> void: _show_shop_page(false))
	%UpgradesTab.pressed.connect(func() -> void: _show_shop_page(true))


func _show_shop_page(upgrades: bool) -> void:
	%DevicesPage.visible = not upgrades
	%UpgradesPage.visible = upgrades


# =====================================================================
# Aktualisierung
# =====================================================================

func _refresh() -> void:
	wumms_label.text = Num.whole(GameState.wumms)
	wps_label.text = tr("pro Sekunde: %s") % Num.fmt(GameState.wps())
	click_label.text = tr("pro Klick: %s") % Num.fmt(GameState.click_value())
	if GameState.time_warp_active():
		wps_label.text += tr(" (Zeitraffer ×2)")
	wumms_label.tooltip_text = tr("Insgesamt erzeugt: %s Schmerz-Token") % Num.whole(GameState.total_wumms) \
		+ "\n" + tr("Treffer gesamt: %s") % Num.whole(GameState.total_hits)
	%MarkenChip.visible = GameState.beulen_marken > 0
	marken_label.text = tr("Reue-Token: %d") % GameState.beulen_marken
	target_label.text = GameState.target_name()
	target_hits_label.text = tr("Insgesamt verhauen: %s") % Num.whole(GameState.current_target_hits())
	# Die Tastenhilfe brauchen nur Neulinge.
	%HelpLabel.visible = GameState.total_hits < 500
	_sync_stage_floor()
	%AchievementsButton.text = tr("Erfolge %d/%d") % [GameState.achievement_count(), GameState.achievement_defs.size()]
	%LaurelButton.visible = GameState.laurel_tree_unlocked()
	var claimable := GameState.claimable_quests()
	%QuestsButton.text = tr("Aufträge (%d!)") % claimable if claimable > 0 else tr("Aufträge")
	%GamesButton.visible = GameState.minigame_unlocked("dojo") or GameState.minigame_unlocked("pie") or GameState.market_unlocked()
	_refresh_progress_widgets()
	_refresh_buffs()
	_refresh_devices()
	_refresh_upgrades()


## Bühnenkante im Hintergrund auf Höhe des Podests unter dem Opfer halten.
func _sync_stage_floor() -> void:
	var bg: GameBackground = %Background
	var local_y := target_area.floor_y()
	var y := -1.0 if local_y < 0.0 else target_area.global_position.y - bg.global_position.y + local_y
	if absf(y - bg.floor_y) > 0.5:
		bg.floor_y = y
		bg.refresh()


func _refresh_progress_widgets() -> void:
	_combo_bar.value = GameState.combo
	_combo_label.text = tr("COMBO %d") % roundi(GameState.combo)
	_combo_mult_label.text = tr("Klick ×%s") % Num.fmt(Balance.combo_multiplier(GameState.combo))
	if GameState.rage_active():
		_rage_bar.max_value = GameState.RAGE_DURATION
		_rage_bar.value = GameState.rage_time
		_rage_label.text = tr("×%s · %d s") % [Num.fmt(GameState.RAGE_MULT), ceili(GameState.rage_time)]
		_rage_button.text = "%d s" % ceili(GameState.rage_time)
		_rage_button.disabled = true
	else:
		_rage_bar.max_value = GameState.RAGE_MAX
		_rage_bar.value = GameState.rage_meter
		_rage_label.text = "%d %%" % roundi(float(GameState.rage_meter) / float(GameState.RAGE_MAX) * 100.0)
		_rage_button.text = tr("WUT!")
		_rage_button.disabled = not GameState.rage_ready()
	_laurel_label.visible = GameState.laurels_total > 0
	_laurel_label.text = tr("Lorbeeren: %d (+%d %% auf alles)") % [GameState.laurels_total, GameState.laurels_total]
	var active_challenge := GameState.challenge_def(GameState.challenge_active)
	_challenge_label.get_parent().visible = not active_challenge.is_empty()
	if not active_challenge.is_empty():
		_challenge_label.text = tr("Herausforderung „%s“: %s / %s Schmerz-Token") % [active_challenge.name,
			Num.whole(GameState.total_wumms), Num.whole(float(active_challenge.goal_wumms))]
	var gain := GameState.prestige_gain()
	_prestige_button.visible = GameState.can_prestige()
	_prestige_button.text = tr("Neuanfang: %s") % laurels_text(gain, true)


func _refresh_buffs() -> void:
	var buffs: Array = GameState.buffs
	while buff_box.get_child_count() < buffs.size():
		var l := Label.new()
		l.add_theme_stylebox_override("normal", _box(CARD, 10, 2, 5, GOLD))
		l.add_theme_font_size_override("font_size", 14)
		buff_box.add_child(l)
	while buff_box.get_child_count() > buffs.size():
		var last := buff_box.get_child(buff_box.get_child_count() - 1)
		buff_box.remove_child(last)
		last.queue_free()
	for i in buffs.size():
		var b: Dictionary = buffs[i]
		var effect := ""
		if not is_equal_approx(float(b.wps_mult), 1.0):
			effect = tr("WPS ×%s") % Num.fmt(float(b.wps_mult))
		if not is_equal_approx(float(b.click_mult), 1.0):
			effect = tr("Klick ×%s") % Num.fmt(float(b.click_mult))
		var label: Label = buff_box.get_child(i)
		label.text = "%s · %s · %d s" % [b.name, effect, ceili(float(b.remaining))]
		var bad := float(b.wps_mult) < 1.0
		label.add_theme_color_override("font_color", Color("ff8fa3") if bad else TEXT)
		label.add_theme_stylebox_override("normal", _box(CARD, 10, 2, 5, RAGE if bad else GOLD))


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
		var stars := "★".repeat(maxi(0, Balance.milestone_tier(owned) - 1))
		row.info.text = tr("je %s WPS") % Num.fmt(unit_wps) + ("  " + stars if stars != "" else "")
		row.count.text = Num.whole(owned)
		row.count.visible = owned > 0
		row.buy.text = Num.whole(cost) if _buy_mode == 1 else "×%s\n%s" % [Num.whole(shown_amount), Num.whole(cost)]
		row.buy.disabled = amount <= 0 or GameState.wumms < cost
		row.sell.disabled = owned <= 0
		var share := 0.0 if total_wps <= 0.0 else GameState.device_total_wps(id) / total_wps * 100.0
		var payback := INF if unit_wps <= 0.0 else GameState.device_cost(id, 1) / unit_wps
		row.panel.tooltip_text = tr("%s\n\n%s\nJedes Gerät: %s WPS (×%s durch Upgrades)\nAlle zusammen: %s WPS (%s %% deiner Produktion)\nAmortisation: %s") % [
			d.name, d.description, Num.fmt(unit_wps), Num.fmt(GameState.device_multiplier(id)),
			Num.fmt(GameState.device_total_wps(id)), Num.fmt(share), Num.duration(payback)]
		if row.index < 9:
			row.panel.tooltip_text += "\n" + tr("Taste %d") % (row.index + 1)


func _refresh_upgrades() -> void:
	var visible_list := GameState.visible_upgrades()
	var ids: Array[String] = []
	for u in visible_list:
		ids.append(u.id)
	if ids != _shown_upgrade_ids:
		_rebuild_upgrades(visible_list)
		_shown_upgrade_ids = ids
	var affordable := 0
	for id in _upgrade_buttons:
		var u := GameState.upgrade_def(id)
		_upgrade_buttons[id].disabled = GameState.wumms < float(u.cost)
		if not _upgrade_buttons[id].disabled:
			affordable += 1
	no_upgrades_label.visible = ids.is_empty()
	%UpgradesTab.text = tr("Upgrades (%d)") % affordable if affordable > 0 else tr("Upgrades")


## Upgrades als Zeilen: Farbpunkt nach Art, Name, Wirkung, Kaufen-Knopf. Die Beschreibung steht im Tooltip.
func _rebuild_upgrades(list: Array[Dictionary]) -> void:
	for id in _upgrade_buttons:
		_upgrade_buttons[id].get_meta("row").queue_free()
	_upgrade_buttons.clear()
	for u in list:
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.add_theme_stylebox_override("panel", _box(ROW, 12, 0, 8))
		panel.tooltip_text = tr("%s\n\n%s\n\nWirkung: %s\nPreis: %s Schmerz-Token") % [
			u.name, u.description, GameState.upgrade_effect_text(u), Num.whole(float(u.cost))]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		panel.add_child(row)

		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(16, 16)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.add_theme_stylebox_override("panel", _box(_upgrade_color(u), 8, 2, 0, LINE))
		row.add_child(dot)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		var name_label := Label.new()
		name_label.text = u.name
		name_label.add_theme_font_override("font", heading_font())
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var effect := Label.new()
		effect.text = GameState.upgrade_effect_text(u)
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect.add_theme_font_size_override("font_size", 12)
		effect.add_theme_color_override("font_color", GOLD)
		info.add_child(name_label)
		info.add_child(effect)
		row.add_child(info)

		var b := Button.new()
		b.text = Num.whole(float(u.cost))
		b.custom_minimum_size = Vector2(104, 42)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.focus_mode = Control.FOCUS_NONE
		_style_buy_button(b, 13)
		b.set_meta("row", panel)
		var id: String = u.id
		b.pressed.connect(func() -> void:
			if GameState.buy_upgrade(id):
				show_toast(tr("Upgrade gekauft: %s") % u.name))
		row.add_child(b)
		upgrade_list.add_child(panel)
		_upgrade_buttons[id] = b


## Farbe nach Upgrade-Art: Gerät = Gerätefarbe, Klick = Hellblau, Global = Gold.
func _upgrade_color(u: Dictionary) -> Color:
	var e: Dictionary = u.effect
	match e.type:
		"device_mult":
			return Color(GameState.device_def(e.device).get("color", "#74c0fc"))
		"synergy":
			return Color(GameState.device_def(e.target).get("color", "#74c0fc"))
		"click_mult", "click_wps", "crit", "autofire":
			return Color("74c0fc")
	return GOLD


func _show_ticker() -> void:
	if _ticker_override != "" and _ticker_index % 3 == 0:
		ticker_label.text = "+++ %s +++" % _ticker_override
		return
	ticker_label.text = "+++ %s +++" % tr(TICKER_LINES[_ticker_index % TICKER_LINES.size()])


## "1 Lorbeer" / "3 Lorbeeren" (mit Plus-Zeichen: "+1 Lorbeer") – übersetzbar.
func laurels_text(n: int, plus: bool = false) -> String:
	var text := tr("1 Lorbeer") if n == 1 else tr("%d Lorbeeren") % n
	return ("+" + text) if plus else text


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
	var boss_mult := boss.filter_hit(uv) if GameState.boss_active else 1.0
	if boss_mult < 0.0:
		target_area.effects.popup_text(tr("Geblockt!"), target_area.uv_to_local(uv), Color("adb5bd"))
		Sfx.play("squeak", 0.2, -6.0)
		return
	var result := GameState.hit()
	if GameState.boss_active:
		GameState.boss_damage(boss_mult)
		if boss_mult > 1.0:
			target_area.effects.popup_text(tr("SCHWACHSTELLE! ×%d") % int(boss_mult), target_area.uv_to_local(uv) + Vector2(0, -60), Color("ff922b"))
	target_area.effects.add_hit(uv, result.value, result.crit)
	target_area.squash()
	Sfx.play_hit(result.crit)
	if result.crit:
		target_area.shake()
		if GameState.has_cosmetic("confetti_crits") and not GameState.reduced_effects:
			Confetti.burst(self, target_area.global_position - global_position + target_area.uv_to_local(uv), 30)


func _on_target_changed() -> void:
	target_area.set_texture(GameState.target_texture())
	_refresh()


# i18n
const MILESTONE_NAMES: Array[String] = ["", "", "Bronze", "Silber", "Gold", "Platin", "Rubin", "Regenbogen"]


func _on_device_bought(id: String, amount: int) -> void:
	Sfx.play("buy", 0.05, -6.0)
	var count := GameState.device_count(id)
	var tier := Balance.milestone_tier(count)
	if tier >= 2 and tier > Balance.milestone_tier(count - amount):
		var d := GameState.device_def(id)
		show_toast(tr("%s: %d Stück – %s-Rahmen!") % [d.name, Balance.MILESTONES[tier - 1], tr(MILESTONE_NAMES[tier])])
		Sfx.play("achievement", 0.05, -8.0)


func _apply_cosmetics() -> void:
	(%Background as GameBackground).refresh()
	target_area.refresh_cursor()


func _try_rage() -> void:
	if GameState.start_rage():
		pass


func _on_rage_changed(active: bool) -> void:
	if _rage_tween:
		_rage_tween.kill()
	_rage_tint.visible = active
	if not active:
		show_toast(tr("Puh. Durchatmen."))
		return
	Sfx.play("rage", 0.0, 0.0)
	show_toast(tr("WUTMODUS! Alles ×3 für 10 Sekunden!"))
	target_area.shake()
	_rage_tint.color.a = 0.16
	if not GameState.reduced_effects:
		_rage_tween = create_tween().set_loops()
		_rage_tween.tween_property(_rage_tint, "color:a", 0.26, 0.25)
		_rage_tween.tween_property(_rage_tint, "color:a", 0.12, 0.25)


func _on_bump_level_up(target: String, level: int) -> void:
	if target != GameState.target_id:
		return
	var texts := ["", tr("Erstes Pflaster!"), tr("Ein Veilchen!"), tr("Riesenbeule!"), tr("Jetzt ist er genervt."), tr("Er sieht Sterne!"),
		tr("Noch ein Veilchen!"), tr("Kopfverband!"), tr("Am Ende seiner Kräfte."), tr("Die Ohren qualmen!"), tr("Vögelchen zwitschern. Maximum erreicht!")]
	show_toast(tr("Beulen-Level %d: %s (+1 Reue-Token)") % [level, texts[mini(level, texts.size() - 1)]])
	Sfx.play("achievement", 0.05, -6.0)
	# Bei der Standardfigur wechselt ab Level 4 und 8 die Mimik.
	target_area.set_texture(GameState.target_texture())


func _on_file_selected(path: String) -> void:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		show_toast(tr("Dieses Bild konnte nicht geladen werden."))
		return
	_open_crop(img, path.get_file().get_basename())


## Vor dem Import: Ausschnitt wählen (oder das ganze Bild übernehmen).
func _open_crop(img: Image, display_name: String) -> void:
	var editor := CropEditor.new()
	editor.setup(img)
	var m := Modal.open(self, tr("Ausschnitt wählen"), editor, [tr("Übernehmen"), tr("Ganzes Bild"), tr("Abbrechen")], 520.0)
	m.closed.connect(func(index: int) -> void:
		var chosen: Image = editor.result() if index == 0 else (img if index == 1 else null)
		if chosen == null:
			return
		if GameState.import_image(chosen, display_name):
			show_toast(tr("Neues Opfer: %s") % GameState.target_name())
			_open_face(GameState.target_id)
		else:
			show_toast(tr("Dieses Bild konnte nicht geladen werden.")))


## Augen markieren, damit Pflaster, Veilchen und Verband auf eigenen Bildern richtig sitzen.
func _open_face(id: String, after: Callable = Callable()) -> void:
	var img := GameState.gallery_image(id)
	if img == null:
		return
	var marker := FaceMarker.new()
	marker.setup(ImageTexture.create_from_image(img), GameState.face_eyes(id))
	var m := Modal.open(self, tr("Wo ist das Gesicht?"), marker, [tr("Passt so"), tr("Überspringen")], 480.0)
	m.closed.connect(func(index: int) -> void:
		if index == 0:
			GameState.set_face(id, marker.eye_left, marker.eye_right)
			target_area.bumps.refresh()
		if after.is_valid():
			after.call())


func _on_files_dropped(files: PackedStringArray) -> void:
	if files.is_empty():
		return
	_on_file_selected(files[0])


func _paste_image() -> void:
	if not DisplayServer.clipboard_has_image():
		show_toast(tr("In der Zwischenablage ist kein Bild."))
		return
	_open_crop(DisplayServer.clipboard_get_image(), tr("Aus der Zwischenablage"))


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
	Sfx.applause(false)
	while achievement_toasts.get_child_count() >= MAX_ACHIEVEMENT_TOASTS:
		var oldest := achievement_toasts.get_child(0)
		achievement_toasts.remove_child(oldest)
		oldest.queue_free()
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _box(CARD, 12, 3, 10, GOLD))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var head := Label.new()
	head.text = tr("Erfolg freigeschaltet!")
	head.add_theme_font_size_override("font_size", 13)
	head.add_theme_color_override("font_color", MUTED)
	var title := Label.new()
	title.text = a.get("name", id)
	_comic(title, 22, GOLD)
	var desc := Label.new()
	desc.text = a.get("description", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 14)
	var reward := Label.new()
	reward.text = _reward_text(GameState.achievement_reward(a), GameState.last_achievement_wumms)
	reward.add_theme_font_size_override("font_size", 14)
	reward.add_theme_color_override("font_color", GOLD)
	box.add_child(head)
	box.add_child(title)
	box.add_child(desc)
	box.add_child(reward)
	achievement_toasts.add_child(panel)
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_interval(4.5)
	tw.tween_property(panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(panel.queue_free)
	if not GameState.reduced_effects:
		Confetti.burst(self, Vector2(size.x - 200.0, 110.0), 40)


## "Belohnung: +1 Reue-Token · +120 Schmerz-Token" (wumms < 0: noch nicht bekannt, dann Minuten Produktion).
func _reward_text(reward: Dictionary, wumms: float = -1.0) -> String:
	var marken := int(reward.marken)
	var tokens := tr("+1 Reue-Token") if marken == 1 else tr("+%d Reue-Token") % marken
	if wumms >= 0.0:
		return tr("Belohnung: %s · +%s Schmerz-Token") % [tokens, Num.fmt(wumms)]
	return tr("Belohnung: %s · %s Min. Produktion") % [tokens, Num.fmt(float(reward.minutes))]


func _show_achievements() -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	var summary := Label.new()
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.text = tr("%d von %d freigeschaltet") % [GameState.achievement_count(), GameState.achievement_defs.size()]
	if GameState.has_upgrade("milchtuete_der_wut"):
		summary.text += tr(" · Wutmilch: +%s %% WPS") % Num.fmt(GameState.achievement_count() * 0.5)
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
		tile.custom_minimum_size = Vector2(262, 112)
		tile.add_theme_stylebox_override("panel", tile_box("active" if unlocked else "locked"))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		tile.add_child(box)
		var name_label := Label.new()
		name_label.text = "???" if hidden else String(a.name)
		name_label.add_theme_font_size_override("font_size", 16)
		if not unlocked:
			name_label.add_theme_color_override("font_color", MUTED)
		var desc := Label.new()
		desc.text = tr("Versteckter Erfolg") if hidden else String(a.description)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(236, 0)
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(TEXT, 0.8) if unlocked else MUTED)
		box.add_child(name_label)
		box.add_child(desc)
		var reward := Label.new()
		reward.text = ("✓ " if unlocked else "") + _reward_text(GameState.achievement_reward(a))
		reward.add_theme_font_size_override("font_size", 11)
		reward.add_theme_color_override("font_color", GOLD if not unlocked else Color(GOLD, 0.6))
		box.add_child(reward)
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
	Modal.open(self, tr("Erfolge"), content, [tr("Schließen")], 860.0)


# =====================================================================
# Menü, Willkommen zurück
# =====================================================================

func _on_menu(id: int) -> void:
	if id in [MENU_SOUND, MENU_EFFECTS, MENU_TIME_WARP, MENU_AUTOBUY, MENU_AUTO_RAGE]:
		_sync_menu_checks.call_deferred()
	match id:
		MENU_SOUND:
			GameState.sound_on = not GameState.sound_on
			Sfx.apply_volumes()
		MENU_VOLUME:
			_show_volume()
		MENU_EFFECTS:
			GameState.reduced_effects = not GameState.reduced_effects
		MENU_TIME_WARP:
			GameState.time_warp = not GameState.time_warp
			show_toast(tr("Zeitraffer an: Geräte arbeiten doppelt so schnell.") if GameState.time_warp else tr("Zeitraffer aus."))
		MENU_AUTOBUY:
			GameState.autobuy_enabled = not GameState.autobuy_enabled
		MENU_AUTO_RAGE:
			GameState.auto_rage_enabled = not GameState.auto_rage_enabled
		MENU_SAVE:
			if GameState.save_game():
				show_toast(tr("Gespeichert."))
		MENU_PHOTO:
			_take_photo()
		MENU_LANGUAGE:
			GameState.set_language("en" if GameState.effective_language() == "de" else "de")
			GameState.save_game()
			get_tree().reload_current_scene.call_deferred()
		MENU_EXPORT:
			var code := GameState.export_save_code()
			DisplayServer.clipboard_set(code)
			var field := LineEdit.new()
			field.text = code
			field.editable = false
			field.select_all_on_focus = true
			Modal.open(self, tr("Spielstand exportieren"),
				_column([tr("Der Textcode ist in deiner Zwischenablage. Heb ihn gut auf!")], field), ["OK"])
		MENU_IMPORT:
			var field := LineEdit.new()
			field.placeholder_text = tr("Textcode hier einfügen")
			if DisplayServer.clipboard_has():
				field.text = DisplayServer.clipboard_get().strip_edges()
			var m := Modal.open(self, tr("Spielstand importieren"),
				_column([tr("Achtung: Dein aktueller Spielstand wird ersetzt.")], field), [tr("Jetzt laden"), tr("Abbrechen")])
			m.closed.connect(func(index: int) -> void:
				if index == 0:
					if GameState.import_save_code(field.text):
						show_toast(tr("Spielstand geladen!"))
					else:
						show_toast(tr("Dieser Code funktioniert leider nicht.")))
		MENU_RESET:
			var m := Modal.open(self, tr("Alles löschen?"),
				tr("Wirklich ALLES wird gelöscht: Schmerz-Token, Geräte, Upgrades, Erfolge, Lorbeeren und der Lorbeer-Baum. Deine Bilder bleiben erhalten.\n\n(Für einen Neuanfang mit Lorbeeren nimm den grünen Knopf in der Statistik.)"),
				[tr("Ja, alles löschen"), tr("Abbrechen")])
			m.closed.connect(func(index: int) -> void:
				if index == 0:
					GameState.reset_progress()
					_apply_cosmetics()
					target_area.effects.clear()
					for shoe in shoe_layer.get_children():
						shoe.queue_free()
					show_toast(tr("Alles auf Anfang. Bombastus atmet auf.")))


## Häkchen sofort nachziehen – das Menü bleibt bei Ankreuz-Einträgen offen.
func _sync_menu_checks() -> void:
	var popup: PopupMenu = (%MenuButton as MenuButton).get_popup()
	var states := {MENU_SOUND: GameState.sound_on, MENU_EFFECTS: GameState.reduced_effects,
		MENU_TIME_WARP: GameState.time_warp, MENU_AUTOBUY: GameState.autobuy_enabled,
		MENU_AUTO_RAGE: GameState.auto_rage_enabled}
	for id in states:
		var index := popup.get_item_index(id)
		if index >= 0:
			popup.set_item_checked(index, bool(states[id]))
	GameState.save_game()


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


func _show_welcome_back(info: Dictionary, login: Dictionary = {}) -> void:
	var text := ""
	if not info.is_empty():
		var seconds := float(info.seconds)
		text = tr("Du warst %s weg.\nIn der Zeit haben deine Geräte\n%s Schmerz-Token\nerwirtschaftet.") % [
			Num.duration(seconds), Num.whole(float(info.gain))]
		if seconds > GameState.offline_cap():
			text += tr("\n\n(Ohne Aufsicht arbeiten sie höchstens %s.)") % Num.duration(GameState.offline_cap())
	if not login.is_empty():
		if text != "":
			text += "\n\n"
		text += tr("Login-Serie: Tag %d von 7%s\nTagesbonus: +%s Schmerz-Token und +%d Reue-Token") % [
			int(login.day), tr(" – Hauptgewinn!") if int(login.day) == 7 else "", Num.whole(float(login.wumms)), int(login.marken)]
	Modal.open(self, tr("Willkommen zurück!"), text, [tr("Weiter hauen!")])


# =====================================================================
# Neuanfang (Prestige)
# =====================================================================

func _show_prestige() -> void:
	if not GameState.can_prestige():
		return
	var gain := GameState.prestige_gain()
	var text := tr("Du fängst von vorne an und bekommst dafür %s.\n\n") % laurels_text(gain)
	text += tr("Jeder Lorbeer gibt dauerhaft +1 %% auf Produktion und Klicks – insgesamt dann +%d %%.\n") % (GameState.laurels_total + gain)
	text += tr("Lorbeeren kannst du zusätzlich im Lorbeer-Baum ausgeben, der Bonus bleibt trotzdem.\n\n")
	text += tr("Weg sind: Schmerz-Token, Geräte und Upgrades.\nBleiben: Erfolge, Statistiken, Bilder, Reue-Token und der Lorbeer-Baum.")
	var m := Modal.open(self, tr("Neuanfang?"), text, [tr("Neu anfangen!"), tr("Noch nicht")], 600.0)
	m.closed.connect(func(index: int) -> void:
		if index == 0:
			GameState.perform_prestige())


func _on_prestiged(gain: int) -> void:
	target_area.effects.clear()
	Sfx.applause(true)
	for shoe in shoe_layer.get_children():
		shoe.queue_free()
	Sfx.play("prestige", 0.0, -2.0)
	if not GameState.reduced_effects:
		Confetti.burst(self, size * Vector2(0.5, 0.35), 120)
	_refresh()
	var m := Modal.open(self, tr("Lorbeeren!"), tr("+%s. Bombastus hat sich erholt – und du bist stärker als vorher.\n\nMagst du gleich etwas im Lorbeer-Baum freischalten?") % laurels_text(gain), [tr("Zum Lorbeer-Baum"), tr("Später")])
	m.closed.connect(func(index: int) -> void:
		if index == 0:
			_show_laurel_tree())


# =====================================================================
# Lorbeer-Baum
# =====================================================================

func _show_laurel_tree() -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	var head := Label.new()
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.text = tr("Verfügbar: %s  ·  %d Reue-Token  ·  Lorbeer-Bonus: +%d %%") % [
		laurels_text(GameState.laurels_available()),
		GameState.beulen_marken, GameState.laurels_total]
	content.add_child(head)
	var hint := Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", MUTED)
	var next_laurel := Balance.wumms_for_laurels(GameState.laurels_total - GameState.laurels_extra + 1)
	hint.text = tr("Lorbeeren gibt es beim Neuanfang. Reue-Token gibt es für Erfolge, Beulen-Level und Pech-Schuhe.") + "\n" + \
		tr("Nächster Lorbeer ab %s Schmerz-Token insgesamt – bisher %s.") % [Num.fmt(next_laurel), Num.fmt(GameState.lifetime_wumms)]
	content.add_child(hint)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	content.add_child(columns)
	var modal_ref: Array = []
	for branch in BRANCHES:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(210, 0)
		col.add_theme_constant_override("separation", 8)
		var title := Label.new()
		title.text = tr(branch[1])
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_comic(title, 24, Color("69db7c") if branch[0] != "show" else Color("da77f2"))
		col.add_child(title)
		for n in GameState.laurel_defs:
			if n.branch != branch[0]:
				continue
			col.add_child(_laurel_node_button(n, modal_ref))
		columns.add_child(col)
	if GameState.challenges_unlocked():
		content.add_child(_section_title(tr("Herausforderungen – Extra-Lorbeeren")))
		for c in GameState.challenge_defs:
			content.add_child(_challenge_row(c, modal_ref))
	var m := Modal.open(self, tr("Lorbeer-Baum"), content, [tr("Schließen")], 940.0)
	modal_ref.append(m)


func _challenge_row(c: Dictionary, modal_ref: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = tr("%s: %s Ziel: %s Schmerz-Token → %s") % [c.name, c.description, Num.whole(float(c.goal_wumms)),
		laurels_text(int(c.reward_laurels), true)]
	row.add_child(label)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(160, 0)
	var id: String = c.id
	if GameState.challenges_done.has(id):
		b.text = tr("Geschafft ✓")
		b.disabled = true
	elif GameState.challenge_active == id:
		b.text = tr("Läuft …")
		b.disabled = true
	else:
		b.text = tr("Starten")
		style_primary(b)
		b.disabled = GameState.challenge_active != ""
		b.pressed.connect(func() -> void:
			var m := Modal.open(self, tr("„%s“ starten?") % c.name,
				tr("Dein Durchlauf beginnt von vorn – wie bei einem Neuanfang, nur ohne neue Lorbeeren.\nLorbeeren, Erfolge und der Lorbeer-Baum bleiben.\n\n%s\nZiel: %s Schmerz-Token") % [c.description, Num.whole(float(c.goal_wumms))],
				[tr("Los geht's!"), tr("Doch nicht")])
			m.closed.connect(func(index: int) -> void:
				if index == 0 and GameState.start_challenge(id):
					modal_ref[0].close()
					target_area.effects.clear()
					show_toast(tr("Herausforderung „%s“ läuft!") % c.name)))
	row.add_child(b)
	return row


func _laurel_node_button(n: Dictionary, modal_ref: Array) -> Button:
	var owned := GameState.has_laurel_node(n.id)
	var unlocked := GameState.laurel_requirements_met(n)
	var affordable := GameState.can_afford_laurel_node(n)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(210, 64)
	b.add_theme_font_size_override("font_size", 14)
	var status := tr("✓ freigeschaltet") if owned else GameState.laurel_cost_text(n)
	b.text = "%s\n%s" % [n.name, status]
	var req_names: Array[String] = []
	for r in n.get("requires", []):
		req_names.append(String(GameState.laurel_def(r).get("name", r)))
	b.tooltip_text = "%s\n\n%s%s" % [n.name, n.description,
		"" if req_names.is_empty() else tr("\n\nBraucht: ") + ", ".join(req_names)]
	if owned:
		b.add_theme_stylebox_override("normal", tile_box("active", 6))
		b.add_theme_stylebox_override("disabled", tile_box("active", 6))
		b.add_theme_color_override("font_disabled_color", GOLD)
		b.disabled = true
	elif not unlocked:
		b.disabled = true
		b.text = tr("%s\ngesperrt · %s") % [n.name, GameState.laurel_cost_text(n)]
	else:
		b.disabled = not affordable
		b.add_theme_stylebox_override("normal", tile_box("good", 6))
		var hover := tile_box("good", 6)
		hover.bg_color = Color("285750")
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_color_override("font_pressed_color", TEXT)
		var id: String = n.id
		b.pressed.connect(func() -> void:
			if GameState.buy_laurel_node(id):
				Sfx.play("buy", 0.0, -3.0)
				show_toast(tr("Freigeschaltet: %s") % n.name)
				if not modal_ref.is_empty():
					modal_ref[0].close()
				_show_laurel_tree())
	return b


# =====================================================================
# Galerie
# =====================================================================

func _show_gallery() -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	var modal_ref: Array = []
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	var import_button := Button.new()
	import_button.text = tr("Neues Bild importieren …")
	import_button.focus_mode = Control.FOCUS_NONE
	import_button.pressed.connect(func() -> void:
		modal_ref[0].close()
		_file_dialog.popup_centered_ratio(0.7))
	top.add_child(import_button)
	content.add_child(top)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(860, 480)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	for entry in GameState.gallery_entries():
		grid.add_child(_gallery_tile(entry, modal_ref))
	modal_ref.append(Modal.open(self, tr("Galerie"), content, [tr("Schließen")], 900.0))


func _gallery_tile(entry: Dictionary, modal_ref: Array) -> PanelContainer:
	var current: bool = entry.id == GameState.target_id
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", tile_box("active" if current else "normal"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	tile.add_child(box)
	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(180, 150)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if entry.custom:
		var img := GameState.gallery_image(entry.id)
		if img:
			thumb.texture = ImageTexture.create_from_image(img)
	else:
		var moods: Array = GameState.figure_def(entry.id).get("moods", [])
		if not moods.is_empty():
			thumb.texture = load(moods[mini(GameState.mood_index(entry.level), moods.size() - 1)])
	box.add_child(thumb)
	var name_label := Label.new()
	name_label.text = entry.name
	name_label.custom_minimum_size = Vector2(180, 0)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 15)
	box.add_child(name_label)
	var info := Label.new()
	info.text = tr("%s Treffer · Beulen-Level %d") % [Num.whole(entry.hits), entry.level]
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", MUTED)
	box.add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)
	var id: String = entry.id
	var pick := _small_button(tr("Aktiv") if current else tr("Hauen!"), not current)
	pick.pressed.connect(func() -> void:
		GameState.select_target(id)
		modal_ref[0].close()
		show_toast(tr("Neues Opfer: %s") % GameState.target_name()))
	row.add_child(pick)
	if entry.custom:
		var rename := _small_button(tr("Name"), true)
		rename.pressed.connect(func() -> void: _rename_dialog(id, modal_ref))
		row.add_child(rename)
		var face := _small_button(tr("Gesicht"), true)
		face.tooltip_text = tr("Augen markieren, damit Pflaster und Verband richtig sitzen")
		face.pressed.connect(func() -> void:
			modal_ref[0].close()
			_open_face(id, _show_gallery))
		row.add_child(face)
		var delete := _small_button(tr("Löschen"), true)
		delete.pressed.connect(func() -> void: _delete_dialog(id, modal_ref))
		row.add_child(delete)
	return tile


func _small_button(text: String, enabled: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	return b


func _rename_dialog(id: String, gallery_ref: Array) -> void:
	var field := LineEdit.new()
	field.text = String(GameState.target_names.get(id, ""))
	field.max_length = 40
	field.select_all_on_focus = true
	var m := Modal.open(self, tr("Umbenennen"), _column([tr("Wie soll das Opfer heißen?")], field), [tr("Speichern"), tr("Abbrechen")])
	field.grab_focus.call_deferred()
	m.closed.connect(func(index: int) -> void:
		if index == 0 and GameState.rename_target(id, field.text):
			gallery_ref[0].close()
			_show_gallery())


func _delete_dialog(id: String, gallery_ref: Array) -> void:
	var m := Modal.open(self, tr("Bild löschen?"), tr("„%s“ und seine Treffer werden gelöscht.") % GameState.target_names.get(id, ""),
		[tr("Löschen"), tr("Abbrechen")])
	m.closed.connect(func(index: int) -> void:
		if index == 0 and GameState.delete_target(id):
			gallery_ref[0].close()
			_show_gallery())


# =====================================================================
# Boss-Kämpfe
# =====================================================================

func _on_boss_started() -> void:
	boss.start()
	Sfx.play("rage", 0.0, 0.0)
	show_toast(tr("BOSS-KAMPF! %s") % GameState.boss_gimmick.get("text", ""))
	target_area.shake()


func _on_boss_finished(won: bool, reward: Dictionary) -> void:
	boss.stop()
	if won:
		Sfx.play("prestige", 0.0, -2.0)
		Sfx.applause(true)
		if not GameState.reduced_effects:
			Confetti.burst(self, size * Vector2(0.5, 0.3), 100)
		Modal.open(self, tr("Boss besiegt!"), tr("Er hat aufgegeben und wedelt mit der weißen Fahne.\n\nPokal: %s\n+%d Reue-Token") % [
			tr(reward.trophy), int(reward.marken)], [tr("Hurra!")])
	else:
		Sfx.play("bad", 0.0, -2.0)
		show_toast(tr("Der Boss ist entkommen! In %s Treffern kommt er wieder.") % Num.whole(GameState.next_boss_at - GameState.total_hits))


# =====================================================================
# Aufträge, Login-Serie, Event, Vitrine
# =====================================================================

func _show_quests() -> void:
	GameState.check_new_day()
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	var modal_ref: Array = []
	content.add_child(_section_title(tr("Tagesaufträge")))
	for i in GameState.quests.size():
		var q: Dictionary = GameState.quests[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label := Label.new()
		label.text = GameState.quest_text(q)
		col.add_child(label)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 12)
		bar.max_value = float(q.amount)
		bar.value = GameState.quest_progress(q)
		col.add_child(bar)
		row.add_child(col)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(170, 0)
		var index := i
		if q.claimed:
			b.text = tr("Erledigt ✓")
			b.disabled = true
		elif GameState.quest_done(q):
			b.text = tr("Abholen: %d Reue-Token") % int(q.reward)
			b.pressed.connect(func() -> void:
				var gain := GameState.claim_quest(index)
				if gain > 0:
					Sfx.play("achievement", 0.0, -4.0)
					show_toast(tr("+%d Reue-Token") % gain)
				modal_ref[0].close()
				_show_quests())
		else:
			b.text = tr("%s / %s · %d Reue-Token") % [Num.whole(GameState.quest_progress(q)), Num.whole(float(q.amount)), int(q.reward)]
			b.disabled = true
		row.add_child(b)
		content.add_child(row)
	var streak := Label.new()
	streak.text = (tr("Login-Serie: 1 Tag · Morgen gibt es %d Reue-Token") % Balance.login_marken(GameState.login_streak + 1)) \
		if GameState.login_streak == 1 else (tr("Login-Serie: %d Tage in Folge · Morgen gibt es %d Reue-Token") % [
		GameState.login_streak, Balance.login_marken(GameState.login_streak + 1)])
	streak.add_theme_color_override("font_color", MUTED)
	content.add_child(streak)

	var event := GameState.active_event()
	if not event.is_empty():
		content.add_child(_section_title(tr("Saison-Event: %s") % event.name))
		var key := GameState.event_key(event)
		var done := GameState.events_done.has(key)
		var info := Label.new()
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.custom_minimum_size = Vector2(640, 0)
		info.text = tr("Geschafft! %s gehört dir.") % tr(event.trophy) if done else String(event.intro)
		content.add_child(info)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 14)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = float(event.goal_hits)
		bar.value = GameState.event_hits(event)
		row.add_child(bar)
		var go := Button.new()
		go.focus_mode = Control.FOCUS_NONE
		go.text = tr("Zur Figur!") if GameState.target_id != event.figure else tr("Ist aktiv")
		go.disabled = GameState.target_id == event.figure
		var fig: String = event.figure
		go.pressed.connect(func() -> void:
			GameState.select_target(fig)
			modal_ref[0].close())
		row.add_child(go)
		content.add_child(row)

	content.add_child(_section_title(tr("Vitrine")))
	var shelf := Label.new()
	shelf.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shelf.custom_minimum_size = Vector2(640, 0)
	shelf.text = tr("Noch leer. Pokale gibt es für Boss-Kämpfe (alle 100.000 Treffer) und Saison-Events.") \
		if GameState.trophies.is_empty() else "🏆 " + " · ".join(GameState.trophies.map(func(t: String) -> String: return tr(t)))
	content.add_child(shelf)
	var next_boss := Label.new()
	next_boss.add_theme_color_override("font_color", MUTED)
	next_boss.text = tr("Nächster Boss in %s Treffern.") % Num.whole(maxf(0.0, GameState.next_boss_at - GameState.total_hits))
	content.add_child(next_boss)
	modal_ref.append(Modal.open(self, tr("Aufträge"), content, [tr("Schließen")], 720.0))


func _section_title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	_comic(l, 22, Color("3bc9db"))
	return l


func _on_event_completed(event: Dictionary) -> void:
	Sfx.play("prestige", 0.0, -2.0)
	Sfx.applause(true)
	if not GameState.reduced_effects:
		Confetti.burst(self, size * Vector2(0.5, 0.3), 100)
	_ticker_override = ""
	Modal.open(self, tr("Event geschafft!"), tr("%s gibt auf!\n\nPokal: %s\n+%d Reue-Token\n\nDie Figur bleibt für immer in deiner Galerie.") % [
		event.name, tr(event.trophy), int(event.reward_marken)], [tr("Hurra!")])


# =====================================================================
# Mini-Spiele
# =====================================================================

func _show_games() -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	var modal_ref: Array = []
	for game in ["dojo", "pie"]:
		var info: Dictionary = GameState.MINIGAMES[game]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := Label.new()
		title.text = tr(info.name)
		title.add_theme_font_size_override("font_size", 20)
		col.add_child(title)
		var desc := Label.new()
		desc.add_theme_font_size_override("font_size", 14)
		desc.add_theme_color_override("font_color", MUTED)
		var today_marken := int(GameState.minigame_rewards_today.get(game, 0))
		desc.text = tr("Rekord: %d Punkte · heute verdient: %d/5 Reue-Token (je %d Punkte einen)") % [
			int(GameState.stat(info.stat)), today_marken, int(info.points_per_marke)]
		col.add_child(desc)
		row.add_child(col)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(180, 0)
		var unlocked := GameState.minigame_unlocked(game)
		b.text = tr("Spielen!") if unlocked else GameState.minigame_unlock_text(game)
		style_primary(b)
		b.disabled = not unlocked
		var which: String = game
		b.pressed.connect(func() -> void:
			modal_ref[0].close()
			MiniGame.open(self, which))
		row.add_child(b)
		content.add_child(row)
	var market_row := HBoxContainer.new()
	market_row.add_theme_constant_override("separation", 12)
	var market_col := VBoxContainer.new()
	market_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var market_title := Label.new()
	market_title.text = tr("Börse für Beulen")
	market_title.add_theme_font_size_override("font_size", 20)
	market_col.add_child(market_title)
	var market_desc := Label.new()
	market_desc.add_theme_font_size_override("font_size", 14)
	market_desc.add_theme_color_override("font_color", MUTED)
	market_desc.text = tr("Pflaster, Eisbeutel, Torten und Gummienten handeln – billig kaufen, teuer verkaufen.")
	market_col.add_child(market_desc)
	market_row.add_child(market_col)
	var market_button := Button.new()
	market_button.focus_mode = Control.FOCUS_NONE
	market_button.custom_minimum_size = Vector2(180, 0)
	market_button.text = tr("Zur Börse!") if GameState.market_unlocked() else tr("Ab 10 Mio. Schmerz-Token")
	style_primary(market_button)
	market_button.disabled = not GameState.market_unlocked()
	market_button.pressed.connect(func() -> void:
		modal_ref[0].close()
		Modal.open(self, tr("Börse für Beulen"), MarketPanel.new(), [tr("Schließen")], 900.0))
	market_row.add_child(market_button)
	content.add_child(market_row)
	modal_ref.append(Modal.open(self, tr("Mini-Spiele"), content, [tr("Schließen")], 680.0))


# =====================================================================
# Foto mit Wasserzeichen
# =====================================================================

func _take_photo() -> void:
	var mark := Label.new()
	mark.text = "Punch your Enemy"
	_comic(mark, 30, Color("ff6fae"))
	mark.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	mark.position = size - Vector2(330, 70)
	add_child(mark)
	toast.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	mark.queue_free()
	var dir := "user://screenshots"
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := "%s/punch_%s.png" % [dir, stamp]
	if img.save_png(path) != OK:
		show_toast(tr("Foto konnte nicht gespeichert werden."))
		return
	GameState.add_stat("screenshots")
	Sfx.play("buy", 0.0, -4.0)
	var m := Modal.open(self, tr("Foto gespeichert!"), tr("Gespeichert als\n%s\n\nDas Foto bleibt auf deinem Rechner – teilen kannst du es, wenn alle Abgebildeten einverstanden sind.") % path.get_file(),
		[tr("Ordner öffnen"), "OK"])
	m.closed.connect(func(index: int) -> void:
		if index == 0:
			OS.shell_open(ProjectSettings.globalize_path(dir)))


# =====================================================================
# Kosmetik-Laden
# =====================================================================

func _show_shop() -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	var modal_ref: Array = []
	var head := Label.new()
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.text = tr("Du hast %d Reue-Token. Gekauftes kannst du jederzeit wechseln.") % GameState.beulen_marken
	content.add_child(head)
	for slot in SHOP_SLOTS:
		content.add_child(_section_title(tr(slot[1])))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		for c in GameState.cosmetic_defs:
			if c.slot == slot[0]:
				flow.add_child(_shop_item(c, modal_ref))
		content.add_child(flow)
	modal_ref.append(Modal.open(self, tr("Kosmetik-Laden"), content, [tr("Schließen")], 940.0))


func _shop_item(c: Dictionary, modal_ref: Array) -> PanelContainer:
	var owned := GameState.has_cosmetic(c.id)
	var equipped := GameState.cosmetic_equipped(c.id)
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(210, 0)
	tile.add_theme_stylebox_override("panel", tile_box("active" if equipped else "normal", 6))
	tile.tooltip_text = String(c.description)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	tile.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	if c.slot == "fist":
		var icon := TextureRect.new()
		var suffix := "" if c.value == "standard" else "_" + String(c.value)
		icon.texture = load("res://assets/cursor/fist_open%s.svg" % suffix)
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		top.add_child(icon)
	var name_label := Label.new()
	name_label.text = c.name
	name_label.add_theme_font_size_override("font_size", 16)
	top.add_child(name_label)
	box.add_child(top)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	var id: String = c.id
	if equipped:
		b.text = tr("Angelegt ✓")
		b.disabled = true
	elif owned:
		b.text = tr("Anlegen")
		b.pressed.connect(func() -> void:
			GameState.apply_cosmetic(id)
			if c.slot == "sound":
				Sfx.play_hit(false)
			modal_ref[0].close()
			_show_shop())
	elif c.get("source", "") == "laurel":
		b.text = tr("Im Lorbeer-Baum")
		b.disabled = true
	else:
		b.text = tr("Kaufen: %d Reue-Token") % int(c.cost)
		b.disabled = GameState.beulen_marken < int(c.cost)
		style_primary(b)
		b.pressed.connect(func() -> void:
			if GameState.buy_cosmetic(id):
				Sfx.play("buy", 0.0, -3.0)
				show_toast(tr("Neu im Schrank: %s") % c.name)
			modal_ref[0].close()
			_show_shop())
	box.add_child(b)
	return tile


# =====================================================================
# Herausforderungen und Zeitlupe
# =====================================================================

func _on_challenge_changed() -> void:
	_refresh()
	var done := GameState.challenges_done
	if GameState.challenge_active == "" and not done.is_empty():
		for c in GameState.challenge_defs:
			if done.has(c.id) and not _celebrated_challenges.has(c.id):
				_celebrated_challenges[c.id] = true
				Sfx.play("prestige", 0.0, -2.0)
				Sfx.applause(true)
				if not GameState.reduced_effects:
					Confetti.burst(self, size * Vector2(0.5, 0.3), 100)
				Modal.open(self, tr("Herausforderung gemeistert!"), tr("„%s“ geschafft!\n%s – ab sofort dauerhaft.") % [
					c.name, laurels_text(int(c.reward_laurels), true)], [tr("Hurra!")])


var _celebrated_challenges: Dictionary = {}


func _update_slow_motion() -> void:
	var slow := false
	for b in GameState.buffs:
		if b.id == "zeitlupe":
			slow = true
	Engine.time_scale = GameState.SLOW_MOTION_SCALE if slow and not GameState.reduced_effects else 1.0


# =====================================================================
# Lautstärke
# =====================================================================

func _show_volume() -> void:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	for entry in [["music_volume", tr("Musik")], ["sfx_volume", tr("Effekte")], ["ambient_volume", tr("Publikum")]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var label := Label.new()
		label.text = entry[1]
		label.custom_minimum_size = Vector2(120, 0)
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = GameState.get(entry[0])
		slider.custom_minimum_size = Vector2(320, 24)
		slider.focus_mode = Control.FOCUS_NONE
		var key: String = entry[0]
		slider.value_changed.connect(func(v: float) -> void:
			GameState.set(key, v)
			Sfx.apply_volumes()
			if key == "sfx_volume":
				Sfx.play_hit(false)
			elif key == "ambient_volume":
				Sfx.applause(false))
		row.add_child(slider)
		content.add_child(row)
	Modal.open(self, tr("Lautstärke"), content, [tr("Fertig")], 520.0).closed.connect(func(_i: int) -> void:
		GameState.save_game())
