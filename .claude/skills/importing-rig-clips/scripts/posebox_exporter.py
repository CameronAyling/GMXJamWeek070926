bl_info = {
    "name": "PoseBox Exporter",
    "author": "PoseBox",
    "version": (0, 1, 0),
    "blender": (3, 0, 0),
    "location": "File > Export > PoseBox Scene",
    "description": "Export rigged characters, animations, and scenes for GameMaker PoseBox",
    "category": "Import-Export",
}

import bpy
import json
import math
import os
import shutil
from mathutils import Matrix, Vector, Quaternion
from bpy_extras.io_utils import ExportHelper
from bpy.props import StringProperty, BoolProperty, EnumProperty


def round_value(val, precision=6):
    return round(val, precision)


def format_compact_json(data, indent=0):
    """Format JSON with compact numeric arrays"""
    indent_str = "  " * indent

    if isinstance(data, dict):
        lines = ["{"]
        items = list(data.items())
        for i, (key, value) in enumerate(items):
            comma = "," if i < len(items) - 1 else ""
            if isinstance(value, (dict, list)):
                lines.append(f'{indent_str}  "{key}": {format_compact_json(value, indent + 1)}{comma}')
            else:
                lines.append(f'{indent_str}  "{key}": {json.dumps(value)}{comma}')
        lines.append(indent_str + "}")
        return "\n".join(lines)

    elif isinstance(data, list):
        if not data:
            return "[]"

        # Check if it's a numeric array
        if all(isinstance(x, (int, float)) for x in data):
            # Format numeric arrays compactly
            if len(data) <= 16:
                return json.dumps(data)
            else:
                # Split long arrays into chunks of 16 per line
                lines = ["["]
                for i in range(0, len(data), 16):
                    chunk = data[i:i+16]
                    chunk_str = ", ".join(json.dumps(x) for x in chunk)
                    comma = "," if i + 16 < len(data) else ""
                    lines.append(f"{indent_str}  {chunk_str}{comma}")
                lines.append(indent_str + "]")
                return "\n".join(lines)
        else:
            # Format object arrays normally
            lines = ["["]
            for i, item in enumerate(data):
                comma = "," if i < len(data) - 1 else ""
                lines.append(f"{indent_str}  {format_compact_json(item, indent + 1)}{comma}")
            lines.append(indent_str + "]")
            return "\n".join(lines)

    else:
        return json.dumps(data)


