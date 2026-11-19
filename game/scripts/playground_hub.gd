extends Node
const KINDS := ["snake","terminal","pong","tateti","memory","trivia"]
var office: Node2D
var zone := "office"
var return_position := Vector2(620,790)
var room_art: Node2D
var screen := ""
var game := {}
var templates: Array = []
var default_questions: Array = []
var profile := {"name":"Explorador","skin":1,"hair":0,"shirt":0,"style":0}
var panel: PanelContainer
var body: VBoxContainer
var heading: Label
var note: Label
var board: Control
var overlay: Control
var interact_button: Button
var home_button: Button
var page_version := 0
var drafts_path := "user://office-creator-drafts.json"
var profile_path := "user://office-profile.json"
var creator_drafts: Dictionary = {}
var creator_capture := Callable()
var creator_key := ""
var creator_identity: Dictionary = {}
var creator_selector: OptionButton
var draft_timer: Timer
var invitation_id := ""
var last_phase := ""
var busy := false
var game_clock := 0.0
var last_notice := ""

func attach(target: Node2D) -> void:
 office = target
 room_art = load("res://scripts/playground_room.gd").new()
 office.add_child(room_art)
 # Simple dedicated-room boundary. The office geometry is preserved.
 for rect in [Rect2(1780,300,640,20),Rect2(1780,750,640,20),Rect2(1780,300,20,470),Rect2(2400,300,20,470)]:
  var wall := StaticBody2D.new()
  var shape := CollisionShape2D.new()
  var box := RectangleShape2D.new()
  box.size = rect.size
  shape.shape = box
  wall.position = rect.get_center()
  wall.add_child(shape)
  office.add_child(wall)
 home_button = Button.new()
 home_button.text = "Personaje y juegos"
 home_button.position = Vector2(180,144)
 home_button.pressed.connect(open_home)
 office.hud.add_child(home_button)
 interact_button = Button.new()
 interact_button.text = "E · Buzón"
 office.hud.add_child(interact_button)
 interact_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
 interact_button.offset_left = -185
 interact_button.offset_right = -18
 interact_button.offset_top = -110
 interact_button.offset_bottom = -62
 interact_button.pressed.connect(interact)
 overlay = Control.new()
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 office.hud.add_child(overlay)
 var shade := ColorRect.new()
 shade.color = Color(0.04,0.09,0.09,0.86)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.add_child(shade)
 panel = PanelContainer.new()
 overlay.add_child(panel)
 var style := StyleBoxFlat.new()
 style.bg_color = Color("243d36")
 style.border_color = Color("b6c69c")
 style.set_border_width_all(2)
 style.set_corner_radius_all(6)
 style.set_content_margin_all(18)
 panel.add_theme_stylebox_override("panel",style)
 var main := VBoxContainer.new()
 main.add_theme_constant_override("separation",12)
 panel.add_child(main)
 var row := HBoxContainer.new()
 main.add_child(row)
 heading = Label.new()
 heading.add_theme_font_size_override("font_size",22)
 heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 row.add_child(heading)
 var close := Button.new()
 close.text = "Cerrar"
 close.pressed.connect(request_close)
 row.add_child(close)
 var scroll := ScrollContainer.new()
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 main.add_child(scroll)
 body = VBoxContainer.new()
 body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 body.add_theme_constant_override("separation",12)
 scroll.add_child(body)
 note = Label.new()
 note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 note.add_theme_color_override("font_color",Color("f0ca7c"))
 main.add_child(note)
 overlay.hide()
 get_viewport().size_changed.connect(resize)
 resize()
 office.network.playground_state.connect(receive)
 if FileAccess.file_exists(profile_path):
  var cached = JSON.parse_string(FileAccess.get_file_as_string(profile_path))
  if cached is Dictionary: profile = cached
 office.player.profile = profile
 office.player.queue_redraw()
 if FileAccess.file_exists(drafts_path):
  var drafts = JSON.parse_string(FileAccess.get_file_as_string(drafts_path))
  if drafts is Dictionary: creator_drafts = drafts
 draft_timer = Timer.new()
 draft_timer.one_shot = true
 draft_timer.wait_time = 0.35
 draft_timer.timeout.connect(persist_creator)
 add_child(draft_timer)
 if DisplayServer.get_name() != "headless": call_deferred("restore_profile")

