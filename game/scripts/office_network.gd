extends Node

const CLIENT_KEY := "office-preview-client-v1" # Public SDK identifier, not an admin credential.
signal playground_state(data: Dictionary)
var action_sequence := 0
var office: Node2D
var client: NakamaClient
var session: NakamaSession
var socket: NakamaSocket
var match_id := ""
var sequence := 0
var last_tick := -1
var elapsed := 0.0
var busy := false
var connecting := false
var dialog: Window
var code_field: LineEdit
var message: Label
var create_button: Button
var join_button: Button
var exit_button: Button
var dialog_column: VBoxContainer

func attach(target: Node2D) -> void:
 office = target
 var button := Button.new()
 button.text = "Jugar con alguien"
 button.position = Vector2(28,144)
 button.pressed.connect(func(): dialog.popup_centered())
 office.hud.add_child(button)
 dialog = Window.new()
 dialog.title = "Recorrer juntos · hasta 2 personas"
 dialog.size = Vector2i(350,285)
 dialog.transient = true
 dialog.exclusive = true
 dialog.close_requested.connect(dialog.hide)
 dialog.visibility_changed.connect(func(): office.player.input_blocked = dialog.visible; office.player.touch_input = Vector2.ZERO)
 dialog.visible = false
 add_child(dialog)
 var column := VBoxContainer.new()
 dialog_column = column
 column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 column.offset_left = 16
 column.offset_top = 16
 column.offset_right = -16
 column.offset_bottom = -16
 column.add_theme_constant_override("separation",12)
 dialog.add_child(column)
 message = Label.new()
 message.text = "Creá una sala y compartí el código."
 message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 column.add_child(message)
 create_button = Button.new()
 create_button.text = "Crear sala"
 create_button.pressed.connect(create_room)
 column.add_child(create_button)
 code_field = LineEdit.new()
 code_field.placeholder_text = "Pegá el código de sala"
 code_field.max_length = 100
 column.add_child(code_field)
 var row := HBoxContainer.new()
 column.add_child(row)
 join_button = Button.new()
 join_button.text = "Entrar / reconectar"
 join_button.pressed.connect(func(): join_room(code_field.text.strip_edges()))
 row.add_child(join_button)
 var copy := Button.new()
 copy.text = "Copiar"
 copy.pressed.connect(func(): DisplayServer.clipboard_set(code_field.text))
 row.add_child(copy)
 exit_button = Button.new()
 exit_button.text = "Salir de la sala"
 exit_button.pressed.connect(leave)
 column.add_child(exit_button)

func resize_dialog() -> void:
 if not dialog: return
 dialog.size = Vector2i(mini(350,int(office.get_viewport_rect().size.x)-24),285)
 if dialog.visible: dialog.popup_centered()

func device_id() -> String:
 if OS.has_feature("web"):
  return str(JavaScriptBridge.eval("localStorage.officeDevice ||= crypto.randomUUID()",true))
 var path := "user://office-device-id"
 if FileAccess.file_exists(path): return FileAccess.get_file_as_string(path)
 var id := Crypto.new().generate_random_bytes(24).hex_encode()
 var file := FileAccess.open(path,FileAccess.WRITE)
 file.store_string(id)
 return id

func create_office_socket(p_client: NakamaClient) -> NakamaSocket:
 var adapter = load("res://scripts/office_socket_adapter.gd").new()
 adapter.name = "OfficeWebSocketAdapter"
 adapter.logger = Nakama.logger
 Nakama.add_child(adapter)
 var scheme := "wss" if p_client.scheme == "https" else "ws"
 return NakamaSocket.new(adapter,p_client.host,p_client.port,scheme,true)

func connect_server() -> bool:
 while connecting: await get_tree().process_frame
 if socket and socket.is_connected_to_host(): return true
 connecting = true
 var host := "127.0.0.1"
 var scheme := "http"
 var port := int(OS.get_environment("OFFICE_BACKEND_PORT")) if OS.has_environment("OFFICE_BACKEND_PORT") else 17350
 if OS.has_feature("web"):
  host = str(JavaScriptBridge.eval("window.location.hostname",true))
  scheme = str(JavaScriptBridge.eval("window.location.protocol.slice(0,-1)",true))
  var location_port := str(JavaScriptBridge.eval("window.location.port",true))
  port = int(location_port) if not location_port.is_empty() else (443 if scheme == "https" else 80)
 client = Nakama.create_client(CLIENT_KEY,host,port,scheme,8,NakamaLogger.LOG_LEVEL.NONE)
 Nakama.get_client_adapter().auto_retry = false
 session = await client.authenticate_device_async(device_id())
 if session.is_exception(): connecting = false; report("No se pudo conectar. Podés seguir explorando."); return false
 socket = create_office_socket(client)
 socket.received_match_state.connect(receive_state)
 socket.closed.connect(disconnected)
 var result = await socket.connect_async(session,false,8)
 if result.is_exception(): connecting = false; report("Sin conexión con la sala. Intentá reconectar."); return false
 connecting = false
 return true

