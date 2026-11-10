extends SceneTree
## Renders assets/branding/wordmark.png from assets/branding/wordmark.svg, at the SVG's own
## size (its letters are paths, so nothing depends on installed fonts). Re-run after
## changing the SVG, then re-render the splash (tools/render_splash.gd):
##   godot --headless --path . -s tools/render_wordmark.gd
const SVG := "res://assets/branding/wordmark.svg"
const PNG := "res://assets/branding/wordmark.png"


func _init() -> void:
	var img := Image.new()
	var err := img.load_svg_from_buffer(FileAccess.get_file_as_bytes(SVG), 1.0)
	if err != OK or img.is_empty():
		push_error("Couldn't read %s (%s)" % [SVG, error_string(err)])
		quit(1)
		return
	img.save_png(PNG)
	print("Wrote %s (%dx%d)" % [PNG, img.get_width(), img.get_height()])
	quit()
