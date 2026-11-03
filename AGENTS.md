# AGENTS.md – Regeln für KI-Agenten (Codex, Claude Code & Co.)

Diese Datei gilt für **alle** Agenten, die an diesem Repo arbeiten. `CLAUDE.md` verweist hierher.

## Projekt

**Punch your Enemy** ist ein alberner Idle-/Clicker im Cookie-Clicker-Stil: Der Spieler haut auf ein Bild (Standard: der fiktive Operetten-Diktator *Generalissimo Bombastus von Größenwahn* oder ein eigenes importiertes Bild) und kauft mit der Währung **Wumms** Slapstick-Geräte.

- Ziel: **Desktop-Spiel für Steam** (Windows, macOS, Linux). **Kein Browserspiel.**
- Engine: **Godot 4.7**, Sprache **GDScript**, Renderer *GL Compatibility*.
- Vollständiges Design: [`docs/konzept.md`](docs/konzept.md). Bei Widersprüchen gilt das Konzept, außer diese Datei sagt etwas anderes.
- Aktueller Stand: **Phasen 1–7** sind umgesetzt (MVP, Clicker-Kern, Tiefe, Steam & Langzeit, Inhalt & Feinschliff, Englisch, Präsentation: Schrift, Musik, Geräte-Reihe, Zuschneiden, Steam-Extras). Das Spiel ist zweisprachig: Deutsch (Quellsprache) und Englisch. Offene Punkte stehen unten; Steam-Veröffentlichung: [`docs/steam.md`](docs/steam.md).

## Ton und Inhalt (wichtig)

- Alles ist **Comic-Slapstick**: Beulen, Sterne, Farbspritzer, Pflaster, Tortenwürfe. **Kein Blut, keine realistischen Verletzungen.**
- Mitgelieferte Figuren sind **frei erfunden** und dürfen keiner realen Person ähneln (auch keinen realen Politikern oder Diktatoren, keine echten Hoheitszeichen).
- Spieltexte werden auf **Deutsch** geschrieben (witzig und harmlos) und ins **Englische** übersetzt (`locale/en.po`). Englische Begriffe: Wumms → *Whams*, Beulen-Marken → *Bump Tokens*, Lorbeeren → *laurels*, Neuanfang → *Fresh Start*, Geräte → *gadgets*, Opfer → *target*.
- Importierte Bilder bleiben **lokal** (`user://images/`), es gibt keinen Upload.

## Struktur

```
project.godot          Projekteinstellungen, Autoloads
scenes/main.tscn       Hauptbildschirm (Bühne mit Zähler, Opfer und Leisten; Shop mit Reitern Geräte/Upgrades)
scripts/core/          game_state.gd (Autoload GameState: Wumms, Geräte, Upgrades, Erfolge, Buffs,
                       Goldener Schuh, Combo, Wutmodus, Neuanfang, Lorbeer-Baum, Galerie, Boss-Kämpfe,
                       Tagesaufträge, Login-Serie, Saison-Events, Mini-Spiel-Belohnungen, Offline,
                       Speichern), balance.gd (Formeln), num.gd (Zahlenformat),
                       steam_service.gd (Autoload SteamService, optional über GodotSteam)
scripts/ui/            main.gd (UI-Logik), target_area.gd (Zielbild, Treffer, Cursor, Shake),
                       shoe.gd (Goldener Schuh/Silberner Pantoffel), modal.gd (Dialoge im Spielstil),
                       background.gd (Hintergründe Standard/Zirkus/Weltraum), boss_fight.gd (Boss-Overlay
                       mit Schwachstelle und Gimmicks), minigame.gd (Reaktions-Dojo, Tortenwurf-Schießbude),
                       market_panel.gd (Börse für Beulen), device_strip.gd (animierte Geräte-Reihe mit
                       Meilenstein-Rahmen), crop_editor.gd (Ausschnitt beim Bild-Import)
scripts/effects/       hit_effects.gd (Spritzer, Beulen, Pflaster, Sterne, Popups), confetti.gd,
                       bump_overlay.gd (dauerhafte Beulen-Level-Optik)
scripts/audio/         sfx.gd (Autoload Sfx: prozedurale Effekte, Audio-Busse Music/SFX/Ambient, Applaus),
                       music.gd (Autoload Music: Ragtime-Schleife in Schichten, im Wutmodus schneller)
data/                  devices.json, upgrades.json, achievements.json, laurels.json (Lorbeer-Baum),
                       figures.json (Figuren inkl. Event-Figuren, Mimik-Stufen, Anker-Punkte),
                       bosses.json, quests.json (Tagesaufträge), events.json (Saison-Events),
                       cosmetics.json (Faust-Skins, Hintergründe, Sounds), challenges.json, market.json
assets/                SVG-Grafiken (Figuren inkl. 3 Mimik-Stufen, Cursor/Faust-Skins, Events, devices/ = Geräte-
                       Symbole), fonts/ (Poppins, OFL; optional heading.ttf), audio/ (optional echte Dateien)
steam/                 Nur für Steamworks, nicht im Spiel (.gdignore): achievements/ = Erfolgsbilder 64×64
tests/run_tests.gd     Headless-Tests
tests/simulate.gd      Balancing-Simulation: 24 h (ca. 1 min), mit `-- --days 7` eine Woche mit
                       Neuanfängen (ca. 4 min), mit `-- --challenge <id>` eine Herausforderung
tools/                 Hilfsskripte (z. B. steam_achievements.gd → docs/steam_achievements.csv)
locale/en.po           Englische Übersetzung (msgid = deutscher Text), gepflegt mit tools/i18n.py
docs/konzept.md        Design-Dokument
docs/design/           Design-Vorlage (Styleguide): README.md + Bilder aus dem Spiel (tools/design_shots.gd)
docs/steam.md          Anleitung: Steamworks, GodotSteam, Erfolge, Steam Cloud, Upload
export_presets.cfg     Export für Windows, Linux, macOS
```

