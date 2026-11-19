extends Control
class_name VeilHoldRing
## THE VEIL - the progress ring that fills round the crosshair while the player holds the interact key on a heavy
## or slow object (see Interactable.hold_time). Plain drawn arcs, pixel-chunky to match the HUD; hidden at zero.

var progress := 0.0:
	set(v):
		progress = v
		visible = v > 0.001
		queue_redraw()

const RADIUS := 22.0


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -RADIUS - 4.0
	offset_right = RADIUS + 4.0
	offset_top = -RADIUS - 4.0
	offset_bottom = RADIUS + 4.0


func _draw() -> void:
	var c := size / 2.0
	draw_arc(c, RADIUS, 0.0, TAU, 40, Color(0, 0, 0, 0.55), 5.0)
	draw_arc(c, RADIUS, -PI / 2.0, -PI / 2.0 + TAU * clampf(progress, 0.0, 1.0), 40, Color(0.95, 0.9, 0.7, 0.95), 3.0)
