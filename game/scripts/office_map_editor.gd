extends Node

const Store = preload("res://scripts/office_layout_store.gd")
const NAMES := ["Escritorio","Escritorio cuadrado","Silla","Mesa","Sofá","Recepción","Bloque","Planta","Pared"]
var office: Node2D
var layout: Dictionary
var active := false
var selected := -1
var history: Array[Dictionary] = []
var panel: PanelContainer
var menu: Button
var pieces: OptionButton
var palette: OptionButton
var info: Label
var status: Label
var transfer: TextEdit
var position_fields: Array[SpinBox] = []
var updating := false
var collision_root: Node2D
var custom_active := false
var dragging := false
var drag_new := false
var drag_before: Dictionary = {}
var drag_offset := Vector2.ZERO
var drag_start := Vector2.ZERO
var drag_valid := false
var drag_moved := false
var drag_pointer := -1
var trash: Button
var hidden_hud: Array[Control] = []

func attach(target: Node2D) -> void:
 office = target
 layout = Store.load_local()
 menu = Button.new()
 menu.text = "Editar mapa 3D"
 menu.pressed.connect(toggle)
 office.hud.add_child(menu)
 office.hud.move_child(menu,office.hub.overlay.get_index())
 panel = PanelContainer.new()
 panel.add_theme_stylebox_override("panel",office.style(Color("203d35")))
 office.hud.add_child(panel)
 var scroll := ScrollContainer.new()
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 panel.add_child(scroll)
 var body := VBoxContainer.new()
 body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 body.add_theme_constant_override("separation",8)
 scroll.add_child(body)
 var title := Label.new()
 title.text = "TU OFICINA · EDITOR 3D"
 body.add_child(title)
 info = Label.new()
 info.text = "Arrastrá las piezas para moverlas.\nSoltalas en Quitar para eliminarlas.\nEscape cancela · Deshacer recupera cambios."
 info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 body.add_child(info)
 pieces = OptionButton.new()
 pieces.fit_to_longest_item = false
 pieces.item_selected.connect(select_piece)
 body.add_child(pieces)
 var move_row := HBoxContainer.new()
 body.add_child(move_row)
 for spec in [["X-",Vector2(-10,0)],["Z-",Vector2(0,-10)],["Z+",Vector2(0,10)],["X+",Vector2(10,0)]]:
  add_button(move_row,spec[0],func(): move_selected(spec[1]))
 var fields := HBoxContainer.new()
 body.add_child(fields)
 for i in range(2):
  var field := SpinBox.new()
  field.min_value = 0 if i==0 else 90
  field.max_value = 1230 if i==0 else 880
  field.step = 10
  field.prefix = "X" if i==0 else "Z"
  field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  field.value_changed.connect(func(value): set_coordinate(i,value))
  fields.add_child(field)
  position_fields.append(field)
 var edit_row := HBoxContainer.new()
 body.add_child(edit_row)
 add_button(edit_row,"Girar 90°",rotate_selected)
 trash = Button.new()
 trash.text = "Quitar"
 trash.tooltip_text = "Soltá una pieza aquí para eliminarla; Deshacer la recupera."
 trash.pressed.connect(remove_selected)
 edit_row.add_child(trash)
 add_button(edit_row,"Deshacer",undo)
 palette = OptionButton.new()
 for label in NAMES: palette.add_item(label)
 body.add_child(palette)
 var source := Button.new()
 source.text = "Arrastrar pieza al mapa"
 source.custom_minimum_size.y = 44
 source.gui_input.connect(palette_input.bind(source))
 body.add_child(source)
 add_button(body,"Agregar en el centro",add_piece)
 var save_row := HBoxContainer.new()
 body.add_child(save_row)
 add_button(save_row,"Guardar borrador",save)
 add_button(save_row,"Probar",toggle)
 add_button(body,"Restaurar distribución original",reset_layout)
 add_button(body,"Exportar mapa (.json)",export_layout)
 transfer = TextEdit.new()
 transfer.placeholder_text = "Pegá un mapa JSON para importarlo"
 transfer.custom_minimum_size.y = 64
 body.add_child(transfer)
 add_button(body,"Importar texto",import_layout)
 status = Label.new()
 status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 body.add_child(status)
 panel.hide()
 office.get_viewport().size_changed.connect(resize)
 resize()
 refresh()
 # Loading a draft is explicit: the published shared map is always the startup default.