func restore_profile() -> void:
 var result: Dictionary = await office.network.rpc_playground("profile_get")
 if result.get("ok",false):
  profile = result.profile
  office.player.profile = profile
  office.player.queue_redraw()

func resize() -> void:
 if not panel: return
 var viewport := get_viewport().get_visible_rect().size
 panel.size = Vector2(minf(700,viewport.x-24),viewport.y-32)
 panel.position = (viewport-panel.size)/2

func clear_body() -> void:
 for child in body.get_children():
  body.remove_child(child)
  child.queue_free()
 board = null

func page(title: String, id: String) -> void:
 persist_creator()
 creator_capture = Callable()
 page_version += 1
 clear_body()
 screen = id
 heading.text = title
 note.text = ""
 overlay.show()
 office.player.input_blocked = true
 office.player.touch_input = Vector2.ZERO
 resize()

func label(text: String) -> Label:
 var item := Label.new()
 item.text = text
 item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 body.add_child(item)
 return item

func button(text: String, action: Callable, parent: Node = null) -> Button:
 var item := Button.new()
 item.text = text
 item.custom_minimum_size.y = 44
 item.clip_text = true
 item.pressed.connect(action)
 (parent if parent else body).add_child(item)
 return item

func field(title: String, value: String, limit: int) -> LineEdit:
 label(title)
 var item := LineEdit.new()
 item.text = value
 item.max_length = limit
 item.expand_to_text_length = false
 item.custom_minimum_size.y = 44
 body.add_child(item)
 return item

func choose(title: String, values: Array, selected: int = 0) -> OptionButton:
 label(title)
 var item := OptionButton.new()
 item.fit_to_longest_item = false
 item.clip_text = true
 for v in values: item.add_item(str(v))
 item.selected = selected
 item.custom_minimum_size.y = 44
 body.add_child(item)
 return item

func close_panel() -> void:
 persist_creator()
 creator_capture = Callable()
 page_version += 1
 overlay.hide()
 screen = ""
 office.player.input_blocked = false
 office.player.touch_input = Vector2.ZERO

func request_close() -> void:
 if not game.is_empty() and game.get("phase") == "playing":
  page("¿Salir de la partida?","abandon")
  label("Se cerrará para ambos. No se asignará una victoria por abandono.")
  button("Seguir jugando",show_game)
  button("Abandonar",func(): office.network.send_playground("abandon",{"run_id":game.id}))
 elif not game.is_empty(): office.network.send_playground("return",{"run_id":game.id})
 else: close_panel()

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode == KEY_ESCAPE:
   if overlay.visible: request_close()
  elif event.keycode == KEY_E and not overlay.visible: interact()

func nearby() -> String:
 var p: Vector2 = office.player.position
 if zone == "office":
  if p.distance_to(Vector2(660,810)) < 76: return "buzon"
  if p.distance_to(Vector2(920,685)) < 76: return "arcade"
  if p.distance_to(Vector2(470,635)) < 76: return "workshop"
 else:
  if p.distance_to(Vector2(2100,730)) < 70: return "office"
  for i in range(6):
   if p.distance_to(Vector2(1870+(i%3)*220,390+(i/3)*150)) < 90: return KINDS[i]
 return ""

func _process(delta: float) -> void:
 var near := nearby()
 interact_button.visible = not near.is_empty() and not overlay.visible
 var names := {"buzon":"Buzón","arcade":"Sala de juegos","workshop":"Taller","office":"Volver a oficina"}
 interact_button.text = "E · " + str(names.get(near,near.capitalize()))
 if board and is_instance_valid(board) and not game.is_empty() and game.get("phase") == "playing" and not game.get("paused",false):
  game_clock += delta
  if game.kind == "pong" and game_clock > 0.1:
   game_clock = 0
   var axis: float = board.pong_axis
   if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W): axis = -1
   elif Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S): axis = 1
   play({"axis":axis})

