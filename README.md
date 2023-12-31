<img src="addons/vertex_painter/icon.png" width="64" align="left" />

## godot-vertex-painter
 
**A simple tool to paint vertex colors on MeshInstance3Ds.**

[Youtube video](https://youtu.be/kPeYi7-9U6U)

---

**Godot Versions Tested**

- v4.1.1

---
2024/01/02 updated UI:

![image](https://github.com/bikemurt/godot-vertex-painter/assets/23486102/6001e497-5619-43bf-9efb-2e0b52c734cd)

V1.2 features:
- Bucket fill
- GUI label to show which MeshInstance3D is active
- "Toggle Vertex Color" visualization now a button instead of checkbox (more intuitive to use)
- Copy vertex data feature: this allows you to save a mesh resource using Godot, and then later load the vertex colors from that mesh onto an identical mesh. This allows backing up vertex painting work
- Save vertex data: allows you to save the mesh from the active MeshInstance3D to the specified resource path

---
Paint directly in the 3D editor

https://github.com/bikemurt/godot-vertex-painter/assets/23486102/25de8684-ecca-4cc3-a9a3-e81fc87b09ed

---
Performance is good enough to interact with other plugins, (for example my fork of [godot-multimesh-scatter](https://github.com/bikemurt/godot-multimesh-scatter))

https://github.com/bikemurt/godot-vertex-painter/assets/23486102/3c218bdb-3fc2-4e35-9641-5d20e35f10e5

---
## 🚀 Install & Use

1. Download this [repository](https://github.com/bikemurt/godot-vertex-painter/), or download from the [Godot Asset Library](https://godotengine.org/asset-library/asset/2470).
    - Import the addons folder into your project (if it already isn't present).
2. Activate the Vertex Painter addon under Project > Project Settings > Plugins. If an error dialog appears, restart the engine and try activating it again.
3. Add a MeshInstance3D to the scene which you wish to paint vertex colors
4. Add a CollisionObject3D (such as StaticBody3D) to the mesh so that the painter can ray cast onto it
5. Set R, G and B values and click "Enable Painting" to start painting
6. (Optional) Click your MeshInstance3D in the scene tree and click "Show Colors" to get a visualization of the vertex colors.

## ⚠️ Limitations

- Only imported meshes will work (or ArrayMesh, which have a clear_surfaces() method)
- Scale *must* be applied to meshes prior to trying to vertex paint them

## 🏠 Links

- [Homepage](https://www.michaeljared.ca/)
- [Youtube](https://www.youtube.com/@michaeljburt)
- [Blender Market](https://blendermarket.com/creators/michaeljared)

## 🗒️ License

[MIT License](/LICENSE)
