#!/usr/bin/env python3
"""Erzeugt die Erfolgsbilder für Steamworks (64×64 PNG, farbig und grau für "gesperrt").

Aufruf: python3 tools/achievement_icons.py
Braucht: rsvg-convert (librsvg) und Pillow. Ausgabe: steam/achievements/<API-NAME>.png und <API-NAME>_locked.png
Der Ordner steam/ hat eine .gdignore – Godot importiert ihn nicht, er landet nicht im Spiel.
"""
import json, os, subprocess, tempfile
from PIL import Image, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "steam", "achievements")
INK = "#2b2118"

GLYPHS = {
 "fist": '<rect x="22" y="36" width="18" height="16" rx="4" fill="#e03131"/><path d="M16 24 C16 18 21 16 24 16 L42 16 C48 16 50 21 50 26 L50 33 C50 39 45 41 40 41 L23 41 C18 41 16 38 16 33 Z" fill="#f6c39b"/><path d="M25 16 L25 27 M33 16 L33 27 M41 16 L41 27" fill="none" stroke-width="2"/>',
 "coin": '<circle cx="32" cy="32" r="17" fill="#fcc419"/><circle cx="32" cy="32" r="12" fill="none" stroke="#e67700" stroke-width="2"/><path d="M24 26 L28 39 L32 30 L36 39 L40 26" fill="none" stroke-width="3"/>',
 "gear": '<circle cx="32" cy="32" r="14" fill="#74c0fc"/><circle cx="32" cy="32" r="5" fill="#ffffff"/><path d="M32 14 L32 20 M32 44 L32 50 M14 32 L20 32 M44 32 L50 32 M19 19 L23 23 M41 41 L45 45 M45 19 L41 23 M19 45 L23 41" stroke-width="5"/>',
 "arrow": '<path d="M32 14 L48 32 L38 32 L38 50 L26 50 L26 32 L16 32 Z" fill="#69db7c"/>',
 "star": '<path d="M32 12 L37 26 L52 26 L40 35 L45 50 L32 41 L19 50 L24 35 L12 26 L27 26 Z" fill="#ffd43b"/>',
 "shoe": '<path d="M18 16 L34 16 L35 36 C44 37 52 40 52 46 C52 49 50 50 46 50 L16 50 C14 50 13 48 14 45 L17 34 Z" fill="#fcc419"/>',
 "bolt": '<path d="M36 12 L18 36 L30 36 L26 52 L46 26 L34 26 Z" fill="#ff922b"/>',
 "camera": '<rect x="14" y="22" width="36" height="26" rx="5" fill="#adb5bd"/><rect x="24" y="16" width="14" height="8" rx="2" fill="#adb5bd"/><circle cx="32" cy="35" r="8" fill="#ffffff"/><circle cx="32" cy="35" r="4" fill="#4dabf7"/>',
 "clock": '<circle cx="32" cy="33" r="17" fill="#ffffff"/><path d="M32 33 L32 22 M32 33 L40 37" stroke-width="3"/>',
 "moon": '<path d="M40 14 C26 16 20 30 24 40 C28 50 42 52 48 46 C36 46 28 36 32 26 C34 20 38 16 40 14 Z" fill="#ffe066"/>',
 "heart": '<path d="M32 48 C14 36 14 22 24 20 C29 19 32 24 32 24 C32 24 35 19 40 20 C50 22 50 36 32 48 Z" fill="#ff8787"/>',
 "drop": '<path d="M32 12 C40 26 46 32 46 39 C46 47 40 52 32 52 C24 52 18 47 18 39 C18 32 24 26 32 12 Z" fill="#74c0fc"/>',
 "tag": '<path d="M16 16 L34 16 L50 32 L34 48 L16 30 Z" fill="#ffa94d"/><circle cx="24" cy="24" r="3" fill="#ffffff"/>',
 "hat": '<path d="M14 36 C14 22 50 22 50 36 Z" fill="#4263eb"/><rect x="14" y="34" width="36" height="7" fill="#e03131"/><path d="M12 42 C24 48 40 48 52 42" fill="none" stroke-width="4"/>',
 "laurel": '<path d="M32 50 C18 46 14 34 18 22 M32 50 C46 46 50 34 46 22" fill="none" stroke="#2f9e44" stroke-width="4"/><ellipse cx="18" cy="30" rx="4" ry="7" fill="#69db7c"/><ellipse cx="22" cy="40" rx="4" ry="7" fill="#69db7c"/><ellipse cx="46" cy="30" rx="4" ry="7" fill="#69db7c"/><ellipse cx="42" cy="40" rx="4" ry="7" fill="#69db7c"/>',
 "flame": '<path d="M32 12 C36 22 46 26 46 38 C46 46 40 52 32 52 C24 52 18 46 18 38 C18 30 24 28 26 20 C28 26 30 28 32 28 C34 22 32 16 32 12 Z" fill="#ff6b6b"/>',
 "bump": '<circle cx="32" cy="36" r="16" fill="#f59f9f"/><circle cx="26" cy="30" r="5" fill="#ffffff"/>',
 "pencil": '<path d="M16 48 L20 36 L42 14 L50 22 L28 44 Z" fill="#ffd43b"/><path d="M16 48 L20 36 L28 44 Z" fill="#f6c39b"/>',
 "crown": '<path d="M14 46 L14 22 L24 32 L32 16 L40 32 L50 22 L50 46 Z" fill="#fcc419"/>',
 "check": '<rect x="16" y="14" width="32" height="38" rx="4" fill="#ffffff"/><path d="M22 26 L26 30 L34 22 M22 40 L26 44 L34 36" fill="none" stroke="#2f9e44" stroke-width="3"/>',
 "target": '<circle cx="32" cy="32" r="18" fill="#ff6b6b"/><circle cx="32" cy="32" r="11" fill="#ffffff"/><circle cx="32" cy="32" r="5" fill="#ff6b6b"/>',
 "pumpkin": '<ellipse cx="32" cy="36" rx="18" ry="14" fill="#ff922b"/><path d="M32 22 L34 14" stroke-width="4"/><path d="M24 34 l4 -4 l4 4 Z M34 34 l4 -4 l4 4 Z M24 42 Q32 48 40 42" fill="#2b2118" stroke-width="2"/>',
 "trophy": '<path d="M22 14 L42 14 L40 32 C38 38 26 38 24 32 Z" fill="#fcc419"/><rect x="29" y="36" width="6" height="8" fill="#fcc419"/><rect x="22" y="44" width="20" height="6" rx="2" fill="#c0895a"/>',
 "chart": '<path d="M14 50 L50 50" stroke-width="3"/><path d="M16 44 L26 32 L34 38 L48 18" fill="none" stroke="#2f9e44" stroke-width="4"/>',
 "glove": '<path d="M16 30 C16 16 30 12 40 16 C50 20 50 34 44 40 L24 42 C18 42 16 36 16 30 Z" fill="#e03131"/><rect x="22" y="42" width="20" height="10" rx="3" fill="#ffffff"/>',
 "masks": '<circle cx="24" cy="30" r="12" fill="#ffe066"/><circle cx="40" cy="34" r="12" fill="#b197fc"/><path d="M19 32 Q24 36 29 32 M35 38 Q40 34 45 38" fill="none" stroke-width="2"/>',
}

