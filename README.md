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
| 1–5 | Gerät kaufen |
| Strg+V | Bild aus der Zwischenablage als neues Opfer |
| Bild ins Fenster ziehen | Neues Opfer |

## Stand: Phase 1 (MVP)

- Klicken mit Faust-Cursor, Treffer-Effekte (Farbspritzer, Beulen, Pflaster, Sterne, Comic-Wörter, kritische Treffer mit Wackeln)
- Bild-Import per Dialog, Drag-and-Drop und Zwischenablage (lokal, max. 1024 px)
- 5 Geräte, 10 Upgrades, Kaufmengen ×1/×10/×100/Max, Verkaufen
- Automatisches Speichern alle 30 s und beim Beenden, mit Backup
- Prozedurale Platzhalter-Sounds, Schalter für Ton und reduzierte Effekte

Das komplette Design steht in [`docs/konzept.md`](docs/konzept.md).

## Tests

```bash
godot --headless --path . --script res://tests/run_tests.gd
```

## Für Steam exportieren

1. In Godot: **Editor → Export-Vorlagen verwalten → Herunterladen und installieren**.
2. **Projekt → Exportieren**: Die Vorlagen für Windows, Linux und macOS sind schon angelegt.
3. Für Steam-Funktionen (Achievements, Cloud, Overlay) später [GodotSteam](https://godotsteam.com/) als GDExtension einbinden.
4. Hochladen über Steamworks (SteamPipe) – dafür brauchst du einen Steamworks-Partner-Account und eine App-ID.

## Mitarbeit (Menschen und KI)

Regeln für Codex, Claude Code und andere Agenten stehen in [`AGENTS.md`](AGENTS.md).
