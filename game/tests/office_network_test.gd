extends SceneTree
var snapshot := {}
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> bool:
	if not value: printerr("OFFICE_NETWORK_FAIL ",label); quit(1)
	return value
func receive(event) -> void:
	if event.op_code==2: snapshot = JSON.parse_string(event.data)
func run() -> void:
	var office = load("res://scenes/office.tscn").instantiate()
	root.add_child(office)
	await process_frame
	if not check(not office.network.dialog.visible,"lobby initially hidden"): return
	office.network.set_busy(true)
	if not check(office.network.exit_button.disabled and office.reset_button.disabled,"exit and reset disabled during pending operation"): return
	office.network.set_busy(false)
	office.network.dialog.show()
	office.player.keyboard_enabled = false
	office.player.test_input = Vector2.UP
	var initial: Vector2 = office.player.position
	await create_timer(0.2).timeout
	if not check(office.player.position==initial and office.player.velocity==Vector2.ZERO,"modal blocks local movement"): return
	office.player.test_input = Vector2.ZERO
	office.network.dialog.hide()
	await office.network.create_room()
	if not check(not office.network.match_id.is_empty(),"scene creates room"): return
	var api = root.get_node("Nakama")
	var client = api.create_client("office-preview-client-v1","127.0.0.1",int(OS.get_environment("OFFICE_BACKEND_PORT")) if OS.has_environment("OFFICE_BACKEND_PORT") else 17350,"http",8,NakamaLogger.LOG_LEVEL.NONE)
	var session = await client.authenticate_device_async("office-peer-"+Crypto.new().generate_random_bytes(16).hex_encode())
	if not check(not session.is_exception(),"peer auth"): return
	var socket = api.create_socket_from(client)
	socket.received_match_state.connect(receive)
	var result = await socket.connect_async(session)
	if not check(not result.is_exception(),"peer socket"): return
	result = await socket.join_match_async(office.network.match_id)
	if not check(not result.is_exception(),"peer join"): return
	await create_timer(0.5).timeout
	if not check(office.remote_players.size()==1,"scene displays peer"): return
	office.player.keyboard_enabled = false
	office.player.test_input = Vector2.UP
	await create_timer(0.8).timeout
	office.player.test_input = Vector2.ZERO
	await create_timer(0.4).timeout
	if not check(snapshot.players[office.network.session.user_id].y<750,"peer receives scene movement"): return
	for i in range(7):
		await socket.send_match_state_async(office.network.match_id,1,JSON.stringify({"seq":i,"x":1,"y":0}))
		await create_timer(0.1).timeout
	if not check(office.remote_players[session.user_id].position.x>650,"scene receives peer movement"): return
	await socket.leave_match_async(office.network.match_id)
	await create_timer(0.4).timeout
	if not check(office.remote_players.is_empty(),"scene clears departed peer"): return
	socket.close()
	await office.network.leave()
	if not check(office.network.match_id.is_empty(),"scene leaves"): return
	office.network.socket.close()
	await create_timer(0.2).timeout
	print("OFFICE_NETWORK_PASS create join visible_peer bidirectional_movement leave")
	quit()
