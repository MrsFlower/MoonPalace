
import trimesh
import numpy as np
from PIL import Image
import json
import os

def convert_glb_to_engine_assets(glb_path, output_dir):
    print(f"Loading {glb_path}...")
    scene = trimesh.load(glb_path, force="scene")
    
    # Extract the first mesh with a texture
    mesh = None
    texture_img = None
    for name, geom in scene.geometry.items():
        if hasattr(geom.visual, "material") and hasattr(geom.visual.material, "image"):
            if geom.visual.material.image is not None:
                mesh = geom
                texture_img = geom.visual.material.image
                break
    
    if mesh is None:
        # Fallback to just the first mesh
        mesh = list(scene.geometry.values())[0]
        texture_img = Image.new("RGB", (256, 256), color="white")
    
    print(f"Mesh bounding box: {mesh.bounds}")
    
    # Save texture atlas
    os.makedirs(output_dir, exist_ok=True)
    atlas_path = os.path.join(output_dir, "atlas_albedo.png")
    texture_img.save(atlas_path)
    print(f"Saved texture to {atlas_path}")
    
    # Voxelize the mesh
    pitch = (mesh.extents.max()) / 32.0  # 32x32x32 resolution
    print(f"Voxelizing with pitch {pitch}...")
    voxelized = mesh.voxelized(pitch).fill()
    points = voxelized.points
    
    # Move points so min is at (0,0,0) and scale to integer
    min_pt = points.min(axis=0)
    int_points = np.round((points - min_pt) / pitch).astype(int)
    
    # Find UVs for each voxel
    print("Finding UVs for voxels...")
    # trimesh proximity query
    closest_points, distances, triangle_ids = mesh.nearest.on_surface(points)
    
    uv_coords = mesh.visual.uv[mesh.faces[triangle_ids][:, 0]] # Just take the first vertex UV of the triangle
    
    # Create asset.json and materials.json
    asset_data = []
    materials_data = {}
    
    for i in range(len(int_points)):
        pt = int_points[i]
        u, v = uv_coords[i]
        
        # Ensure UV is within 0-1
        u = max(0.0, min(1.0, float(u)))
        v = max(0.0, min(1.0, float(v)))
        
        # We will create a unique material ID for each voxel to map its UV
        mat_id = i + 1
        
        # Flip Y because Moonbit Y is up, but maybe model Y is different? 
        # Actually just keep it as is, or flip Z? Let us just map directly.
        asset_data.append({
            "x": int(pt[0]),
            "y": int(pt[1]),
            "z": int(pt[2]),
            "mat_id": mat_id
        })
        
        # Map a small region around the UV (since Raylib texture mapping wraps around)
        materials_data[str(mat_id)] = {
            "u_min": u - 0.001,
            "v_min": 1.0 - v - 0.001, # Raylib/OpenGL UV V is flipped compared to GLB
            "u_max": u + 0.001,
            "v_max": 1.0 - v + 0.001
        }
        
    asset_path = os.path.join(output_dir, "asset.json")
    materials_path = os.path.join(output_dir, "materials.json")
    
    with open(asset_path, "w") as f:
        json.dump(asset_data, f)
    with open(materials_path, "w") as f:
        json.dump(materials_data, f)
        
    print(f"Saved {len(asset_data)} voxels to {asset_path}")
    print(f"Saved materials to {materials_path}")

if __name__ == "__main__":
    convert_glb_to_engine_assets("Trellis2output/DwarfWarrior_Textured_00001_.glb", "aetheria_engine/assets")

