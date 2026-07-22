# Release completo de tiddl by ElVigilante: GUI + CLI standalone + instalador.
#
#   .\release.ps1                      # release 1.0.0 completo
#   .\release.ps1 -Version 1.1.0       # nueva version
#   .\release.ps1 -SkipGui             # reusar el build de GUI existente
#   .\release.ps1 -SkipCli             # reusar el tiddl.exe existente
#
# Resultado: C:\tiddl-gui\installer\tiddl-ElVigilante-Setup-<version>.exe
#
# Notas (aprendidas a golpes):
# - flet build NO funciona desde rutas con "!" (C:\!z) -> se trabaja en C:\tiddl-gui
# - flet build EMPAQUETA TODO lo que haya en la carpeta del proyecto -> C:\tiddl-gui
#   debe contener SOLO main.py y requirements.txt; los artefactos de CLI e
#   instalador viven en C:\tiddl-release (si no, el setup dobla de tamano)
# - flet 0.86 pregunta por su Flutter SDK propio -> se auto-responde "y"
# - PyInstaller necesita --collect-submodules rich._unicode_data (imports dinamicos)
#   y --paths al repo porque tiddl esta instalado editable

param(
    [string]$Version = "1.0.0",
    [switch]$SkipGui,
    [switch]$SkipCli
)

$ErrorActionPreference = "Stop"
$src  = "C:\!z\home\tiddl-flet"
$work = "C:\tiddl-gui"
$rel  = "C:\tiddl-release"
$repo = "C:\!z\home\tiddl-elvigilante-main"
$iscc = "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"

# ---------- 1. GUI (flet build) ----------
if (-not $SkipGui) {
    Write-Host "[1/3] Compilando GUI (flet build windows)..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Force $work | Out-Null
    # La carpeta del proyecto debe quedar limpia: flet build empaqueta todo lo
    # que encuentre en ella (excepto build\).
    Get-ChildItem $work -Exclude build | Where-Object { $_.Name -notin "main.py", "requirements.txt", "assets" } |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item "$src\main.py", "$src\requirements.txt" $work -Force
    Copy-Item "$src\assets" $work -Recurse -Force
    Set-Location $work
    "y" | flet build windows --project tiddl-gui --product "tiddl by ElVigilante" `
        --company ElVigilante --build-version $Version
    if (-not (Test-Path "$work\build\windows\tiddl-gui.exe")) {
        throw "flet build fallo: no existe $work\build\windows\tiddl-gui.exe"
    }
} else { Write-Host "[1/3] GUI: reusando build existente" -ForegroundColor Yellow }

# ---------- 2. CLI standalone (PyInstaller) ----------
if (-not $SkipCli) {
    Write-Host "[2/3] Compilando tiddl.exe (PyInstaller)..." -ForegroundColor Cyan
    $cli = "$rel\cli-build"
    New-Item -ItemType Directory -Force $cli | Out-Null
    @'
"""PyInstaller entry point for the standalone tiddl.exe."""

from tiddl.cli.app import main

if __name__ == "__main__":
    main()
'@ | Set-Content "$cli\entry.py" -Encoding UTF8
    Set-Location $cli
    pyinstaller --onefile --console --name tiddl --noconfirm `
        --paths $repo --hidden-import tiddl --collect-submodules tiddl `
        --collect-submodules rich._unicode_data --hidden-import filelock entry.py
    if ($LASTEXITCODE -ne 0) { throw "pyinstaller fallo (exit $LASTEXITCODE)" }
    $v = & "$cli\dist\tiddl.exe" --version 2>&1 | Select-Object -Last 1
    if ($LASTEXITCODE -ne 0) { throw "tiddl.exe no arranca" }
    Write-Host "tiddl.exe OK - version: $v"
} else { Write-Host "[2/3] CLI: reusando tiddl.exe existente" -ForegroundColor Yellow }

# ---------- 3. Instalador (Inno Setup) ----------
Write-Host "[3/3] Compilando instalador (Inno Setup)..." -ForegroundColor Cyan
if (-not (Test-Path "C:\ffmpeg\bin\ffmpeg.exe")) { throw "ffmpeg no encontrado en C:\ffmpeg\bin" }
if (-not (Test-Path $iscc)) { throw "ISCC.exe no encontrado en $iscc" }
& $iscc "/DMyAppVersion=$Version" "$src\installer.iss"
if ($LASTEXITCODE -ne 0) { throw "ISCC fallo (exit $LASTEXITCODE)" }

$setup = "$rel\installer\tiddl-ElVigilante-Setup-$Version.exe"
$mb = [math]::Round((Get-Item $setup).Length / 1MB)
Write-Host ""
Write-Host "RELEASE OK -> $setup ($mb MB)" -ForegroundColor Green
