<img src="addons/vertex_painter/icon.png" width="64" align="left" />

## godot-vertex-painter
 
**A simple tool to paint vertex colors on MeshInstance3Ds.**

[Youtube video](https://youtu.be/kPeYi7-9U6U)

---

**Godot Versions Tested**
- v4.3.5 dev release
- v4.1.1

---
**V2.0: May 6, 2024**
- Paint directly on MeshInstance3Ds. StaticBodies are no longer required!
- This is thanks to an updated algorithm to find the 3D surface: https://twitter.com/_michaeljared/status/1787020920751579407
- Interface is improved
- Bucketfill is temporarily removed, let me know if you want this feature

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