func add_button(parent: Node,text: String,action: Callable) -> void:
 var b := Button.new()
 b.text = text
 b.pressed.connect(action)
 parent.add_child(b)

func resize() -> void:
 var size := office.get_viewport_rect().size
 menu.position = Vector2(18,238 if size.x<370 else 192)
 menu.size = Vector2(152,36)
 if size.x < 900:
  var height := minf(330, size.y * 0.46)
  panel.position = Vector2(12, size.y-height-12)
  panel.size = Vector2(size.x-24,height)
 else:
  panel.position = Vector2(size.x-340,60)
  panel.size = Vector2(328,maxf(240,size.y-76))
 if active: menu.position = Vector2(12,12)
 if dragging: cancel_drag()

func toggle() -> void:
 if not active and (office.network.busy or office.network.connecting):
  office.status_label.text = "Esperá a que termine la conexión para editar el mapa."
  return
 if not active and not office.network.match_id.is_empty():
  office.status_label.text = "Salí de la sala para editar tu borrador local."
  return
 if not active and (office.hub.screen!="" or office.network.dialog.visible): return
 if dragging: cancel_drag()
 active = not active
 if active:
  for child in office.hud.get_children():
   if child is Control and child != menu and child != panel and child.visible:
    hidden_hud.append(child)
    child.hide()
 else:
  for child in hidden_hud:
   if is_instance_valid(child): child.show()
  hidden_hud.clear()
 if active:
  office.hub.travel("office")
  office.map_mode = true
  apply()
 office.player.input_blocked = active
 office.player.touch_input = Vector2.ZERO
 office.hub.set_process(not active)
 office.hub.home_button.disabled = active
 office.hub.interact_button.disabled = active
 for child in office.hud.get_children():
  if child is Button and child.text == "Jugar con alguien": child.disabled = active
 office.world3d.set_editor_active(active)
 panel.visible = active
 menu.text = "Cerrar editor" if active else "Editar mapa 3D"
 resize()
 if active: refresh()

func _unhandled_input(event: InputEvent) -> void:
 if not active or dragging: return
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode == KEY_DELETE and not office.get_viewport().gui_get_focus_owner() is LineEdit and not transfer.has_focus():
   remove_selected()
   get_viewport().set_input_as_handled()
 elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
  begin_existing_drag(event.position)
 elif event is InputEventScreenTouch and event.pressed:
  begin_existing_drag(event.position,event.index)

func _input(event: InputEvent) -> void:
 if not active or not dragging: return
 if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
  cancel_drag()
  get_viewport().set_input_as_handled()
 elif event is InputEventMouseMotion and drag_pointer == -1:
  update_drag(event.position)
  get_viewport().set_input_as_handled()
 elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and drag_pointer == -1:
  finish_drag(event.position)
  get_viewport().set_input_as_handled()
 elif event is InputEventScreenDrag and event.index == drag_pointer:
  update_drag(event.position)
  get_viewport().set_input_as_handled()
 elif event is InputEventScreenTouch and not event.pressed and event.index == drag_pointer:
  finish_drag(event.position)
  get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT and dragging: cancel_drag()

func palette_input(event: InputEvent, source: Control) -> void:
 if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
  begin_palette_drag(get_viewport().get_mouse_position())
 elif event is InputEventScreenTouch and event.pressed:
  begin_palette_drag(source.get_global_transform() * event.position,event.index)

func begin_existing_drag(screen: Vector2, pointer := -1) -> void:
 var id: String = office.world3d.pick_object(screen)
 for i in range(layout.objects.size()):
  if layout.objects[i].id == id:
   select_piece(i)
   start_drag(screen,false,pointer)
   return

