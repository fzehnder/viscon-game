extends SceneTree
## Writes the boot splash res://splash.png from scripts/eth_front.gd (scaled up 4x without filtering).
##   godot --headless --path godot --script res://tools/make_splash.gd

const EthFront = preload("res://scripts/eth_front.gd")


func _init() -> void:
	var img: Image = EthFront.render(true)
	img.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
	var err := img.save_png("res://splash.png")
	print("splash.png: ", "ok" if err == OK else "error %d" % err)
	quit()
