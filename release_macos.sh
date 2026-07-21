#!/bin/bash
# Release macOS de tiddl GUI. Correr EN el Mac, desde la carpeta del repo tiddl-gui.
#
#   ./release_macos.sh            # version 1.0.0
#   ./release_macos.sh 1.1.0      # otra version
#
# Requisitos (una sola vez):
#   xcode-select --install                       # toolchain de Apple
#   brew install python ffmpeg cocoapods         # Python 3.10+, ffmpeg, pods
#   pip3 install "git+https://github.com/np3ir/tiddl-elvigilante.git" \
#                pyinstaller "flet[all]==0.86.1" tomlkit
#
# Resultado: dist-mac/tiddl-ElVigilante-<version>-macos.dmg
# Nota Gatekeeper: app sin firmar -> primera apertura con click derecho > Open
# (o: xattr -cr "/Applications/tiddl by ElVigilante.app")

set -euo pipefail
VERSION="${1:-1.0.0}"

echo "[1/4] tiddl binario standalone (PyInstaller)..."
rm -rf cli-build && mkdir cli-build && cd cli-build
cat > entry.py <<'EOF'
"""PyInstaller entry point for the standalone tiddl binary."""

from tiddl.cli.app import main

if __name__ == "__main__":
    main()
EOF
pyinstaller --onefile --console --name tiddl --noconfirm \
    --collect-submodules tiddl --collect-submodules rich._unicode_data entry.py
./dist/tiddl --version
cd ..

echo "[2/4] GUI (flet build macos)..."
yes | flet build macos --project tiddl-gui --product "tiddl by ElVigilante" \
    --company ElVigilante --build-version "$VERSION"

echo "[3/4] Empacando tiddl + ffmpeg dentro del .app..."
APP=$(ls -d build/macos/*.app | head -1)
BINDIR="$APP/Contents/MacOS"
cp cli-build/dist/tiddl "$BINDIR/tiddl"
cp "$(command -v ffmpeg)" "$BINDIR/ffmpeg"
chmod +x "$BINDIR/tiddl" "$BINDIR/ffmpeg"

echo "[4/4] Creando DMG..."
mkdir -p dist-mac
hdiutil create -volname "tiddl by ElVigilante" -srcfolder "$APP" -ov -format UDZO \
    "dist-mac/tiddl-ElVigilante-$VERSION-macos.dmg"

echo ""
echo "RELEASE OK -> dist-mac/tiddl-ElVigilante-$VERSION-macos.dmg"
echo "Subir al release de GitHub:"
echo "  gh release upload v$VERSION dist-mac/tiddl-ElVigilante-$VERSION-macos.dmg"
