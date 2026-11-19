extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run() -> void:
	var scene := load("res://scenes/office3d.tscn") as PackedScene
	if not scene:
		printerr("OFFICE3D_FAIL missing scene")
		quit(1)
		return
	var office = scene.instantiate()
	root.add_child(office)
	await process_frame
	await process_frame
	var world = office.world3d
	for kind in ["desk", "desk_square", "chair", "table", "sofa", "reception", "core", "plant", "arcade", "door", "mailbox", "avatar"]:
		expect(world.asset_scenes.get(kind) is PackedScene, "imported GLB: " + kind)
	expect(office.local_avatar.left_leg != null and office.local_avatar.right_leg != null, "Blender avatar leg pivots")
	expect(office.local_avatar.palette.has_all(["skin", "hair", "shirt"]), "Blender avatar materials")
	expect(world is Node3D and world.camera is Camera3D and world.camera.current, "active 3D camera")
	expect(not office.camera.enabled and office.player.modulate.a == 0.0, "hidden planar simulation")
	expect(not office.map_mode and office.zoom_button.text == "Mapa", "follow camera starts active")
	expect(world.objects_root.get_child_count() > 20, "canonical furniture")
	expect(world.doors.size() >= 8, "canonical doors")
	var screen: Vector2 = world.camera.unproject_position(world.map_to_world(office.player.position))
	expect(world.screen_to_map(screen).distance_to(office.player.position) < 0.1, "screen-to-floor roundtrip")
	var door: Dictionary = world.doors.filter(func(entry: Dictionary) -> bool: return entry.zone == "office")[0]
	expect(door.model is Node3D and door.hinge.get_node_or_null("LeafGeometry") is Node3D, "Blender door leaf geometry")
	expect(is_equal_approx(door.model.scale.z, 0.22) and door.hinge.scale.is_equal_approx(Vector3.ONE), "thin door frame and rigid swing pivot")
	office.player.position = door.center
	world.update_doors(office.player.position, "office", 1.0)
	expect(absf(door.hinge.rotation.y) > 1.0, "door opens on approach")
	world.update_doors(Vector2.ZERO, "office", 1.0)
	expect(absf(door.hinge.rotation.y) < 0.05, "door closes after departure")

	office.player.position = Vector2(920, 685)
	office.hub.interact()
	await process_frame
	await process_frame
	expect(office.hub.zone == "arcade" and world.room_root.visible, "arcade travel updates 3D zone")
	expect(office.local_avatar.position.distance_to(world.map_to_world(Vector2(2100, 680))) < 0.1, "avatar follows arcade spawn")
	office.player.position = Vector2(2100, 730)
	office.hub.interact()
	await process_frame
	await process_frame
	expect(office.hub.zone == "office" and world.office_root.visible, "office return updates 3D zone")

	var remote = load("res://scripts/office_player.gd").new()
	remote.set_physics_process(false)
	remote.position = Vector2(645, 790)
	remote.profile = {"name": "Visitante", "shirt": 4}
	office.add_child(remote)
	office.remote_players["remote"] = remote
	office._process(0.016)
	var avatar = office.remote_avatars["remote"]
	expect(avatar.nameplate.text == "Visitante" and avatar.visible, "remote profile and presence")
	if avatar.palette.has("shirt") and office.local_avatar.palette.has("shirt"):
		expect(avatar.palette.shirt.albedo_color != office.local_avatar.palette.shirt.albedo_color, "instance-local profile materials")
	remote.visible = false
	office._process(0.016)
	expect(not avatar.visible, "remote zone visibility")
	office.remote_players.erase("remote")
	office._process(0.016)
	expect(office.remote_avatars.is_empty(), "remote departure")
	test_editor(office)
	var preview = office.create_character_preview()
	office.hud.add_child(preview)
	preview.update_profile({"skin": 4, "hair": 2, "shirt": 1, "style": 2})
	await process_frame
	expect(preview.get_child(0).own_world_3d, "avatar preview has an isolated 3D world")
	expect(preview.avatar.headphones.visible and not preview.avatar.hat.visible, "avatar preview updates the profile")
	expect(preview.avatar.palette.shirt.albedo_color == Color("ce7456"), "avatar preview updates imported materials")
	office.queue_free()
	await process_frame
	if failures.is_empty():
		print("OFFICE3D_PASS GLB_assets camera layout projection doors travel avatar remote_presence editor")
	else:
		for failure in failures:
			printerr("OFFICE3D_FAIL " + failure)
	quit(0 if failures.is_empty() else 1)

func test_editor(office: Node2D) -> void:
	var editor = office.map_editor
	var world = office.world3d
	var store = load("res://scripts/office_layout_store.gd")
	expect(editor.menu.get_index() < office.hub.overlay.get_index(), "game overlay stays above office editor entry")
	editor.layout = store.canonical()
	var baseline: int = editor.layout.objects.size()
	editor.toggle()
	expect(editor.active and world.editor_active and office.player.input_blocked, "map editing blocks movement")
	expect(office.hub.home_button.disabled and office.hub.interact_button.disabled, "map editing blocks play controls")
	editor.add_piece()
	var item: Dictionary = editor.layout.objects[editor.selected]
	var id: String = item.id
	var before := Vector2(item.x, item.y)
	expect(world.objects_by_id.size() == baseline + 1 and world.objects_by_id.has(id), "editor adds rendered object")
	editor.rotate_selected()
	expect(is_equal_approx(world.objects_by_id[id].rotation.y, PI / 2), "editor rotates rendered object")
	editor.move_selected(Vector2(16, 0))
	expect(world.objects_by_id[id].position.distance_to(world.map_to_world(before + Vector2(16, 0))) < 0.001, "editor moves rendered object")
	editor.undo()
	expect(world.objects_by_id[id].position.distance_to(world.map_to_world(before)) < 0.001, "editor undoes movement")
	office.prepare_multiplayer()
	expect(not editor.active and not office.player.input_blocked, "multiplayer preparation closes editor and restores input")
	expect(world.objects_by_id.size() == baseline and not world.objects_by_id.has(id), "multiplayer restores canonical geometry")
	expect(editor.layout.objects.size() == baseline + 1, "multiplayer preserves local draft")
	for pending in ["busy", "connecting"]:
		office.network.set(pending, true)
		editor.toggle()
		expect(not editor.active and not world.objects_by_id.has(id), "hidden network dialog cannot reopen draft while " + pending)
		office.network.set(pending, false)
