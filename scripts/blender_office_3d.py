"""Build the editable original office kit and derive its Godot GLBs."""

import hashlib
import json
import sys
from collections import defaultdict
from pathlib import Path
from tempfile import TemporaryDirectory

import bpy
from mathutils import Quaternion, Vector

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from verify_office_3d_assets import KINDS, MANIFEST, ROOT, SOURCE, TARGET, glb_summary

PALETTE = {
    "outline": "344e48", "deep": "24493f", "sage": "729b83",
    "green": "4c7966", "light": "a6c2a1", "cream": "eadbb8",
    "ivory": "faf0d3", "wood": "b99467", "earth": "bc7055",
    "earth_light": "db9a70", "screen": "8dc5b4", "brass": "dfb76a",
    "skin": "e8ae82", "hair": "4b3936", "shirt": "549e86",
    "legs": "45607a", "shoes": "39434b",
}


def make_materials():
    def linear(value):
        return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4

    materials = {}
    for name, rgb in PALETTE.items():
        rgba = tuple(linear(int(rgb[i:i+2], 16) / 255) for i in (0, 2, 4)) + (1,)
        material = bpy.data.materials.new(name)
        material.diffuse_color = rgba
        material.use_nodes = True
        shader = material.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value = rgba
        shader.inputs["Roughness"].default_value = 0.76
        if name == "screen":
            shader.inputs["Emission Color"].default_value = rgba
            shader.inputs["Emission Strength"].default_value = 0.2
        materials[name] = material
    return materials


class KitPart:
    def __init__(self, kind, materials):
        self.collection = bpy.data.collections.new(f"office3d_{kind}")
        bpy.context.scene.collection.children.link(self.collection)
        self.materials = materials

    def put(self, obj, material, pivot):
        for collection in list(obj.users_collection):
            collection.objects.unlink(obj)
        self.collection.objects.link(obj)
        obj.data.materials.append(self.materials[material])
        if pivot:
            obj.parent = pivot
            obj.location -= pivot.location
        return obj

    def pivot(self, name, location):
        obj = bpy.data.objects.new(name, None)
        self.collection.objects.link(obj)
        obj.location = location
        obj.empty_display_size = 0.12
        return obj

    def box(self, name, location, dimensions, material, bevel=0.018, pivot=None):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
        obj = bpy.context.object
        obj.name = name
        for vertex in obj.data.vertices:
            vertex.co = Vector(tuple(value * size for value, size in zip(vertex.co, dimensions)))
        if bevel:
            modifier = obj.modifiers.new("Soft edges", "BEVEL")
            modifier.width = bevel
            modifier.segments = 1
        return self.put(obj, material, pivot)

    def cone(self, name, location, radii, depth, material, sides=12):
        bpy.ops.mesh.primitive_cone_add(
            vertices=sides, radius1=radii[0], radius2=radii[1], depth=depth, location=location,
        )
        obj = bpy.context.object
        obj.name = name
        return self.put(obj, material, None)


