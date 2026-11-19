extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var map = load("res://scripts/office_map.gd").new()
	root.add_child(map)
	var text := "-- Generated from office_map.gd; run tests/export_geometry.gd after map edits.\nreturn { outline={"
	for p in map.OUTLINE: text += "{%s,%s}," % [p.x,p.y]
	text += "}, rects={"
	var rects: Array = map.walls.duplicate()
	for item in map.furniture: rects.append(item.rect)
	for r in rects: text += "{%s,%s,%s,%s}," % [r.position.x,r.position.y,r.size.x,r.size.y]
	text += "}}\n"
	var file := FileAccess.open("res://../server/modules/geometry.lua",FileAccess.WRITE)
	if file == null: quit(1); return
	file.store_string(text)
	file.close()
	print("GEOMETRY_EXPORTED ",rects.size()," collision rectangles")
	quit()