## Befehle

```bash
# Projekt importieren (nach neuen Assets nötig)
godot --headless --path . --import

# Tests ausführen – müssen vor jedem Commit grün sein
godot --headless --path . --script res://tests/run_tests.gd

# Balancing prüfen – nach jeder Änderung an data/*.json oder Formeln
godot --headless --path . --script res://tests/simulate.gd
godot --headless --path . --script res://tests/simulate.gd -- --days 7   # inkl. Neuanfänge

# Erfolgsliste für Steamworks neu erzeugen – nach jeder Änderung an data/achievements.json
godot --headless --path . --script res://tools/steam_achievements.gd

# Übersetzungen: neue Texte einsammeln (dann in locale/en.po übersetzen) und prüfen
python3 tools/i18n.py
python3 tools/i18n.py --check      # muss vor jedem Commit ohne Fehler durchlaufen

# Steam-Dateien neu erzeugen (Erfolgsbilder brauchen rsvg-convert + Pillow)
python3 tools/achievement_icons.py
godot --headless --path . --script res://tools/steam_rich_presence.gd

# Spiel kurz headless starten, um Skriptfehler zu finden
godot --headless --path . --quit-after 180

# Spielbare Versionen für Windows, Linux, macOS bauen und nach build/dist/ packen
# (Export-Vorlagen müssen installiert sein; prüft vorher Übersetzungen und Tests)
GODOT=/pfad/zu/godot tools/build_release.sh
# Ergebnisse landen im Repo Arasax-Games/punch-my-enemy-ausfuehrbar (Ordner downloads/ + README)
```

## Code-Konventionen