func interact() -> void:
 var near := nearby()
 if near == "buzon": show_inbox()
 elif near in ["office","arcade","workshop"]: travel(near)
 elif near in KINDS:
  if zone == "workshop": show_creator(near)
  else: show_catalog(near)

func travel(destination: String) -> void:
 if not game.is_empty(): return
 if zone == "office" and destination != "office": return_position = office.player.position
 zone = destination
 room_art.zone = zone
 room_art.queue_redraw()
 office.player.position = return_position if zone == "office" else Vector2(2100,680)
 office.network.send_playground("travel",{"zone":zone})
 close_panel()
 office.resize()

func call_server(action: String, data := {}) -> Dictionary:
 var version := page_version
 var result: Dictionary = await office.network.rpc_playground(action,data)
 if version == page_version and not result.get("ok",false): note.text = result.get("error","No se pudo completar.")
 return result

func catalog() -> bool:
 if not templates.is_empty(): return true
 var result := await call_server("catalog")
 if not result.get("ok",false): return false
 templates = result.templates
 default_questions = result.questions
 return true

func open_home() -> void:
 if not game.is_empty(): show_game(); return
 page("Tu oficina, tus juegos","home")
 label("Explorá la oficina o atravesá las puertas. En el taller podés inventar un desafío con seis juegos de base.")
 button("Crear mi personaje",show_character)
 button("Sala de juegos · 6 minijuegos",func(): travel("arcade"))
 button("Taller · crear un desafío",func(): travel("workshop"))
 button("Mis desafíos / usar un código",show_library)
 button("Buzón de sugerencias",show_inbox)
 label("Para jugar de a dos: cerrá este panel, elegí Jugar con alguien y compartí el código de sala.")

func show_character() -> void:
 page("Tu personaje","character")
 var version := page_version
 label("Tu apariencia se guarda en este navegador. Elegí un nombre y tu estilo.")
 var preview = office.create_character_preview() if office.has_method("create_character_preview") else preload("res://scripts/character_preview.gd").new()
 body.add_child(preview)
 preview.update_profile(profile)
 var name_input := field("Nombre",str(profile.get("name","Explorador")),24)
 var skin := choose("Piel",["Marfil","Arena","Miel","Cobre","Cacao","Ébano"],int(profile.get("skin",1)))
 var hair := choose("Pelo",["Oscuro","Castaño","Dorado","Rubio","Ciruela","Plateado"],int(profile.get("hair",0)))
 var shirt := choose("Ropa",["Jade","Terracota","Azul","Mostaza","Malva","Crema"],int(profile.get("shirt",0)))
 var style := choose("Accesorio",["Clásico","Gorra","Auriculares"],int(profile.get("style",0)))
 var appearance := func() -> Dictionary: return {"name":name_input.text,"skin":skin.selected,"hair":hair.selected,"shirt":shirt.selected,"style":style.selected}
 var update_preview := func(_value): preview.update_profile(appearance.call())
 name_input.text_changed.connect(update_preview)
 for choice in [skin,hair,shirt,style]: choice.item_selected.connect(update_preview)
 button("Guardar personaje",func():
  if busy: return
  busy = true
  var result := await call_server("profile_save",{"profile":appearance.call()})
  busy = false
  if result.get("ok",false):
   profile = result.profile
   var file := FileAccess.open(profile_path,FileAccess.WRITE)
   if file: file.store_string(JSON.stringify(profile))
   office.player.profile = profile
   office.player.queue_redraw()
   office.network.send_playground("profile")
   if version == page_version: note.text = "Personaje guardado. ¡Listo para explorar!")
 button("Recuperar apariencia guardada",func():
  var result := await call_server("profile_get")
  if result.get("ok",false) and version == page_version: profile = result.profile; show_character())

