"""Original office sprites. Run with Blender --background --disable-autoexec --python this_file.

No downloads, addons, external textures or embedded executable text blocks.
Each scene is a separately editable module; final PNGs are rendered by Blender.
"""
import bpy
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/source"
TARGET = ROOT / "game/art/office"
SOURCE.mkdir(parents=True, exist_ok=True)
TARGET.mkdir(parents=True, exist_ok=True)
PALETTE = {
    "outline": "344e48", "deep": "24493f", "sage": "729b83",
    "green": "4c7966", "light": "a6c2a1", "cream": "eadbb8",
    "ivory": "faf0d3", "wood": "b99467", "earth": "bc7055",
    "earth_light": "db9a70", "screen": "8dc5b4", "ink": "427568",
    "shadow": "52685b", "brass": "dfb76a",
}
MATERIALS = {}

def linear(c):
    return c / 12.92 if c < 0.04045 else ((c + 0.055) / 1.055) ** 2.4

for name, value in PALETTE.items():
    material = bpy.data.materials.new(name)
    rgba = tuple(linear(int(value[i:i+2], 16) / 255) for i in (0, 2, 4)) + (1,)
    material.diffuse_color = rgba
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs[0].default_value = rgba
    output = nodes.new("ShaderNodeOutputMaterial")
    material.node_tree.links.new(emission.outputs[0], output.inputs[0])
    MATERIALS[name] = material

