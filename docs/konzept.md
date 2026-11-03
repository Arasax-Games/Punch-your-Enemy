# Punch your Enemy – Design-Dokument

Ein alberner Clicker im Cookie-Clicker-Stil: Fäuste statt Kekse, Slapstick statt Gewalt.

> Quelle: `Konzept Punch your Enemy.pdf` (ursprünglicher Arbeitstitel „Watsch den Warlord“).
> Geändert gegenüber der PDF: Der Spielname ist **Punch your Enemy**. Das Spiel wird nicht als Browserspiel, sondern als **Desktop-Spiel mit Godot 4 für Steam** gebaut (siehe Abschnitt 15).

## 1. Überblick

- **Genre:** Idle-/Incremental-Clicker (Desktop/Steam, später optional mobil)
- **Ton:** Komplett albern, cartoonhaft, überdreht. Niemand wird verletzt, alles ist Comic-Slapstick (Beulen, Sternchen, Farbspritzer, Pflaster, Tortenwürfe).
- **Kernidee:** Der Spieler klickt auf ein frei importierbares Bild und verpasst ihm Comic-Treffer. Mit der Währung kauft er immer absurdere Slapstick-Geräte, die automatisch weiterhauen, auch wenn er nicht da ist.
- **Standardfigur:** Generalissimo Bombastus von Größenwahn – ein fiktiver, völlig überzeichneter Operetten-Diktator mit riesiger Mütze, übertriebenem Schnurrbart und zu vielen Orden. Ein Comic-Bösewicht, keine reale Person.
- **Zielgruppe:** Gelegenheitsspieler, Idle-Fans, Streamer (die eigene Bilder von Freunden, Haustieren oder Memes importieren).
- **Plattform:** Desktop (Windows, macOS, Linux) über Steam, speichert lokal.

### Das Versprechen an den Spieler

1. **Sofortiger Spaß:** Klick, Wumms, Zahl wird größer.
2. **Persönlich:** Das eigene Bild macht jede Runde einzigartig.
3. **Immer ein nächstes Ziel:** Das nächste Gerät, Upgrade oder Achievement ist immer knapp in Reichweite.

## 2. Kern-Spielschleife

1. Spieler klickt auf das Zielbild und erhält **Wumms** (Hauptwährung).
2. Mit Wumms kauft er **Geräte**, die pro Sekunde automatisch Wumms erzeugen (**WPS**).
3. Mit Wumms kauft er **Upgrades**, die Klicks und Geräte verstärken.
4. Zufällige Events (**der Goldene Schuh**) belohnen Aufmerksamkeit.
5. Nach genug Fortschritt kann der Spieler einen **Neuanfang (Prestige)** machen, erhält dauerhafte Boni und fängt stärker neu an.

### Währungen

| Währung | Rolle |
|---|---|
| Wumms | Hauptwährung, wird ständig ausgegeben |
| Lorbeeren | Prestige-Währung, bleibt dauerhaft |
| Beulen-Marken | Seltene Währung aus Mini-Spielen und Events, für kosmetische Freischaltungen |

## 3. Steuerung und Eingabe

- **Mauszeiger:** Standardmäßig eine Cartoon-Faust. Beim Klick wechselt sie auf „Faust ausgeholt“ und danach „Faust zugeschlagen“ (2–3 Frames).
- **Klick auf das Bild:** Erzeugt Treffer-Effekt, Zahl-Popup und Sound.
- **Gedrückt halten:** Als Upgrade freischaltbar („Dauerfeuer“, automatische Klicks bis zu 10 pro Sekunde).
- **Touch:** Tippen statt Klicken, Multi-Touch zählt mehrere Treffer.
- **Tastatur:** Leertaste = Klick (Barrierefreiheit), Zahlen 1–9 = Schnellkauf der ersten Geräte.

## 4. Das Zielbild

### 4.1 Bild-Import

