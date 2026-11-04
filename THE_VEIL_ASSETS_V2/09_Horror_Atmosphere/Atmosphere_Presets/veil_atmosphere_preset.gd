## THE VEIL - one atmosphere look (presentation only: sky, light, fog, mist, lamps, corruption, particles).
## Used for the 5 environment states and the 8 lighting presets. No gameplay data lives here.
@tool
class_name VeilAtmospherePreset
extends Resource

@export var preset_name := "Normal"
@export_group("Sky & ambient")
@export var sky_top := Color(0.20, 0.24, 0.38)
@export var sky_horizon := Color(0.78, 0.52, 0.36)
@export var ground_horizon := Color(0.32, 0.28, 0.26)
@export var ground_bottom := Color(0.08, 0.08, 0.09)
@export var ambient_color := Color(0.42, 0.40, 0.44)
@export var ambient_energy := 0.55
@export var background_is_sky := true
@export var background_color := Color(0.05, 0.05, 0.06)
@export_group("Sun / moon")
@export var sun_color := Color(1.0, 0.66, 0.42)
@export var sun_energy := 0.6
@export var sun_pitch := -8.0
@export var sun_yaw := 225.0
@export var sun_shadows := true
@export var shadow_distance := 45.0
@export_group("Distance fog (Environment)")
@export var fog_enabled := true
@export var fog_color := Color(0.55, 0.50, 0.50)
@export var fog_density := 0.004
@export var fog_height := 0.0
@export var fog_height_density := 0.0
@export var fog_sky_affect := 0.4
@export_group("Veil mist (layered sheets + fog cards)")
@export var mist_enabled := false
@export var mist_color := Color(0.62, 0.66, 0.64)
@export var mist_density := 0.0
@export var mist_height := 1.4
@export var mist_speed := 1.0
@export var mist_cards := 0
@export_group("Lamps")
@export var streetlight_energy := 1.0
@export_range(0.0, 1.0) var flicker_amount := 0.0
@export var window_glow := 1.0
@export_group("Set dressing & particles")
@export_range(0, 3) var corruption_level := 0
@export var rain := false
@export var dust := false
@export var leaves := false
