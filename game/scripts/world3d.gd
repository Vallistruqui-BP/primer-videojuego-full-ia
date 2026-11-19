extends Node3D

const SIZE := 40.0
const ASSET_PATH := "res://art/office3d/%s.glb"
const STATIONS := ["Snake", "Terminal", "Pong", "Ta-te-ti", "Memoria", "Trivia"]

var camera: Camera3D
var office_root: Node3D
var room_root: Node3D
var objects_root: Node3D
var objects_by_id: Dictionary[String, Node3D] = {}
var doors: Array[Dictionary] = []
var editor_active := false
var layout_bounds := Rect2(20, 90, 1210, 790)
var asset_scenes: Dictionary[String, PackedScene] = {}
var materials: Dictionary[Color, StandardMaterial3D] = {}
var room_floor: MeshInstance3D
var shown_zone := ""
var selection: MeshInstance3D
var selected_id := ""

static func map_to_world(point: Vector2, height := 0.0) -> Vector3:
	return Vector3(point.x / SIZE, height, point.y / SIZE)

func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("263e3c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d7e8e7")
	environment.ambient_light_energy = 0.44
	var atmosphere := WorldEnvironment.new()
	atmosphere.environment = environment
	add_child(atmosphere)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -28, 0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = 0.74
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 95
	add_child(sun)

	camera = Camera3D.new()
	camera.fov = 38
	camera.far = 180
	add_child(camera)
	camera.make_current()
	office_root = Node3D.new()
	office_root.name = "Office"
	add_child(office_root)
	room_root = Node3D.new()
	room_root.name = "Playground"
	add_child(room_root)
	build_playground()

func apply_layout(data: Dictionary) -> void:
	for child in office_root.get_children():
		office_root.remove_child(child)
		child.queue_free()
	doors = doors.filter(func(door: Dictionary) -> bool: return door.zone != "office")
	objects_by_id.clear()
	selection = null
	objects_root = Node3D.new()
	objects_root.name = "Furniture"
	office_root.add_child(objects_root)

	var outline := PackedVector2Array()
	for point in data.get("outline", []):
		outline.append(Vector2(point[0], point[1]))
	if outline.size() >= 3:
		make_floor(outline)
		for i in range(outline.size()):
			add_wall_segment(outline[i], outline[(i + 1) % outline.size()])
	for room in data.get("rooms", []):
		var center := Vector2(room.x + room.w / 2.0, room.y + room.d / 2.0)
		add_box(office_root, map_to_world(center, 0.003), Vector3(room.w / SIZE, 0.014, room.d / SIZE), Color("becaba"))
		add_label(office_root, center + Vector2(0, room.d * 0.3), str(room.title), 0.018, true, 0.29)
	for wall in data.get("walls", []):
		var center := Vector2(wall[0] + wall[2] / 2.0, wall[1] + wall[3] / 2.0)
		add_box(office_root, map_to_world(center, 0.50), Vector3(wall[2] / SIZE, 1.0, wall[3] / SIZE), Color("637d73"))
	for object in data.get("objects", []):
		var id := str(object.id)
		var node := add_prop(objects_root, str(object.kind), Vector2(object.x, object.y), Vector2(object.w, object.d), float(object.get("rotation", 0)))
		node.set_meta("layout_id", id)
		node.set_meta("footprint", Vector2(object.w, object.d))
		objects_by_id[id] = node
	for door in data.get("doors", []):
		add_door(office_root, Vector2(door.x, door.y), float(door.width), float(door.rotation), "office")
	for label in data.get("labels", []):
		add_label(office_root, Vector2(label.x, label.y), str(label.text), 0.022, true, 0.35)
	add_portal(office_root, Vector2(470, 635), "TALLER", Color("cf9552"), "office")
	add_portal(office_root, Vector2(920, 685), "ARCADE", Color("a86aa0"), "office")
	add_prop(office_root, "mailbox", Vector2(660, 810), Vector2(25, 22))
	add_label(office_root, Vector2(660, 825), "BUZÓN", 0.03, true, 0.36)
	set_selected_object(selected_id)

func make_floor(outline: PackedVector2Array) -> void:
	layout_bounds = Rect2(outline[0], Vector2.ZERO)
	for point in outline:
		layout_bounds = layout_bounds.expand(point)
	var indices := Geometry2D.triangulate_polygon(outline)
	if indices.is_empty():
		return
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.set_material(material(Color("ddc9aa")))
	# Godot renders clockwise front faces. Keep mesh indices aligned to +Y.
	for i in range(0, indices.size(), 3):
		for offset in [0, 1, 2]:
			mesh.set_normal(Vector3.UP)
			mesh.add_vertex(map_to_world(outline[indices[i + offset]]))
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "OfficeFloor"
	floor_mesh.mesh = mesh.commit()
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	office_root.add_child(floor_mesh)

