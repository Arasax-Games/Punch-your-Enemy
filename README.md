# Punch your Enemy

Ein alberner Slapstick-Clicker: Fäuste statt Kekse, Beulen statt Blut.
Hau auf Generalissimo Bombastus von Größenwahn – oder auf ein eigenes Bild – und kaufe immer absurdere Geräte, die für dich weiterhauen.

Gebaut mit **Godot 4.7** für **Steam** (Windows, macOS, Linux).

## Spielen und Entwickeln

1. [Godot 4.7](https://godotengine.org/download) herunterladen (Standard-Version, nicht .NET).
2. Godot starten → **Importieren** → `project.godot` aus diesem Ordner wählen.
3. **F5** startet das Spiel.

### Steuerung

| Eingabe | Wirkung |
|---|---|
| Klick auf das Bild / Leertaste | Hauen |
| Maus gedrückt halten | Dauerfeuer (nach Upgrade) |
| 1–9 | Gerät kaufen |
| Goldener Schuh / Silberner Pantoffel anklicken | Bonus (Segen, Raserei, Klick-Raserei, Kettenreaktion … oder Pech) |
| Strg+V | Bild aus der Zwischenablage als neues Opfer |
| Bild ins Fenster ziehen | Neues Opfer |

## Stand: Phase 2 (Clicker-Kern)

**Phase 2**
- Alle 12 Geräte, je 3 Geräte-Upgrades, 6 Synergie-Upgrades, globale Upgrades (Wutmilch, Fanclub, Kamerateam …) – insgesamt 54 Upgrades
- 51 Erfolge mit Erfolgs-Seite, Fortschrittsbalken, versteckten Erfolgen und Konfetti
- Goldener Schuh (alle 5–10 min) und Silberner Pantoffel mit Raserei, Klick-Raserei, Segen, Kettenreaktion und Pech-Schuh
- Offline-Fortschritt (50 % für max. 8 h) mit Willkommen-zurück-Bildschirm
- Menü: Speichern, Spielstand als Textcode exportieren/importieren, Neu anfangen
- Balancing per 24-h-Simulation geprüft (`tests/simulate.gd`)

**Phase 1**
- Klicken mit Faust-Cursor, Treffer-Effekte (Farbspritzer, Beulen, Pflaster, Sterne, Comic-Wörter, kritische Treffer mit Wackeln)
- Bild-Import per Dialog, Drag-and-Drop und Zwischenablage (lokal, max. 1024 px)
- 5 Geräte, 10 Upgrades, Kaufmengen ×1/×10/×100/Max, Verkaufen
- Automatisches Speichern alle 30 s und beim Beenden, mit Backup
- Prozedurale Platzhalter-Sounds, Schalter für Ton und reduzierte Effekte

Das komplette Design steht in [`docs/konzept.md`](docs/konzept.md).

## Tests

```bash
godot --headless --path . --script res://tests/run_tests.gd   # Tests
godot --headless --path . --script res://tests/simulate.gd    # Balancing-Simulation (24 h)
```

## Für Steam exportieren

1. In Godot: **Editor → Export-Vorlagen verwalten → Herunterladen und installieren**.
2. **Projekt → Exportieren**: Die Vorlagen für Windows, Linux und macOS sind schon angelegt.
3. Für Steam-Funktionen (Achievements, Cloud, Overlay) später [GodotSteam](https://godotsteam.com/) als GDExtension einbinden.
4. Hochladen über Steamworks (SteamPipe) – dafür brauchst du einen Steamworks-Partner-Account und eine App-ID.

## Mitarbeit (Menschen und KI)

Regeln für Codex, Claude Code und andere Agenten stehen in [`AGENTS.md`](AGENTS.md).
