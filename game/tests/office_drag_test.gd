extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func expect(value: bool,message: String) -> void:
 if not value: failures.append(message)
func run() -> void:
 root.size=Vector2i(1440,1000)
 var office=load("res://scenes/office3d.tscn").instantiate()
 root.add_child(office)
 await process_frame
 await process_frame
 var editor=office.map_editor
 var world=office.world3d
 editor.layout=editor.Store.canonical()
 editor.toggle()
 await process_frame
 await process_frame
 editor.add_piece()
 var index: int=editor.selected
 var item: Dictionary=editor.layout.objects[index].duplicate()
 var screen: Vector2=world.camera.unproject_position(world.map_to_world(Vector2(item.x,item.y),0.8))
 expect(world.pick_object(screen)==item.id,"pick actual mesh")
 var count: int=editor.history.size()
 editor.begin_existing_drag(screen)
 expect(editor.dragging,"press starts drag")
 var node: Node3D=world.objects_by_id[item.id]
 var floor_node: Node=world.office_root.get_node("OfficeFloor")
 var destination: Vector2=world.camera.unproject_position(world.map_to_world(Vector2(item.x+80,item.y)))
 editor.update_drag(destination)
 expect(world.objects_by_id[item.id]==node and world.office_root.get_node("OfficeFloor")==floor_node,"motion reuses objects and floor")
 editor.finish_drag(destination)
 expect(not editor.dragging and editor.history.size()==count+1,"one undo entry per drag")
 expect(editor.layout.objects[index].x!=item.x,"drag commits new coordinates")
 editor.undo()
 expect(editor.layout.objects[index]==item,"undo restores exact transform")
 editor.select_piece(index)
 editor.start_drag(screen,false,-1)
 editor.update_drag(Vector2(-500,-500))
 editor.finish_drag(Vector2(-500,-500))
 expect(editor.layout.objects[index]==item,"outside drop restores original")
 editor.start_drag(screen,false,-1)
 editor.update_drag(destination)
 editor.cancel_drag()
 expect(editor.layout.objects[index]==item,"escape restores original")
 var before: int=editor.layout.objects.size()
 editor.begin_palette_drag(Vector2(1300,500))
 editor.update_drag(destination)
 editor.finish_drag(destination)
 expect(editor.layout.objects.size()==before+1,"palette adds at drop")
 editor.undo()
 expect(editor.layout.objects.size()==before,"undo palette addition")
 editor.select_piece(index)
 editor.start_drag(screen,false,-1)
 var trash_point: Vector2=editor.trash.get_global_rect().get_center()
 editor.update_drag(trash_point)
 editor.finish_drag(trash_point)
 expect(editor.layout.objects.size()==before-1,"drop on trash removes")
 editor.undo()
 expect(editor.layout.objects.size()==before,"undo trash")
 editor.begin_palette_drag(Vector2(1300,500))
 editor.update_drag(Vector2(-500,-500))
 editor.finish_drag(Vector2(-500,-500))
 expect(editor.layout.objects.size()==before,"invalid palette drop creates nothing")
 editor.select_piece(index)
 editor.start_drag(screen,false,0)
 var touch:=InputEventScreenDrag.new()
 touch.index=0;touch.position=destination
 editor._input(touch)
 var release:=InputEventScreenTouch.new()
 release.index=0;release.pressed=false;release.position=destination
 editor._input(release)
 expect(not editor.dragging and editor.layout.objects[index].x!=item.x,"touch drag commits")
 editor.undo()
 var source: Button
 for button in office.hud.find_children("*","Button",true,false):
  if button.text=="Arrastrar pieza al mapa": source=button
 var start_touch:=InputEventScreenTouch.new()
 start_touch.index=0;start_touch.pressed=true;start_touch.position=Vector2(12,12)
 editor.palette_input(start_touch,source)
 expect(editor.drag_start.distance_to(source.global_position+Vector2(12,12))<0.01,"palette touch converts local coordinates")
 editor.cancel_drag()
 for size in [Vector2i(390,844),Vector2i(320,568),Vector2i(844,390)]:
  root.size=size
  await process_frame
  await process_frame
  editor.resize()
  expect(editor.panel.get_global_rect().end.x<=size.x+0.1,"panel fits width "+str(size))
 editor.toggle()
 expect(office.title_label.get_parent().get_parent().visible,"HUD restored")
 office.queue_free()
 await process_frame
 for failure in failures: printerr("OFFICE_DRAG_FAIL "+failure)
 if failures.is_empty(): print("OFFICE_DRAG_PASS picking movement reuse undo outside cancel palette trash touch")
 quit(0 if failures.is_empty() else 1)
