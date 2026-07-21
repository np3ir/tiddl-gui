# Build del instalable de Windows para tiddl GUI.
# Flutter rechaza rutas con caracteres especiales (el "!" de C:\!z), asi que
# el build corre desde C:\tiddl-gui: este script sincroniza el codigo alli
# y ejecuta flet build. El resultado queda en C:\tiddl-gui\build\windows\.

$src = "C:\!z\home\tiddl-flet"
$dst = "C:\tiddl-gui"

New-Item -ItemType Directory -Force $dst | Out-Null
Copy-Item "$src\main.py", "$src\requirements.txt" $dst -Force

Set-Location $dst
"y" | flet build windows --project tiddl-gui --product "tiddl by ElVigilante" --company ElVigilante --build-version 1.0.0
