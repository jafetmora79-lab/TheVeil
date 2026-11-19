@echo off
rem THE VEIL - play the game (the Meshy characters stand in for the old ones). Needs Godot 4.3 (standard). Set GODOT to its path, or put godot.exe on PATH.
if "%GODOT%"=="" set GODOT=godot
"%GODOT%" --path "%~dp0"
