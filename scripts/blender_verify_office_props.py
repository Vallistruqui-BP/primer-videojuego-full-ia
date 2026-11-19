"""Read-only asset verification, run after opening office-props.blend with autoexec disabled."""
import bpy
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / "art/asset-manifest.json").read_text(encoding="utf-8"))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
assert bpy.data.filepath == str(root / "art/source/office-props.blend"), "Wrong blend file"
assert set(bpy.data.scenes.keys()) == {"Desk", "Desk_square", "Chair", "Door"}
assert not bpy.data.texts, "Unexpected embedded script"
assert sha(root / manifest["recipe"]) == manifest["recipe_sha256"]
rows = []
for asset in manifest["assets"]:
    assert sha(root / asset["original"]) == asset["sha256"]
    path = root / asset["derivatives"][0]
    assert sha(path) == asset["derivative_sha256"]
    assert path.stat().st_size == asset["derivative_bytes"]
    image = bpy.data.images.load(str(path), check_existing=False)
    assert list(image.size) == asset["dimensions"]
    assert image.channels == 4
    alpha = list(image.pixels)[3::4]
    assert min(alpha) == 0 and max(alpha) == 1, "Missing transparent or opaque pixels"
    scene = bpy.data.scenes[asset["scene"]]
    assert scene.camera.data.type == "ORTHO"
    assert scene.render.film_transparent
    assert all(mod.type != "NODES" for obj in scene.objects for mod in obj.modifiers)
    rows.append({"asset":asset["id"], "dimensions":list(image.size), "bytes":path.stat().st_size,
                 "meshes":sum(obj.type == "MESH" for obj in scene.objects), "transparent":True})
print("OFFICE_ART_VERIFY_PASS", json.dumps({"blender":bpy.app.version_string, "embedded_scripts":0,
       "files_and_hashes_verified":True, "assets":rows, "png_bytes":sum(row["bytes"] for row in rows)}))
