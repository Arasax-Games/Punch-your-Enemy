# AGENTS.md – Regeln für KI-Agenten (Codex, Claude Code & Co.)

Diese Datei gilt für **alle** Agenten, die an diesem Repo arbeiten. `CLAUDE.md` verweist hierher.

## Projekt

**Punch your Enemy** ist ein alberner Idle-/Clicker im Cookie-Clicker-Stil: Der Spieler haut auf ein Bild (Standard: der fiktive Operetten-Diktator *Generalissimo Bombastus von Größenwahn* oder ein eigenes importiertes Bild) und kauft mit der Währung **Wumms** Slapstick-Geräte.

- Ziel: **Desktop-Spiel für Steam** (Windows, macOS, Linux). **Kein Browserspiel.**
- Engine: **Godot 4.7**, Sprache **GDScript**, Renderer *GL Compatibility*.
- Vollständiges Design: [`docs/konzept.md`](docs/konzept.md). Bei Widersprüchen gilt das Konzept, außer diese Datei sagt etwas anderes.
- Aktueller Stand: **Phasen 1–4** sind umgesetzt (MVP, Clicker-Kern, Tiefe, Steam & Langzeit: Steam-Anbindung, Boss-Kämpfe, Tagesaufträge, Login-Serie, Saison-Events, Mini-Spiele, Fotos). Offene Punkte stehen unten; Steam-Veröffentlichung: [`docs/steam.md`](docs/steam.md).

## Ton und Inhalt (wichtig)

- Alles ist **Comic-Slapstick**: Beulen, Sterne, Farbspritzer, Pflaster, Tortenwürfe. **Kein Blut, keine realistischen Verletzungen.**
- Mitgelieferte Figuren sind **frei erfunden** und dürfen keiner realen Person ähneln (auch keinen realen Politikern oder Diktatoren, keine echten Hoheitszeichen).
- Spieltexte sind **Deutsch**, witzig und harmlos. Englische Übersetzung kommt später über Godot-Übersetzungen.
- Importierte Bilder bleiben **lokal** (`user://images/`), es gibt keinen Upload.

## Struktur

```
project.godot          Projekteinstellungen, Autoloads
scenes/main.tscn       Hauptbildschirm (Drei-Spalten-Layout)
scripts/core/          game_state.gd (Autoload GameState: Wumms, Geräte, Upgrades, Erfolge, Buffs,
                       Goldener Schuh, Combo, Wutmodus, Neuanfang, Lorbeer-Baum, Galerie, Boss-Kämpfe,
                       Tagesaufträge, Login-Serie, Saison-Events, Mini-Spiel-Belohnungen, Offline,
                       Speichern), balance.gd (Formeln), num.gd (Zahlenformat),
                       steam_service.gd (Autoload SteamService, optional über GodotSteam)
scripts/ui/            main.gd (UI-Logik), target_area.gd (Zielbild, Treffer, Cursor, Shake),
                       shoe.gd (Goldener Schuh/Silberner Pantoffel), modal.gd (Dialoge im Spielstil),
                       background.gd (Hintergründe Standard/Zirkus/Weltraum), boss_fight.gd (Boss-Overlay
                       mit Schwachstelle und Gimmicks), minigame.gd (Reaktions-Dojo, Tortenwurf-Schießbude)
scripts/effects/       hit_effects.gd (Spritzer, Beulen, Pflaster, Sterne, Popups), confetti.gd,
                       bump_overlay.gd (dauerhafte Beulen-Level-Optik)
scripts/audio/         sfx.gd (Autoload Sfx, prozedurale Sounds)
data/                  devices.json, upgrades.json, achievements.json, laurels.json (Lorbeer-Baum),
                       figures.json (Figuren inkl. Event-Figuren, Mimik-Stufen, Anker-Punkte),
                       bosses.json, quests.json (Tagesaufträge), events.json (Saison-Events)
assets/                SVG-Grafiken (Figuren inkl. 3 Mimik-Stufen, Cursor inkl. goldene Faust, Events)
tests/run_tests.gd     Headless-Tests
tests/simulate.gd      Balancing-Simulation: 24 h (ca. 1 min) oder mit `-- --days 7` eine Woche mit
                       Neuanfängen (ca. 4 min)
tools/                 Hilfsskripte (z. B. steam_achievements.gd → docs/steam_achievements.csv)
docs/konzept.md        Design-Dokument
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

# Spiel kurz headless starten, um Skriptfehler zu finden
godot --headless --path . --quit-after 180

# Export (Export-Templates müssen installiert sein)
godot --headless --path . --export-release "Windows Desktop" build/windows/PunchYourEnemy.exe
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
- Steam: Nur über `SteamService` (keine direkten `Steam`-Aufrufe anderswo). Steam-API-Name eines Erfolgs = ID in Großbuchstaben. Importierte Bilder und Fotos dürfen **nie** in die Steam Cloud.
- Klassen, die Autoloads (`GameState`, `Sfx`) benutzen, nicht direkt aus `--script`-Testskripten referenzieren, sondern zur Laufzeit mit `load()` holen (die Autoloads existieren beim Kompilieren des Testskripts noch nicht).
- **Formeln** gehören in `balance.gd` (reine, testbare Funktionen). Jede neue Formel bekommt einen Test in `tests/run_tests.gd`.
- Spiellogik läuft über Zeitdifferenz (`delta`), nie über Frames.
- Die UI fragt `GameState` regelmäßig ab; Signale nur für strukturelle Änderungen (Kauf, Bildwechsel).
- **Spielstand:** JSON in `user://savegame.json` mit `version` (aktuell 4). `user://` ist ein eigener Ordner `PunchYourEnemy` (für Steam Cloud); alte Spielstände aus dem Godot-Standardordner werden beim Start einmalig kopiert. Bei Formatänderungen `SAVE_VERSION` erhöhen und `_migrate()` erweitern. Alte Spielstände dürfen nie kaputtgehen – jede Migration bekommt einen Test.
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

- Eigene Comic-Schrift (OFL-Lizenz, z. B. „Bangers“ für Überschriften, „Nunito“ für Text) in `assets/fonts/` einbinden; aktuell wird eine Systemschrift genutzt.
- Echte Soundeffekte und Musik statt der prozeduralen Platzhalter in `sfx.gd`.
- Phase 2 offen: animierte Geräte-Reihen unter dem Bild, Geräte-Meilenstein-Optik (1, 5, 25, …), Zeitlupe-Special beim Goldenen Schuh, Musik.
- Phase 3 offen: Herausforderungen (Läufe mit Einschränkungen für Extra-Lorbeeren), Ausschnitt-Editor beim Bild-Import, weitere Standardfiguren (Dr. Doomsday Dieter, Baron von Blamage, Sir Fiesling – Figuren-Daten in `data/figures.json` anlegen), Sound-Pack „Kampfsport“, weitere Faust-Skins.
- Phase 4 offen: Mini-Spiel „Börse für Beulen“, Steam-Bestenlisten (nur nicht-bildbezogene Werte), Rich Presence, Kosmetik-Laden für Beulen-Marken (weitere Faust-Skins, Sound-Pack „Kampfsport“), Englische Übersetzung, Erfolgs-Bilder für Steam (64×64).
