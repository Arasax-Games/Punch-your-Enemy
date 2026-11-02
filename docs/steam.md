# Punch your Enemy auf Steam veröffentlichen

Das Spiel ist für Steam vorbereitet. Die Steam-Anbindung (`scripts/core/steam_service.gd`) ist **optional**: Ohne das Plugin GodotSteam läuft das Spiel ganz normal, nur ohne Steam-Erfolge.

## 1. Steamworks-Konto und App-ID

1. Bei [Steamworks](https://partner.steamgames.com/) als Partner registrieren (einmalige App-Gebühr pro Spiel).
2. Eine neue App anlegen. Du bekommst eine **App-ID** (eine Zahl).
3. In Godot unter **Projekt → Projekteinstellungen → Steam → App ID** die Zahl eintragen (`steam/app_id` in `project.godot`).
   Bis dahin steht dort `480` – das ist Valves offizielle Test-App „Spacewar“, damit kann man die Anbindung schon ausprobieren.

## 2. GodotSteam installieren

1. In Godot: **AssetLib** öffnen, nach **GodotSteam GDExtension** suchen, die zur Godot-Version passende Ausgabe (4.x) installieren.
   Alternativ von [godotsteam.com](https://godotsteam.com/) herunterladen und den Ordner `addons/godotsteam` ins Projekt kopieren.
2. Godot neu starten. Danach gibt es das Singleton `Steam`, und `SteamService` meldet sich automatisch an.
3. Zum Testen muss der **Steam-Client laufen** und du musst angemeldet sein.

> Die Plugin-Dateien (Binärdateien) bitte **nicht** von Hand ändern. Ob sie ins Repo committet werden, ist Geschmackssache – sie sind groß; ein kurzer Hinweis im README reicht oft.

## 3. Erfolge in Steamworks anlegen

Die Erfolge des Spiels stehen in `data/achievements.json`. Für Steamworks gibt es eine fertige Liste:

```bash
godot --headless --path . --script res://tools/steam_achievements.gd
```

Das schreibt `docs/steam_achievements.csv` (API-Name; Anzeigename; Beschreibung; versteckt). In Steamworks unter **Stats & Achievements** jeden Erfolg mit genau diesem **API-Namen** anlegen (Großbuchstaben, z. B. `ERSTES_AUA`), Bilder hochladen (je 64×64 px, farbig und grau) und veröffentlichen.

Das Spiel meldet Erfolge sofort beim Freischalten und beim Start noch einmal alle bereits verdienten (falls jemand vorher ohne Steam gespielt hat).

## 4. Steam Cloud (Spielstände)

Kein Code nötig – **Auto-Cloud** in Steamworks einrichten (**Steam Cloud → Auto-Cloud Configuration**):

| Betriebssystem | Root | Unterordner | Muster |
|---|---|---|---|
| Windows | `WinAppDataRoaming` | `PunchYourEnemy` | `savegame*.json` |
| macOS | `MacAppSupport` | `PunchYourEnemy` | `savegame*.json` |
| Linux | `LinuxXdgDataHome` | `PunchYourEnemy` | `savegame*.json` |

Der Ordner `PunchYourEnemy` kommt aus `project.godot` (`application/config/custom_user_dir_name`).

> **Wichtig:** Nur die Spielstände synchronisieren, **nicht** den Ordner `images/` oder `screenshots/`. Importierte Bilder bleiben laut Konzept immer lokal auf dem Rechner der Spielerin bzw. des Spielers.

Ältere Testversionen haben im Standard-Ordner von Godot gespeichert (`…/Godot/app_userdata/Punch your Enemy`). Beim ersten Start werden Spielstand und Bilder automatisch in den neuen Ordner kopiert.

## 5. Exportieren und hochladen

1. In Godot **Editor → Export-Vorlagen verwalten** → passende Vorlagen installieren.
2. **Projekt → Exportieren** → Windows, Linux und macOS exportieren (Vorlagen sind angelegt, Ausgabe nach `build/…`).
   Beim Export mit GodotSteam die zum Betriebssystem passenden Steam-Bibliotheken mitliefern (macht das GDExtension-Plugin automatisch, bitte im Export-Ordner prüfen).
3. Mit dem **Steamworks SDK** (`tools/ContentBuilder`) die Builds per SteamPipe hochladen und im Steamworks-Backend auf einen Branch setzen.

## 6. Vor dem Release prüfen

- [ ] `steam/app_id` auf die echte App-ID gesetzt (nicht 480)
- [ ] Alle Erfolge aus `docs/steam_achievements.csv` in Steamworks angelegt und veröffentlicht
- [ ] Auto-Cloud nur für `savegame*.json`
- [ ] Store-Seite: Hinweis, dass importierte Bilder lokal bleiben und man nur Bilder nimmt, bei denen alle Beteiligten Spaß verstehen
- [ ] Altersfreigabe-Fragebogen in Steamworks ausgefüllt (Comic-Slapstick, keine realistische Gewalt)

## Noch nicht umgesetzt

- Bestenlisten (Steam Leaderboards) – laut Konzept nur für nicht-bildbezogene Werte, z. B. Rekorde in den Mini-Spielen.
- Rich Presence („Haut gerade auf Bombastus“).
