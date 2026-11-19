extends Control
## THE VEIL - the menu title drawn from hand-made 5x7 pixel letters (the pixel font's V carries a stray pixel at
## this size). Crisp at any scale (whole-pixel blocks), centred, a dark drop shadow, and every few seconds a faint
## stutter, as if the light on it failed for a moment.

const GLYPHS := {
	"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
	"H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
	"V": ["10001", "10001", "10001", "10001", "01010", "01010", "00100"],
	"I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
	"L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
	" ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"]}
var text := "THE VEIL"
var px := 9.0
var _flick := 0.0
var _next := 4.0


func _ready() -> void:
	custom_minimum_size = Vector2(_width(px), 7 * px + px * 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _width(p: float) -> float:
	return (text.length() * 6 - 1) * p + (p * 2 if text.contains(" ") else 0.0)


func _process(delta: float) -> void:
	_next -= delta
	if _next <= 0.0:
		_next = randf_range(3.5, 9.0)
		_flick = 0.35
	if _flick > 0.0:
		_flick -= delta
		queue_redraw()


func _draw() -> void:
	var w := _width(px)
	var x0 := (size.x - w) * 0.5
	var a := 1.0
	if _flick > 0.0:
		a = 0.45 if fmod(_flick, 0.12) < 0.06 else 0.9
	var col := Color(0.93, 0.94, 0.92, a)
	var x := x0
	for ch in text:
		var g: Array = GLYPHS.get(ch, GLYPHS[" "])
		for r in 7:
			var row: String = g[r]
			for c in 5:
				if row[c] == "1":
					var rr := Rect2(Vector2(x + c * px, r * px), Vector2(px, px))
					draw_rect(Rect2(rr.position + Vector2(px * 0.35, px * 0.35), rr.size), Color(0, 0, 0, 0.7 * a))
					draw_rect(rr, col)
		x += 6 * px + (px * 2 if ch == " " else 0.0)
