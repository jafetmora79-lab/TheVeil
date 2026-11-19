@echo off
rem THE VEIL - Meshy NPC trial (Eddie and the clerk). Needs Godot 4.3 (standard). Set GODOT to its path, or put godot.exe on PATH.
if "%GODOT%"=="" set GODOT=godot
"%GODOT%" --path "%~dp0" -- meshy_npcs