def desk(part, square=False):
    b = part.box
    for x in (-0.42, 0.42):
        for y in (-0.40, 0.40):
            b("Desk leg", (x, y, 0.36), (0.075, 0.08, 0.72), "deep")
    b("Oak desktop", (0, 0, 0.72), (1, 1, 0.10), "wood", 0.025)
    b("Desk mat", (-0.16, -0.09, 0.78), (0.48, 0.50, 0.018), "green", 0.008)
    b("Monitor stand", (-0.15, 0.22, 0.82), (0.19, 0.14, 0.10), "deep")
    b("Monitor housing", (-0.15, 0.25, 1.02), (0.50, 0.074, 0.29), "outline")
    b("Monitor screen", (-0.15, 0.21, 1.02), (0.45, 0.02, 0.234), "screen", 0.012)
    b("Monitor chart", (-0.30, 0.198, 1.05), (0.075, 0.01, 0.095), "green", 0)
    for z in (0.98, 1.04, 1.09):
        b("Monitor line", (-0.09, 0.198, z), (0.20, 0.01, 0.013), "ivory", 0)
    b("Keyboard", (-0.16, -0.19, 0.807), (0.37, 0.145, 0.037), "ivory")
    for x in (-0.285, -0.235, -0.185, -0.135, -0.085, -0.035):
        b("Keyboard key", (x, -0.18, 0.828), (0.028, 0.06, 0.012), "sage", 0)
    b("Mouse", (0.117, -0.19, 0.809), (0.08, 0.13, 0.055), "cream", 0.022)
    journal = b("Terracotta journal", (0.34, -0.26, 0.788), (0.176, 0.175, 0.035), "earth")
    journal.rotation_euler.z = -0.12
    part.cone("Ceramic mug", (0.35, 0.22, 0.826), (0.052, 0.064), 0.112, "ivory")
    part.cone("Coffee", (0.35, 0.22, 0.885), (0.049, 0.049), 0.008, "wood")
    if square:
        b("Pedestal drawer", (0.32, 0, 0.42), (0.25, 0.53, 0.54), "cream")
        for z in (0.29, 0.47, 0.62):
            b("Drawer handle", (0.32, -0.27, z), (0.087, 0.028, 0.027), "brass")


def chair(part):
    b = part.box
    b("Caster beam X", (0, 0, 0.07), (1, 0.13, 0.14), "outline", 0.035)
    b("Caster beam Y", (0, 0, 0.07), (0.13, 1, 0.14), "outline", 0.035)
    part.cone("Swivel post", (0, 0, 0.26), (0.10, 0.085), 0.36, "deep")
    b("Seat support", (0, -0.025, 0.46), (0.77, 0.73, 0.13), "deep", 0.04)
    b("Seat cushion", (0, -0.06, 0.55), (0.70, 0.65, 0.16), "sage", 0.055)
    b("Back post", (0, 0.28, 0.69), (0.09, 0.10, 0.49), "outline")
    b("Back cushion", (0, 0.276, 0.87), (0.73, 0.16, 0.41), "green", 0.05)
    for x in (-0.38, 0.38):
        b("Arm support", (x, 0.038, 0.57), (0.056, 0.062, 0.27), "deep")
        b("Armrest", (x, -0.05, 0.71), (0.10, 0.46, 0.072), "cream")


def table(part):
    b = part.box
    part.cone("Round foot", (0, 0, 0.06), (0.32, 0.25), 0.12, "deep")
    part.cone("Column", (0, 0, 0.38), (0.09, 0.12), 0.61, "outline")
    part.cone("Oak underside", (0, 0, 0.69), (0.47, 0.50), 0.06, "wood", 16)
    part.cone("Cream top", (0, 0, 0.74), (0.50, 0.50), 0.04, "cream", 16)
    b("Closed notebook", (0.15, 0.02, 0.785), (0.23, 0.29, 0.050), "earth")
    part.cone("Mug", (-0.15, -0.10, 0.818), (0.065, 0.076), 0.118, "sage")
    part.cone("Coffee", (-0.15, -0.10, 0.880), (0.059, 0.058), 0.007, "wood")


def sofa(part):
    b = part.box
    for x in (-0.35, 0.35):
        for y in (-0.34, 0.34):
            b("Oak foot", (x, y, 0.07), (0.12, 0.13, 0.14), "wood")
    b("Upholstered body", (0, 0, 0.24), (1, 1, 0.30), "deep", 0.07)
    b("Back rail", (0, 0.38, 0.49), (0.94, 0.24, 0.58), "green", 0.08)
    for x in (-0.418, 0.418):
        b("Padded arm", (x, -0.06, 0.39), (0.164, 0.86, 0.33), "green", 0.065)
    for x in (-0.164, 0.164):
        b("Seat cushion", (x, -0.085, 0.414), (0.307, 0.66, 0.15), "sage", 0.045)
        b("Back cushion", (x, 0.28, 0.57), (0.307, 0.17, 0.36), "sage", 0.05)
    pillow = b("Ochre pillow", (-0.27, 0.12, 0.58), (0.21, 0.10, 0.21), "brass", 0.038)
    pillow.rotation_euler.y = -0.19


