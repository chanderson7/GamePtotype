## Numbers that come back from a save exactly as they went in.
##
## Godot's JSON reader rounds some numbers to a neighbouring value: written in full, about
## one fractional number in twelve reads back a unit off in its last place, and a few can't
## be written in any form it reads back exactly. A loaded world would then drift from the
## one that was saved. So when the game saves, each fractional number settles on the value
## its saved form reads back as: the game carries on with exactly what a load would give.
## The change is at most a unit in the last place.
extends RefCounted


## `x` as it will read back from a save: itself when it already does.
static func keep(x: float) -> float:
	if x == floorf(x) and absf(x) < 9.0e15:
		return x
	var y := x
	for i in 4:
		var back := JSON.stringify(y, "", false, true).to_float()
		if back == y:
			return y
		y = back
	return y


## Every fractional number in `v` (dictionaries and arrays, all the way down) settled in
## place as keep() settles it.
static func settle(v) -> void:
	if v is Dictionary:
		var d: Dictionary = v
		for k in d:
			var x = d[k]
			if x is float:
				d[k] = keep(x)
			elif x is Dictionary or x is Array:
				settle(x)
	elif v is Array:
		var a: Array = v
		for i in a.size():
			var x = a[i]
			if x is float:
				a[i] = keep(x)
			elif x is Dictionary or x is Array:
				settle(x)
