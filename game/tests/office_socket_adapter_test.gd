extends SceneTree

var closed_count := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> bool:
 if not value:
  printerr("OFFICE_SOCKET_ADAPTER_FAIL ",label)
  quit(1)
 return value

func run() -> void:
 if not check(ResourceLoader.exists("res://scripts/office_socket_adapter.gd"),"background-aware adapter exists"): return
 var network = load("res://scripts/office_network.gd").new()
 root.add_child(network)
 var api = root.get_node("Nakama")
 var client = api.create_client("test","127.0.0.1",17350,"http")
 var socket = network.create_office_socket(client)
 var adapter = socket._adapter
 if not check(adapter._ws.inbound_buffer_size == 4*1024*1024,"receive buffer configured before connect"): return
 if not check(adapter._ws.get_ready_state() == WebSocketPeer.STATE_CLOSED,"constructor does not connect"): return
 adapter.closed.connect(func():
  closed_count += 1
  adapter.pump_network())
 adapter._ws_last_state = WebSocketPeer.STATE_OPEN
 adapter._background_pump([])
 if not check(closed_count == 1 and not adapter._pumping,"background pump handles transition without reentry"): return
 adapter._process(0.0)
 if not check(closed_count == 1,"frame pump shares last state with background pump"): return
 adapter.dispose_web_pump()
 adapter.dispose_web_pump()
 if not check(adapter._web_callback == null and not adapter._web_installed,"cleanup is idempotent in headless"): return
 socket = null
 network.queue_free()
 await process_frame
 print("OFFICE_SOCKET_ADAPTER_PASS buffer constructor shared_pump reentry cleanup")
 quit(0)