func begin_palette_drag(screen: Vector2, pointer := -1) -> void:
 if not active or dragging: return
 if layout.objects.size() >= 250: status.text="Límite de 250 piezas.";return
 drag_before = layout.duplicate(true)
 layout.objects.append(new_piece())
 selected = layout.objects.size()-1
 office.world3d.add_layout_object(layout.objects[selected])
 start_drag(screen,true,pointer)

func start_drag(screen: Vector2, is_new: bool, pointer: int) -> void:
 dragging=true
 drag_new=is_new
 if not is_new: drag_before=layout.duplicate(true)
 drag_start=screen
 drag_moved=false
 drag_valid=false
 drag_pointer=pointer
 var item: Dictionary=layout.objects[selected]
 drag_offset=Vector2.ZERO if is_new else Vector2(item.x,item.y)-office.world3d.screen_to_map(screen)
 refresh()
 status.text="Arrastrá al mapa. Escape cancela."
 get_viewport().set_input_as_handled()

func update_drag(screen: Vector2) -> void:
 if not dragging: return
 drag_moved=drag_moved or screen.distance_to(drag_start)>4
 var point: Vector2=office.world3d.screen_to_map(screen)+drag_offset
 if not point.is_finite(): drag_valid=false;return
 var item: Dictionary=layout.objects[selected]
 item.x=snappedf(point.x,10)
 item.y=snappedf(point.y,10)
 drag_valid=not panel.get_global_rect().has_point(screen) and Store.validate(layout).is_empty()
 office.world3d.move_layout_object(item)
 status.text="Soltá para colocar · ajuste de 10" if drag_valid else "Fuera del mapa: al soltar se cancela."
 if trash.get_global_rect().has_point(screen) and not drag_new: status.text="Soltá para quitar la pieza."

func finish_drag(screen: Vector2) -> void:
 if not dragging: return
 if not drag_moved:
  cancel_drag()
  return
 update_drag(screen)
 var remove := not drag_new and trash.get_global_rect().has_point(screen)
 if not drag_valid and not remove:
  cancel_drag()
  status.text="Movimiento cancelado: soltá dentro de la oficina."
  return
 dragging=false
 if remove:
  layout.objects.remove_at(selected)
 history.append(drag_before)
 if history.size()>30: history.pop_front()
 apply()
 refresh()
 status.text="Pieza quitada. Deshacer la recupera." if remove else "Pieza colocada. Guardá el borrador para conservarla."
 drag_before={}

func cancel_drag() -> void:
 if not dragging: return
 dragging=false
 layout=drag_before
 drag_before={}
 apply()
 refresh()
 status.text="Arrastre cancelado."

func new_piece() -> Dictionary:
 var kind: String=Store.KINDS[palette.selected]
 return {"id":"piece_"+str(Time.get_ticks_usec()),"kind":kind,"x":620.0,"y":740.0,"w":60.0 if kind!="plant" else 20.0,"d":6.0 if kind=="wall" else 30.0,"rotation":0.0,"zone":"office"}

func refresh() -> void:
 updating = true
 pieces.clear()
 for item in layout.objects: pieces.add_item("%s · %s" % [NAMES[Store.KINDS.find(item.kind)],item.id])
 selected = clampi(selected,0,layout.objects.size()-1) if not layout.objects.is_empty() else -1
 if selected>=0:
  pieces.select(selected)
  position_fields[0].value=layout.objects[selected].x
  position_fields[1].value=layout.objects[selected].y
 if office.world3d.has_method("set_selected_object"):
  office.world3d.set_selected_object(str(layout.objects[selected].id) if selected>=0 else "")
 updating = false

func select_piece(index: int) -> void:
 selected=index
 refresh()
 status.text = "Pieza seleccionada: "+str(layout.objects[index].id) if index>=0 else "Sin piezas"

func remember() -> void:
 history.append(layout.duplicate(true))

func apply_edit() -> void:
 var problem := Store.validate(layout)
 if not problem.is_empty():
  layout=history.pop_back()
  status.text=problem
  refresh()
  return
 if history.size()>30: history.pop_front()
 apply()
 refresh()

func move_selected(delta: Vector2) -> void:
 if selected<0:return
 remember()
 layout.objects[selected].x=clampf(layout.objects[selected].x+delta.x,0,1230)
 layout.objects[selected].y=clampf(layout.objects[selected].y+delta.y,90,880)
 apply_edit()