func show_catalog(kind := "") -> void:
 page("Sala de juegos","catalog")
 var version := page_version
 label("Elegí un juego. Probalo con un rival de práctica o invitá a la otra persona de tu sala.")
 if not await catalog(): return
 if version != page_version: return
 for item in templates:
  if not kind.is_empty() and item.id != kind: continue
  label(item.name + " · " + item.description)
  button("Probar " + item.name,func(): start("builtin:"+item.id,true))
  button("Invitar a " + item.name,func(): start("builtin:"+item.id,false))
  button("Crear una variante",func(): show_creator(item.id))
 button("Ver los seis juegos",func(): show_catalog())

func show_library() -> void:
 page("Mis desafíos","library")
 var version := page_version
 if not await catalog(): return
 if version != page_version: return
 var result := await call_server("blueprint_list")
 if version != page_version or not result.get("ok",false): return
 var code := field("Código compartido","",50)
 button("Abrir desafío",func():
  var found := await call_server("blueprint_get",{"code":code.text.strip_edges()})
  if found.get("ok",false) and version == page_version: show_blueprint(found.blueprint,false))
 button("Crear un desafío",func(): show_creator("snake"))
 var items: Array = result.items if result.items is Array else []
 if items.is_empty(): label("Tu biblioteca está lista para tu primera creación.")
 for item in items:
  button(item.title + " · v" + str(int(item.revision)),func(): show_blueprint(item,true))

func show_blueprint(item: Dictionary, owned: bool) -> void:
 page(str(item.title),"blueprint")
 label(str(item.get("description","")))
 label("Plantilla: " + str(item.kind).capitalize() + " · Revisión " + str(int(item.revision)))
 button("Probar",func(): start(item.code,true,int(item.revision)))
 button("Invitar a mi compañero",func(): start(item.code,false,int(item.revision)))
 button("Copiar código",func(): DisplayServer.clipboard_set(item.code); note.text = "Código copiado.")
 var code := field("Código para compartir",item.code,50)
 code.editable = false
 if owned: button("Editar y guardar nueva versión",func(): show_creator(item.kind,item))
 button("Volver a mis desafíos",show_library)