- **Statisch typisiertes GDScript** (`var x: int`, `func f() -> void`). Tabs zur Einrückung.
- Bezeichner auf Englisch, Kommentare und Spieltexte auf Deutsch.
- **Datengetrieben:** Neue Geräte/Upgrades/Achievements kommen als Einträge in `data/*.json`, nicht als Code. Neue Upgrade-Wirkungen (`effect.type`) brauchen Logik in `game_state.gd` **und** einen Text in `upgrade_effect_text()`. Neue Erfolgs-Bedingungen (`condition.type`) brauchen einen Zweig in `condition_progress()`.
- Upgrade-Wirkungen: `click_mult`, `device_mult`, `wps_mult`, `click_wps`, `crit`, `autofire`, `synergy`, `achievement_wps` (Wutmilch), `fanclub`, `golden_luck`.
- Upgrade-Voraussetzungen (`requires`): `device`+`count`, `devices` (Dict), `upgrade`, `total_wumms`, `achievements`, `golden_shoes`.
- Neue Statistiken für Erfolge: Schlüssel in `STAT_KEYS` ergänzen und mit `GameState.add_stat()` hochzählen.
- Erfolgs-Bedingungen: `hits`, `total_wumms` (über alle Durchläufe), `wps`, `device`, `devices_total`, `device_types`, `upgrades`, `stat`, `target_hits`, `idle`, `night`, `laurels`, `laurel_nodes`, `bump_level`.
- Lorbeer-Baum-Wirkungen (`data/laurels.json`): `device_cost`, `start_devices`, `golden_luck`, `shoe_lifetime`, `buff_duration`, `crit_chance`, `offline_rate`, `offline_cap`, `offline_full`, `autofire`, `autobuy_upgrades`, `cosmetic`. Lorbeer-Wirkungen werden über `_laurel_effects()` gelesen, Upgrade-Wirkungen über `_owned_effects()`. Knoten mit `"currency": "marken"` kosten Beulen-Marken statt Lorbeeren (Zweig „Show“).
- `total_wumms` gilt für den aktuellen Durchlauf, `lifetime_wumms` über alle Neuanfänge (Basis für Lorbeeren und Erfolge).
- Tests und Simulationen setzen `persist = false`, damit sie nie den echten Spielstand überschreiben. Datumsabhängiges (Aufträge, Login-Serie, Events, Mini-Spiel-Tageslimit) testet man über `_today_override = "JJJJ-MM-TT"`.
- Tagesauftrags-Metriken (`quests.json` → `metric`): `hits` oder ein beliebiger Schlüssel aus `STAT_KEYS`. Fortschritt = Wert jetzt − Wert bei Tagesbeginn.
- Saison-Events (`events.json`): Zeitraum als `MM-TT`, Figur muss in `figures.json` existieren. Event-Figuren bleiben nach einem geschafften Event dauerhaft in der Galerie.
- Kosmetik (`cosmetics.json`): `slot` (`fist`/`background`/`sound`), `value`, `source` (`default`, `laurel` = über den Lorbeer-Baum, `shop` = für Beulen-Marken mit `cost`). Ein neuer Faust-Skin braucht `assets/cursor/fist_open_<value>.svg` und `fist_hit_<value>.svg`, ein neuer Hintergrund einen Zweig in `background.gd`, ein Sound-Pack ein Präfix in `Sfx.PACK_PREFIX`.
- Herausforderungen (`challenges.json`): Regeln `no_devices`, `no_upgrades`, `device_cost_mult`. Belohnung landet in `laurels_total` **und** `laurels_extra` – Extra-Lorbeeren zählen nicht für die Neuanfang-Formel. Neuanfang und Herausforderungs-Start nutzen gemeinsam `_reset_run()`.
- Börse: Preise = Sekunden Produktion × höchste WPS dieses Durchlaufs × Kursfaktor (0,3–3, Schritt jede Minute). Beim Neuanfang schließt die Börse (Bestand weg).
- Zeitlupe: `Engine.time_scale` wird in der Oberfläche gesetzt; `GameState._process` rechnet mit Echtzeit (`delta / Engine.time_scale`), damit Produktion und Timer nicht langsamer werden.
- **Übersetzung:** Jeder Anzeigetext im Code steht in `tr("…")` (in statischen Funktionen `TranslationServer.translate("…")`). Texte in Konstanten bekommen darüber einen Kommentar `# i18n` und werden bei der Anzeige mit `tr()` übersetzt. Datenfelder `name`, `description`, `text`, `intro` übersetzt `GameState._localize_data()` beim Laden; Pokalnamen erst bei der Anzeige (sie stehen im Spielstand). Mehrzahl nie mit angehängten Endungen bauen (`"Lorbeer%s"`), sondern ganze Sätze übersetzen (Beispiel: `laurels_text()` in `main.gd`). Zahlen immer über `Num` – das Format hängt von der Sprache ab. Ersatzsprache ist Deutsch (`locale/fallback="de"`), sonst sähen deutsche Spieler Englisch. Sprachwechsel lädt die Hauptszene neu.
- **Audio:** Effekte immer über `Sfx.play()`, Publikum über `Sfx.applause()`. Busse `Music`, `SFX`, `Ambient` (Lautstärke in `GameState.music_volume` usw., angewendet mit `Sfx.apply_volumes()`). Echte Aufnahmen ersetzen die Platzhalter ohne Code-Änderung: `assets/audio/sfx/<sound>[_n].ogg|wav` und `assets/audio/music/loop.ogg`. Musik wird nur außerhalb von `headless` erzeugt.
- **Schrift:** Text Poppins Medium, Überschriften `main.gd.heading_font()` (Poppins Bold oder `assets/fonts/heading.ttf`).
- **Farben:** Der Hauptbildschirm ist eine dunkle „Comic-Arena bei Nacht“ – Farben nur über die Paletten-Konstanten in `main.gd` (`PANEL`, `CARD`, `TEXT`, `MUTED`, `GOLD` = kaufen/leistbar, `RAGE` = Wut/Krit). Dialoge (`Modal`) und Mini-Spiele nutzen das helle `main.gd.paper_theme()`. Alle Gestaltungsregeln: [`docs/design/README.md`](docs/design/README.md) – bei sichtbaren Änderungen die Bilder mit `godot --path . --script res://tools/design_shots.gd` neu erzeugen.
- Neue Geräte brauchen ein Symbol `assets/devices/<id>.svg` (in `devices.json` als `icon`).
- Steam: Nur über `SteamService` (keine direkten `Steam`-Aufrufe anderswo). Steam-API-Name eines Erfolgs = ID in Großbuchstaben. Importierte Bilder und Fotos dürfen **nie** in die Steam Cloud.
- Klassen, die Autoloads (`GameState`, `Sfx`) benutzen, nicht direkt aus `--script`-Testskripten referenzieren, sondern zur Laufzeit mit `load()` holen (die Autoloads existieren beim Kompilieren des Testskripts noch nicht).
- **Formeln** gehören in `balance.gd` (reine, testbare Funktionen). Jede neue Formel bekommt einen Test in `tests/run_tests.gd`.
- Spiellogik läuft über Zeitdifferenz (`delta`), nie über Frames.
- Die UI fragt `GameState` regelmäßig ab; Signale nur für strukturelle Änderungen (Kauf, Bildwechsel).
- Die Versionsnummer steht in `project.godot` (`config/version`) **und** in `export_presets.cfg` (Windows `file_version`/`product_version`, macOS `short_version`/`version`) – bei einem neuen Build alle anpassen. macOS wird nur ad-hoc signiert (keine Apple-Notarisierung); dafür muss `import_etc2_astc` an bleiben.
- **Spielstand:** JSON in `user://savegame.json` mit `version` (aktuell 5). `user://` ist ein eigener Ordner `PunchYourEnemy` (für Steam Cloud); im Godot-Editor speichert das Spiel stattdessen in `user://dev/` (Spielstand + Bilder), damit Test-Spielstände nie im fertigen Spiel auftauchen. Jeder Spielstand trägt `channel` (`dev`/`release`); das fertige Spiel legt fremde Spielstände (ohne `channel: release`) beim Start als `old-dev-savegame.json` beiseite und beginnt frisch. Pfade nur über `GameState.save_path`/`image_dir`, nie fest verdrahten. Bei Formatänderungen `SAVE_VERSION` erhöhen und `_migrate()` erweitern. Alte Spielstände dürfen nie kaputtgehen – jede Migration bekommt einen Test.
- Buffs, Schuh-Timer, `idle_time`, Combo, Wut-Leiste und ein laufender Boss-Kampf sind Laufzeitzustand und werden bewusst nicht gespeichert.
- Dialoge immer über `Modal.open()`, nicht über Godots `AcceptDialog` (passt sonst nicht zum Stil).
- Effekte respektieren `GameState.reduced_effects` (Barrierefreiheit).
- Große Zahlen: im MVP `float`. Anzeige immer über `Num.fmt()` / `Num.whole()`.

