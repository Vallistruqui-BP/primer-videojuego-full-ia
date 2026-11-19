extends SubViewportContainer

var avatar: Node3D
var helper: Node3D
var profile: Dictionary = {}

func _ready() -> void:
 name="CharacterPreview3D"
 custom_minimum_size=Vector2(0,190)
 stretch=true
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 var viewport:=SubViewport.new()
 viewport.size=Vector2i(500,190)
 viewport.own_world_3d=true
 viewport.transparent_bg=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 add_child(viewport)
 var root:=Node3D.new()
 viewport.add_child(root)
 helper=load("res://scripts/world3d.gd").new()
 avatar=load("res://scripts/avatar3d.gd").new()
 root.add_child(avatar)
 avatar.init(helper)
 avatar.rotation_degrees.y=-18
 avatar.nameplate.visible=false
 var light:=DirectionalLight3D.new()
 light.rotation_degrees=Vector3(-40,-30,0)
 light.light_energy=0.8
 root.add_child(light)
 var ambient:=WorldEnvironment.new()
 ambient.environment=Environment.new()
 ambient.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 ambient.environment.ambient_light_color=Color.WHITE
 ambient.environment.ambient_light_energy=0.5
 root.add_child(ambient)
 var camera:=Camera3D.new()
 root.add_child(camera)
 camera.position=Vector3(0,1.2,4)
 camera.look_at(Vector3(0,0.9,0))
 camera.fov=32
 camera.make_current()
 update_profile(profile)

func update_profile(value: Dictionary) -> void:
 profile=value.duplicate(true)
 if avatar:avatar.apply_profile(profile)

func _exit_tree() -> void:
 if is_instance_valid(helper):helper.free()