def reception(part):
    b = part.box
    b("Recessed foot", (0, 0, 0.07), (0.90, 0.87, 0.14), "deep")
    b("Counter front", (0, -0.32, 0.48), (0.94, 0.30, 0.83), "green", 0.045)
    for x in (-0.41, 0.41):
        b("Side panel", (x, 0.12, 0.40), (0.12, 0.65, 0.68), "green")
    b("Work surface", (0, 0.16, 0.71), (0.95, 0.65, 0.10), "cream")
    b("Welcome ledge", (0, -0.28, 0.90), (1, 0.44, 0.12), "wood", 0.025)
    for x in (-0.37, -0.25, -0.13, -0.01, 0.11, 0.23, 0.35):
        b("Front slat", (x, -0.474, 0.48), (0.036, 0.031, 0.55), "sage", 0.006)
    b("Sign pedestal", (0.25, -0.18, 1.005), (0.29, 0.13, 0.09), "deep")
    b("Welcome plaque", (0.25, -0.197, 1.096), (0.28, 0.07, 0.16), "ivory")
    b("Welcome accent", (0.25, -0.235, 1.10), (0.18, 0.012, 0.03), "earth")


def core(part):
    b = part.box
    b("Foundry plinth", (0, 0, 0.105), (1, 1, 0.21), "deep", 0.055)
    b("Fabricator cabinet", (0, 0.02, 0.58), (0.86, 0.80, 0.83), "green", 0.048)
    b("Lower panel", (0, -0.40, 0.35), (0.66, 0.12, 0.24), "outline")
    for x in (-0.24, -0.12, 0, 0.12, 0.24):
        b("Vent slot", (x, -0.466, 0.35), (0.065, 0.02, 0.09), "sage", 0)
    b("Status bezel", (-0.11, -0.40, 0.71), (0.46, 0.16, 0.30), "outline")
    b("Status screen", (-0.11, -0.47, 0.72), (0.39, 0.06, 0.22), "screen")
    b("Status heading", (-0.11, -0.504, 0.77), (0.23, 0.02, 0.028), "ivory", 0)
    b("Emergency switch", (0.26, -0.46, 0.70), (0.11, 0.08, 0.11), "earth")
    part.cone("Copper chamber", (0, 0, 1.13), (0.28, 0.22), 0.34, "brass", 8)
    part.cone("Mint crystal", (0, 0, 1.48), (0.22, 0.045), 0.49, "screen", 6)


def plant(part):
    part.cone("Terracotta saucer", (0, 0, 0.041), (0.46, 0.50), 0.082, "earth_light")
    part.cone("Terracotta pot", (0, 0, 0.26), (0.34, 0.49), 0.43, "earth")
    part.cone("Pot rim", (0, 0, 0.495), (0.48, 0.50), 0.075, "earth_light")
    part.cone("Potting soil", (0, 0, 0.525), (0.42, 0.42), 0.045, "outline")
    part.cone("Plant stem", (0, 0, 0.86), (0.054, 0.022), 0.72, "deep", 6)
    for i, (x, y, z) in enumerate((
        (0.22, 0.11, 0.78), (-0.23, -0.12, 0.91), (-0.15, 0.18, 1.02),
        (0.16, -0.16, 1.13), (0, 0.11, 1.31),
    )):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=(x, y, z))
        obj = bpy.context.object
        obj.name = "Angular leaf"
        for vertex in obj.data.vertices:
            vertex.co.x *= 0.17
            vertex.co.y *= 0.11
            vertex.co.z *= 0.24
        obj.rotation_euler = (0.65 * y / 0.22, 0.72 * x / 0.24, i * 0.65)
        part.put(obj, ("green", "sage", "light")[i % 3], None)