- Button „Neues Opfer wählen“ öffnet einen Datei-Dialog (PNG, JPG, WEBP).
- Per Drag-and-Drop ins Spielfenster oder per Einfügen aus der Zwischenablage (Strg+V).
- Bild wird nur lokal verarbeitet, nie hochgeladen.
- Automatische Skalierung auf max. 1024 px Kantenlänge, Mittelpunkt-Zentrierung.
- Optionaler Ausschnitt-Editor: Zuschneiden, Rund-Maske, Zoom.
- Mehrere Bilder in einer Galerie speichern, mit Namen versehen und jederzeit wechseln.
- Zu jedem Bild wird ein eigener Zähler („Insgesamt verhauen: …“) geführt.
- Hinweis im Import-Dialog: „Nimm Bilder, bei denen alle Beteiligten Spaß verstehen.“ Eine Meldefunktion entfällt, da alles lokal bleibt.

### 4.2 Standardfiguren (mitgeliefert, alle fiktiv)

| Figur | Beschreibung |
|---|---|
| Generalissimo Bombastus | Operetten-Diktator, Standard |
| Dr. Doomsday Dieter | Superschurke mit Katze, zu großem Labor und zu kleinem Budget |
| Baron von Blamage | Aufgeblasener Adliger mit Monokel |
| Sir Fiesling der Dritte | Schurke aus einem Stummfilm |

Jede Figur hat 3 Mimik-Zustände (gelassen, genervt, am Ende), die mit dem Beulen-Level wechseln.

### 4.3 Treffer-Effekte (statt Blut)

Bei jedem Klick am Klickpunkt:

- Farbspritzer in Bonbonfarben (Pink, Gelb, Türkis), die langsam verblassen.
- Beulen wachsen als Overlay-Sprites an der getroffenen Stelle.
- Pflaster, Sterne, Vögelchen kreisen kurz um das Bild.
- Comic-Wörter („WUMMS!“, „KLATSCH!“, „AUA-UA!“) poppen kurz auf.
- Tortenflecken, Schlammspritzer, Eiswürfel bei bestimmten Geräten.
- Kritische Treffer: Screen-Shake, Zeitlupe (100 ms), großer Schriftzug.
- Effekte sammeln sich bis zu einem Limit (z. B. 60 Overlay-Sprites), danach verblassen die ältesten.
- Reinigungs-Button „Duschen“ setzt die Optik zurück, ohne den Fortschritt zu verlieren.

### 4.4 Beulen-Level (visuelle Progression)

Alle 1.000 Treffer pro Bild steigt das Beulen-Level (max. 10). Jedes Level schaltet Overlays frei: Veilchen, schiefe Mütze, zerzauste Frisur, wackelnder Schnurrbart, rauchende Ohren.

## 5. Geräte (Produktionsgebäude)

Kosten = Basiskosten × 1,15^Anzahl (aufgerundet). Verkaufen erstattet 25 %.

| # | Gerät | Basiskosten | Basis-WPS | Beschreibung |
|---|---|---|---|---|
| 1 | Faust | 15 | 0,1 | Der Klassiker. Haut einfach mal drauf. |
| 2 | Pantoffel | 100 | 1 | Oma-Schlappen mit viel Schwung. |
| 3 | Gummihammer | 1.100 | 8 | Quietscht bei jedem Treffer. |
| 4 | Boxhandschuh-Katapult | 12.000 | 47 | Feder, Hebel, Handschuh. |
| 5 | Tortenwurf-Kanone | 130.000 | 260 | Sahne in Überschallgeschwindigkeit. |
| 6 | Abrissbirne (aus Schaumstoff) | 1,4 Mio. | 1.400 | Groß, weich, beeindruckend. |
| 7 | Ohrfeigen-Fließband | 20 Mio. | 7.800 | 400 mechanische Hände im Takt. |
| 8 | Amboss-Regen-Anlage | 330 Mio. | 44.000 | Acme lässt grüßen. |
| 9 | Boxroboter Mk. I | 5,1 Mrd. | 260.000 | Gelenkig, humorlos, effektiv. |
| 10 | Mond-Katapult | 75 Mrd. | 1,6 Mio. | Der Mond holt aus. |
| 11 | Zeitreise-Backpfeife | 1 Bio. | 10 Mio. | Haut gestern, heute und morgen gleichzeitig. |
| 12 | Die Universelle Backpfeife | 14 Bio. | 65 Mio. | Eine Ohrfeige, die durch das Multiversum hallt. |