func set_coordinate(axis: int,value: float) -> void:
 if updating or selected<0:return
 remember()
 layout.objects[selected]["x" if axis==0 else "y"]=value
 apply_edit()

func rotate_selected() -> void:
 if selected<0:return
 remember()
 layout.objects[selected].rotation=fposmod(float(layout.objects[selected].rotation)+PI/2,TAU)
 apply_edit()

func remove_selected() -> void:
 if selected<0:return
 remember();layout.objects.remove_at(selected);apply_edit()

func add_piece() -> void:
 if layout.objects.size()>=250:status.text="Límite de 250 piezas.";return
 remember()
 layout.objects.append(new_piece())
 selected=layout.objects.size()-1
 apply_edit()

func undo() -> void:
 if history.is_empty():return
 layout=history.pop_back();apply();refresh()

func reset_layout() -> void:
 remember();layout=Store.canonical();apply_edit()
 status.text="Distribución original recuperada. Deshacer vuelve al borrador anterior."

func apply() -> void:
 custom_active=true
 office.world3d.apply_layout(layout)
 rebuild_collisions(layout)

func save() -> void:
 status.text="Borrador guardado en este navegador. Exportalo para compartirlo." if Store.save_local(layout) else "No se pudo guardar el borrador."

func export_layout() -> void:
 var text := JSON.stringify(Store.sanitized(layout),"  ")
 if OS.has_feature("web"):
  JavaScriptBridge.download_buffer(text.to_utf8_buffer(),"oficina-mapa.json","application/json")
 else:
  var file := FileAccess.open("user://oficina-mapa.json",FileAccess.WRITE)
  if not file or not file.store_string(text):
   status.text="No se pudo exportar el mapa."
   return
 transfer.text=text
 status.text="Mapa exportado. Conservá el JSON para otros equipos o desarrolladores."

func import_layout() -> void:
 if transfer.text.length()>200000:status.text="Archivo demasiado grande.";return
 var value = JSON.parse_string(transfer.text)
 var problem := Store.validate(value)
 if not problem.is_empty():status.text=problem;return
 remember();layout=Store.sanitized(value);apply_edit()
 status.text="Mapa importado como borrador local. Guardá para conservarlo."

func prepare_multiplayer() -> void:
 if active:toggle()
 if custom_active:
  office.world3d.apply_layout(Store.canonical())
  rebuild_collisions(Store.canonical())
  custom_active=false
  office.player.position=Vector2(620,790)

func rebuild_collisions(data: Dictionary) -> void:
 # Preserve the existing server's canonical planar contract. Draft collisions only affect local play.
 for child in office.get_children():
  if child.get_script()==load("res://scripts/office_map.gd"):
   for body in child.get_children():
    if body is StaticBody2D: body.collision_layer=0;body.collision_mask=0
 if collision_root:
  office.remove_child(collision_root);collision_root.queue_free()
 collision_root=Node2D.new();office.add_child(collision_root)
 for i in range(data.outline.size()):
  var a: Array=data.outline[i];var b: Array=data.outline[(i+1)%data.outline.size()]
  var segment:=SegmentShape2D.new();segment.a=Vector2(a[0],a[1]);segment.b=Vector2(b[0],b[1])
  add_collider(segment,Vector2.ZERO,0)
 for r in data.walls:
  var shape:=RectangleShape2D.new();shape.size=Vector2(r[2],r[3]);add_collider(shape,Vector2(r[0]+r[2]/2.0,r[1]+r[3]/2.0),0)
 for item in data.objects:
  if item.kind in ["chair","plant"]:continue
  var shape:=RectangleShape2D.new();shape.size=Vector2(item.w,item.d)
  add_collider(shape,Vector2(item.x,item.y),-float(item.rotation))

func add_collider(shape: Shape2D,position: Vector2,rotation: float) -> void:
 var body:=StaticBody2D.new();var collision:=CollisionShape2D.new()
 collision.shape=shape;body.position=position;body.rotation=rotation
 body.add_child(collision);collision_root.add_child(body)
