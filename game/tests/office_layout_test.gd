extends SceneTree
const Store = preload("res://scripts/office_layout_store.gd")
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> bool:
 if not ok:printerr("LAYOUT_FAIL ",label);quit(1)
 return ok
func run() -> void:
 var base := Store.canonical()
 if not check(Store.validate(base).is_empty(),"existing layout accepted"):return
 var changed := base.duplicate(true)
 changed.objects[0].x+=20
 changed.outline=[[0,0],[1,0],[1,1]]
 var normalized := Store.sanitized(changed)
 if not check(normalized.outline==base.outline and normalized.objects[0].x==base.objects[0].x+20,"import keeps structural bounds but accepts prop edits"):return
 changed.objects.append(changed.objects[0].duplicate(true))
 if not check(not Store.validate(changed).is_empty(),"duplicate rejected"):return
 changed=base.duplicate(true);changed.objects[0].x=NAN
 if not check(not Store.validate(changed).is_empty(),"nan rejected"):return
 changed=base.duplicate(true);changed.objects[0].kind="script"
 if not check(not Store.validate(changed).is_empty(),"unknown type rejected"):return
 changed=base.duplicate(true);changed.objects[0].w=300
 if not check(not Store.validate(changed).is_empty(),"oversize rejected"):return
 var piece: Dictionary = changed.objects[0]
 piece.merge({"x":100.0,"y":100.0,"w":20.0,"d":40.0,"rotation":0.0},true)
 changed.outline=[[0,0],[1250,0],[1250,900],[0,900]]
 if not check(not Store.validate(changed).is_empty(),"outside L footprint rejected even with imported outline"):return
 piece.x=715.0;piece.y=400.0
 if not check(Store.validate(changed).is_empty(),"axis-aligned footprint fits"):return
 piece.rotation=PI/4
 if not check(not Store.validate(changed).is_empty(),"rotated corner outside footprint rejected"):return
 piece.x=750.0
 if not check(Store.validate(changed).is_empty(),"oblique footprint fits fully inside the map"):return
 print("LAYOUT_PASS canonical editable_props structural_bounds duplicate nonfinite type size rotated_footprint")
 quit()