Erweiterungsideen: Kitzel-Armee, Clown-Gewerkschaft, Klavier-Schleuder, Schwarzes-Loch-Kissenschlacht.

**Geräte-Mechanik**

- Meilensteine bei 1, 5, 25, 50, 100, 150, 200 Stück: neue Optik, neue Animation.
- Kauf-Menge: Umschalter x1 / x10 / x100 / Max.
- Tooltip: Beitrag pro Gerät, Gesamtanteil in Prozent, Zeit bis zur Amortisation.
- Visualisierung: Unterhalb des Bildes laufen die Geräte als kleine animierte Reihen.

## 6. Upgrades

### 6.1 Klick-Upgrades

| Name | Wirkung | Kosten |
|---|---|---|
| Boxhandschuh-Training | Klick-Wert ×2 | 100 |
| Stahlkappenhandschuh | Klick-Wert ×2 | 500 |
| Karate-Kurs (Volkshochschule) | Klick-Wert ×2 | 10.000 |
| Klick = 1 % deiner WPS | Klick-Bonus aus Produktion | 100.000 |
| Klick = 5 % deiner WPS | dito | 10 Mio. |
| Dauerfeuer | Gedrückt halten schlägt 10×/s | 50.000 |
| Kritische Treffer | 5 % Chance auf ×10 | 25.000 |

### 6.2 Geräte-Upgrades

Für jedes Gerät drei Upgrades bei 1, 10 und 25 Stück: Verdopplung der Produktion dieses Geräts. Beispiel Pantoffel: Flauschfutter, Stahlkappen-Pantoffel, Pantoffel mit Raketenantrieb.

### 6.3 Synergie-Upgrades

Geräte stärken sich gegenseitig, z. B. „Je 10 Pantoffel erhöhen die Faust um +1 %.“

### 6.4 Globale Upgrades

- **Fanclub:** +5 % WPS pro 10 Achievements.
- **Milchtüte der Wut („Wutmilch“):** WPS steigt mit der Zahl der Achievements.
- **Sponsorenvertrag:** WPS +10 %.
- **Kamerateam:** Goldene Schuhe erscheinen 20 % häufiger.

### 6.5 Freischalt-Logik

Upgrades erscheinen, sobald der Spieler 50 % des Preises besitzt oder die Voraussetzung erfüllt hat. In der Upgrade-Leiste nach Preis sortiert, bezahlbare hell hervorgehoben.

## 7. Zusatzsysteme

### 7.1 Der Goldene Schuh (Zufallsevent)

Erscheint alle 5–10 Minuten irgendwo auf dem Bildschirm, bleibt 13 Sekunden. Mögliche Effekte beim Klick:

- **Wumms-Segen:** Sofort 15 Minuten WPS (max. 15 % des Guthabens).
- **Raserei:** WPS ×7 für 77 s.
- **Klick-Raserei:** Klick-Wert ×777 für 13 s.
- **Kettenreaktion:** Mehrere Goldene Schuhe folgen nacheinander.
- **Pech-Schuh (selten):** Halbierte WPS für 66 s, mit Gegenleistung (Beulen-Marken).
- **Zeitlupe-Special:** Alles läuft 10 s langsamer, Effekte besonders hübsch.

Zusätzlich gibt es den **Silbernen Pantoffel** als häufigeres, schwächeres Event.

### 7.2 Combo-System

Schnelle Klicks bauen einen Combo-Zähler auf (0–100). Je höher, desto größer die Effekte und der Klick-Bonus (bis ×2). Nach 2 s Pause fällt der Combo wieder ab.

### 7.3 Wut-Anzeige (Rage-Mode)

Eine Leiste füllt sich mit Klicks. Voll → 10 s Wutmodus: Bildschirm färbt sich rot, Musik beschleunigt, alle Treffer ×3, aber Goldene Schuhe erscheinen nicht.

### 7.4 Aufträge und Tagesbonus