class ExportPoseBoxScene(bpy.types.Operator, ExportHelper):
    bl_idname = "export_scene.posebox"
    bl_label = "Export PoseBox Scene"
    bl_options = {'PRESET'}

    filename_ext = ".json"

    filter_glob: StringProperty(
        default="*.json;*.bin",
        options={'HIDDEN'},
    )

    file_format: EnumProperty(
        name="Format",
        description="Export file format",
        items=(
            ('JSON', "JSON", "Export as JSON text file"),
            ('BINARY', "Binary", "Export as binary file (not yet implemented)"),
        ),
        default='JSON',
    )

    export_meshes: BoolProperty(
        name="Export Meshes",
        description="Export mesh geometry and vertex data",
        default=True,
    )

    export_skeleton: BoolProperty(
        name="Export Skeleton",
        description="Export armature and bone hierarchy",
        default=True,
    )

    export_animations: BoolProperty(
        name="Export Animations",
        description="Export animation actions",
        default=True,
    )

    export_materials: BoolProperty(
        name="Export Materials",
        description="Export PBR material parameters",
        default=True,
    )

    export_lights: BoolProperty(
        name="Export Lights",
        description="Export light objects",
        default=True,
    )

    export_cameras: BoolProperty(
        name="Export Cameras",
        description="Export camera objects",
        default=True,
    )

    animation_sample_rate: bpy.props.IntProperty(
        name="Sample Rate",
        description="Animation sampling rate (fps)",
        default=30,
        min=1,
        max=120,
    )

    export_selected_only: BoolProperty(
        name="Export Selected Only",
        description="Export only selected objects instead of entire scene",
        default=False,
    )

    vertex_precision: bpy.props.IntProperty(
        name="Vertex Precision",
        description="Decimal places for vertex positions",
        default=6,
        min=1,
        max=10,
    )

    normal_precision: bpy.props.IntProperty(
        name="Normal/UV Precision",
        description="Decimal places for normals, UVs, and weights",
        default=4,
        min=1,
        max=10,
    )

    optimize_static_bones: BoolProperty(
        name="Optimize Static Bones",
        description="Skip exporting keyframes for bones that don't move",
        default=True,
    )

    export_textures: BoolProperty(
        name="Export Textures",
        description="Copy texture files to a 'textures' folder next to the exported JSON",
        default=True,
    )

    def execute(self, context):
        if self.file_format == 'BINARY':
            self.report({'ERROR'}, "Binary export not yet implemented")
            return {'CANCELLED'}

        self._total_steps = 0
        self._current_step = 0
        self._exported_textures = {}

        scene_data = self.export_scene(context)

        try:
            with open(self.filepath, 'w') as f:
                f.write(format_compact_json(scene_data))
                f.write('\n')
            self.report({'INFO'}, f"PoseBox scene exported to {self.filepath}")
            return {'FINISHED'}
        except Exception as e:
            self.report({'ERROR'}, f"Export failed: {str(e)}")
            return {'CANCELLED'}

    def _get_objects(self, context):
        """Get objects to export based on selection mode."""
        if self.export_selected_only:
            return [obj for obj in context.selected_objects]
        else:
            return list(context.scene.objects)

    def _get_armature(self, context):
        """Find the first armature in the export set."""
        objects = self._get_objects(context)
        for obj in objects:
            if obj.type == 'ARMATURE':
                return obj
        return None

    def _build_bone_index_map(self, armature_obj):
        """Build a map of bone names to indices."""
        if not armature_obj:
            return {}
        bone_index_map = {}
        for i, bone in enumerate(armature_obj.data.bones):
            bone_index_map[bone.name] = i
        return bone_index_map

    def _build_material_index_map(self, context):
        """Build a map of material names to indices."""
        material_index_map = {}
        objects = self._get_objects(context)
        for obj in objects:
            if obj.type == 'MESH':
                for mat_slot in obj.material_slots:
                    mat = mat_slot.material
                    if mat and mat.name not in material_index_map:
                        material_index_map[mat.name] = len(material_index_map)
        return material_index_map

    def _report_progress(self, message):
        """Report progress to the user."""
        self._current_step += 1
        if self._total_steps > 0:
            progress = (self._current_step / self._total_steps) * 100
            self.report({'INFO'}, f"[{progress:.0f}%] {message}")
        else:
            self.report({'INFO'}, message)

    def _copy_texture(self, image):
        """Copy texture file and return relative path."""
        if not self.export_textures or not image:
            return None

        import hashlib
        import tempfile

        def get_file_hash(filepath):
            if not os.path.exists(filepath):
                return None
            hasher = hashlib.md5()
            with open(filepath, 'rb') as f:
                hasher.update(f.read())
            return hasher.hexdigest()

        def get_image_hash(image):
            if image.packed_file:
                temp_path = os.path.join(tempfile.gettempdir(), f"temp_{image.name}.png")
                image.save_render(temp_path)
                file_hash = get_file_hash(temp_path)
                os.remove(temp_path)
                return file_hash
            elif image.filepath:
                src_path = bpy.path.abspath(image.filepath)
                return get_file_hash(src_path)
            return None

        image_hash = get_image_hash(image)
        cache_key = f"{image.name}_{image_hash}" if image_hash else image.name

        if cache_key in self._exported_textures:
            return self._exported_textures[cache_key]

        export_dir = os.path.dirname(self.filepath)
        textures_dir = os.path.join(export_dir, "textures")
        os.makedirs(textures_dir, exist_ok=True)

        filename = bpy.path.basename(image.filepath) if image.filepath else image.name
        if not filename or filename == "":
            filename = f"{image.name}.png"

        base_name, ext = os.path.splitext(filename)
        if not ext:
            ext = ".png"
            filename = base_name + ext

        dest_path = os.path.join(textures_dir, filename)

        counter = 1
        while os.path.exists(dest_path):
            existing_hash = get_file_hash(dest_path)
            new_hash = get_image_hash(image)

            if existing_hash == new_hash:
                self._exported_textures[cache_key] = os.path.join("textures", filename)
                return self._exported_textures[cache_key]

            filename = f"{base_name}_{counter}{ext}"
            dest_path = os.path.join(textures_dir, filename)
            counter += 1

        try:
            if image.packed_file:
                image.save_render(dest_path)
                self.report({'INFO'}, f"Saved packed texture: {filename}")
            elif image.filepath:
                src_path = bpy.path.abspath(image.filepath)
                if os.path.exists(src_path):
                    shutil.copy2(src_path, dest_path)
                    self.report({'INFO'}, f"Copied texture: {filename}")
                else:
                    image.save_render(dest_path)
                    self.report({'INFO'}, f"Saved texture from memory: {filename}")
            else:
                image.save_render(dest_path)
                self.report({'INFO'}, f"Saved texture: {filename}")

        except Exception as e:
            self.report({'WARNING'}, f"Failed to save texture {filename}: {str(e)}")
            return None

        relative_path = f"textures/{filename}"
        self._exported_textures[cache_key] = relative_path
        return relative_path

    def export_scene(self, context):
        """Export the entire scene to PoseBox format."""
        scene_data = {
            "posebox_version": "1.0",
            "generator": f"posebox_exporter {bl_info['version'][0]}.{bl_info['version'][1]}.{bl_info['version'][2]}",
            "coordinate_system": "Z-up, right-handed",
            "units": "meters",
        }

        armature_obj = self._get_armature(context)
        bone_index_map = self._build_bone_index_map(armature_obj)
        material_index_map = self._build_material_index_map(context)

        # No unit scaling - use transforms as-is from Blender
        self._unit_scale = 1.0

        if self.export_meshes:
            self._report_progress("Exporting meshes...")
            scene_data["meshes"] = self.export_meshes_data(context, material_index_map, bone_index_map, armature_obj)

        if self.export_skeleton:
            self._report_progress("Exporting skeleton...")
            scene_data["skeleton"] = self.export_skeleton_data(context, armature_obj, bone_index_map)

        if self.export_animations:
            self._report_progress("Exporting animations...")
            scene_data["animations"] = self.export_animations_data(context, armature_obj, bone_index_map)

        if self.export_materials:
            self._report_progress("Exporting materials...")
            scene_data["materials"] = self.export_materials_data(context, material_index_map)

        if self.export_lights:
            self._report_progress("Exporting lights...")
            scene_data["lights"] = self.export_lights_data(context)

        if self.export_cameras:
            self._report_progress("Exporting cameras...")
            scene_data["cameras"] = self.export_cameras_data(context)

        self._report_progress("Exporting attachments...")
        scene_data["attachments"] = self.export_attachments_data(context, bone_index_map)

        self._report_progress("Exporting physics...")
        scene_data["physics"] = self.export_physics_data(context)

        return scene_data

    def export_meshes_data(self, context, material_index_map, bone_index_map, armature_obj):
        """Export all mesh data from the scene."""
        meshes = []
        objects = self._get_objects(context)

        for obj in objects:
            if obj.type != 'MESH':
                continue

            if obj.rigid_body:
                continue

            mesh_data = self.export_mesh(obj, context, material_index_map, bone_index_map, armature_obj)
            if mesh_data:
                meshes.append(mesh_data)

        return meshes

    def _triangulate_mesh(self, mesh):
        """Create a triangulated copy of the mesh."""
        import bmesh

        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.triangulate(bm, faces=bm.faces)

        temp_mesh = bpy.data.meshes.new("temp")
        bm.to_mesh(temp_mesh)
        bm.free()

        return temp_mesh

    def _get_vertex_bone_weights(self, vert, obj, bone_index_map):
        """Get bone indices and weights for a vertex (up to 4 bones)."""
        vert_bone_indices = [0, 0, 0, 0]
        vert_bone_weights = [0.0, 0.0, 0.0, 0.0]

        vert_weights = []
        for vg in vert.groups:
            if vg.weight > 0.0:
                vg_name = obj.vertex_groups[vg.group].name
                if vg_name in bone_index_map:
                    bone_idx = bone_index_map[vg_name]
                    vert_weights.append((bone_idx, vg.weight))

        vert_weights.sort(key=lambda x: x[1], reverse=True)
        vert_weights = vert_weights[:4]

        total_weight = sum(w[1] for w in vert_weights)
        if total_weight > 0.0:
            for i, (bone_idx, weight) in enumerate(vert_weights):
                vert_bone_indices[i] = bone_idx
                vert_bone_weights[i] = round_value(weight / total_weight, self.normal_precision)

        return vert_bone_indices, vert_bone_weights

    def export_mesh(self, obj, context, material_index_map, bone_index_map, armature_obj):
        """Export a single mesh object with all vertex data."""
        armature_modifier = None
        for modifier in obj.modifiers:
            if modifier.type == 'ARMATURE':
                armature_modifier = modifier
                break

        has_armature_modifier = armature_modifier is not None

        if has_armature_modifier and armature_modifier:
            original_show_viewport = armature_modifier.show_viewport
            armature_modifier.show_viewport = False

        try:
            depsgraph = context.evaluated_depsgraph_get()
            obj_eval = obj.evaluated_get(depsgraph)
            mesh = obj_eval.data

            if not mesh.polygons and obj.data.polygons:
                mesh = obj.data

            if not mesh.polygons:
                self.report({'WARNING'}, f"Mesh '{obj.name}' has no polygons, skipping")
                return None
        finally:
            if has_armature_modifier and armature_modifier:
                armature_modifier.show_viewport = original_show_viewport

        temp_mesh = self._triangulate_mesh(mesh)

        if not temp_mesh.uv_layers:
            self.report({'WARNING'}, f"Mesh '{obj.name}' has no UV layer, using (0,0) for all vertices")

        vertices = []
        normals = []
        uvs = []
        indices = []
        bone_indices = []
        bone_weights = []

        uv_layer = temp_mesh.uv_layers.active if temp_mesh.uv_layers else None
        vertex_groups = obj.vertex_groups

        has_skinning = armature_modifier is not None and vertex_groups and armature_obj

        # If scene has no armature, export meshes in local space (for attachment scenes)
        export_in_local_space = armature_obj is None

        vertex_map = {}
        vertex_index = 0

        for poly in temp_mesh.polygons:
            for loop_index in poly.loop_indices:
                loop = temp_mesh.loops[loop_index]
                vert_index = loop.vertex_index
                vert = temp_mesh.vertices[vert_index]

                uv = uv_layer.data[loop_index].uv if uv_layer else (0.0, 0.0)

                key = (vert_index, tuple(loop.normal), tuple(uv))

                if key not in vertex_map:
                    vertex_map[key] = vertex_index

                    world_co = obj.matrix_world @ vert.co
                    world_co = world_co * self._unit_scale
                    world_normal = (obj.matrix_world.to_3x3() @ loop.normal).normalized()

                    vertices.extend([
                        round_value(world_co.x, self.vertex_precision),
                        round_value(world_co.y, self.vertex_precision),
                        round_value(world_co.z, self.vertex_precision)
                    ])
                    normals.extend([
                        round_value(world_normal.x, self.normal_precision),
                        round_value(world_normal.y, self.normal_precision),
                        round_value(world_normal.z, self.normal_precision)
                    ])
                    uvs.extend([
                        round_value(uv[0], self.normal_precision),
                        round_value(uv[1], self.normal_precision)
                    ])

                    if has_skinning:
                        vert_bone_indices, vert_bone_weights = self._get_vertex_bone_weights(
                            vert, obj, bone_index_map
                        )
                        bone_indices.extend(vert_bone_indices)
                        bone_weights.extend(vert_bone_weights)

                    vertex_index += 1

                indices.append(vertex_map[key])

        bpy.data.meshes.remove(temp_mesh)

        if vertex_index == 0:
            self.report({'WARNING'}, f"Mesh '{obj.name}' has no valid vertices, skipping")
            return None

        mesh_data = {
            "name": obj.name,
            "vertices": vertices,
            "normals": normals,
            "uvs": uvs,
            "indices": indices
        }

        if obj.material_slots and obj.material_slots[0].material:
            mat_name = obj.material_slots[0].material.name
            if mat_name in material_index_map:
                mesh_data["material_index"] = material_index_map[mat_name]

        if has_skinning:
            mesh_data["bone_indices"] = bone_indices
            mesh_data["bone_weights"] = bone_weights

        return mesh_data

    def export_skeleton_data(self, context, armature_obj, bone_index_map):
        """Export skeleton bone hierarchy and rest pose."""
        if not armature_obj:
            return None

        armature = armature_obj.data
        bones_data = []

        for bone in armature.bones:
            parent_index = -1
            if bone.parent:
                parent_index = bone_index_map[bone.parent.name]

            world_matrix = armature_obj.matrix_world @ bone.matrix_local
            rest_matrix = self.matrix_to_list_scaled(world_matrix, self._unit_scale)

            inverse_bind_matrix = world_matrix.inverted()
            inverse_bind = self.matrix_to_list(inverse_bind_matrix)

            bone_data = {
                "name": bone.name,
                "parent": parent_index,
                "rest_matrix": rest_matrix,
                "inverse_bind_matrix": inverse_bind,
                "length": round_value(bone.length, self.normal_precision)
            }

            pose_bone = armature_obj.pose.bones.get(bone.name)
            if pose_bone:
                has_limits = (
                    pose_bone.use_ik_limit_x or
                    pose_bone.use_ik_limit_y or
                    pose_bone.use_ik_limit_z
                )

                if has_limits:
                    bone_data["rotation_limits"] = {
                        "use_limit_x": pose_bone.use_ik_limit_x,
                        "use_limit_y": pose_bone.use_ik_limit_y,
                        "use_limit_z": pose_bone.use_ik_limit_z,
                        "min_x": round_value(pose_bone.ik_min_x, self.normal_precision),
                        "max_x": round_value(pose_bone.ik_max_x, self.normal_precision),
                        "min_y": round_value(pose_bone.ik_min_y, self.normal_precision),
                        "max_y": round_value(pose_bone.ik_max_y, self.normal_precision),
                        "min_z": round_value(pose_bone.ik_min_z, self.normal_precision),
                        "max_z": round_value(pose_bone.ik_max_z, self.normal_precision)
                    }

            bones_data.append(bone_data)

        return {
            "bones": bones_data
        }

    def matrix_to_list(self, matrix):
        """Convert a 4x4 matrix to a flat list (column-major order)."""
        result = []
        for col in range(4):
            for row in range(4):
                result.append(round_value(matrix[row][col], self.vertex_precision))
        return result

    def matrix_to_list_scaled(self, matrix, scale):
        """Convert a 4x4 matrix to a flat list with translation scaled."""
        result = []
        for col in range(4):
            for row in range(4):
                value = matrix[row][col]
                # Scale translation components (last column, rows 0-2)
                if col == 3 and row < 3:
                    value *= scale
                result.append(round_value(value, self.vertex_precision))
        return result

    def _is_bone_static(self, keyframes, tolerance=0.0001):
        """Check if a bone's keyframes are all identical (static bone)."""
        if len(keyframes) <= 1:
            return True

        first_t = keyframes[0]["transform"]
        for kf in keyframes[1:]:
            t = kf["transform"]
            for i in range(3):
                if abs(first_t["pos"][i] - t["pos"][i]) > tolerance:
                    return False
                if abs(first_t["scale"][i] - t["scale"][i]) > tolerance:
                    return False
            for i in range(4):
                if abs(first_t["rot"][i] - t["rot"][i]) > tolerance:
                    return False
        return True

    def _sample_animation_frames(self, context, armature_obj, bone_index_map, frame_start, frame_end):
        """Sample all bones for all frames in an animation."""
        bone_tracks = {}

        for bone in armature_obj.data.bones:
            bone_tracks[bone.name] = []

        for frame in range(frame_start, frame_end + 1):
            context.scene.frame_set(frame)
            time = (frame - frame_start) / self.animation_sample_rate

            for pose_bone in armature_obj.pose.bones:
                if pose_bone.parent:
                    local_matrix = pose_bone.parent.matrix.inverted() @ pose_bone.matrix
                else:
                    local_matrix = armature_obj.matrix_world @ pose_bone.matrix

                loc, rot, scale = local_matrix.decompose()

                bone_tracks[pose_bone.name].append({
                    "time": round_value(time, self.normal_precision),
                    "transform": {
                        "pos": [
                            round_value(loc.x * self._unit_scale, self.vertex_precision),
                            round_value(loc.y * self._unit_scale, self.vertex_precision),
                            round_value(loc.z * self._unit_scale, self.vertex_precision)
                        ],
                        "rot": [
                            round_value(rot.x, self.normal_precision),
                            round_value(rot.y, self.normal_precision),
                            round_value(rot.z, self.normal_precision),
                            round_value(rot.w, self.normal_precision)
                        ],
                        "scale": [
                            round_value(scale.x, self.normal_precision),
                            round_value(scale.y, self.normal_precision),
                            round_value(scale.z, self.normal_precision)
                        ]
                    }
                })

        tracks = []
        for bone_name, keyframes in bone_tracks.items():
            if keyframes:
                if self.optimize_static_bones and self._is_bone_static(keyframes):
                    keyframes = [keyframes[0]]

                tracks.append({
                    "bone": bone_index_map[bone_name],
                    "keyframes": keyframes
                })

        return tracks

    def export_animations_data(self, context, armature_obj, bone_index_map):
        """Export all animation actions for the armature."""
        if not armature_obj or not armature_obj.animation_data:
            return []

        animations = []
        armature = armature_obj.data

        original_action = armature_obj.animation_data.action
        original_frame = context.scene.frame_current

        for action in bpy.data.actions:
            frame_start = int(action.frame_range[0])
            frame_end = int(action.frame_range[1])

            if frame_end <= frame_start:
                continue

            duration = (frame_end - frame_start) / self.animation_sample_rate

            armature_obj.animation_data.action = action

            tracks = self._sample_animation_frames(
                context, armature_obj, bone_index_map, frame_start, frame_end
            )

            animations.append({
                "name": action.name,
                "duration": round_value(duration, self.normal_precision),
                "sample_rate": self.animation_sample_rate,
                "tracks": tracks
            })

        armature_obj.animation_data.action = original_action
        context.scene.frame_set(original_frame)

        return animations

    def _has_armature_modifier(self, obj):
        """Check if object has an armature modifier (i.e., is skinned)."""
        for modifier in obj.modifiers:
            if modifier.type == 'ARMATURE':
                return True
        return False

    def export_attachments_data(self, context, bone_index_map):
        """Export objects parented to bones or with Child Of constraints (attachments like weapons, props)."""
        attachments = []
        objects = self._get_objects(context)

        for obj in objects:
            # Check for bone parenting
            if obj.parent and obj.parent.type == 'ARMATURE' and obj.parent_bone:
                if not self._has_armature_modifier(obj):
                    local_transform = self.matrix_to_list_scaled(obj.matrix_local, self._unit_scale)

                    attachments.append({
                        "name": obj.name,
                        "parent_bone": obj.parent_bone,
                        "transform": local_transform
                    })
            # Check for Child Of constraints
            else:
                for constraint in obj.constraints:
                    if constraint.type == 'CHILD_OF' and constraint.target and constraint.target.type == 'ARMATURE':
                        if constraint.subtarget and constraint.subtarget in bone_index_map:
                            # For Child Of constraint, we need to compute the local offset
                            # But we must handle bone scale correctly to avoid huge values
                            armature_obj = constraint.target
                            bone = armature_obj.data.bones[constraint.subtarget]
                            bone_world_matrix = armature_obj.matrix_world @ bone.matrix_local

                            # Decompose matrices to separate translation, rotation, and scale
                            bone_loc, bone_rot, bone_scale = bone_world_matrix.decompose()
                            obj_loc, obj_rot, obj_scale = obj.matrix_world.decompose()

                            # Compute local position offset (in bone's local space)
                            # Remove bone's position and rotation to get the offset
                            bone_world_no_scale = Matrix.LocRotScale(bone_loc, bone_rot, (1, 1, 1))
                            local_transform_matrix = bone_world_no_scale.inverted() @ obj.matrix_world
                            local_transform = self.matrix_to_list_scaled(local_transform_matrix, self._unit_scale)

                            attachments.append({
                                "name": obj.name,
                                "parent_bone": constraint.subtarget,
                                "transform": local_transform
                            })
                            break

        return attachments

    def export_materials_data(self, context, material_index_map):
        """Export PBR material parameters and texture references."""
        import os
        materials = []
        processed_materials = set()
        objects = self._get_objects(context)

        for obj in objects:
            if obj.type == 'MESH':
                for mat_slot in obj.material_slots:
                    mat = mat_slot.material
                    if mat and mat.name not in processed_materials:
                        processed_materials.add(mat.name)

                        material_data = {
                            "name": mat.name,
                            "base_color": [1.0, 1.0, 1.0, 1.0],
                            "metallic": 0.0,
                            "roughness": 0.8,
                            "specular": 0.5,
                            "emissive": [0.0, 0.0, 0.0],
                            "textures": {}
                        }

                        if mat.use_nodes:
                            normal_map_image = None
                            for node in mat.node_tree.nodes:
                                if node.type == 'NORMAL_MAP':
                                    color_input = node.inputs.get('Color')
                                    if color_input and color_input.is_linked:
                                        linked = color_input.links[0].from_node
                                        if linked.type == 'TEX_IMAGE' and linked.image:
                                            normal_map_image = linked.image
                                            self.report({'INFO'}, f"Found normal map for {mat.name}: {linked.image.name}")

                            for node in mat.node_tree.nodes:
                                if node.type == 'BSDF_PRINCIPLED':
                                    base_color_input = node.inputs.get('Base Color')
                                    if base_color_input:
                                        material_data["base_color"] = [
                                            round_value(v, self.normal_precision) for v in base_color_input.default_value
                                        ]

                                    metallic_input = node.inputs.get('Metallic')
                                    if metallic_input:
                                        material_data["metallic"] = round_value(
                                            metallic_input.default_value, self.normal_precision
                                        )

                                    roughness_input = node.inputs.get('Roughness')
                                    if roughness_input:
                                        material_data["roughness"] = round_value(
                                            roughness_input.default_value, self.normal_precision
                                        )

                                    specular_input = node.inputs.get('Specular')
                                    if specular_input:
                                        material_data["specular"] = round_value(
                                            specular_input.default_value, self.normal_precision
                                        )

                                    emission_input = node.inputs.get('Emission')
                                    if emission_input:
                                        material_data["emissive"] = [
                                            round_value(v, self.normal_precision) for v in emission_input.default_value[:3]
                                        ]

                                    for input_socket in node.inputs:
                                        if input_socket.is_linked:
                                            linked_node = input_socket.links[0].from_node

                                            if input_socket.name == 'Normal' and linked_node.type == 'NORMAL_MAP':
                                                color_input = linked_node.inputs.get('Color')
                                                if color_input and color_input.is_linked:
                                                    tex_node = color_input.links[0].from_node
                                                    if tex_node.type == 'TEX_IMAGE' and tex_node.image:
                                                        texture_path = self._copy_texture(tex_node.image)
                                                        if texture_path:
                                                            material_data["textures"]["normal"] = texture_path
                                            elif linked_node.type == 'TEX_IMAGE' and linked_node.image:
                                                if input_socket.name in ['Base Color', 'Metallic', 'Roughness']:
                                                    texture_path = self._copy_texture(linked_node.image)
                                                    if texture_path:
                                                        if input_socket.name == 'Base Color':
                                                            material_data["textures"]["base_color"] = texture_path
                                                        elif input_socket.name == 'Metallic':
                                                            material_data["textures"]["metallic"] = texture_path
                                                        elif input_socket.name == 'Roughness':
                                                            material_data["textures"]["roughness"] = texture_path

                            if normal_map_image and "normal" not in material_data["textures"]:
                                texture_path = self._copy_texture(normal_map_image)
                                if texture_path:
                                    material_data["textures"]["normal"] = texture_path

                        materials.append(material_data)

        return materials

    def export_cameras_data(self, context):
        """Export camera objects with transform and projection parameters."""
        cameras = []
        objects = self._get_objects(context)

        for obj in objects:
            if obj.type == 'CAMERA':
                camera = obj.data
                transform = self.matrix_to_list_scaled(obj.matrix_world, self._unit_scale)

                fov = 60.0
                if camera.type == 'PERSP':
                    fov = math.degrees(camera.angle)

                cameras.append({
                    "name": obj.name,
                    "transform": transform,
                    "fov": round_value(fov, self.normal_precision),
                    "near": round_value(camera.clip_start, self.normal_precision),
                    "far": round_value(camera.clip_end, self.normal_precision)
                })

        return cameras

    def export_lights_data(self, context):
        """Export light objects with transform, color, and intensity."""
        lights = []
        objects = self._get_objects(context)

        for obj in objects:
            if obj.type == 'LIGHT':
                light = obj.data
                transform = self.matrix_to_list_scaled(obj.matrix_world, self._unit_scale)

                light_type = "point"
                if light.type == 'POINT':
                    light_type = "point"
                elif light.type == 'SUN':
                    light_type = "directional"
                elif light.type == 'SPOT':
                    light_type = "spot"

                lights.append({
                    "name": obj.name,
                    "type": light_type,
                    "transform": transform,
                    "color": [round_value(c, self.normal_precision) for c in light.color],
                    "intensity": round_value(light.energy, self.normal_precision)
                })

        return lights

    def export_physics_data(self, context):
        """Export rigid body physics data including collision shapes and constraints."""
        physics_data = {
            "rigid_bodies": [],
            "constraints": []
        }

        armature_obj = self._get_armature(context)
        bone_index_map = self._build_bone_index_map(armature_obj) if armature_obj else {}

        rb_to_bone_map = {}
        if armature_obj and armature_obj.pose:
            for bone in armature_obj.pose.bones:
                for constraint in bone.constraints:
                    if constraint.type == 'COPY_TRANSFORMS' and constraint.target:
                        intermediary_armature = constraint.target
                        if intermediary_armature.type == 'ARMATURE':
                            for inter_bone in intermediary_armature.pose.bones:
                                for inter_constraint in inter_bone.constraints:
                                    if inter_constraint.type == 'CHILD_OF' and inter_constraint.target:
                                        if inter_bone.name == bone.name:
                                            rb_to_bone_map[inter_constraint.target.name] = bone.name

        objects = self._get_objects(context)

        for obj in objects:
            if obj.rigid_body:
                rb = obj.rigid_body

                collision_groups = [i for i in range(20) if rb.collision_collections[i]]

                collision_shape = {
                    "name": obj.name,
                    "type": rb.type,
                    "enabled": rb.enabled,
                    "collision_shape": rb.collision_shape,
                    "mass": round_value(rb.mass, self.normal_precision),
                    "friction": round_value(rb.friction, self.normal_precision),
                    "restitution": round_value(rb.restitution, self.normal_precision),
                    "kinematic": rb.kinematic,
                    "collision_groups": collision_groups,
                    "transform": self.matrix_to_list_scaled(obj.matrix_world, self._unit_scale),
                }

                if obj.name in rb_to_bone_map and rb_to_bone_map[obj.name] in bone_index_map:
                    collision_shape["bone_index"] = bone_index_map[rb_to_bone_map[obj.name]]

                if rb.collision_shape == 'CAPSULE':
                    dims = sorted([obj.dimensions[0], obj.dimensions[1], obj.dimensions[2]], reverse=True)
                    collision_shape["radius"] = round_value(max(dims[1], dims[2]) / 2, self.normal_precision)
                    collision_shape["height"] = round_value(dims[0], self.normal_precision)
                elif rb.collision_shape == 'MESH' or rb.collision_shape == 'CONVEX_HULL':
                    depsgraph = context.evaluated_depsgraph_get()
                    obj_eval = obj.evaluated_get(depsgraph)
                    mesh = obj_eval.data

                    # Fallback to base mesh if evaluated mesh is empty
                    if mesh and not mesh.polygons and obj.data.polygons:
                        mesh = obj.data

                    if mesh and mesh.polygons:
                        temp_mesh = self._triangulate_mesh(mesh)

                        vertices = []
                        indices = []

                        for vert in temp_mesh.vertices:
                            if rb.collision_shape == 'CONVEX_HULL':
                                local_co = vert.co * self._unit_scale
                                vertices.extend([
                                    round_value(local_co.x, self.vertex_precision),
                                    round_value(local_co.y, self.vertex_precision),
                                    round_value(local_co.z, self.vertex_precision)
                                ])
                            else:
                                world_co = obj.matrix_world @ vert.co
                                world_co = world_co * self._unit_scale
                                vertices.extend([
                                    round_value(world_co.x, self.vertex_precision),
                                    round_value(world_co.y, self.vertex_precision),
                                    round_value(world_co.z, self.vertex_precision)
                                ])

                        for poly in temp_mesh.polygons:
                            for vert_idx in poly.vertices:
                                indices.append(vert_idx)

                        collision_shape["vertices"] = vertices
                        collision_shape["indices"] = indices

                        bpy.data.meshes.remove(temp_mesh)
                else:
                    collision_shape["dimensions"] = [
                        round_value(obj.dimensions[0], self.normal_precision),
                        round_value(obj.dimensions[1], self.normal_precision),
                        round_value(obj.dimensions[2], self.normal_precision)
                    ]

                physics_data["rigid_bodies"].append(collision_shape)

            if obj.rigid_body_constraint:
                rbc = obj.rigid_body_constraint

                constraint_data = {
                    "name": obj.name,
                    "type": rbc.type,
                    "enabled": rbc.enabled,
                    "disable_collisions": rbc.disable_collisions,
                    "object1": rbc.object1.name if rbc.object1 else None,
                    "object2": rbc.object2.name if rbc.object2 else None,
                }

                if rbc.object1 and rbc.object2:
                    pivot_world = obj.matrix_world.translation
                    pivot1_local = rbc.object1.matrix_world.inverted() @ pivot_world
                    pivot2_local = rbc.object2.matrix_world.inverted() @ pivot_world

                    constraint_data["pivot1"] = [
                        round_value(pivot1_local.x * self._unit_scale, self.vertex_precision),
                        round_value(pivot1_local.y * self._unit_scale, self.vertex_precision),
                        round_value(pivot1_local.z * self._unit_scale, self.vertex_precision)
                    ]
                    constraint_data["pivot2"] = [
                        round_value(pivot2_local.x * self._unit_scale, self.vertex_precision),
                        round_value(pivot2_local.y * self._unit_scale, self.vertex_precision),
                        round_value(pivot2_local.z * self._unit_scale, self.vertex_precision)
                    ]

                    frame1_local = rbc.object1.matrix_world.inverted() @ obj.matrix_world
                    frame2_local = rbc.object2.matrix_world.inverted() @ obj.matrix_world

                    constraint_data["frame1"] = self.matrix_to_list(frame1_local)
                    constraint_data["frame2"] = self.matrix_to_list(frame2_local)

                if rbc.type == 'GENERIC':
                    constraint_data["limits"] = {
                        "linear_x": {
                            "enabled": rbc.use_limit_lin_x,
                            "lower": round_value(rbc.limit_lin_x_lower, self.normal_precision),
                            "upper": round_value(rbc.limit_lin_x_upper, self.normal_precision),
                        },
                        "linear_y": {
                            "enabled": rbc.use_limit_lin_y,
                            "lower": round_value(rbc.limit_lin_y_lower, self.normal_precision),
                            "upper": round_value(rbc.limit_lin_y_upper, self.normal_precision),
                        },
                        "linear_z": {
                            "enabled": rbc.use_limit_lin_z,
                            "lower": round_value(rbc.limit_lin_z_lower, self.normal_precision),
                            "upper": round_value(rbc.limit_lin_z_upper, self.normal_precision),
                        },
                        "angular_x": {
                            "enabled": rbc.use_limit_ang_x,
                            "lower": round_value(math.degrees(rbc.limit_ang_x_lower), self.normal_precision),
                            "upper": round_value(math.degrees(rbc.limit_ang_x_upper), self.normal_precision),
                        },
                        "angular_y": {
                            "enabled": rbc.use_limit_ang_y,
                            "lower": round_value(math.degrees(rbc.limit_ang_y_lower), self.normal_precision),
                            "upper": round_value(math.degrees(rbc.limit_ang_y_upper), self.normal_precision),
                        },
                        "angular_z": {
                            "enabled": rbc.use_limit_ang_z,
                            "lower": round_value(math.degrees(rbc.limit_ang_z_lower), self.normal_precision),
                            "upper": round_value(math.degrees(rbc.limit_ang_z_upper), self.normal_precision),
                        }
                    }

                physics_data["constraints"].append(constraint_data)

        return physics_data


def menu_func_export(self, context):
    self.layout.operator(ExportPoseBoxScene.bl_idname, text="PoseBox Scene (.json)")


def register():
    bpy.utils.register_class(ExportPoseBoxScene)
    bpy.types.TOPBAR_MT_file_export.append(menu_func_export)


def unregister():
    bpy.utils.unregister_class(ExportPoseBoxScene)
    bpy.types.TOPBAR_MT_file_export.remove(menu_func_export)


if __name__ == "__main__":
    register()
