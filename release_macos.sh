#!/bin/bash
# Release macOS de tiddl GUI. Correr EN el Mac, desde la carpeta del repo tiddl-gui.
#
#   ./release_macos.sh            # version 1.0.0
#   ./release_macos.sh 1.1.0      # otra version
#
# Requisitos (una sola vez):
#   1. Xcode completo (App Store) y aceptar licencia:
#        sudo xcodebuild -license accept
#   2. Homebrew (si no lo tienes: https://brew.sh) y luego:
#        brew install python ffmpeg cocoapods
#   3. Entorno Python. Usa python3.14 de brew EXPLICITAMENTE: si el venv se
#      crea con un python3 viejo, hereda un pip anticuado que no ve flet
#      0.86.1 ("Could not find a version ... flet[all]==0.86.1"). Actualiza
#      pip antes de instalar.
#        python3.14 -m venv ~/tiddl-venv   # o "$(brew --prefix)/bin/python3.14"
#        source ~/tiddl-venv/bin/activate
#        python -m pip install --upgrade pip
#        pip install "git+https://github.com/np3ir/tiddl-elvigilante.git" \
#                    pyinstaller "flet[all]==0.86.1" tomlkit
#   Correr este script SIEMPRE con el venv activado.
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
    --collect-submodules tiddl --collect-submodules rich._unicode_data \
    --hidden-import filelock entry.py
./dist/tiddl --version
cd ..

echo "[2/4] GUI (flet build macos)..."
# flet build EMPAQUETA todo lo que haya en la carpeta del proyecto ->
# compilar desde un staging limpio con solo main.py y requirements.txt.
# echo (no `yes`): cuando flet termina, `yes` muere por SIGPIPE (141) y con
# pipefail eso abortaria el script aunque el build haya sido exitoso.
WORKDIR="$HOME/.tiddl-gui-build"
rm -rf "$WORKDIR" && mkdir -p "$WORKDIR"
cp main.py requirements.txt "$WORKDIR/"
[ -d assets ] && cp -r assets "$WORKDIR/"
pushd "$WORKDIR" > /dev/null
echo y | flet build macos --project tiddl-gui --product "tiddl by ElVigilante" \
    --company ElVigilante --build-version "$VERSION"
popd > /dev/null

echo "[3/4] Empacando tiddl + ffmpeg dentro del .app..."
APP=$(ls -d "$WORKDIR"/build/macos/*.app | head -1)
BINDIR="$APP/Contents/MacOS"
cp cli-build/dist/tiddl "$BINDIR/tiddl"
cp "$(command -v ffmpeg)" "$BINDIR/ffmpeg"
# u+w too: Homebrew's ffmpeg is read-only, which later blocks `xattr -cr`
# (removing the download quarantine) on the user's machine.
chmod u+rwx "$BINDIR/tiddl" "$BINDIR/ffmpeg"
# Ad-hoc re-sign: bundling binaries invalidates flet's signature, and an
# unsigned app fails to launch on Apple Silicon. (Does not remove the
# download-quarantine step; only notarization would.)
codesign --force --deep --sign - "$APP" 2>/dev/null || true

echo "[4/4] Creando DMG..."
mkdir -p dist-mac
# Stage the app next to an Applications symlink so the DMG has the standard
# drag-to-Applications layout instead of a bare .app with no drop target.
STAGE="$WORKDIR/dmg-stage"
rm -rf "$STAGE" && mkdir "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "tiddl by ElVigilante" -srcfolder "$STAGE" -ov -format UDZO \
    "dist-mac/tiddl-ElVigilante-$VERSION-macos.dmg"

echo ""
echo "RELEASE OK -> dist-mac/tiddl-ElVigilante-$VERSION-macos.dmg"
echo "Subir al release de GitHub:"
echo "  gh release upload v$VERSION dist-mac/tiddl-ElVigilante-$VERSION-macos.dmg"