- **Tagesauftrag:** „Verhaue 5.000 Mal“, „Kaufe 10 Faust-Stufen“. Belohnung: Beulen-Marken.
- **Login-Serie:** Täglicher Bonus, steigend bis Tag 7.
- **Wochenevent:** Spezialfigur, z. B. „Halloween-Hexe“ oder „Weihnachtsmuffel“.

### 7.5 Mini-Spiele (freischaltbar)

1. **Reaktions-Dojo:** Bewegliche Ziele auf dem Bild treffen, belohnt Beulen-Marken.
2. **Tortenwurf-Schießbude:** Zielschießen mit Tortenkanone, Highscore lokal.
3. **Börse für Beulen:** Kleiner Handelsmarkt mit schwankenden Preisen.

### 7.6 Rivalen-Boss

Alle 100.000 Treffer erscheint ein Boss-Kampf: Die Figur bekommt eine Lebensleiste und wehrt sich mit harmlosen Gimmicks (Wegducken, Schild aus Pappe, Gummiente). Der Spieler klickt gezielt auf Schwachstellen. Belohnung: einzigartige Dekoration und Beulen-Marken.

### 7.7 Sammlungen und Kosmetik

- **Faust-Skins:** Boxhandschuh, Gummihandschuh, Schaumstoff-Hand, goldene Faust, Pfote, Brathähnchenkeule.
- **Hintergründe:** Arena, Wohnzimmer, Weltraum, Zirkuszelt.
- **Sound-Packs:** Comic, Retro-Arcade, Kampfsport.
- **Titel:** „Backpfeifen-Beauftragter“, „Meister der Ohrfeige“.

## 8. Achievements

Etwa 80 Achievements in Kategorien, jedes mit +0,5 % Wutmilch-Bonus und einem witzigen Text. Benachrichtigung als Toast oben rechts mit Sound; eigene Seite mit Fortschrittsbalken und Rarität. Auf Steam zusätzlich als Steam-Achievements.

| Kategorie | Beispiele |
|---|---|
| Klicks | „Erstes Aua“ (1), „Zappelphilipp“ (1.000), „Sehnenscheidenentzündung“ (100.000) |
| Geräte | „Pantoffel-Armee“ (100 Pantoffel), „Mond-Manager“ |
| Produktion | „Wumms-Millionär“, „Wumms-Billionär“ |
| Zeit | „Nachtschicht“ (spielen zwischen 2 und 4 Uhr), „Ein Jahr Backpfeife“ |
| Versteckte | „Pazifist“ (10 Minuten nichts klicken), „Wieder zuhause“ (Rückkehr nach 24 h) |
| Bild-Import | „Fotograf“ (erstes eigenes Bild), „Sammler“ (10 Bilder) |
| Events | „Goldener Finger“ (50 Goldene Schuhe), „Raserei-Reiter“ |

## 9. Prestige: Der Neuanfang

Ab 10 Milliarden insgesamt erzeugtem Wumms freigeschaltet (früher 1 Billion – nach Spielertests gesenkt, damit der erste Neuanfang nach einigen Stunden kommt). Der Spieler setzt Fortschritt zurück und erhält Lorbeeren.

**Formel:** Lorbeeren = floor(∛(Gesamt-Wumms ÷ 10 Milliarden))

Jede Lorbeere gibt dauerhaft +1 % WPS und +1 % Klickwert.

**Lorbeer-Baum:**

- **Handwerk:** Geräte günstiger, Startgeräte nach Reset.
- **Glück:** Goldene Schuhe häufiger und länger.
- **Komfort:** Offline-Fortschritt besser, automatischer Kauf.
- **Show:** Neue Effekte, Skins, Sounds.

**Umsetzungsentscheidung:** Der Zweig „Show“ wird mit **Beulen-Marken** bezahlt, die anderen drei mit Lorbeeren. Beulen-Marken gibt es für jeden Erfolg, jedes Beulen-Level und den Pech-Schuh. So haben die Marken früh einen Nutzen, und der Lorbeer-Baum ist nach einer Woche etwa zur Hälfte gefüllt (geprüft mit `tests/simulate.gd -- --days 7`).