def arcade(part):
    b = part.box
    b("Arcade foot", (0, 0, 0.10), (1, 1, 0.20), "outline", 0.035)
    b("Arcade cabinet", (0, 0.12, 0.82), (0.90, 0.76, 1.56), "deep", 0.065)
    b("Control deck", (0, -0.23, 0.90), (0.91, 0.49, 0.16), "wood", 0.04)
    b("Screen bezel", (0, -0.278, 1.22), (0.72, 0.15, 0.50), "outline", 0.035)
    b("Screen glass", (0, -0.354, 1.22), (0.61, 0.06, 0.39), "screen", 0.043)
    b("Pixel paddle left", (-0.20, -0.389, 1.20), (0.035, 0.018, 0.15), "ivory", 0)
    b("Pixel paddle right", (0.20, -0.389, 1.27), (0.035, 0.018, 0.15), "ivory", 0)
    b("Pixel ball", (0.046, -0.389, 1.15), (0.043, 0.018, 0.046), "earth", 0)
    b("Arcade marquee", (0, -0.14, 1.60), (0.89, 0.48, 0.21), "earth", 0.045)
    b("Marquee stripe", (0, -0.392, 1.61), (0.66, 0.05, 0.088), "brass", 0.017)
    part.cone("Joystick shaft", (-0.20, -0.35, 1.015), (0.023, 0.023), 0.085, "outline", 8)
    part.cone("Joystick ball", (-0.20, -0.35, 1.072), (0.05, 0.047), 0.05, "earth", 8)
    for x, material in ((0.12, "earth"), (0.25, "light")):
        part.cone("Arcade button", (x, -0.35, 0.993), (0.053, 0.05), 0.043, material, 8)
    b("Coin plate", (0, -0.28, 0.53), (0.22, 0.08, 0.27), "green")
    b("Coin slot", (0, -0.326, 0.57), (0.12, 0.018, 0.028), "brass", 0)


def door(part):
    b = part.box
    for x in (-0.435, 0.435):
        b("Door jamb", (x, 0, 1.015), (0.13, 1, 2.03), "deep", 0.024)
        b("Jamb inlay", (x, -0.46, 1.01), (0.069, 0.085, 1.98), "wood", 0.014)
    b("Door lintel", (0, 0, 2.025), (1, 1, 0.19), "deep", 0.024)
    b("Lintel inlay", (0, -0.46, 2.025), (0.84, 0.085, 0.084), "wood")
    hinge = part.pivot("DoorLeaf", (-0.363, 0, 0))
    b("Door slab", (0, 0, 0.98), (0.719, 0.27, 1.91), "wood", 0.022, hinge)
    for y in (-0.145, 0.145):
        b("Door recessed panel", (0, y, 0.52), (0.58, 0.035, 0.71), "green", 0.018, hinge)
        b("Window frame", (0, y, 1.43), (0.525, 0.04, 0.64), "deep", 0.018, hinge)
        b("Window inset", (0, y * 1.12, 1.43), (0.45, 0.04, 0.555), "screen", 0.013, hinge)
        b("Door handle", (0.25, y * 1.35, 0.97), (0.15, 0.18, 0.045), "brass", 0.010, hinge)


def mailbox(part):
    b = part.box
    b("Mailbox base", (0, 0, 0.08), (1, 1, 0.16), "deep", 0.06)
    b("Mailbox pedestal", (0, 0.02, 0.50), (0.52, 0.61, 0.90), "green", 0.028)
    b("Mailbox head", (0, 0.03, 1.00), (0.88, 0.85, 0.41), "earth", 0.08)
    b("Copper lid", (0, 0.03, 1.21), (0.92, 0.91, 0.13), "earth_light", 0.041)
    b("Slot frame", (0, -0.403, 1.06), (0.68, 0.04, 0.13), "deep", 0.017)
    b("Mail slot", (0, -0.43, 1.06), (0.54, 0.024, 0.056), "outline", 0.004)
    b("Label", (0, -0.403, 0.91), (0.25, 0.05, 0.095), "cream")
    b("Label stripe", (0, -0.431, 0.91), (0.143, 0.012, 0.023), "earth", 0)


