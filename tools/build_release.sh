#!/usr/bin/env bash
# Baut spielbare Versionen für Windows, Linux und macOS und packt sie nach build/dist/.
#
# Voraussetzungen:
#   - Godot 4.7.x im PATH (oder GODOT=/pfad/zu/godot)
#   - Export-Vorlagen derselben Version (Godot-Editor: Editor → Export-Vorlagen verwalten)
#   - zip, tar
# Aufruf (im Projektordner):  tools/build_release.sh [Version]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
VERSION="${1:-$(grep -oP 'config/version="\K[^"]+' project.godot)}"
OUT="build/dist"

python3 tools/i18n.py --check
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
"$GODOT" --headless --path . --script res://tests/run_tests.gd | tail -1

rm -rf build/windows build/linux build/macos "$OUT"
mkdir -p build/windows build/linux build/macos "$OUT"
"$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/PunchYourEnemy.exe
"$GODOT" --headless --path . --export-release "Linux" build/linux/PunchYourEnemy.x86_64
"$GODOT" --headless --path . --export-release "macOS" build/macos/PunchYourEnemy.zip
"$GODOT" --headless --path . --script res://tools/third_party_licenses.gd

for dir in windows linux; do
	cp build/LICENSES.md assets/fonts/OFL.txt "build/$dir/"
	mv "build/$dir/OFL.txt" "build/$dir/OFL-Poppins.txt"
done
(cd build/windows && zip -q -9 "../../$OUT/PunchYourEnemy-$VERSION-Windows.zip" PunchYourEnemy.exe LICENSES.md OFL-Poppins.txt)
(cd build/linux && chmod +x PunchYourEnemy.x86_64 && tar -czf "../../$OUT/PunchYourEnemy-$VERSION-Linux.tar.gz" PunchYourEnemy.x86_64 LICENSES.md OFL-Poppins.txt)
# macOS: .app aus dem Godot-Export plus Lizenzen
(cd build/macos && rm -rf app && mkdir app && cd app && unzip -q ../PunchYourEnemy.zip && cp ../../LICENSES.md . && cp ../../../assets/fonts/OFL.txt OFL-Poppins.txt \
	&& zip -q -9 -r -y "../../../$OUT/PunchYourEnemy-$VERSION-macOS.zip" .)
ls -la "$OUT"