func add_wall_segment(a: Vector2, b: Vector2) -> void:
	var middle := (a + b) / 2
	var length := a.distance_to(b) / SIZE
	var height := 0.46
	var wall := add_box(office_root, map_to_world(middle, height / 2), Vector3(length, height, 0.16), Color("46655e"))
	wall.rotation.y = -(b - a).angle()
	var foundation := add_box(office_root, map_to_world(middle, -0.16), Vector3(length + 0.1, 0.32, 0.24), Color("263f3c"))
	foundation.rotation.y = wall.rotation.y

func add_prop(parent: Node3D, kind: String, point: Vector2, footprint: Vector2, rotation_y := 0.0) -> Node3D:
	var node := Node3D.new()
	node.name = kind.capitalize()
	node.position = map_to_world(point)
	node.rotation.y = rotation_y
	parent.add_child(node)
	if kind == "wall":
		add_box(node, Vector3(0, 0.6, 0), Vector3(footprint.x / SIZE, 1.2, footprint.y / SIZE), Color("637d73"))
		return node
	var model := load_model(kind)
	if model:
		model.scale = Vector3(footprint.x / SIZE, 1, footprint.y / SIZE)
		node.add_child(model)
	else:
		var prop_height := 0.88 if kind != "chair" else 0.51
		add_box(node, Vector3(0, prop_height / 2, 0), Vector3(footprint.x / SIZE, prop_height, footprint.y / SIZE), Color("9b7655"))
	return node

func load_model(kind: String) -> Node3D:
	if not asset_scenes.has(kind):
		var path := ASSET_PATH % kind
		asset_scenes[kind] = load(path) as PackedScene if ResourceLoader.exists(path) else null
	var scene := asset_scenes[kind]
	return scene.instantiate() as Node3D if scene else null

func add_door(parent: Node3D, center: Vector2, width: float, rotation_y: float, zone: String) -> Node3D:
	var frame := Node3D.new()
	frame.name = "Door"
	frame.position = map_to_world(center)
	frame.rotation.y = rotation_y
	parent.add_child(frame)
	var door_width := width / SIZE
	var model := load_model("door")
	var hinge: Node3D
	if model:
		model.scale = Vector3(door_width, 1.0, 0.22)
		frame.add_child(model)
		hinge = model.find_child("DoorLeaf", true, false) as Node3D
		if hinge:
			# Bake the compressed depth into the geometry. The hinge must
			# rotate outside the scaled frame to keep the leaf rigid.
			hinge.reparent(frame, true)
			var leaf_meshes := Node3D.new()
			leaf_meshes.name = "LeafGeometry"
			leaf_meshes.scale = hinge.scale
			var parts := hinge.get_children()
			hinge.scale = Vector3.ONE
			hinge.add_child(leaf_meshes)
			for part in parts:
				part.reparent(leaf_meshes, false)
	if not hinge:
		for side in [-1, 1]:
			add_box(frame, Vector3(side * door_width / 2, 0.96, 0), Vector3(0.11, 1.92, 0.24), Color("42645e"))
		hinge = Node3D.new()
		hinge.name = "DoorLeaf"
		hinge.position.x = -door_width / 2
		frame.add_child(hinge)
		add_box(hinge, Vector3(door_width * 0.48, 0.85, 0), Vector3(door_width * 0.9, 1.7, 0.08), Color("9d7754"))
	doors.append({"center": center, "hinge": hinge, "model": model, "zone": zone})
	return frame

func add_portal(parent: Node3D, center: Vector2, title: String, color: Color, zone: String) -> void:
	add_box(parent, map_to_world(center, 0.01), Vector3(1.55, 0.03, 1.12), color.darkened(0.28))
	add_door(parent, center, 47, 0, zone)
	add_label(parent, center, title, 2.75, false, 0.49, color.lightened(0.5))

func build_playground() -> void:
	room_floor = add_box(room_root, map_to_world(Vector2(2100, 535), -0.14), Vector3(16.0, 0.28, 11.75), Color("465663"))
	for wall in [Rect2(1780, 300, 640, 20), Rect2(1780, 750, 640, 20), Rect2(1780, 320, 20, 430), Rect2(2400, 320, 20, 430)]:
		add_box(room_root, map_to_world(wall.get_center(), 0.24), Vector3(wall.size.x / SIZE, 0.48, wall.size.y / SIZE), Color("293f46"))
	for i in range(STATIONS.size()):
		@warning_ignore("integer_division")
		var center := Vector2(1870 + (i % 3) * 220, 390 + (i / 3) * 150)
		add_box(room_root, map_to_world(center, 0.006), Vector3(2.8, 0.022, 2.7), Color("536a76"))
		add_prop(room_root, "arcade", center, Vector2(60, 49))
		add_label(room_root, center, STATIONS[i], 2.3, false, 0.51)
	add_portal(room_root, Vector2(2100, 730), "OFICINA", Color("83ae96"), "playground")

