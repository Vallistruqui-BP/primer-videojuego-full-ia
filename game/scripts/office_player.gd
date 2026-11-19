extends CharacterBody2D

const SPEED := 180.0
var profile := {"name":"Explorador","skin":1,"hair":0,"shirt":0,"style":0}
var walk_time := 0.0
var keyboard_enabled := true
var test_input := Vector2.ZERO
var touch_input := Vector2.ZERO
var heading := Vector2.DOWN
var tint := Color("2f8f84")
var move_input := Vector2.ZERO
var input_blocked := false

func _ready() -> void:
 var collision := CollisionShape2D.new()
 var circle := CircleShape2D.new()
 circle.radius = 9.0
 collision.shape = circle
 add_child(collision)
 queue_redraw()

func _physics_process(delta: float) -> void:
 if input_blocked:
  move_input = Vector2.ZERO
  velocity = Vector2.ZERO
  return
 var direction := test_input + touch_input
 if keyboard_enabled and not get_viewport().gui_get_focus_owner() is LineEdit:
  direction += Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
 move_input = direction.limit_length()
 velocity = move_input * SPEED
 if velocity.length() > 1:
  heading = velocity.normalized()
  walk_time += delta * 10
  queue_redraw()
 move_and_slide()

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
  touch_input = Vector2.ZERO
  test_input = Vector2.ZERO

func _draw() -> void:
 var skin_colors := ["f8d8b0","e8b98c","c98d62","a96d48","805038","533729"]
 var hair_colors := ["342c32","7b4d35","c78e47","e9d6ac","8c547c","dde4de"]
 var shirt_colors := ["318975","ce7456","5c7da8","ae8d40","a76a9d","dde4d1"]
 var skin := Color(skin_colors[int(profile.get("skin",1)) % 6])
 var hair := Color(hair_colors[int(profile.get("hair",0)) % 6])
 var shirt := Color(shirt_colors[int(profile.get("shirt",0)) % 6])
 var step := 2.0 * sin(walk_time) if velocity.length()>1 else 0.0
 draw_rect(Rect2(-10,5,20,5),Color(0,0,0,0.22))
 draw_rect(Rect2(-7,-3,6,11+step),Color("354452"))
 draw_rect(Rect2(1,-3,6,11-step),Color("354452"))
 draw_rect(Rect2(-8,-14,16,15),shirt)
 draw_rect(Rect2(-11,-12,4,10),skin)
 draw_rect(Rect2(7,-12,4,10),skin)
 draw_rect(Rect2(-7,-25,14,13),skin)
 draw_rect(Rect2(-8,-27,16,5),hair)
 draw_rect(Rect2(-8,-23,3,7),hair)
 if heading.y < -0.5: draw_rect(Rect2(-7,-24,14,11),hair)
 else:
  draw_rect(Rect2(-4,-20,2,2),Color("253633"))
  draw_rect(Rect2(3,-20,2,2),Color("253633"))
 if int(profile.get("style",0)) == 1:
  draw_rect(Rect2(-10,-28,20,4),shirt.lightened(0.2))
  draw_rect(Rect2(-7,-32,14,5),shirt)
 elif int(profile.get("style",0)) == 2:
  draw_rect(Rect2(-9,-22,3,8),Color("e7b957"))
  draw_rect(Rect2(6,-22,3,8),Color("e7b957"))
 var name_text := str(profile.get("name","Explorador"))
 draw_rect(Rect2(-42,-48,84,14),Color("243d36d9"))
 draw_string(ThemeDB.fallback_font,Vector2(-40,-37),name_text,HORIZONTAL_ALIGNMENT_CENTER,80,10,Color("fff5d8"))
