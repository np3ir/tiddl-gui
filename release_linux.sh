#!/bin/bash
# Release Linux de tiddl GUI. Correr EN Linux (nativo o WSL2), desde el repo tiddl-gui.
#
#   ./release_linux.sh            # version 1.0.0
#   ./release_linux.sh 1.1.0      # otra version
#
# Requisitos (una sola vez, Debian/Ubuntu):
#   sudo apt install -y python3-pip python3-venv clang cmake ninja-build \
#       pkg-config libgtk-3-dev liblzma-dev git curl unzip xz-utils zip
#   pip3 install "git+https://github.com/np3ir/tiddl-elvigilante.git" \
#       pyinstaller "flet[all]==0.86.1" tomlkit
#
# Resultado: dist-linux/tiddl-ElVigilante-<version>-linux-x64.tar.gz
# El usuario final necesita ffmpeg del sistema:  sudo apt install ffmpeg
# (no se bundlea: el de las distros es dinamico y no viaja bien)

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

echo "[2/4] GUI (flet build linux)..."
# flet build EMPAQUETA todo lo que haya en la carpeta del proyecto ->
# compilar desde un staging limpio con solo main.py y requirements.txt.
# echo (no `yes`): cuando flet termina, `yes` muere por SIGPIPE (141) y con
# pipefail eso abortaria el script aunque el build haya sido exitoso.
WORKDIR="$HOME/.tiddl-gui-build"
rm -rf "$WORKDIR" && mkdir -p "$WORKDIR"
cp main.py requirements.txt "$WORKDIR/"
pushd "$WORKDIR" > /dev/null
echo y | flet build linux --project tiddl-gui --product "tiddl by ElVigilante" \
    --company ElVigilante --build-version "$VERSION"
popd > /dev/null

echo "[3/4] Empacando tiddl junto al ejecutable..."
BUNDLE="$WORKDIR/build/linux"
cp cli-build/dist/tiddl "$BUNDLE/tiddl"
chmod +x "$BUNDLE/tiddl"
cat > "$BUNDLE/README.txt" <<EOF
tiddl by ElVigilante $VERSION (Linux x64)

1. Instala ffmpeg:   sudo apt install ffmpeg   (o el equivalente de tu distro)
2. Ejecuta:          ./tiddl-gui
3. Log in to TIDAL desde la app y configura tus carpetas en Settings.

https://github.com/np3ir/tiddl-gui
EOF

echo "[4/4] Creando tar.gz..."
mkdir -p dist-linux
STAGE="dist-linux/tiddl-ElVigilante-$VERSION"
rm -rf "$STAGE" && mkdir "$STAGE"
cp -r "$BUNDLE"/. "$STAGE"/
tar -czf "dist-linux/tiddl-ElVigilante-$VERSION-linux-x64.tar.gz" -C dist-linux "tiddl-ElVigilante-$VERSION"
rm -rf "$STAGE"

echo ""
echo "RELEASE OK -> dist-linux/tiddl-ElVigilante-$VERSION-linux-x64.tar.gz"
echo "Subir al release de GitHub:"
echo "  gh release upload v$VERSION dist-linux/tiddl-ElVigilante-$VERSION-linux-x64.tar.gz"
