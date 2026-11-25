@echo off
rem Double-clique ici pour demarrer Redis et charger les donnees de demo.
rem -ExecutionPolicy Bypass ne vaut que pour cette fenetre : rien n'est modifie sur le PC.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0load-demo.ps1"
echo.
pause