CATEGORY = {
 "hits": ("fist", "#ffd8a8"), "total_wumms": ("coin", "#fff3bf"), "wps": ("coin", "#ffe066"),
 "device": ("gear", "#d0ebff"), "devices_total": ("gear", "#a5d8ff"), "device_types": ("gear", "#74c0fc"),
 "upgrades": ("arrow", "#d3f9d8"), "target_hits": ("hat", "#dbe4ff"), "idle": ("heart", "#ffe3e3"),
 "night": ("moon", "#364fc7"), "laurels": ("laurel", "#ebfbee"), "laurel_nodes": ("laurel", "#d3f9d8"),
 "bump_level": ("bump", "#ffe3e3"), "figures_hit": ("masks", "#f3f0ff"),
}
STATS = {
 "crits": ("star", "#fff9db"), "golden_shoes": ("shoe", "#fff3bf"), "silver_slippers": ("shoe", "#f1f3f5"),
 "frenzies": ("bolt", "#fff4e6"), "bad_luck": ("bolt", "#e9ecef"), "images_imported": ("camera", "#e7f5ff"),
 "play_time": ("clock", "#e3fafc"), "showers": ("drop", "#d0ebff"), "devices_sold": ("tag", "#fff4e6"),
 "long_return": ("heart", "#fff0f6"), "prestiges": ("laurel", "#ebfbee"), "rages": ("flame", "#ffe3e3"),
 "max_combo": ("flame", "#fff4e6"), "renames": ("pencil", "#fff9db"), "bosses_defeated": ("crown", "#fff3bf"),
 "quests_done": ("check", "#ebfbee"), "best_streak": ("check", "#e6fcf5"), "dojo_best": ("target", "#fff5f5"),
 "pie_best": ("target", "#f8f0fc"), "events_done": ("pumpkin", "#fff4e6"), "screenshots": ("camera", "#f1f3f5"),
 "challenges_done": ("trophy", "#fff9db"), "market_wins": ("chart", "#ebfbee"), "cosmetics_bought": ("glove", "#fff5f5"),
}


def icon_for(cond):
    if cond["type"] == "stat":
        return STATS.get(cond["stat"], ("star", "#f1f3f5"))
    return CATEGORY.get(cond["type"], ("star", "#f1f3f5"))


def main():
    os.makedirs(OUT, exist_ok=True)
    achievements = json.load(open(os.path.join(ROOT, "data", "achievements.json"), encoding="utf-8"))
    with tempfile.TemporaryDirectory() as tmp:
        for a in achievements:
            glyph, bg = icon_for(a["condition"])
            svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <rect x="2" y="2" width="60" height="60" rx="12" fill="{bg}" stroke="{INK}" stroke-width="3"/>
  <g stroke="{INK}" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round">{GLYPHS[glyph]}</g>
</svg>'''
            src = os.path.join(tmp, "icon.svg")
            open(src, "w").write(svg)
            name = a["id"].upper()
            color = os.path.join(OUT, name + ".png")
            subprocess.run(["rsvg-convert", "-w", "64", "-h", "64", src, "-o", color], check=True)
            img = Image.open(color).convert("RGBA")
            gray = ImageOps.grayscale(img).convert("RGBA")
            gray.putalpha(img.getchannel("A"))
            Image.blend(gray, Image.new("RGBA", gray.size, (255, 255, 255, 255)), 0.35).save(os.path.join(OUT, name + "_locked.png"))
    print("%d Erfolgsbilder (farbig + gesperrt) in steam/achievements/ geschrieben." % len(achievements))


if __name__ == "__main__":
    main()