## Zusammenarbeit mehrerer Agenten

- Arbeite auf einem **eigenen Branch** und öffne einen Pull Request; nicht direkt auf `main` pushen (Ausnahme: ausdrücklicher Auftrag).
- Kleine, thematisch getrennte Commits mit aussagekräftiger Nachricht (Deutsch oder Englisch).
- `.godot/` und Export-Ergebnisse (`build/`) werden nie committet. `*.import`-Dateien **werden** committet.
- Bevor du größere Systeme anfängst (z. B. Prestige, Steam-Integration), prüfe offene PRs/Branches, damit nicht zwei Agenten dasselbe bauen.

## Offene Punkte / To-dos

- Eine echte Comic-Schrift als `assets/fonts/heading.ttf` (z. B. Bangers, OFL) – konnte in der Entwicklungsumgebung nicht heruntergeladen werden.
- Echte Soundeffekte und eingespielte Musik (z. B. CC0 von Kenney.nl) in `assets/audio/` ablegen.
- Weitere Sprachen: `LANGS` in `tools/i18n.py` und `GameState.LANGUAGES` ergänzen, `locale/<sprache>.po` übersetzen, in `project.godot` eintragen.
- Steam: Bestenlisten `DOJO_BEST`, `PIE_BEST`, `LAURELS` in Steamworks anlegen; Rich-Presence-Dateien hochladen (siehe docs/steam.md). Ungetestet ohne echten Steam-Client.
