extends SceneTree

var sockets: Array = []
var sessions: Array = []
var clients: Array = []
var snapshots: Array = [{},{},{}]
var room := ""
var concurrent_results := {}

func concurrent_join(index: int) -> void:
	var result = await sockets[index].join_match_async(room)
	concurrent_results[index] = not result.is_exception()

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> bool:
	if not value:
		printerr("NAKAMA_TEST_FAIL ",label)
		quit(1)
	return value

func pause(seconds: float) -> void:
	await create_timer(seconds).timeout

func state(event, index: int) -> void:
	if event.op_code == 2: snapshots[index] = JSON.parse_string(event.data)

func run() -> void:
	var api = root.get_node("Nakama")
	for i in range(3):
		var client = api.create_client("office-preview-client-v1","127.0.0.1",int(OS.get_environment("OFFICE_BACKEND_PORT")) if OS.has_environment("OFFICE_BACKEND_PORT") else 17350,"http",5,NakamaLogger.LOG_LEVEL.NONE)
		api.get_client_adapter().auto_retry = false
		clients.append(client)
		var session = await client.authenticate_device_async("office-test-"+Crypto.new().generate_random_bytes(16).hex_encode())
		if session.is_exception():
			print("AUTH_DIAGNOSTIC status=",session.get_exception().status_code," grpc=",session.get_exception().grpc_status_code," message=",session.get_exception().message)
			check(false,"authenticate")
			return
		sessions.append(session)
		var socket = api.create_socket_from(client)
		socket.received_match_state.connect(state.bind(i))
		sockets.append(socket)
		var connected = await socket.connect_async(session)
		if not check(not connected.is_exception(),"socket"): return
	var result = await clients[0].rpc_async(sessions[0],"office_create","{}")
	if not check(not result.is_exception(),"create"): return
	room = JSON.parse_string(result.payload).match_id
	for i in range(2):
		result = await sockets[i].join_match_async(room)
		if not check(not result.is_exception(),"join two"): return
	result = await sockets[2].join_match_async(room)
	if not check(result.is_exception(),"third rejected"): return
	await pause(0.4)
	if not check(snapshots[0].players.size()==2 and snapshots[1].players.size()==2,"both receive two identities"): return
	var id = sessions[0].user_id
	for i in range(20):
		await sockets[0].send_match_state_async(room,1,JSON.stringify({"seq":i,"x":0,"y":1}))
		await pause(0.1)
	await pause(0.3)
	var p = snapshots[1].players[id]
	if not check(p.y>800 and p.y<=831,"movement and outer-wall collision received by peer"): return
	var before = Vector2(p.x,p.y)
	await sockets[0].send_match_state_async(room,1,'{"seq":100,"x":9999,"y":0}')
	await sockets[0].send_match_state_async(room,1,'{"seq":1,"x":1,"y":0}')
	await sockets[0].send_match_state_async(room,1,'invalid json')
	var before_tick: int = snapshots[1].tick
	sockets[0]._adapter.send(JSON.stringify({"match_data_send":{"match_id":room,"op_code":1}}).to_utf8_buffer())
	await pause(0.5)
	if not check(snapshots[1].tick>before_tick,"missing payload does not terminate room"): return
	p = snapshots[1].players[id]
	if not check(before.distance_to(Vector2(p.x,p.y))<0.1,"invalid and stale inputs ignored"): return
	for i in range(100,160):
		await sockets[0].send_match_state_async(room,1,JSON.stringify({"seq":i,"x":1,"y":-1}))
	await pause(0.15)
	p = snapshots[1].players[id]
	if not check(before.distance_to(Vector2(p.x,p.y))<90,"message burst cannot teleport"): return
	await sockets[0].leave_match_async(room)
	await pause(0.3)
	if not check(snapshots[1].players.size()==1,"leave clears presence"): return
	sockets[0].close()
	await pause(0.3)
	sockets[0] = api.create_socket_from(clients[0])
	sockets[0].received_match_state.connect(state.bind(0))
	result = await sockets[0].connect_async(sessions[0])
	if not check(not result.is_exception(),"reconnect socket"): return
	result = await sockets[0].join_match_async(room)
	if not check(not result.is_exception(),"rejoin identity"): return
	await pause(0.3)
	if not check(snapshots[1].players.size()==2,"reconnect without duplicates"): return
	for i in range(2): await sockets[i].leave_match_async(room)
	result = await clients[2].rpc_async(sessions[2],"office_create","{}")
	if not check(not result.is_exception(),"create concurrent room"): return
	room = JSON.parse_string(result.payload).match_id
	for i in range(3): concurrent_join(i)
	await pause(1)
	if not check(concurrent_results.size()==3,"all concurrent joins settled"): return
	var accepted := 0
	for value in concurrent_results.values():
		if value: accepted += 1
	if not check(accepted==2,"concurrent admission caps at two"): return
	for socket in sockets: socket.close()
	print("NAKAMA_TEST_PASS auth socket two_players movement collision capacity malformed stale burst leave reconnect concurrent_capacity")
	await pause(0.2)
	quit()