Nach dem ersten Neuanfang: optionaler „Zeitraffer“-Modus (Spiel läuft 2× schneller). Herausforderungen (nur Klicks, keine Upgrades) belohnen Extra-Lorbeeren.

## 10. Idle- und Offline-Mechanik

- Offline-Fortschritt: 50 % der WPS für maximal 8 Stunden (per Lorbeer-Baum auf 100 % und 48 h steigerbar).
- Willkommen-zurück-Bildschirm: „Während du weg warst, haben deine Geräte X Wumms erwirtschaftet.“
- Automatisches Speichern alle 30 s, manuelles Speichern, Export/Import als Textcode (Base64). Auf Steam zusätzlich Steam Cloud.

## 11. Balancing

### 11.1 Formeln

- Gerätekosten: `kosten(n) = ceil(basis × 1.15^n)`
- Produktion: `WPS = Σ(basis_wps_i × anzahl_i × upgrade_mult_i) × global_mult × (1 + lorbeeren × 0.01)`
- Klickwert: `klick = (1 + upgrades_add) × klick_mult × combo_mult + wps × prozent_upgrade`
- Achievement-Bonus: +0,5 % pro Achievement auf WPS (Wutmilch)
- Goldener-Schuh-Intervall: `zufall(300, 600) s ÷ glück_mult`
- Boss-Leben: `100 × 2^(boss_nr)` Klick-Äquivalente

### 11.2 Tempo-Zielwerte

| Zeitpunkt | Erwartung |
|---|---|
| 1. Minute | 15 Wumms, erste Faust gekauft |
| 10. Minute | Erste 3 Geräte-Typen, erste Upgrades |
| 1. Stunde | Gerät 5–6, erstes Goldener-Schuh-Highlight |
| 1. Tag | Gerät 9–10, Prestige in Sichtweite |
| 1. Woche | 2–4 Neuanfänge, Lorbeer-Baum halb |

### 11.3 Große Zahlen

Anzeige in Kurzform (1,23 Mio. / 4,56 Mrd.), ab 1e15 wissenschaftliche Notation. Godot-`float` (64 Bit) reicht bis ca. 1e308; für spätere Phasen ggf. eine BigNumber-Klasse (Mantisse + Exponent).

## 12. Benutzeroberfläche

Drei-Spalten-Layout (Desktop):

| Links | Mitte | Rechts |
|---|---|---|
| Statistik: Wumms, WPS, Lorbeeren, Combo, Wut-Leiste | Zielbild mit Treffer-Effekten, darunter animierte Geräte-Reihen | Shop: Reiter Geräte und Upgrades, Menge-Umschalter |

- **Kopfleiste:** Spielname, Bildwechsel, Galerie, Einstellungen, Achievements, Statistik, Info.
- **Unten:** Nachrichten-Ticker mit lustigen Sprüchen („Nachbarn beschweren sich über Quietschen“, „Der Mond sagt, er sei bereit“).
- **Barrierefreiheit:** Schalter für reduzierte Effekte (kein Blitzen/Shaken), hohe Kontraste, Tastaturbedienung, skalierbare Schrift, farbenblind-freundliche Palette.

## 13. Audio und Effekte

- **Treffer-Sounds:** 8–12 Variationen pro Gerät, zufällig, leichter Pitch-Shift. Stil: Cartoon-Quietschen, Boing, Klatsch, Kazoo.
- **Musik:** Fünf entspannte, chillige Titel (Lo-Fi, Bossa nova, Jazz-Lounge, Strand-Chill, Ambient), die sich abwechseln; jeder wächst mit dem Fortschritt um Instrumentenschichten. Im Wutmodus schneller. (Früher: schräge Ragtime-Schleife – nach Spielertests durch ruhigere Musik ersetzt.)
- **Ambient:** Publikumsgelächter und Applaus bei Meilensteinen.
- **Mixer:** Getrennte Regler für Musik, Effekte, Ambient. Stummschalter.
- **Juice:** Screen-Shake, Hitstop (2 Frames), Partikel, Zahl-Popups mit Skalierung, Konfetti beim Achievement, Zeitlupe bei kritischen Treffern.

