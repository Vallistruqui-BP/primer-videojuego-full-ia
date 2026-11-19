extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1100,760)
	var office = load("res://scenes/office.tscn").instantiate()
	root.add_child(office)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../output/preview-desktop.png")
	root.size = Vector2i(390,844)
	office.map_mode = false
	office.resize()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../output/preview-mobile.png")
	print("PREVIEW_CAPTURE_PASS desktop mobile")
	quit()
