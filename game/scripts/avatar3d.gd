extends Node3D

const SKIN := ["f8d8b0", "e8b98c", "c98d62", "a96d48", "805038", "533729"]
const HAIR := ["342c32", "7b4d35", "c78e47", "e9d6ac", "8c547c", "dde4de"]
const SHIRT := ["318975", "ce7456", "5c7da8", "ae8d40", "a76a9d", "dde4d1"]

var world: Node3D
var figure: Node3D
var nameplate: Label3D
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var hat: Node3D
var headphones: Node3D
var palette: Dictionary[String, StandardMaterial3D] = {}
var last_profile: Dictionary = {}
var phase := 0.0
var initialized := false
var last_position := Vector2.ZERO
var draw_point := Vector2.ZERO
var heading := Vector2.DOWN

func init(target_world: Node3D) -> void:
	world = target_world
	figure = world.load_model("avatar")
	if figure:
		figure.scale = Vector3(0.68, 1.0, 0.68)
		add_child(figure)
		left_leg = figure.find_child("LegLeft", true, false) as Node3D
		right_leg = figure.find_child("LegRight", true, false) as Node3D
		left_arm = figure.find_child("ArmLeft", true, false) as Node3D
		right_arm = figure.find_child("ArmRight", true, false) as Node3D
		bind_materials(figure)
	else:
		make_fallback()
	nameplate = world.add_label(self, Vector2.ZERO, "Explorador", 1.9, false, 0.20)
	nameplate.no_depth_test = true
	nameplate.render_priority = 3
	hat = Node3D.new()
	figure.add_child(hat)
	world.add_box(hat, Vector3(0, 1.83, 0.08), Vector3(0.86, 0.09, 0.72), Color("566c54"))
	world.add_box(hat, Vector3(0, 1.91, 0), Vector3(0.65, 0.12, 0.49), Color("566c54"))
	headphones = Node3D.new()
	figure.add_child(headphones)
	for side in [-1, 1]:
		world.add_box(headphones, Vector3(side * 0.40, 1.59, 0), Vector3(0.15, 0.23, 0.22), Color("e7b957"))

func sync(target: CharacterBody2D, delta: float, local: bool) -> void:
	visible = target.visible
	var point := target.position
	var motion := point - last_position
	var teleport := not initialized or motion.length_squared() > 128.0 * 128.0
	if local or teleport or not visible:
		draw_point = point
	else:
		draw_point = draw_point.lerp(point, 1.0 - exp(-16.0 * delta))
	var walking := false
	if local:
		heading = target.heading
		walking = target.move_input.length_squared() > 0.01
		phase = target.walk_time
	elif not teleport:
		if motion.length_squared() > 0.05:
			heading = motion.normalized()
		walking = draw_point.distance_squared_to(point) > 0.4
		phase += delta * 12.0
	position = world.map_to_world(draw_point)
	figure.rotation.y = atan2(heading.x, heading.y)
	var swing := sin(phase) * 0.45 if walking else 0.0
	figure.position.y = absf(swing) * 0.11
	if left_leg: left_leg.rotation.x = swing
	if right_leg: right_leg.rotation.x = -swing
	if left_arm: left_arm.rotation.x = -swing * 0.55
	if right_arm: right_arm.rotation.x = swing * 0.55
	last_position = point
	initialized = true
	if teleport or last_profile != target.profile:
		apply_profile(target.profile)

func apply_profile(profile: Dictionary) -> void:
	last_profile = profile.duplicate()
	nameplate.text = str(profile.get("name", "Explorador"))
	recolor("skin", SKIN, int(profile.get("skin", 1)))
	recolor("hair", HAIR, int(profile.get("hair", 0)))
	recolor("shirt", SHIRT, int(profile.get("shirt", 0)))
	hat.visible = int(profile.get("style", 0)) == 1
	headphones.visible = int(profile.get("style", 0)) == 2

func recolor(key: String, colors: Array, index: int) -> void:
	if palette.has(key):
		palette[key].albedo_color = Color(colors[posmod(index, colors.size())])

func bind_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for i in range(node.get_surface_override_material_count()):
			var surface: Material = node.get_active_material(i)
			if not surface is StandardMaterial3D:
				continue
			var key := surface.resource_name.to_lower()
			if key not in ["skin", "hair", "shirt"]:
				continue
			if not palette.has(key):
				palette[key] = surface.duplicate() as StandardMaterial3D
			node.set_surface_override_material(i, palette[key])
	for child in node.get_children():
		bind_materials(child)

func make_fallback() -> void:
	figure = Node3D.new()
	add_child(figure)
	var body: MeshInstance3D = world.add_box(figure, Vector3(0, 0.94, 0), Vector3(0.55, 0.62, 0.34), Color("318975"))
	var head: MeshInstance3D = world.add_box(figure, Vector3(0, 1.50, 0), Vector3(0.48, 0.47, 0.43), Color("e8b98c"))
	var hair: MeshInstance3D = world.add_box(figure, Vector3(0, 1.76, 0), Vector3(0.50, 0.10, 0.45), Color("342c32"))
	for entry in [["shirt", body], ["skin", head], ["hair", hair]]:
		palette[entry[0]] = entry[1].material_override.duplicate()
		entry[1].material_override = palette[entry[0]]
	left_leg = make_leg(-0.14)
	right_leg = make_leg(0.14)

func make_leg(x: float) -> Node3D:
	var leg := Node3D.new()
	leg.position = Vector3(x, 0.65, 0)
	figure.add_child(leg)
	world.add_box(leg, Vector3(0, -0.30, 0), Vector3(0.21, 0.60, 0.26), Color("354452"))
	return leg