func show_creator(kind: String, existing := {}) -> void:
 page("Crear un desafío","creator")
 var version := page_version
 if not await catalog(): return
 if version != page_version: return
 creator_key = str(existing.get("code",kind))
 # A newly saved creation can still have edits in its original template slot.
 # Opening it through the library must use that same pending draft.
 if existing.has("code") and creator_drafts.get(kind,{}).get("code","") == existing.code:
  creator_key = kind
 var initial: Dictionary = creator_drafts.get(creator_key,existing).duplicate(true)
 creator_identity = {}
 if initial.has("code"):
  creator_identity = {"code":initial.code,"revision":initial.revision}
 # Closures share this dictionary so later saves use the acknowledged revision.
 var identity := creator_identity
 var names: Array = []
 var selected := 0
 for i in range(templates.size()):
  names.append(templates[i].name)
  if templates[i].id == kind: selected = i
 var selector := choose("Juego de base",names,selected)
 creator_selector = selector
 selector.disabled = identity.has("code")
 selector.item_selected.connect(func(i):
  var previous: Dictionary = creator_capture.call()
  var next_kind: String = templates[i].id
  var next: Dictionary = creator_drafts.get(next_kind,{}).duplicate(true)
  next.title = previous.title
  next.description = previous.description
  creator_drafts[next_kind] = next
  show_creator(next_kind))
 var template: Dictionary = templates[selected]
 var title := field("Nombre del desafío",str(initial.get("title",template.name+" de la oficina")),48)
 var description := field("Descripción (opcional)",str(initial.get("description","")),240)
 label("El borrador se conserva en este navegador. Podés cambiar de juego o cerrar y seguir después.")
 var rules: Dictionary = initial.get("rules",template.defaults).duplicate(true)
 var controls := {}
 for f in template.fields:
  var selected_value: int = f.values.find(rules.get(f.id,template.defaults[f.id]))
  var choices: Array = []
  for v in f.values: choices.append(("Sí" if v else "No") if v is bool else str(int(v)))
  controls[f.id] = choose(f.name,choices,maxi(0,selected_value))
 var questions: Array = []
 if kind == "trivia":
  label("Escribí entre 3 y 10 preguntas. Completá 2 a 4 opciones por pregunta y elegí la correcta.")
  var source: Array = rules.get("questions",default_questions).duplicate(true)
  var question_count := choose("Cantidad de preguntas",[3,4,5,6,7,8,9,10],source.size()-3)
  question_count.item_selected.connect(func(i):
   var draft := capture_creator(kind,title,description,template,controls,questions,identity)
   var qs: Array = draft.rules.questions
   qs.resize(i+3)
   for q in range(qs.size()):
    if qs[q] == null: qs[q] = {"text":"","options":["",""],"answer":1}
   # The explicit replacement must win over the snapshot taken by page().
   creator_capture = Callable()
   creator_drafts[creator_key] = draft
   write_creator_drafts()
   show_creator(kind,existing))
  for i in range(source.size()):
   var q: Dictionary = source[i]
   var text := field("Pregunta " + str(i+1),q.text,160)
   var options: Array = []
   for j in range(4): options.append(field("Opción " + str(j+1) + (" (opcional)" if j>1 else ""),q.options[j] if j<q.options.size() else "",80))
   var answer := choose("Respuesta correcta",[1,2,3,4],int(q.get("answer",1))-1)
   questions.append({"text":text,"options":options,"answer":answer})
 creator_capture = func(): return capture_creator(kind,title,description,template,controls,questions,identity)
 var summary := PanelContainer.new()
 var summary_style := StyleBoxFlat.new()
 summary_style.bg_color = Color("172e28")
 summary_style.border_color = Color("698369")
 summary_style.set_border_width_all(1)
 summary_style.set_content_margin_all(12)
 summary.add_theme_stylebox_override("panel",summary_style)
 body.add_child(summary)
 var summary_text := Label.new()
 summary_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 summary_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 summary.add_child(summary_text)
 var refresh := func(_value):
  summary_text.text = creator_summary(creator_capture.call(),template)
  draft_timer.start()
 for control in body.get_children():
  if control is LineEdit: control.text_changed.connect(refresh)
  elif control is OptionButton and control != selector:
   # Count rebuilds the page, so its former controls cannot be read afterward.
   if control.item_selected.get_connections().is_empty(): control.item_selected.connect(refresh)
 summary_text.text = creator_summary(creator_capture.call(),template)
 button("Guardar desafío",func():
  if busy: return
  var draft := read_creator(kind,title,description,template,controls,questions,identity)
  if draft.has("error"):
   note.text = draft.error
   persist_creator()
   return
  var submitted: Dictionary = creator_capture.call()
  var submitted_key := creator_key
  persist_creator()
  busy = true
  var saved := await call_server("blueprint_save",{"blueprint":draft})
  busy = false
  if saved.get("ok",false):
   # Keep newer edits when a save was in flight while another form opened.
   if creator_capture.is_valid() and creator_key == submitted_key:
    persist_creator()
    creator_identity.code = saved.blueprint.code
    creator_identity.revision = saved.blueprint.revision
    creator_selector.disabled = true
   if creator_drafts.get(submitted_key,{}) == submitted:
    creator_drafts.erase(submitted_key)
   elif creator_drafts.has(submitted_key):
    var pending: Dictionary = creator_drafts[submitted_key]
    pending.code = saved.blueprint.code
    pending.revision = saved.blueprint.revision
   write_creator_drafts()
   if version == page_version:
    if creator_drafts.has(submitted_key):
     note.text = "Se guardó la versión enviada. Tus cambios nuevos siguen en este borrador."
     return
    creator_capture = Callable()
    show_blueprint(saved.blueprint,true)
    note.text = "Guardado. Podés probarlo o compartir el código.")
 button("Volver a mis desafíos",show_library)

func capture_creator(kind: String, title: LineEdit, description: LineEdit, template: Dictionary, controls: Dictionary, questions: Array, existing: Dictionary) -> Dictionary:
 var draft := {"kind":kind,"title":title.text,"description":description.text,"rules":{}}
 if existing.has("code"): draft.code = existing.code; draft.revision = existing.revision
 for f in template.fields: draft.rules[f.id] = f.values[controls[f.id].selected]
 if kind == "trivia":
  draft.rules.questions = []
  for q in questions:
   var options: Array = []
   for option in q.options: options.append(option.text)
   draft.rules.questions.append({"text":q.text.text,"options":options,"answer":q.answer.selected+1})
 return draft