func set_busy(value: bool) -> void:
 busy = value
 create_button.disabled = value
 join_button.disabled = value
 exit_button.disabled = value
 office.reset_button.disabled = value
 if value: message.text = "Conectando con la sala…"

func create_room() -> void:
 if busy: return
 if office.has_method("prepare_multiplayer"): office.prepare_multiplayer()
 set_busy(true)
 if not await connect_server(): set_busy(false); return
 var result = await client.rpc_async(session,"office_create","{}")
 if result.is_exception(): report("No se pudo crear. Esperá 10 segundos e intentá otra vez."); set_busy(false); return
 var data = JSON.parse_string(result.payload)
 set_busy(false)
 await join_room(str(data.match_id))

func join_room(code: String) -> void:
 if busy: return
 if code.length() < 36 or code.length() > 100: report("Pegá el código completo de una sala."); return
 if office.has_method("prepare_multiplayer"): office.prepare_multiplayer()
 set_busy(true)
 if not await connect_server(): set_busy(false); return
 if not match_id.is_empty(): await socket.leave_match_async(match_id)
 clear_remote()
 match_id = ""
 var result = await socket.join_match_async(code)
 set_busy(false)
 if result.is_exception(): report("Sala llena, vencida o no disponible. Revisá el código."); return
 match_id = result.match_id
 code_field.text = match_id
 sequence = 0
 action_sequence = 0
 last_tick = -1
 office.player.position = Vector2(620,790)
 report("Sala abierta · compartí el código con otra persona.")
 dialog.hide()

func leave() -> void:
 if busy: return
 var old_id := match_id
 match_id = ""
 clear_remote()
 if socket and socket.is_connected_to_host() and not old_id.is_empty(): await socket.leave_match_async(old_id)
 report("Exploración local · WASD, flechas o controles táctiles")

func disconnected() -> void:
 match_id = ""
 clear_remote()
 report("Conexión perdida · abrí Jugar con alguien para reconectar.")
 if office.hub: office.hub.connection_lost()

func report(text: String) -> void:
 message.text = text
 office.status_label.text = text

func clear_remote() -> void:
 for node in office.remote_players.values(): node.queue_free()
 office.remote_players.clear()

func _process(delta: float) -> void:
 if match_id.is_empty() or not socket or not socket.is_connected_to_host(): return
 elapsed += delta
 if elapsed < 0.1: return
 elapsed = 0
 sequence += 1
 var input: Vector2 = office.player.move_input
 if dialog.visible: input = Vector2.ZERO
 socket.send_match_state_async(match_id,1,JSON.stringify({"seq":sequence,"x":input.x,"y":input.y}))

func receive_state(event) -> void:
 if event.match_id != match_id: return
 if event.op_code == 4:
  var view = JSON.parse_string(event.data)
  if view is Dictionary: playground_state.emit(view)
  return
 if event.op_code != 2: return
 var data = JSON.parse_string(event.data)
 if not data is Dictionary or not data.get("players") is Dictionary or int(data.get("tick",-1)) <= last_tick: return
 last_tick = int(data.tick)
 for id in office.remote_players.keys():
  if not data.players.has(id): office.remote_players[id].queue_free(); office.remote_players.erase(id)
 for id in data.players:
  var p = data.players[id]
  var position := Vector2(float(p.x),float(p.y))
  if id == session.user_id:
   office.player.profile = p.get("profile",office.player.profile)
   office.player.queue_redraw()
   if office.player.position.distance_to(position)>35: office.player.position = position
   continue
  if not office.remote_players.has(id):
   var avatar = load("res://scripts/office_player.gd").new()
   avatar.tint = Color("d18a51")
   avatar.collision_layer = 0
   avatar.collision_mask = 0
   avatar.set_physics_process(false)
   avatar.z_index = 10
   office.add_child(avatar)
   office.remote_players[id] = avatar
  office.remote_players[id].position = position
  office.remote_players[id].profile = p.get("profile",{})
  office.remote_players[id].visible = p.get("zone","office") == office.hub.zone
  office.remote_players[id].queue_redraw()
 office.status_label.text = "Sala conectada · %s/2 personas" % data.players.size()

func rpc_playground(action: String, data := {}) -> Dictionary:
 if not await connect_server(): return {"ok":false,"error":"No hay conexión. Tu borrador sigue abierto."}
 var payload: Dictionary = data.duplicate(true)
 payload.action = action
 var result = await client.rpc_async(session,"playground",JSON.stringify(payload))
 if result.is_exception(): return {"ok":false,"error":"No se pudo guardar. Revisá la conexión e intentá otra vez."}
 var decoded = JSON.parse_string(result.payload)
 return decoded if decoded is Dictionary else {"ok":false,"error":"Respuesta no válida."}

func send_playground(action: String, data := {}) -> void:
 if match_id.is_empty() or not socket or not socket.is_connected_to_host(): return
 action_sequence += 1
 var payload: Dictionary = data.duplicate(true)
 payload.action = action
 payload.seq = action_sequence
 socket.send_match_state_async(match_id,3,JSON.stringify(payload))