def avatar(part):
    b = part.box
    for x, name in ((-0.14, "LegLeft"), (0.14, "LegRight")):
        pivot = part.pivot(name, (x, 0, 0.56))
        b("Trouser leg", (x, 0.04, 0.33), (0.22, 0.34, 0.48), "legs", 0.045, pivot)
        b("Shoe", (x, -0.094, 0.083), (0.25, 0.57, 0.166), "shoes", 0.040, pivot)
    b("Shirt torso", (0, 0.035, 0.85), (0.65, 0.43, 0.62), "shirt", 0.10)
    b("Collar", (0, -0.13, 1.09), (0.22, 0.13, 0.14), "ivory", 0.033)
    b("Neck", (0, 0, 1.13), (0.21, 0.24, 0.23), "skin", 0.045)
    for x in (-0.405, 0.405):
        b("Sleeve", (x, 0.045, 0.935), (0.19, 0.34, 0.35), "shirt", 0.055)
        b("Hand", (x, -0.012, 0.735), (0.17, 0.25, 0.19), "skin", 0.053)
    b("Head", (0, -0.04, 1.345), (0.59, 0.55, 0.47), "skin", 0.096)
    b("Hair cap", (0, 0.019, 1.545), (0.64, 0.59, 0.22), "hair", 0.077)
    b("Hair back", (0, 0.243, 1.38), (0.58, 0.22, 0.42), "hair", 0.06)
    b("Hair fringe", (-0.16, -0.262, 1.49), (0.306, 0.18, 0.15), "hair", 0.050)
    for x in (-0.13, 0.13):
        b("Eye", (x, -0.317, 1.362), (0.055, 0.022, 0.068), "outline", 0.011)
    b("Nose", (0, -0.32, 1.304), (0.08, 0.09, 0.075), "skin", 0.026)
    b("Smile", (0, -0.318, 1.235), (0.102, 0.026, 0.027), "earth", 0.010)


def bounds(collection):
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    meshes = [obj.evaluated_get(depsgraph) for obj in collection.objects if obj.type == "MESH"]
    points = [obj.matrix_world @ vertex.co for obj in meshes for vertex in obj.data.vertices]
    lo = Vector(min(point[i] for point in points) for i in range(3))
    hi = Vector(max(point[i] for point in points) for i in range(3))
    return lo, hi


def normalize(part):
    lo, hi = bounds(part.collection)
    center = (lo + hi) * 0.5
    center.z = lo.z
    scale = Vector((1 / (hi.x - lo.x), 1 / (hi.y - lo.y), 1))
    # Keep hinge and limb origins independent when normalizing the whole part.
    for obj in part.collection.objects:
        if obj.parent is None:
            obj.location = (obj.location - center) * scale
            obj.scale = scale


def select(objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]


def combine_meshes(collection):
    groups = defaultdict(list)
    for obj in list(collection.objects):
        if obj.type != "MESH":
            continue
        bpy.context.view_layer.objects.active = obj
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        groups[(obj.parent, obj.data.materials[0].name)].append(obj)

    for (parent, material), objects in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        merged = bpy.data.objects.new(material if parent is None else f"{material}_{parent.name}", bpy.data.meshes.new(material))
        collection.objects.link(merged)
        merged.parent = parent
        merged.data.materials.append(objects[0].data.materials[0])
        select([merged, *objects])
        bpy.ops.object.join()