func update_doors(player_point: Vector2, zone: String, delta: float) -> void:
	var active := "office" if zone == "office" else "playground"
	for door in doors:
		if door.zone != active:
			continue
		var hinge: Node3D = door.hinge
		var open := player_point.distance_squared_to(door.center) < 68 * 68
		hinge.rotation.y = move_toward(hinge.rotation.y, -PI * 0.46 if open else 0.0, delta * 6.0)

func update_camera(player_point: Vector2, zone: String, map_mode: bool) -> void:
	if shown_zone != zone:
		shown_zone = zone
		office_root.visible = zone == "office"
		room_root.visible = zone != "office"
		room_floor.material_override = material(Color("506650") if zone == "workshop" else Color("465663"))
	var viewport_size := get_viewport().get_visible_rect().size
	var pane_width := 320.0 if editor_active and viewport_size.x >= 900 else 0.0
	var aspect := maxf(0.15, (viewport_size.x - pane_width) / maxf(1.0, viewport_size.y))
	var overview := map_mode or editor_active or zone != "office"
	var bounds := layout_bounds if zone == "office" else Rect2(1780, 300, 640, 470)
	var target := map_to_world(bounds.get_center() if overview else player_point)
	var distance := 14.0
	if overview:
		var fit_width := bounds.size.x / SIZE / (1.58 * aspect)
		var fit_depth := (bounds.size.y / SIZE * 0.9 + 3.5) / 1.33
		distance = maxf(fit_width, fit_depth) / tan(deg_to_rad(camera.fov / 2.0))
	camera.position = target + Vector3(0.0, 0.89, 0.456).normalized() * distance
	camera.look_at(target)
	# Camera offsets shift the framing without changing the view angle.
	camera.h_offset = pane_width * distance * tan(deg_to_rad(camera.fov / 2.0)) / maxf(1.0, viewport_size.y)

func screen_to_map(screen: Vector2) -> Vector2:
	var start := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	if direction.y >= -0.0001:
		return Vector2.INF
	var hit := start - direction * (start.y / direction.y)
	return Vector2(hit.x, hit.z) * SIZE

func set_editor_active(active: bool) -> void:
	editor_active = active
	if not active:
		set_selected_object("")

func set_selected_object(id: String) -> void:
	if selected_id == id and is_instance_valid(selection):
		return
	selected_id = id
	if is_instance_valid(selection):
		selection.get_parent().remove_child(selection)
		selection.queue_free()
		selection = null
	if not editor_active or not objects_by_id.has(id):
		return
	var parent := objects_by_id[id]
	var footprint: Vector2 = parent.get_meta("footprint") / SIZE
	var mark := TorusMesh.new()
	mark.inner_radius = 0.84
	mark.outer_radius = 0.95
	mark.rings = 32
	mark.ring_segments = 8
	selection = MeshInstance3D.new()
	selection.name = "Selection"
	selection.mesh = mark
	selection.material_override = material(Color("d69b3a"))
	selection.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	selection.position.y = 0.055
	selection.scale = Vector3(maxf(0.38, footprint.x * 0.66), 0.16, maxf(0.30, footprint.y * 0.79))
	parent.add_child(selection)

func material(color: Color) -> StandardMaterial3D:
	if not materials.has(color):
		var result := StandardMaterial3D.new()
		result.albedo_color = color
		result.roughness = 0.87
		result.cull_mode = BaseMaterial3D.CULL_DISABLED
		materials[color] = result
	return materials[color]

func add_box(parent: Node3D, point: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.material_override = material(color)
	instance.position = point
	parent.add_child(instance)
	return instance

func add_label(parent: Node3D, point: Vector2, caption: String, height: float, on_floor: bool, size: float = 0.4, color: Color = Color("f7ead4")) -> Label3D:
	var label := Label3D.new()
	label.text = caption
	label.position = map_to_world(point, height)
	label.font_size = 48
	label.pixel_size = size / 48
	label.modulate = Color("334e47") if on_floor else color
	label.outline_modulate = Color("223e39")
	label.outline_size = 0 if on_floor else 10
	if on_floor:
		label.rotation.x = -PI / 2
	else:
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	return label
