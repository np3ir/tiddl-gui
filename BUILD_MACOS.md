# Build de macOS — paso a paso

Guía para compilar y publicar el DMG de tiddl GUI desde un Mac. (El build de macOS
solo puede hacerse EN un Mac — no hay cross-compile desde Windows/Linux.)

## 1. Preparación (una sola vez, ~30-60 min por las descargas)

```bash
# Xcode completo desde el App Store (es grande); cuando termine de instalar:
sudo xcodebuild -license accept

# Homebrew si no lo tienes (https://brew.sh), y luego:
brew install python ffmpeg cocoapods

# Entorno Python aislado (el Python de brew es "externally managed",
# no permite pip install directo):
python3 -m venv ~/tiddl-venv
source ~/tiddl-venv/bin/activate
pip install "git+https://github.com/np3ir/tiddl-elvigilante.git" pyinstaller "flet[all]==0.86.1" tomlkit
```

## 2. Build

```bash
git clone https://github.com/np3ir/tiddl-gui.git
cd tiddl-gui
source ~/tiddl-venv/bin/activate   # si abriste una terminal nueva
chmod +x release_macos.sh
./release_macos.sh 1.0.2           # o la version que toque
```

- La **primera corrida** descarga el Flutter SDK de flet (~10-20 min extra);
  las siguientes son rápidas.
- Al final imprime la ruta del DMG en `dist-mac/`.
- El DMG incluye el binario `tiddl` standalone y `ffmpeg` dentro del `.app` —
  el usuario final no necesita instalar nada más.

## 3. Probar

1. Monta el DMG y arrastra la app a Applications.
2. Primera apertura: **click derecho → Open** (Gatekeeper, app sin firmar).
   Alternativa: `xattr -cr "/Applications/tiddl by ElVigilante.app"`
3. La app debe pedir el login de TIDAL (device flow en el navegador),
   luego configurar carpetas en Settings y probar una descarga.

## 4. Subir el DMG al release

```bash
brew install gh
gh auth login
gh release upload v1.0.2 dist-mac/tiddl-ElVigilante-1.0.2-macos.dmg -R np3ir/tiddl-gui
```

(O copia el DMG a otra máquina que ya tenga `gh` autenticado y súbelo desde allí.)

## Notas

- **Arquitectura**: el DMG sale para la arquitectura del Mac que compila
  (Apple Silicon en M1/M2/...). Cubre cualquier Mac moderno.
- **Versiones**: usa el mismo número que el release de GitHub existente para
  añadirle el DMG, o crea release nuevo si es una versión nueva.
- Los gotchas del build (SIGPIPE del `yes`, staging limpio porque flet
  empaqueta todo lo que ve, ícono en `assets/`) ya están resueltos dentro de
  `release_macos.sh` — leer sus comentarios si algo se comporta raro.
