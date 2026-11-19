"""Verify the editable Blender source and reimport all twelve delivered GLBs."""

import hashlib
import json
import math
import struct
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/source/office-kit-3d.blend"
TARGET = ROOT / "game/art/office3d"
MANIFEST = ROOT / "art/office3d-manifest.json"
KINDS = (
    "desk", "desk_square", "chair", "table", "sofa", "reception",
    "core", "plant", "arcade", "door", "mailbox", "avatar",
)


def glb_summary(path):
    raw = path.read_bytes()
    magic, version, length, chunk_length, chunk_type = struct.unpack_from("<4sIII4s", raw)
    assert (magic, version, length, chunk_type) == (b"glTF", 2, len(raw), b"JSON"), path
    document = json.loads(raw[20:20 + chunk_length])
    assert not document.get("images"), path
    assert all("uri" not in buffer for buffer in document.get("buffers", [])), path
    primitives = [primitive for mesh in document["meshes"] for primitive in mesh["primitives"]]
    assert all(primitive.get("mode", 4) == 4 for primitive in primitives), path
    triangles = sum(document["accessors"][primitive["indices"]]["count"] // 3 for primitive in primitives)
    assert 24 <= triangles < 6000, (path, triangles)
    return {"sha256": hashlib.sha256(raw).hexdigest(), "bytes": length, "triangles": triangles}


def inspect_import(kind, path, expected):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    assert bpy.ops.import_scene.gltf(filepath=str(path)) == {"FINISHED"}, kind
    objects = bpy.context.scene.objects
    meshes = [obj for obj in objects if obj.type == "MESH"]
    points = [obj.matrix_world @ vertex.co for obj in meshes for vertex in obj.data.vertices]
    bounds = [(min(point[i] for point in points), max(point[i] for point in points)) for i in range(3)]
    for xyz in bounds[:2]:
        assert math.isclose(xyz[0], -0.5, abs_tol=0.001), (kind, bounds)
        assert math.isclose(xyz[1], 0.5, abs_tol=0.001), (kind, bounds)
    assert math.isclose(bounds[2][0], 0.0, abs_tol=0.001), (kind, bounds)
    assert math.isclose(bounds[2][1], expected["height_m"], abs_tol=0.001), (kind, bounds)
    for obj in meshes:
        obj.data.calc_loop_triangles()
    assert sum(len(obj.data.loop_triangles) for obj in meshes) == expected["triangles"], kind

    if kind == "avatar":
        materials = {mat.name.lower() for obj in meshes for mat in obj.data.materials if mat}
        assert {"skin", "hair", "shirt", "legs"} <= materials, materials
        assert {"LegLeft", "LegRight"} <= set(objects.keys())
    if kind == "door":
        leaf = objects["DoorLeaf"]
        assert leaf.children and leaf.matrix_world.translation.x < -0.35
        assert math.isclose(leaf.matrix_world.translation.z, 0.0, abs_tol=0.001)
        for obj in meshes:
            if obj.parent == leaf:
                continue
            for vertex in obj.data.vertices:
                position = obj.matrix_world @ vertex.co
                assert abs(position.x) >= 0.36 or position.z >= 1.8, obj.name


def main():
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    assert set(manifest["models"]) == set(KINDS)
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == manifest["source"]["sha256"]
    assert bpy.ops.wm.open_mainfile(filepath=str(SOURCE), use_scripts=False) == {"FINISHED"}
    assert not bpy.data.texts
    assert not bpy.data.libraries
    for kind in KINDS:
        collection = bpy.data.collections[f"office3d_{kind}"]
        assert len(collection.objects) > 1, kind
    assert {path.stem for path in TARGET.glob("*.glb")} == set(KINDS)
    for kind in KINDS:
        path = TARGET / f"{kind}.glb"
        expected = manifest["models"][kind]
        assert expected["path"] == path.relative_to(ROOT).as_posix()
        assert all(expected[key] == value for key, value in glb_summary(path).items()), kind
        inspect_import(kind, path, expected)
        print(f"{kind}: {expected['triangles']} triangles, {expected['bytes']} bytes")
    print(f"Verified Blender source and {len(KINDS)} imported GLBs")
    if "assembled_map" in manifest:
        inspect_map(manifest["assembled_map"], manifest["source"]["sha256"])


def inspect_map(expected, kit_hash):
    path = ROOT / expected["path"]
    layout_data = (ROOT / expected["layout"]).read_bytes()
    layout = json.loads(layout_data)
    assert path.stat().st_size == expected["bytes"]
    assert hashlib.sha256(path.read_bytes()).hexdigest() == expected["sha256"]
    assert hashlib.sha256(layout_data).hexdigest() == expected["layout_sha256"]
    assert kit_hash == expected["kit_sha256"]
    assert bpy.ops.wm.open_mainfile(filepath=str(path), use_scripts=False) == {"FINISHED"}
    scene = bpy.context.scene
    assert not bpy.data.libraries and not bpy.data.texts
    assert scene["pixels_per_meter"] == expected["pixels_per_meter"] == 40
    assert scene["layout_sha256"] == expected["layout_sha256"]
    assert scene["kit_sha256"] == kit_hash
    collections = scene.collection.children
    assert set(collections.keys()) == {"Floors", "Walls", "Furniture", "Doors", "Gameplay", "Labels"}
    assert collections["Floors"].objects["OfficeFloor"].type == "MESH"
    furniture = {obj["layout_id"]: obj for obj in collections["Furniture"].objects if "layout_id" in obj}
    assert set(furniture) == {item["id"] for item in layout["objects"]}
    for item in layout["objects"]:
        obj = furniture[item["id"]]
        actual = (*obj.location, *obj.scale, obj.rotation_euler.z)
        position = (item["x"] / 40, -item["y"] / 40, 0)
        dimensions = (item["w"] / 40, item["d"] / 40, 1)
        assert all(math.isclose(a, b, abs_tol=0.0001) for a, b in zip(actual, (*position, *dimensions, item["rotation"])))
        assert any(child.type == "MESH" for child in obj.children_recursive)
    doors = [obj for obj in collections["Doors"].objects if obj.get("kind") == "door"]
    assert len(doors) == len(layout["doors"]) + 3
    assert all(any(child.name.startswith("DoorLeaf") for child in door.children) for door in doors)
    gameplay = collections["Gameplay"].objects
    assert len([obj for obj in gameplay if obj.get("kind") == "arcade"]) == 6
    assert gameplay["Office mailbox"].get("kind") == "mailbox"
    print(f"Verified assembled Blender scene: {len(furniture)} furniture instances, {len(doors)} door models, 6 arcade stations")


if __name__ == "__main__":
    main()
