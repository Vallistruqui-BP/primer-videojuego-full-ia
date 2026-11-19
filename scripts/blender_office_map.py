"""Assemble the office layout as an editable Blender scene."""

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_LAYOUT = ROOT / "game/data/office_layout.json"
DEFAULT_MAP = ROOT / "art/source/office-map-3d.blend"
KIT = ROOT / "art/source/office-kit-3d.blend"
MANIFEST = ROOT / "art/office3d-manifest.json"
PIXELS_PER_METER = 40
STATIONS = ("Snake", "Terminal", "Pong", "Ta-te-ti", "Memoria", "Trivia")


def point(x, y, elevation=0):
    return (x / PIXELS_PER_METER, -y / PIXELS_PER_METER, elevation)


def color_material(name, hex_color):
    def linear(channel):
        return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4

    rgba = tuple(linear(int(hex_color[i:i+2], 16) / 255) for i in (0, 2, 4)) + (1,)
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = rgba
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = rgba
    shader.inputs["Roughness"].default_value = 0.78
    return mat


class OfficeMap:
    def __init__(self, scene, assets):
        self.assets = assets
        self.collections = {}
        for name in ("Floors", "Walls", "Furniture", "Doors", "Gameplay", "Labels"):
            collection = bpy.data.collections.new(name)
            scene.collection.children.link(collection)
            self.collections[name] = collection
        self.materials = {
            name: color_material(name, color) for name, color in {
                "Oak floor": "e6dac3", "Room floor inset": "d3d9ce", "Perimeter wall": "46655e",
                "Office interior wall": "637d73", "Perimeter foundation": "263f3c",
                "Room arcade floor": "465663", "Room arcade edge": "293f46",
                "Arcade station pad": "536a76", "Floor lettering": "334e47",
                "Sign lettering": "f7ead4", "Workshop mat": "ba8246",
                "Arcade mat": "874c82", "Office mat": "697e70",
            }.items()
        }

    def mesh(self, group, name, verts, faces, material, location=(0, 0, 0)):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(verts, [], faces)
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        obj.location = location
        obj.data.materials.append(self.materials[material])
        self.collections[group].objects.link(obj)
        return obj

    def box(self, group, name, location, size, material):
        w, d, h = (dimension / 2 for dimension in size)
        ring = [(-w, -d), (w, -d), (w, d), (-w, d)]
        verts = [(x, y, z) for z in (-h, h) for x, y in ring]
        faces = [(3, 2, 1, 0), (4, 5, 6, 7)]
        faces += [(i, (i+1) % 4, (i+1) % 4 + 4, i+4) for i in range(4)]
        return self.mesh(group, name, verts, faces, material, location)

    def floor(self, outline):
        vertices = [point(*xy) for xy in outline]
        signed_area = sum(
            a[0] * b[1] - b[0] * a[1] for a, b in zip(vertices, vertices[1:] + vertices[:1])
        )
        indices = tuple(range(len(vertices)))
        if signed_area < 0:
            indices = tuple(reversed(indices))
        obj = self.mesh("Floors", "OfficeFloor", vertices, [indices], "Oak floor")
        thickness = obj.modifiers.new("Floor slab", "SOLIDIFY")
        thickness.thickness = 0.15
        thickness.offset = -1

    def prop(self, group, name, kind, x, y, dimensions, rotation=0):
        source_root = self.assets[kind]
        source_objects = [source_root, *source_root.children_recursive]
        instances = {source: source.copy() for source in source_objects}
        root = instances[source_root]
        root.name = name
        root.location = point(x, y)
        root.scale = dimensions
        root.rotation_euler.z = rotation
        root["kind"] = kind
        for source, instance in instances.items():
            self.collections[group].objects.link(instance)
            if source != source_root:
                instance.parent = instances[source.parent]
        return root

    def door(self, name, x, y, width, rotation=0):
        width /= PIXELS_PER_METER
        root = self.prop("Doors", name, "door", x, y, (1, 1, 1), rotation)
        # Apply jamb depth and lever thickness in model space. Leave the hinge parent
        # at a uniform scale so its rotation reflects the in-engine door swing.
        for obj in root.children_recursive:
            obj.location.x *= width
            obj.location.y *= 0.22
            if obj.type == "MESH":
                obj.scale.x *= width
                obj.scale.y *= 0.22
        return root

    def label(self, text, x, y, elevation, size, on_floor):
        curve = bpy.data.curves.new(text, "FONT")
        curve.body = text
        curve.align_x = "CENTER"
        curve.align_y = "CENTER"
        curve.size = size
        curve.materials.append(self.materials["Floor lettering" if on_floor else "Sign lettering"])
        obj = bpy.data.objects.new(text, curve)
        obj.location = point(x, y, elevation)
        if not on_floor:
            obj.rotation_euler.x = math.pi / 2
        self.collections["Labels"].objects.link(obj)

    def portal(self, name, x, y, material):
        self.box("Gameplay", f"{name} · portal mat", point(x, y, 0.01), (1.55, 1.12, 0.03), material)
        self.door(f"{name} · portal frame", x, y, 47)
        self.label(name, x, y, 2.75, 0.49, False)


