"""terminal-gun model generator — runs inside Blender headless.

Low-poly per definizione: primitive con pochi segmenti, vertex color,
nessuna texture, nessun rig. Deterministico: SEED fisso, nessuna data
nei dati, stesso comando -> stessi byte (a pari versione di Blender).
Uso:
    blender -b --python tools/blender/gen_models.py -- --out assets/models
"""
import argparse
import os
import random
import sys

SEED = 1337

# nome -> (colore RGBA, dimensione indicativa)
COLORS = {
    "enemy_small": (0.9, 0.15, 0.15, 1.0),
    "enemy_big": (0.85, 0.4, 0.05, 1.0),
    "enemy_boss": (0.55, 0.1, 0.85, 1.0),
    "player": (0.1, 0.85, 0.9, 1.0),
    "ground_tile": (0.25, 0.35, 0.25, 1.0),
    "crate": (0.55, 0.38, 0.2, 1.0),
}

NAMES = ["enemy_small", "enemy_big", "enemy_boss", "player", "ground_tile", "crate"]


def parse_out():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    args = ap.parse_args(argv)
    return args.out


def clear_scene():
    import bpy
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    # rimuove datablock orfani per export puliti e stabili
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for x in list(coll):
            try:
                coll.remove(x)
            except Exception:
                pass


def paint_uniform(obj, color, rng):
    import bpy
    mesh = obj.data
    if hasattr(mesh, "color_attributes"):
        try:
            layer = mesh.color_attributes.new(
                name="Color", type="FLOAT_COLOR", domain="POINT")
        except Exception:
            layer = mesh.color_attributes.get("Color")
    else:
        # fallback Blender vecchi: vertex_colors
        try:
            layer = mesh.vertex_colors.new(name="Color")
        except Exception:
            layer = None
    if layer is None:
        return
    # leggera variazione deterministica per vertice (+/-3%) cosi' il
    # vertex color non e' degenere ma resta riproducibile via SEED
    try:
        for i in range(len(mesh.vertices)):
            f = 1.0 + (rng.uniform(-0.03, 0.03))
            c = (min(1.0, color[0] * f), min(1.0, color[1] * f),
                 min(1.0, color[2] * f), 1.0)
            try:
                layer.data[i].color = c
            except Exception:
                pass
    except Exception:
        pass


def add_material_vertex_color(obj, name):
    import bpy
    mat = bpy.data.materials.new(name="M_" + name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    out = nodes.new(type="ShaderNodeOutputMaterial")
    princ = nodes.new(type="ShaderNodeBsdfPrincipled")
    princ.inputs["Roughness"].default_value = 0.9
    princ.inputs["Metallic"].default_value = 0.0
    vcol = nodes.new(type="ShaderNodeVertexColor")
    vcol.layer_name = "Color"
    try:
        links.new(vcol.outputs["Color"], princ.inputs["Base Color"])
    except Exception:
        pass
    try:
        links.new(princ.outputs["BSDF"], out.inputs["Surface"])
    except Exception:
        pass
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)


def build(name):
    import bpy
    if name == "enemy_small":
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.5)
    elif name == "enemy_big":
        bpy.ops.mesh.primitive_cube_add(size=1.2)
    elif name == "enemy_boss":
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0)
    elif name == "player":
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.45, depth=1.1)
    elif name == "ground_tile":
        bpy.ops.mesh.primitive_plane_add(size=2.0)
    elif name == "crate":
        bpy.ops.mesh.primitive_cube_add(size=0.9)
    else:
        raise ValueError(name)
    obj = bpy.context.active_object
    obj.name = name
    return obj


def export_one(name, out_dir):
    import bpy
    clear_scene()
    rng = random.Random(SEED + NAMES.index(name))
    obj = build(name)
    paint_uniform(obj, COLORS[name], rng)
    add_material_vertex_color(obj, name)
    # applica trasformazioni per export stabile
    try:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    except Exception:
        pass
    path = os.path.join(out_dir, name + ".glb")
    try:
        bpy.ops.export_scene.gltf(
            filepath=path,
            use_selection=True,
            export_format="GLB",
            export_apply=True,
            export_cameras=False,
            export_lights=False,
            export_animations=False,
        )
    except TypeError:
        # fallback per firme diverse tra versioni di Blender
        bpy.ops.export_scene.gltf(
            filepath=path,
            use_selection=True,
            export_format="GLB",
        )
    print("wrote %s" % path)


def main():
    out_dir = parse_out()
    os.makedirs(out_dir, exist_ok=True)
    for name in NAMES:
        export_one(name, out_dir)


main()