func read_creator(kind: String, title: LineEdit, description: LineEdit, template: Dictionary, controls: Dictionary, questions: Array, existing: Dictionary) -> Dictionary:
 var draft := capture_creator(kind,title,description,template,controls,questions,existing)
 if title.text.strip_edges().is_empty(): return {"error":"Escribí un nombre para tu desafío."}
 if kind == "trivia":
  for i in range(draft.rules.questions.size()):
   var q: Dictionary = draft.rules.questions[i]
   var prefix := "Pregunta " + str(i+1) + ": "
   if str(q.text).strip_edges().is_empty(): return {"error":prefix+"escribí la pregunta."}
   if str(q.options[0]).strip_edges().is_empty() or str(q.options[1]).strip_edges().is_empty():
    return {"error":prefix+"completá las opciones 1 y 2."}
   if str(q.options[q.answer-1]).strip_edges().is_empty(): return {"error":prefix+"la respuesta correcta está vacía."}
   var compact: Array = []
   var answer := 1
   for j in range(q.options.size()):
    if not str(q.options[j]).strip_edges().is_empty():
     compact.append(str(q.options[j]).strip_edges())
     if j == q.answer-1: answer = compact.size()
   q.options = compact
   q.answer = answer
 return draft

func persist_creator() -> void:
 if creator_capture.is_valid():
  creator_drafts[creator_key] = creator_capture.call()
  write_creator_drafts()
 if draft_timer: draft_timer.stop()

func write_creator_drafts() -> void:
 var file := FileAccess.open(drafts_path,FileAccess.WRITE)
 if file: file.store_string(JSON.stringify(creator_drafts))

func creator_summary(draft: Dictionary, template: Dictionary) -> String:
 var lines := PackedStringArray(["VISTA PREVIA · " + str(template.name),str(draft.title)])
 if not str(draft.description).is_empty(): lines.append(str(draft.description))
 for f in template.fields:
  var value = draft.rules[f.id]
  lines.append(str(f.name) + ": " + (("Sí" if value else "No") if value is bool else str(value)))
 if draft.kind == "trivia":
  lines.append(str(draft.rules.questions.size()) + " preguntas")
  for i in range(draft.rules.questions.size()):
   var q: Dictionary = draft.rules.questions[i]
   lines.append(str(i+1) + ". " + str(q.text))
   var answer := str(q.options[int(q.answer)-1]).strip_edges()
   lines.append("✓ " + (answer if not answer.is_empty() else "Elegí una respuesta con texto"))
 lines.append("Se guardará cuando pulses Guardar desafío.")
 return "\n".join(lines)

func start(code: String, practice: bool, revision := 1) -> void:
 if office.network.match_id.is_empty(): await office.network.create_room()
 if office.network.match_id.is_empty(): note.text = "No se pudo abrir la sala."; return
 office.network.send_playground("practice" if practice else "invite",{"code":code,"revision":revision})
 note.text = "Preparando práctica…" if practice else "Invitación enviada. Esperando a tu compañero (30 segundos)."

