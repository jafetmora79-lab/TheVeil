@echo off
rem THE VEIL - the nine Meshy NPCs standing in the supermarket (keys 1-9 then T/B/S/A/W/N). Needs Godot 4.3 (standard).
if "%GODOT%"=="" set GODOT=godot
"%GODOT%" --path "%~dp0" res://game/prototypes/npc_meshy/NpcSupermarketTest.tscn
