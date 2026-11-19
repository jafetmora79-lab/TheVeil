"""Pack 03 GLB writer: the shared Pack 02 writer plus glTF node `extras`
(interaction metadata: hinge / slide / switch, axis, open angle or distance).
Godot 4 imports node extras as node metadata."""
import res_materials  # noqa: F401  (path setup)
from veil_mesh.gltf import GLBWriter as _Base, write_glb_import, write_obj, COL_KEY  # noqa: F401


class GLBWriter(_Base):
    def add_node(self, spec, parent=None):
        idx = super().add_node(spec, parent)
        # super() appends children after the node itself; the node is at idx
        if spec.get("extras"):
            self.j["nodes"][idx]["extras"] = spec["extras"]
        return idx
