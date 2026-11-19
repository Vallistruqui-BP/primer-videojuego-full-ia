extends SceneTree
var draft_file := "user://creator-regression-" + str(Time.get_ticks_usec()) + ".json"
var profile_file := "user://profile-regression-" + str(Time.get_ticks_usec()) + ".json"

class FakeNetwork extends Node:
 signal playground_state(data: Dictionary)
 var calls: Array = []
 var delay := false
 var entities := {}
 var conflicts := 0
 signal release_response
 func rpc_playground(action: String, data := {}) -> Dictionary:
  calls.append({"action":action,"data":data.duplicate(true)})
  if delay: await release_response
  if action == "blueprint_save":
   var item: Dictionary = data.blueprint.duplicate(true)
   if item.has("code"):
    if not entities.has(item.code) or int(item.revision) != int(entities[item.code].revision):
     conflicts += 1
     return {"ok":false,"error":"revision conflict"}
    item.revision = int(item.revision)+1
   else:
    item.code = "test-code-" + str(entities.size()+1)
    item.revision = 1
   entities[item.code] = item.duplicate(true)
   return {"ok":true,"blueprint":item}
  return {"ok":true,"profile":{"name":"Saved","skin":1,"hair":0,"shirt":0,"style":0}}
 func send_playground(_action: String, _data := {}) -> void: pass

class FakeOffice extends Node2D:
 var hud := CanvasLayer.new()
 var player = load("res://scripts/office_player.gd").new()
 var network := FakeNetwork.new()
 func _ready() -> void:
  add_child(hud)
  add_child(player)
  player.set_physics_process(false)
  add_child(network)

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> bool:
 if not ok:
  printerr("CREATOR_REGRESSION_FAIL ",message)
  quit(1)
 return ok
func inputs(hub: Node) -> Array:
 return hub.body.get_children().filter(func(n): return n is LineEdit)
func click(hub: Node, text: String) -> void:
 for child in hub.body.get_children():
  if child is Button and child.text == text:
   child.pressed.emit()
   return
 push_error("Button missing: " + text)
func setup_hub(office: Node) -> Node:
 var hub = load("res://scripts/playground_hub.gd").new()
 hub.drafts_path = draft_file
 hub.profile_path = profile_file
 office.add_child(hub)
 hub.set_process(false)
 hub.attach(office)
 hub.templates = [
  {"id":"snake","name":"Snake","defaults":{"speed":2},"fields":[{"id":"speed","name":"Velocidad","values":[1,2,3]}]},
  {"id":"trivia","name":"Trivia","defaults":{},"fields":[]}
 ]
 hub.default_questions = [
  {"text":"Uno","options":["A","B"],"answer":1},
  {"text":"Dos","options":["A","B"],"answer":1},
  {"text":"Tres","options":["A","B"],"answer":1}
 ]
 return hub
