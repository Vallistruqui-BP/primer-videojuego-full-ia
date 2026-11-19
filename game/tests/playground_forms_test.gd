extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var office = load("res://scenes/office.tscn").instantiate()
 root.add_child(office)
 await process_frame
 for kind in ["snake","terminal","pong","tateti","memory","trivia"]:
  await office.hub.show_creator(kind)
  if office.hub.templates.size() != 6 or office.hub.body.get_child_count() < 8:
   printerr("PLAYGROUND_FORMS_FAIL ",kind)
   quit(1)
   return
  print("FORM_PASS ",kind)
 await office.hub.show_library()
 await office.hub.show_inbox()
 office.hub.close_panel()
 office.network.socket.close()
 await create_timer(0.2).timeout
 print("PLAYGROUND_FORMS_PASS six_creators library inbox")
 quit(0)