def build_source():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    materials = make_materials()
    scene = bpy.context.scene
    scene.name = "Office kit | 3D"
    scene.unit_settings.system = "METRIC"
    scene["export_convention"] = "Blender +Z up and -Y front. Godot +Y up and +Z front."
    builders = {
        "desk": desk, "desk_square": lambda part: desk(part, square=True), "chair": chair,
        "table": table, "sofa": sofa, "reception": reception, "core": core, "plant": plant,
        "arcade": arcade, "door": door, "mailbox": mailbox, "avatar": avatar,
    }
    for index, kind in enumerate(KINDS):
        part = KitPart(kind, materials)
        builders[kind](part)
        normalize(part)
        root = part.pivot(f"Asset_{kind}", (0, 0, 0))
        for obj in part.collection.objects:
            if obj != root and obj.parent is None:
                obj.parent = root
        root.location = (2.1 * ((index % 4) - 1.5), 2.4 * (1 - index // 4), 0)

    bpy.ops.object.select_all(action="DESELECT")
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                space = area.spaces.active
                space.shading.color_type = "MATERIAL"
                space.overlay.show_extras = False
                space.region_3d.view_location = (0, 0, 0.55)
                space.region_3d.view_rotation = Quaternion((1, 0, 0), 0.85)
                space.region_3d.view_distance = 12
                space.region_3d.view_perspective = "ORTHO"
    bpy.context.preferences.filepaths.save_version = 0
    SOURCE.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE), compress=True)


def main():
    arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if arguments == ["--from-blend"]:
        bpy.ops.wm.open_mainfile(filepath=str(SOURCE), use_scripts=False)
    elif not arguments:
        build_source()
    else:
        raise ValueError("Supported arguments: --from-blend")

    exports = []
    for kind in KINDS:
        collection = bpy.data.collections[f"office3d_{kind}"]
        layer = bpy.context.view_layer.layer_collection.children[collection.name]
        layer.exclude = False
        layer.hide_viewport = False
        collection.hide_viewport = False
        for obj in collection.objects:
            obj.hide_viewport = False
            obj.hide_set(False)
        root = collection.objects[f"Asset_{kind}"]
        root.location = (0, 0, 0)
        lo, hi = bounds(collection)
        if (lo - Vector((-0.5, -0.5, 0))).length > 0.001 or (hi.xy - Vector((0.5, 0.5))).length > 0.001:
            raise ValueError(f"{kind} must retain its centered 1 x 1 m footprint and ground contact")
        exports.append((kind, collection, round(hi.z, 6)))

    TARGET.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(prefix="office3d-", dir=ROOT / "art") as directory:
        staging = Path(directory)
        models = {}
        for kind, collection, height in exports:
            combine_meshes(collection)
            select(list(collection.objects))
            path = staging / f"{kind}.glb"
            result = bpy.ops.export_scene.gltf(
                filepath=str(path), export_format="GLB", use_selection=True,
                export_yup=True, export_animations=False, export_apply=True,
            )
            if result != {"FINISHED"}:
                raise RuntimeError(f"Export failed for {kind}: {result}")
            models[kind] = {
                "path": (TARGET / path.name).relative_to(ROOT).as_posix(), "height_m": height,
                **glb_summary(path),
            }

        manifest = {
            "schema_version": 1,
            "origin": "Original project artwork. Palette and motifs adapted from the project's original office sprites.",
            "rights": "Project-owned source. Public source license and redistribution permission are unspecified.",
            "blender_version": bpy.app.version_string,
            "recipe": "scripts/blender_office_3d.py",
            "source": {"path": SOURCE.relative_to(ROOT).as_posix(), "sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest()},
            "gltf_axes": {"up": "+Y", "front": "+Z"},
            "footprint_m": [1, 1],
            "models": models,
        }
        if MANIFEST.exists():
            existing_map = json.loads(MANIFEST.read_text(encoding="utf-8")).get("assembled_map")
            if existing_map:
                manifest["assembled_map"] = existing_map
        staged_manifest = staging / MANIFEST.name
        staged_manifest.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        for path in staging.glob("*.glb"):
            path.replace(TARGET / path.name)
        staged_manifest.replace(MANIFEST)


if __name__ == "__main__":
    main()
