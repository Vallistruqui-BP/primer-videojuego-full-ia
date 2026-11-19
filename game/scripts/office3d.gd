extends "res://scripts/office.gd"

const WORLD_SCRIPT := preload("res://scripts/world3d.gd")
const AVATAR_SCRIPT := preload("res://scripts/avatar3d.gd")
const LAYOUT_PATH := "res://data/office_layout.json"

var world3d: Node3D
var local_avatar: Node3D
var remote_avatars: Dictionary[String, Node3D] = {}
var map_editor: Node

func _ready() -> void:
	super._ready()
	camera.enabled = false
	map_mode = false
	resize()
	for child in get_children():
		if child is Node2D:
			hide_planar_render(child)
	world3d = WORLD_SCRIPT.new()
	world3d.name = "World3D"
	add_child(world3d)
	var layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	if layout is Dictionary:
		world3d.apply_layout(layout)
	local_avatar = make_avatar()
	local_avatar.name = "LocalAvatar3D"
	sync_3d(0.0)
	map_editor = load("res://scripts/office_map_editor.gd").new()
	add_child(map_editor)
	map_editor.attach(self)

func _process(delta: float) -> void:
	super._process(delta)
	if world3d:
		sync_3d(delta)

func sync_3d(delta: float) -> void:
	var zone: String = hub.zone
	world3d.update_camera(player.position, zone, map_mode)
	world3d.update_doors(player.position, zone, delta)
	local_avatar.sync(player, delta, true)
	for id in remote_avatars.keys():
		if not remote_players.has(id):
			remote_avatars[id].queue_free()
			remote_avatars.erase(id)
	for id in remote_players:
		var planar: CharacterBody2D = remote_players[id]
		if not is_instance_valid(planar):
			continue
		if not remote_avatars.has(id):
			hide_planar_render(planar)
			remote_avatars[id] = make_avatar()
		remote_avatars[id].sync(planar, delta, false)

func make_avatar() -> Node3D:
	var avatar := AVATAR_SCRIPT.new()
	world3d.add_child(avatar)
	avatar.init(world3d)
	return avatar

func hide_planar_render(node: Node2D) -> void:
	# Keep visibility flags and processing for the planar simulation and network.
	node.modulate.a = 0.0

func prepare_multiplayer() -> void:
	map_editor.prepare_multiplayer()

func create_character_preview() -> Control:
	return load("res://scripts/character_preview3d.gd").new()