def build_office(office, layout):
    outline = layout["outline"]
    office.floor(outline)
    for index, ((ax, ay), (bx, by)) in enumerate(zip(outline, outline[1:] + outline[:1]), start=1):
        x, y = (ax + bx) / 2, (ay + by) / 2
        length = math.hypot(bx - ax, by - ay) / PIXELS_PER_METER
        angle = math.atan2(ay - by, bx - ax)
        wall = office.box("Walls", f"Perimeter {index:02d}", point(x, y, 0.23), (length, 0.16, 0.46), "Perimeter wall")
        foundation = office.box("Walls", f"Foundation {index:02d}", point(x, y, -0.16), (length + 0.1, 0.24, 0.32), "Perimeter foundation")
        wall.rotation_euler.z = foundation.rotation_euler.z = angle
    for index, (x, y, w, d) in enumerate(layout["walls"], start=1):
        office.box("Walls", f"Partition {index:02d}", point(x + w / 2, y + d / 2, 0.5), (w / 40, d / 40, 1), "Office interior wall")
    for room in layout["rooms"]:
        x, y, w, d, title = (room[key] for key in ("x", "y", "w", "d", "title"))
        office.box("Floors", title, point(x + w / 2, y + d / 2, 0.003), (w / 40, d / 40, 0.014), "Room floor inset")
        office.label(title, x + w / 2, y + d * 0.8, 0.018, 0.29, True)
    for item in layout["objects"]:
        name = f"{item['id']} · {item['kind']}"
        root = office.prop("Furniture", name, item["kind"], item["x"], item["y"], (item["w"] / 40, item["d"] / 40, 1), item["rotation"])
        root["layout_id"] = item["id"]
        root["zone"] = item["zone"]
    for index, door in enumerate(layout["doors"], start=1):
        office.door(f"Office door {index:02d}", door["x"], door["y"], door["width"], door["rotation"])
    for label in layout["labels"]:
        office.label(label["text"], label["x"], label["y"], 0.022, 0.35, True)


def build_gameplay(office):
    office.portal("TALLER", 470, 635, "Workshop mat")
    office.portal("ARCADE", 920, 685, "Arcade mat")
    office.prop("Gameplay", "Office mailbox", "mailbox", 660, 810, (25 / 40, 22 / 40, 1))
    office.label("BUZÓN", 660, 825, 0.03, 0.36, True)
    office.box("Floors", "Arcade room slab", point(2100, 535, -0.14), (16, 11.75, 0.28), "Room arcade floor")
    for index, (x, y, w, d) in enumerate(((1780, 300, 640, 20), (1780, 750, 640, 20), (1780, 320, 20, 430), (2400, 320, 20, 430)), start=1):
        office.box("Walls", f"Arcade edge {index}", point(x + w / 2, y + d / 2, 0.24), (w / 40, d / 40, 0.48), "Room arcade edge")
    for index, caption in enumerate(STATIONS):
        x, y = 1870 + (index % 3) * 220, 390 + (index // 3) * 150
        office.box("Gameplay", f"{caption} · station mat", point(x, y, 0.006), (2.8, 2.7, 0.022), "Arcade station pad")
        office.prop("Gameplay", f"{caption} · cabinet", "arcade", x, y, (60 / 40, 49 / 40, 1))
        office.label(caption, x, y, 2.3, 0.51, False)
    office.portal("OFICINA", 2100, 730, "Office mat")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--layout", type=Path, default=DEFAULT_LAYOUT)
    parser.add_argument("--output", type=Path, default=DEFAULT_MAP)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    layout_path, output_path = args.layout.resolve(), args.output.resolve()
    if output_path.suffix != ".blend" or output_path == KIT:
        parser.error("Choose a .blend output distinct from office-kit-3d.blend")
    if layout_path != DEFAULT_LAYOUT and output_path == DEFAULT_MAP:
        parser.error("An alternate --layout needs an explicit --output")
    layout_data = layout_path.read_bytes()
    layout = json.loads(layout_data)
    if layout.get("schema") != 1:
        raise ValueError("Expected office layout schema 1")

    bpy.ops.wm.open_mainfile(filepath=str(KIT), use_scripts=False)
    kit_scene = bpy.context.scene
    assets = {
        collection.name.removeprefix("office3d_"): next(obj for obj in collection.objects if obj.name.startswith("Asset_"))
        for collection in kit_scene.collection.children
    }
    scene = bpy.data.scenes.new("Office and Arcade | Editable Map")
    bpy.context.window.scene = scene
    scene.unit_settings.system = "METRIC"
    scene["pixels_per_meter"] = PIXELS_PER_METER
    scene["layout_sha256"] = hashlib.sha256(layout_data).hexdigest()
    scene["kit_sha256"] = hashlib.sha256(KIT.read_bytes()).hexdigest()
    scene["layout_origin"] = layout_path.relative_to(ROOT).as_posix() if layout_path.is_relative_to(ROOT) else layout_path.name
    office = OfficeMap(scene, assets)
    build_office(office, layout)
    build_gameplay(office)
    bpy.data.scenes.remove(kit_scene)

    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                space = area.spaces.active
                space.shading.color_type = "MATERIAL"
                space.overlay.show_extras = False
                space.overlay.show_floor = False
                space.overlay.show_axis_x = False
                space.overlay.show_axis_y = False
                space.region_3d.view_rotation = Quaternion((1, 0, 0), 0.67)
                space.region_3d.view_location = Vector((30, -12, 0))
                space.region_3d.view_distance = 71
                space.region_3d.view_perspective = "ORTHO"
    bpy.context.preferences.filepaths.save_version = 0
    output_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output_path), compress=True)
    if output_path == DEFAULT_MAP:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        manifest["assembled_map"] = {
            "path": output_path.relative_to(ROOT).as_posix(), "bytes": output_path.stat().st_size,
            "sha256": hashlib.sha256(output_path.read_bytes()).hexdigest(),
            "recipe": "scripts/blender_office_map.py", "layout": scene["layout_origin"],
            "layout_sha256": scene["layout_sha256"], "kit_sha256": scene["kit_sha256"],
            "pixels_per_meter": PIXELS_PER_METER,
        }
        MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Built {len(layout['objects'])} furniture instances, {len(layout['doors'])} office doors and {len(STATIONS)} arcade stations")


if __name__ == "__main__":
    main()
