# AGENTS.md – Regeln für KI-Agenten (Codex, Claude Code & Co.)

Diese Datei gilt für **alle** Agenten, die an diesem Repo arbeiten. `CLAUDE.md` verweist hierher.

## Projekt

**Punch your Enemy** ist ein alberner Idle-/Clicker im Cookie-Clicker-Stil: Der Spieler haut auf ein Bild (Standard: der fiktive Operetten-Diktator *Generalissimo Bombastus von Größenwahn* oder ein eigenes importiertes Bild) und kauft mit der Währung **Wumms** Slapstick-Geräte.

- Ziel: **Desktop-Spiel für Steam** (Windows, macOS, Linux). **Kein Browserspiel.**
- Engine: **Godot 4.7**, Sprache **GDScript**, Renderer *GL Compatibility*.
- Vollständiges Design: [`docs/konzept.md`](docs/konzept.md). Bei Widersprüchen gilt das Konzept, außer diese Datei sagt etwas anderes.
- Aktueller Stand: **Phase 1 (MVP)** ist umgesetzt. Nächste Phase siehe Roadmap im Konzept, Abschnitt 16.

## Ton und Inhalt (wichtig)

- Alles ist **Comic-Slapstick**: Beulen, Sterne, Farbspritzer, Pflaster, Tortenwürfe. **Kein Blut, keine realistischen Verletzungen.**
- Mitgelieferte Figuren sind **frei erfunden** und dürfen keiner realen Person ähneln (auch keinen realen Politikern oder Diktatoren, keine echten Hoheitszeichen).
- Spieltexte sind **Deutsch**, witzig und harmlos. Englische Übersetzung kommt später über Godot-Übersetzungen.
- Importierte Bilder bleiben **lokal** (`user://images/`), es gibt keinen Upload.

## Struktur

```
project.godot          Projekteinstellungen, Autoloads
scenes/main.tscn       Hauptbildschirm (Drei-Spalten-Layout)
scripts/core/          game_state.gd (Autoload GameState), balance.gd (Formeln), num.gd (Zahlenformat)
scripts/ui/            main.gd (UI-Logik), target_area.gd (Zielbild, Treffer, Cursor, Shake)
scripts/effects/       hit_effects.gd (Spritzer, Beulen, Pflaster, Sterne, Popups)
scripts/audio/         sfx.gd (Autoload Sfx, prozedurale Sounds)
data/                  devices.json, upgrades.json – Balancing ohne Code ändern
assets/                SVG-Grafiken (Figuren, Cursor)
tests/run_tests.gd     Headless-Tests
docs/konzept.md        Design-Dokument
export_presets.cfg     Export für Windows, Linux, macOS
```

## Befehle

```bash
# Projekt importieren (nach neuen Assets nötig)
godot --headless --path . --import

# Tests ausführen – müssen vor jedem Commit grün sein
godot --headless --path . --script res://tests/run_tests.gd

# Spiel kurz headless starten, um Skriptfehler zu finden
godot --headless --path . --quit-after 180

# Export (Export-Templates müssen installiert sein)
godot --headless --path . --export-release "Windows Desktop" build/windows/PunchYourEnemy.exe
```

## Code-Konventionen

- **Statisch typisiertes GDScript** (`var x: int`, `func f() -> void`). Tabs zur Einrückung.
- Bezeichner auf Englisch, Kommentare und Spieltexte auf Deutsch.
- **Datengetrieben:** Neue Geräte/Upgrades/Achievements kommen als Einträge in `data/*.json`, nicht als Code. Neue Upgrade-Wirkungen (`effect.type`) brauchen Logik in `game_state.gd` **und** einen Text in `upgrade_effect_text()`.
- **Formeln** gehören in `balance.gd` (reine, testbare Funktionen). Jede neue Formel bekommt einen Test in `tests/run_tests.gd`.
- Spiellogik läuft über Zeitdifferenz (`delta`), nie über Frames.
- Die UI fragt `GameState` regelmäßig ab; Signale nur für strukturelle Änderungen (Kauf, Bildwechsel).
- **Spielstand:** JSON in `user://savegame.json` mit `version`. Bei Formatänderungen `SAVE_VERSION` erhöhen und `_migrate()` erweitern. Alte Spielstände dürfen nie kaputtgehen.
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
- Phase 2: alle 12 Geräte, Synergien, Achievements, Goldener Schuh, Offline-Fortschritt.
- Steam: GodotSteam (GDExtension) für Achievements, Cloud-Saves und Overlay.
