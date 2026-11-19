extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> bool:
	if not value:
		printerr("OFFICE_TEST_FAIL ",message)
		quit(1)
	return value

func run() -> void:
	var scene = load("res://scenes/office.tscn")
	if scene == null:
		push_error("office scene missing")
		quit(1)
		return
	var office = scene.instantiate()
	root.add_child(office)
	await process_frame
	var player = office.player
	player.keyboard_enabled = false
	player.test_input = Vector2(1, 1)
	await physics_frame
	await physics_frame
	if not check(abs(player.velocity.length() - player.SPEED) < 0.1, "diagonal must normalize"): return
	player.position = Vector2(160, 800)
	player.test_input = Vector2.DOWN
	for i in range(60):
		await physics_frame
	if not check(player.position.y < 840, "outer wall must stop player"): return
	player.position = Vector2(180, 600)
	player.test_input = Vector2.RIGHT
	for i in range(20):
		await physics_frame
	if not check(player.position.x > 215, "corridor must be traversable"): return
	player.test_input = Vector2.ZERO
	await physics_frame
	await physics_frame
	if not check(player.velocity == Vector2.ZERO, "released input must stop player"): return
	print("OFFICE_TEST_PASS movement diagonal wall corridor release")
	quit(0)