def block(name, x, y, z, w, h, depth, material, corner=0):
    # Chamfered solid meshes are useful both as editable models and crisp sprites.
    c = min(corner, w / 2, h / 2)
    ring = [(-w/2+c,-h/2), (w/2-c,-h/2), (w/2,-h/2+c),
            (w/2,h/2-c), (w/2-c,h/2), (-w/2+c,h/2),
            (-w/2,h/2-c), (-w/2,-h/2+c)] if c else [(-w/2,-h/2),(w/2,-h/2),(w/2,h/2),(-w/2,h/2)]
    n = len(ring)
    verts = [(a+x,b+y,z+d) for d in (-depth/2,depth/2) for a,b in ring]
    faces = [tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj = bpy.data.objects.new(name,mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(MATERIALS[material])
    return obj

def scene(name, width, height):
    result = bpy.data.scenes.new(name)
    bpy.context.window.scene = result
    camera_data = bpy.data.cameras.new(name + "Camera")
    camera = bpy.data.objects.new(name + "Camera", camera_data)
    result.collection.objects.link(camera)
    camera.location = (0,0,20)
    camera.rotation_euler = (0,0,0)
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = width / 8
    result.camera = camera
    result.render.engine = "BLENDER_EEVEE_NEXT"
    result.render.resolution_x = width
    result.render.resolution_y = height
    result.render.resolution_percentage = 100
    result.render.film_transparent = True
    result.render.image_settings.file_format = "PNG"
    result.render.image_settings.color_mode = "RGBA"
    result.render.image_settings.color_depth = "8"
    result.render.image_settings.compression = 100
    result.render.filter_size = 0.01
    result.view_settings.view_transform = "Standard"
    result.view_settings.look = "None"
    result.view_settings.exposure = 0
    result.view_settings.gamma = 1
    result.world = bpy.data.worlds.new(name + "World")
    result.world.color = (0,0,0)
    result["pixels_per_blender_unit"] = 8
    result["projection"] = "Orthographic along -Z; +Y is image top"
    return result

def desk(square=False):
    result = scene("Desk_square" if square else "Desk", 64, 64 if square else 32)
    height = 8 if square else 4
    for x in (-3.25,3.25):
        for y in (-height/2+.75,height/2-.75): block("Desk leg",x,y,0.4,.35,.35,.8,"deep")
    block("Dark desktop edge",0,0,1,8,height,.25,"outline",.25)
    block("Honey oak apron",0,-.125,1.16,7.75,height-.5,.1,"wood",.125)
    block("Cream desktop",0,.125,1.25,7.5,height-.5,.1,"cream",.125)
    block("Desktop highlight",0,height/2-.25,1.31,7,.125,.02,"ivory")
    frame = set(result.objects)
    block("Green desk mat",-.75,-.1,1.33,3.75,2.5,.03,"green",.125)
    block("Monitor stand",-.75,.6,1.4,1.25,.5,.1,"deep",.125)
    block("Monitor housing",-.75,.85,1.55,2.75,1.5,.15,"outline",.125)
    block("Monitor screen",-.75,.975,1.65,2.25,1,.02,"screen")
    block("Screen heading",-1.25,1.225,1.68,.75,.125,.02,"ivory")
    block("Screen line",-1.125,.975,1.68,1,.125,.02,"ink")
    block("Screen chart",-.125,.85,1.68,.25,.5,.02,"light")
    block("Keyboard",-.75,-.8,1.5,2.25,.625,.07,"ivory",.125)
    for row in (-.9,-.65):
        for col in (-1.5,-1,-.5,0): block("Keyboard key",col,row,1.55,.25,.125,.02,"sage")
    block("Mouse",.875,-.8,1.5,.375,.625,.1,"cream",.125)
    block("Terracotta journal",2,-.75,1.45,1.25,1.5,.12,"earth",.125)
    block("Journal pages",2.125,-.75,1.52,.75,1.25,.03,"ivory")
    block("Journal band",2.25,-.75,1.56,.125,1.25,.02,"earth_light")
    block("Cup handle",2.875,.95,1.5,.375,.375,.15,"ivory",.125)
    block("Coffee cup",2.5,1,1.55,.625,.75,.3,"ivory",.125)
    block("Coffee",2.5,1.05,1.72,.375,.375,.02,"wood",.125)
    if square:
        for obj in result.objects:
            if obj not in frame:
                obj.location.y += 1.5
        block("Work sheet",-.875,-1.75,1.4,2.75,2.25,.05,"ivory")
        for y in (-1.125,-1.625,-2.125):
            block("Sheet ruling",-.875,y,1.45,1.75,.125,.02,"sage")
        block("Terracotta pencil",1,-1.75,1.45,.125,2,.05,"earth")
    return result

def chair():
    result = scene("Chair", 24, 24)
    block("Chair base vertical",0,0,.2,.375,2.5,.2,"outline")
    block("Chair base horizontal",0,0,.2,2.5,.375,.2,"outline")
    for x,y in [(0,1.125),(0,-1.125),(-1.125,0),(1.125,0)]:
        block("Caster",x,y,.22,.375,.375,.25,"deep",.125)
    block("Seat outline",0,.125,.8,2,2,.25,"outline",.375)
    block("Sage seat",0,.25,.95,1.5,1.5,.1,"sage",.25)
    block("Seat highlight",0,.75,1.02,1,.125,.02,"light")
    for x in (-1.125,1.125): block("Armrest",x,0,1.1,.375,1.25,.2,"cream",.125)
    block("Backrest edge",0,-.875,1.3,2.25,.75,.6,"deep",.125)
    block("Backrest cushion",0,-.75,1.62,1.75,.375,.04,"green")
    return result

def door():
    result = scene("Door", 48, 16)
    # Open frame: the entire existing passage stays visibly open. No fake closed leaf.
    block("Threshold",0,0,.05,6,.75,.1,"wood")
    block("Threshold highlight",0,.125,.11,5.25,.25,.02,"cream")
    for x in (-2.75,2.75):
        block("Door jamb",x,0,.8,.5,1.5,1.6,"outline")
        block("Door jamb cap",x,.125,1.65,.25,1.25,.05,"sage")
        block("Brass hinge",x,-.375,1.72,.125,.25,.05,"brass")
    return result

old_scenes = list(bpy.data.scenes)
scenes = [desk(),desk(square=True),chair(),door()]
for old in old_scenes:
    bpy.data.scenes.remove(old)
for data in list(bpy.data.objects):
    if not data.users_scene:
        bpy.data.objects.remove(data)
bpy.context.window.scene = scenes[0]
blend_path = SOURCE / "office-props.blend"
for item in scenes:
    item.render.filepath = "//../../game/art/office/" + item.name.lower() + ".png"
bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
for item in scenes:
    bpy.context.window.scene = item
    item.render.filepath = str(TARGET / (item.name.lower() + ".png"))
    bpy.ops.render.render(write_still=True)

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

assets = []
for item in scenes:
    derivative = TARGET / (item.name.lower() + ".png")
    assets.append({
        "id": "office-" + item.name.lower(), "title": "Original office " + item.name.lower(),
        "creator": "Pedro Vallarino project / Codex procedural authoring",
        "creator_url": "", "source_url": "project://scripts/blender_office_props.py",
        "license": "Project-owned original; authorized for this game's source and distribution",
        "license_url": "project://art/ATTRIBUTIONS.md", "acquisition": "original_work",
        "license_review": "Created from primitive meshes for the user-authorized release; no external art or source licenses",
        "reviewed_at": "2026-11-19", "original": str(blend_path.relative_to(ROOT)).replace("\\", "/"),
        "sha256": digest(blend_path), "modifications": "Original meshes and emission palette rendered by Blender",
        "derivatives": [str(derivative.relative_to(ROOT)).replace("\\", "/")],
        "derivative_sha256": digest(derivative), "derivative_bytes": derivative.stat().st_size,
        "dimensions": [item.render.resolution_x,item.render.resolution_y],
        "anchor": "center", "scene": item.name,
        "attribution": "Original procedural office module created for Primer Videojuego Full IA; no third-party art",
        "redistribution_reviewed": True,
    })
manifest = {"schema_version": 1, "blender_version": bpy.app.version_string,
            "recipe": "scripts/blender_office_props.py", "recipe_sha256": digest(Path(__file__)), "assets": assets}
(ROOT / "art/asset-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
print("OFFICE_PROPS_RENDERED", bpy.app.version_string)
