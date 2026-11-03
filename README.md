# Punch your Enemy

Ein alberner Slapstick-Clicker: Fäuste statt Kekse, Beulen statt Blut.
Hau auf Generalissimo Bombastus von Größenwahn – oder auf ein eigenes Bild – und kaufe immer absurdere Geräte, die für dich weiterhauen.

Gebaut mit **Godot 4.7** für **Steam** (Windows, macOS, Linux).

## Fertige Spielversionen

Spielbare Versionen für Windows, macOS und Linux (ohne Godot) gibt es im Repo
**[punch-my-enemy-ausfuehrbar](https://github.com/Arasax-Games/punch-my-enemy-ausfuehrbar)**.
Neu bauen: `tools/build_release.sh` (braucht Godot 4.7 und die Export-Vorlagen).

## Spielen und Entwickeln

1. [Godot 4.7](https://godotengine.org/download) herunterladen (Standard-Version, nicht .NET).
2. Godot starten → **Importieren** → `project.godot` aus diesem Ordner wählen.
3. **F5** startet das Spiel.

### Steuerung

| Eingabe | Wirkung |
|---|---|
| Klick auf das Bild / Leertaste | Hauen |
| Maus gedrückt halten | Dauerfeuer (nach Upgrade) |
| R | Wutmodus entfesseln (wenn die Wut-Leiste voll ist) |
| 1–9 | Gerät kaufen |
| Goldener Schuh / Silberner Pantoffel anklicken | Bonus (Segen, Raserei, Klick-Raserei, Kettenreaktion … oder Pech) |
| Strg+V | Bild aus der Zwischenablage als neues Opfer |
| Bild ins Fenster ziehen | Neues Opfer |

## Stand: Phase 7 (Präsentation)

**Phase 7**
- **Schrift Poppins** fest eingebaut (OFL); eine eigene Comic-Schrift für Überschriften als `assets/fonts/heading.ttf` ablegen
- **Musik:** Ragtime-Schleife, die mit dem Fortschritt um Instrumente wächst (Schlagzeug → Bass → Klavier → Klarinette → Bläser) und im Wutmodus schneller wird
- **Lautstärke** getrennt für Musik, Effekte und Publikum (Menü → Lautstärke), Applaus bei Erfolgen und großen Momenten, mehr Treffer-Varianten
- **Echte Sounds und Musik** einfach als Dateien ablegen: `assets/audio/sfx/punch_1.ogg` …, `assets/audio/music/loop.ogg`
- **Animierte Geräte-Reihe** unter dem Bild mit Meilenstein-Rahmen (1, 5, 25, 50, 100, 150, 200 Stück: Holz bis Regenbogen) und Sternchen im Shop
- **Ausschnitt wählen** beim Bild-Import: verschieben, zoomen, Original/Quadrat/Rund
- **Steam:** Bestenlisten (Mini-Spiele, Lorbeeren), Rich Presence, 152 Erfolgsbilder in `steam/achievements/`

## Phase 6 (Englisch)

Das Spiel ist **zweisprachig: Deutsch und Englisch** (Menü → „Sprache / Language“; Standard ist die Systemsprache). Zahlen werden passend formatiert (1.234 / 1,23 Mio. bzw. 1,234 / 1.23 M).

**Phase 6**
- Alle 692 Texte übersetzt (Oberfläche, Geräte, Upgrades, Erfolge, Lorbeer-Baum, Aufträge, Events …) in `locale/en.po`
- `tools/i18n.py` sammelt neue Texte ein und prüft auf fehlende Übersetzungen
- Steam-Erfolgsliste (`docs/steam_achievements.csv`) jetzt mit deutschen und englischen Namen

**Phase 5**
- **Drei neue Standardfiguren** mit je 3 Mimik-Stufen: Dr. Doomsday Dieter (mit Katze), Baron von Blamage (mit Monokel) und Sir Fiesling der Dritte (Stummfilm-Schurke in Schwarz-Weiß)
- **Kosmetik-Laden** für Beulen-Marken: Faust-Skins (Gummihandschuh, Boxhandschuh, Schaumstoff-Hand, Pfote, Brathähnchenkeule), Hintergründe Wohnzimmer und Arena, Sound-Pack Kampfsport – alles jederzeit wechselbar
- **Herausforderungen** nach dem ersten Neuanfang: „Nur Fäuste“, „Ohne Upgrades“, „Inflation“ – bringen Extra-Lorbeeren
- **Börse für Beulen**: Pflaster, Eisbeutel, Sahnetorten und Gummienten billig kaufen, teuer verkaufen
- **Zeitlupe** als neuer Effekt des Goldenen Schuhs

**Phase 4**
- **Boss-Kämpfe** alle 100.000 Treffer: Lebensleiste, 30 Sekunden, wandernde Schwachstelle (×5) und harmlose Gimmicks (Wegducken, Pappschild, Gummiente). Belohnung: Pokal und Beulen-Marken
- **Tagesaufträge** (3 pro Tag) und **Login-Serie** (Tag 1–7, steigende Belohnung)
- **Saison-Events** mit eigener Figur: Halloween-Hexe Hildegard (24.10.–7.11.) und Weihnachtsmuffel Gustav (1.–26.12.)
- **Mini-Spiele**: Reaktions-Dojo und Tortenwurf-Schießbude (bis zu 5 Beulen-Marken pro Spiel und Tag)
- **Vitrine** für Pokale, **Foto speichern** mit Wasserzeichen (bleibt lokal)
- **Steam vorbereitet**: Erfolge werden über GodotSteam gemeldet, Spielstand für Steam Cloud – Anleitung in [`docs/steam.md`](docs/steam.md)

**Phase 3**
- **Neuanfang (Prestige)** ab 1 Billion Wumms: Lorbeeren = ∛(Wumms ÷ 1 Billion), je Lorbeer +1 % auf alles
- **Lorbeer-Baum** mit 4 Zweigen: Handwerk (Rabatte, Startgeräte), Glück (Schuhe, Krits), Komfort (Offline, Dauerfeuer, Autokauf) und Show (goldene Faust, Hintergründe, Retro-Sounds, Konfetti – bezahlt mit Beulen-Marken)
- **Combo** (bis ×2 Klick-Wert) und **Wutmodus** (Leiste füllen, mit R entfesseln: 10 s alles ×3, keine Goldenen Schuhe)
- **Beulen-Level** 1–10 pro Opfer (alle 1.000 Treffer): Pflaster, Veilchen, Kopfverband, rauchende Ohren, Vögelchen – Bombastus wird ab Level 4 genervt und ab Level 8 ist er am Ende
- **Galerie**: Opfer wechseln, umbenennen, löschen
- **Zeitraffer** nach dem ersten Neuanfang (Menü)
- Ton- und Effekt-Einstellungen sind ins Menü gewandert

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

Wie das Spiel aussieht (Farben, Schrift, Komponenten, Bilder): **[`docs/design/`](docs/design/README.md)**.

## Tests

```bash
godot --headless --path . --script res://tests/run_tests.gd   # Tests
godot --headless --path . --script res://tests/simulate.gd    # Balancing-Simulation (24 h)
godot --headless --path . --script res://tests/simulate.gd -- --days 7   # eine Woche mit Neuanfängen
```

## Für Steam exportieren

Schritt-für-Schritt-Anleitung (Steamworks, GodotSteam, Erfolge, Steam Cloud, Upload): **[`docs/steam.md`](docs/steam.md)**.

## Mitarbeit (Menschen und KI)

Regeln für Codex, Claude Code und andere Agenten stehen in [`AGENTS.md`](AGENTS.md).
