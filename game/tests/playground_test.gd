extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var office = load("res://scenes/office.tscn").instantiate()
 root.add_child(office)
 await process_frame
 if not "hub" in office:
  printerr("PLAYGROUND_TEST_FAIL missing playground hub")
  quit(1)
  return
 office.hub.open_home()
 await process_frame
 assert(office.player.input_blocked)
 office.hub.close_panel()
 assert(not office.player.input_blocked)
 var pos = office.player.position
 office.hub.travel("arcade")
 assert(office.hub.zone == "arcade")
 office.hub.travel("office")
 assert(office.player.position == pos)
 office.hub.show_character()
 assert(office.hub.body.get_child_count() > 5)
 office.hub.close_panel()
 var board = load("res://scripts/playground_board.gd").new()
 office.hub.body.add_child(board)
 board.update_state({"id":"fixture","kind":"tateti","phase":"playing","scores":[0,0],"you":1,"your_turn":true,"board":[0,0,0,0,0,0,0,0,0]})
 assert(board.cells.size() == 9)
 assert(not board.cells[0].disabled)
 board.update_state({"id":"fixture","kind":"tateti","phase":"playing","scores":[0,0],"you":1,"your_turn":false,"board":[1,0,0,0,0,0,0,0,0]})
 assert(board.cells[1].disabled)
 office.hub.invitation_id = "expired-fixture"
 office.hub.screen = "blueprint"
 office.hub.note.text = "Esperando a tu compañero"
 office.hub.receive({"zone":"office"})
 if office.hub.note.text == "Esperando a tu compañero":
  printerr("PLAYGROUND_TEST_FAIL sender expiry notice")
  quit(1)
  return
 print("PLAYGROUND_TEST_PASS modal_input door_return character_editor")
 quit(0)