## 14. Grafikstil

Buntes 2D-Cartoon, dicke Outlines, übertriebene Squash-and-Stretch-Animationen. Palette aus Bonbonfarben mit warmem Hintergrund. Assets als Sprites/Spritesheets, Partikel über Godot-Partikelsysteme oder eigene Zeichenroutinen.

## 15. Technische Umsetzung (Godot 4 / Steam)

- **Engine:** Godot 4.7, Sprache GDScript (statisch typisiert).
- **Rendering:** Godot 2D (Control-UI + Node2D/CanvasItem für Effekte).
- **Zahlen:** `float` im MVP, später BigNumber-Klasse.
- **Audio:** Godot AudioStreamPlayer, Busse für Musik/Effekte/Ambient.
- **Speichern:** JSON in `user://`, Bilder als PNG in `user://images/`. Später Steam Cloud.
- **Steam:** GodotSteam (GDExtension) für Achievements, Cloud-Saves, Overlay. Export für Windows, macOS, Linux.
- **Daten:** Geräte, Upgrades und Achievements als JSON in `data/`, damit sich Balancing ohne Code ändern lässt.

### Architektur

```
/scenes     – Szenen (.tscn)
/scripts
  /core     – GameState (Autoload), Formeln, Speichern, Zahlenformat
  /ui       – Hauptbildschirm, Shop, Statistik, Dialoge
  /effects  – Treffer-Effekte, Popups, Cursor
  /audio    – Sound-Manager
/data       – devices.json, upgrades.json (später achievements.json)
/assets     – Grafiken, Sounds, Schriften
/tests      – Headless-Tests für Formeln
```

### Wichtige Punkte

- **Tick-Loop:** Logik über Zeitdifferenz (`delta`), nicht über Frames. Offline-Fortschritt über gespeicherten Zeitstempel.
- **Bild-Import:** Godot `FileDialog` (nativ) + `Image.load()`, Drag-and-Drop über `Window.files_dropped`, Zwischenablage über `DisplayServer.clipboard_get_image()`. Bild wird auf max. 1024 px verkleinert und nach `user://images/` kopiert.
- **Custom-Cursor:** `Input.set_custom_mouse_cursor()` mit Faust-Frames.
- **Performance:** Obergrenze für Overlays, Effekte bei Bedarf reduzieren.
- **Anti-Datenverlust:** Versionsnummer im Spielstand, Migrationsfunktionen, Backup des letzten Spielstands.
- **Tests:** Headless-Tests für Formeln und Prestige; Simulations-Skript, das einen Spieler 24 h durchspielt.

## 16. Entwicklungs-Roadmap

- **Phase 1 – MVP:** Klicken, Faust-Cursor, Treffer-Effekte, Bild-Import, 5 Geräte, 10 Upgrades, Speichern.
- **Phase 2 – Clicker-Kern:** Alle 12 Geräte, Synergien, Achievements, Goldener Schuh, Offline-Fortschritt, Sound/Musik.
- **Phase 3 – Tiefe:** Prestige und Lorbeer-Baum, Combo, Wutmodus, Beulen-Level, Galerie.
- **Phase 4 – Steam & Langzeit:** GodotSteam-Integration (Achievements, Cloud), Boss-Kämpfe, Mini-Spiele, Tagesaufträge, Wochenevents, Skins, Screenshot-Teilen mit Wasserzeichen.

## 17. Was Spieler überzeugt

1. Eigenes Bild = emotionale Bindung und Streamer-Tauglichkeit.
2. Sofortiges, saftiges Feedback bei jedem Klick (Sound, Partikel, Shake).
3. Klare Ziele auf jeder Zeitebene: Sekunden (nächster Kauf), Minuten (Goldener Schuh), Stunden (Meilenstein), Tage (Prestige).
4. Humor überall: Ticker, Gerätetexte, Achievements.
5. Respekt vor der Zeit des Spielers: Offline-Fortschritt, keine Bezahlschranken, keine Werbung.
6. Zugänglichkeit: Effekte abschaltbar, Tastatur, Touch.
