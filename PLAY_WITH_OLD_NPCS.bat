@echo off
rem THE VEIL - play with the OLD characters instead of the Meshy ones. Needs Godot 4.3 (standard). Set GODOT to its path, or put godot.exe on PATH.
if "%GODOT%"=="" set GODOT=godot
"%GODOT%" --path "%~dp0" -- old_npcs
