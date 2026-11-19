extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var map = load("res://scripts/office_map.gd").new()
 root.add_child(map)
 var data := {"schema":1,"objects":[],"walls":[],"outline":[],"rooms":[],"doors":[],"labels":[]}
 for p in map.OUTLINE: data.outline.append([p.x,p.y])
 for r in map.walls: data.walls.append([r.position.x,r.position.y,r.size.x,r.size.y])
 for item in map.furniture:
  var r: Rect2 = item.rect
  var kind: String = item.kind
  if kind == "desk" and r.size.x < r.size.y*1.5: kind = "desk_square"
  data.objects.append({"id":"prop_%03d" % data.objects.size(),"kind":kind,"x":r.get_center().x,"y":r.get_center().y,"w":r.size.x,"d":r.size.y,"rotation":0.0,"zone":"office"})
  if item.kind == "desk": data.objects.append({"id":"prop_%03d" % data.objects.size(),"kind":"chair","x":r.get_center().x,"y":r.end.y+8,"w":12,"d":12,"rotation":0.0,"zone":"office"})
 for p in map.plants: data.objects.append({"id":"prop_%03d" % data.objects.size(),"kind":"plant","x":p.x,"y":p.y,"w":20,"d":20,"rotation":0.0,"zone":"office"})
 for item in map.rooms:
  var r: Rect2 = item.rect
  data.rooms.append({"x":r.position.x,"y":r.position.y,"w":r.size.x,"d":r.size.y,"title":item.title})
 for item in map.door_visuals: data.doors.append({"x":item.center.x,"y":item.center.y,"width":item.width,"rotation":item.rotation})
 for item in map.labels: data.labels.append({"x":item.p.x,"y":item.p.y,"text":item.text})
 var file := FileAccess.open("res://data/office_layout.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(data,"  ")+"\n")
 print("LAYOUT_EXPORTED ",data.objects.size())
 quit()