func receive(data: Dictionary) -> void:
 if data.has("profile"):
  profile = data.profile
 if data.get("zone","office") != zone:
  zone = data.zone
  room_art.zone = zone
  room_art.queue_redraw()
  office.resize()
 var notice := str(data.get("notice",""))
 if notice != last_notice:
  last_notice = notice
  if not notice.is_empty(): note.text = notice
 var invitation: Dictionary = data.get("invitation",{})
 if not invitation.is_empty() and invitation.id != invitation_id:
  invitation_id = invitation.id
  if invitation.to == office.network.session.user_id:
   page("Te invitaron a jugar","invitation")
   label(invitation.title)
   label("La invitación dura 30 segundos. Aceptar abre el juego para ambos.")
   button("Aceptar",func(): office.network.send_playground("accept",{"invitation_id":invitation.id}))
   button("Ahora no",func(): office.network.send_playground("reject",{"invitation_id":invitation.id}); close_panel())
 elif invitation.is_empty() and not invitation_id.is_empty():
  invitation_id = ""
  note.text = "La invitación terminó. Podés volver a invitar."
  if screen == "invitation": close_panel(); office.status_label.text = "La invitación terminó."
 var next: Dictionary = data.get("game",{})
 if next.is_empty():
  if not game.is_empty(): game = {}; close_panel()
  return
 var changed: bool = game.get("id","") != next.id or game.get("phase","") != next.phase
 game = next
 if changed: show_game()
 if board and is_instance_valid(board): board.update_state(game)
 if screen == "game":
  note.text = "Partida pausada: esperando reconexión (hasta 30 s)." if game.get("paused",false) else "Práctica · resultado orientativo" if game.get("practice",false) else "Partida compartida · resultado del servidor"

func show_game() -> void:
 if game.is_empty(): close_panel(); return
 page(str(game.title),"game")
 board = load("res://scripts/playground_board.gd").new()
 body.add_child(board)
 board.action.connect(play)
 board.update_state(game)
 if game.phase == "finished":
  label(str(game.reason))
  var winner := str(game.get("winner",""))
  label("Partida interrumpida" if game.get("abandoned",false) else "Empate" if winner.is_empty() else "¡Ganaste!" if winner == office.network.session.user_id else "Ganó tu rival")
  button("Volver a la oficina",func(): office.network.send_playground("return",{"run_id":game.id}))
  label("Para la revancha, elegí el mismo desafío e invitá de nuevo.")
 else: button("Salir de la partida…",request_close)

func play(data: Dictionary) -> void:
 if game.is_empty() or game.get("paused",false): return
 var payload := data.duplicate()
 payload.run_id = game.id
 office.network.send_playground("play",payload)

func show_inbox() -> void:
 page("Buzón de la oficina","inbox")
 var version := page_version
 label("Compartí una idea o contanos qué falló. Sólo vos y Pedro pueden leer tu envío. La revisión es manual.")
 button("Escribir una sugerencia",suggest_form)
 var result := await call_server("suggest_list")
 if version != page_version or not result.get("ok",false): return
 label("Tus envíos")
 var items: Array = result.items if result.items is Array else []
 if items.is_empty(): label("Todavía no enviaste sugerencias.")
 for item in items:
  label(item.title + " · " + item.status)
  label(item.text)
  if not str(item.response).is_empty(): label("Respuesta: " + item.response)

func suggest_form() -> void:
 page("Dejá tu sugerencia","suggest")
 var version := page_version
 label("Hasta tres envíos por hora. Vas a poder consultar el estado y la respuesta acá.")
 var category := choose("Categoría",["Idea","Error","Otro"])
 var title := field("Título","",80)
 label("Tu sugerencia (10 a 2000 caracteres)")
 var text := TextEdit.new()
 text.custom_minimum_size.y = 160
 text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
 body.add_child(text)
 button("Enviar sugerencia",func():
  if busy: return
  busy = true
  var result := await call_server("suggest_create",{"category":["idea","error","otro"][category.selected],"title":title.text,"text":text.text})
  busy = false
  if result.get("ok",false) and version == page_version:
   await show_inbox()
   if page_version == version+1: note.text = "Envío guardado · " + result.id)
 button("Volver al buzón",show_inbox)

func connection_lost() -> void:
 if game.is_empty(): return
 page("Conexión interrumpida","reconnect")
 label("La partida espera hasta 30 segundos. Reconectá para seguir; si pasó más tiempo, podrás volver a la oficina.")
 button("Reconectar",func():
  await office.network.join_room(office.network.code_field.text)
  if office.network.match_id.is_empty(): note.text = "La sala ya no está disponible. Podés volver a explorar."
  elif not game.is_empty(): show_game())
 button("Volver a explorar",func(): game = {}; travel("office"))