func run() -> void:
 var office := FakeOffice.new()
 root.add_child(office)
 var hub := setup_hub(office)
 await hub.show_creator("trivia")
 var fields := inputs(hub)
 fields[0].text = "Trivia con hueco"
 fields[6].text = "D correcta" # option 4, while optional option 3 is empty
 var answers: Array = hub.body.get_children().filter(func(n): return n is OptionButton)
 answers[2].selected = 3
 click(hub,"Guardar desafío")
 if not check(office.network.calls.size() == 1,"valid trivia must save"): return
 var q: Dictionary = office.network.calls[0].data.blueprint.rules.questions[0]
 if not check(q.options == ["A","B","D correcta"] and q.answer == 3,"option 4 identity must remap to compact index 3"): return
 await hub.show_creator("trivia")
 fields = inputs(hub)
 fields[3].text = ""
 click(hub,"Guardar desafío")
 if not check(office.network.calls.size() == 1,"required first choice must reject locally"): return
 fields[3].text = "A"
 fields[4].text = "  "
 click(hub,"Guardar desafío")
 if not check(office.network.calls.size() == 1,"required second choice must reject locally"): return
 fields[4].text = "B"
 answers = hub.body.get_children().filter(func(n): return n is OptionButton)
 fields[6].text = ""
 answers[2].selected = 3
 click(hub,"Guardar desafío")
 if not check(office.network.calls.size() == 1,"empty selected answer must reject locally"): return
 fields[0].text = "Mi borrador"
 fields[1].text = "Descripción conservada"
 fields[2].text = "Pregunta propia"
 answers[0].item_selected.emit(0)
 fields = inputs(hub)
 if not check(fields[0].text == "Mi borrador" and fields[1].text == "Descripción conservada","title and description survive template switch"): return
 answers = hub.body.get_children().filter(func(n): return n is OptionButton)
 answers[1].selected = 2
 hub.close_panel()
 await hub.show_creator("trivia")
 if not check(inputs(hub)[2].text == "Pregunta propia","trivia draft survives switch and close"): return
 answers = hub.body.get_children().filter(func(n): return n is OptionButton)
 answers[1].item_selected.emit(1)
 fields = inputs(hub)
 if not check(fields.size() == 22 and fields[2].text == "Pregunta propia","question count preserves incomplete question drafts"): return
 answers = hub.body.get_children().filter(func(n): return n is OptionButton)
 if not check(not answers[0].disabled,"question count must not lock template choice"): return
 answers[1].item_selected.emit(0)
 hub.close_panel()
 await hub.show_creator("snake")
 answers = hub.body.get_children().filter(func(n): return n is OptionButton)
 if not check(answers[1].selected == 2,"per-template rules survive reopen"): return
 hub.close_panel()
 var second_office := FakeOffice.new()
 root.add_child(second_office)
 var second_hub := setup_hub(second_office)
 await second_hub.show_creator("trivia")
 if not check(inputs(second_hub)[2].text == "Pregunta propia","draft restores from local disk in fresh instance"): return
 second_office.free()
 await hub.show_creator("snake")
 fields = inputs(hub)
 fields[0].text = "Saved draft"
 office.network.delay = true
 click(hub,"Guardar desafío")
 hub.close_panel()
 await hub.show_creator("snake")
 inputs(hub)[0].text = "Newer edits"
 hub.close_panel()
 office.network.release_response.emit()
 await process_frame
 if not check(hub.screen == "" and not hub.overlay.visible,"late blueprint save must not reopen panel"): return
 await hub.show_creator("snake")
 if not check(inputs(hub)[0].text == "Newer edits","late save preserves newer draft"): return
 office.network.delay = false
 click(hub,"Guardar desafío")
 if not check(office.network.entities.size() == 2 and office.network.entities["test-code-2"].revision == 2,"new draft reopened after delayed save must update same entity to revision 2"): return
 await hub.show_creator("snake")
 if not check(inputs(hub)[0].text == "Snake de la oficina","successful save clears stale draft"): return
 office.network.delay = true
 click(hub,"Guardar desafío")
 inputs(hub)[0].text = "Edited during save"
 office.network.release_response.emit()
 await process_frame
 if not check(hub.screen == "creator" and inputs(hub)[0].text == "Edited during save","late save keeps active newer edits visible"): return
 office.network.delay = false
 click(hub,"Guardar desafío")
 if not check(office.network.entities.size() == 3 and office.network.entities["test-code-3"].revision == 2,"new active draft must use returned identity on second save"): return
 var existing: Dictionary = office.network.entities["test-code-3"].duplicate(true)
 await hub.show_creator("snake",existing)
 office.network.delay = true
 click(hub,"Guardar desafío")
 inputs(hub)[0].text = "Existing edited during save"
 office.network.release_response.emit()
 await process_frame
 office.network.delay = false
 click(hub,"Guardar desafío")
 if not check(office.network.conflicts == 0 and office.network.entities[existing.code].revision == 4,"existing active draft must advance N to N+1 to N+2 without CAS conflict"): return
 existing = office.network.entities[existing.code].duplicate(true)
 await hub.show_creator("snake",existing)
 office.network.delay = true
 click(hub,"Guardar desafío")
 inputs(hub)[0].text = "Existing persisted newer edit"
 hub.close_panel()
 office.network.release_response.emit()
 await process_frame
 # Rebuild from disk and a stale library object: draft metadata must be newer.
 var reopened_office := FakeOffice.new()
 root.add_child(reopened_office)
 reopened_office.network.entities = office.network.entities.duplicate(true)
 var reopened_hub := setup_hub(reopened_office)
 await reopened_hub.show_creator("snake",existing)
 if not check(inputs(reopened_hub)[0].text == "Existing persisted newer edit","existing pending edit restores from disk"): return
 click(reopened_hub,"Guardar desafío")
 if not check(reopened_office.network.conflicts == 0 and reopened_office.network.entities[existing.code].revision == 6,"persisted draft metadata must advance revision after delayed save"): return
 reopened_office.free()
 office.network.delay = false
 hub.show_character()
 var preview = hub.body.find_child("CharacterPreview",false,false)
 if not check(preview != null,"character preview exists"): return
 fields = inputs(hub)
 fields[0].text = "Live"
 fields[0].text_changed.emit("Live")
 if not check(preview.avatar.profile.name == "Live" and not preview.avatar.is_physics_processing(),"preview updates live without moving"): return
 root.size = Vector2i(320,568)
 hub.resize()
 for i in range(4): await process_frame
 if not check(hub.panel.size.x <= 296 and hub.panel.get_global_rect().end.x <= 320,"character form fits 320px"): return
 hub.show_blueprint({"title":"W".repeat(48),"kind":"snake","revision":1,"code":"example"},false)
 for i in range(4): await process_frame
 if not check(hub.panel.size.x <= 296 and hub.panel.get_global_rect().end.x <= 320,"long title fits 320px"): return
 hub.show_character()
 office.network.delay = true
 click(hub,"Guardar personaje")
 hub.close_panel()
 office.network.release_response.emit()
 await process_frame
 if not check(hub.screen == "" and not hub.overlay.visible,"late profile save must not reopen panel"): return
 office.free()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(draft_file))
 DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_file))
 print("CREATOR_REGRESSION_PASS remap validation per_template_drafts disk_restore preview stale_response mobile320 identity_revision_CAS")
 quit(0)
