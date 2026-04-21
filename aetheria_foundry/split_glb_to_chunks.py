
import trimesh
import numpy as np
import os
import math
import sys

def split_mesh(glb_path, output_path, max_vertices=60000):
    print(f"Loading {glb_path}...")
    scene = trimesh.load(glb_path, force="scene")
    
    # We want to extract the actual mesh. A scene might have multiple geometries.
    meshes = []
    for geom in scene.geometry.values():
        if isinstance(geom, trimesh.Trimesh):
            meshes.append(geom)
            
    if not meshes:
        print("No valid meshes found.")
        return
        
    # Combine them all if there are multiple
    if len(meshes) > 1:
        base_mesh = trimesh.util.concatenate(meshes)
    else:
        base_mesh = meshes[0]
        
    print(f"Total vertices: {len(base_mesh.vertices)}, Total faces: {len(base_mesh.faces)}")
    
    if len(base_mesh.vertices) <= max_vertices:
        print("Model is already small enough. Exporting as is.")
        os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
        base_mesh.export(output_path)
        return
        
    print(f"Model exceeds {max_vertices} vertices. Splitting into chunks...")
    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    
    # Simple strategy: Sort faces by their centroid X, Y, or Z coordinate, 
    # and split them into chunks of faces that have <= max_vertices vertices.
    # To do this correctly and preserve textures/colors, we extract submeshes based on face indices.
    
    # Calculate face centroids
    centroids = base_mesh.triangles_center
    
    # We will sort faces by X coordinate first, then Y, then Z to group them spatially
    # Sort indices based on centroid X coordinate
    # Actually, a better spatial split is grid-based. 
    # Let's use a grid approach.
    bounds = base_mesh.bounds
    extents = base_mesh.extents
    
    # Estimate how many chunks we need
    num_chunks_needed = math.ceil(len(base_mesh.vertices) / (max_vertices * 0.8)) # 0.8 factor for safety margin
    grid_size = math.ceil(num_chunks_needed ** (1/3))
    print(f"Targeting {grid_size}x{grid_size}x{grid_size} grid to get ~{num_chunks_needed} chunks.")
    
    step_x = extents[0] / grid_size
    step_y = extents[1] / grid_size
    step_z = extents[2] / grid_size
    
    # If a dimension has 0 extent, step is 1 to avoid division by zero
    if step_x == 0: step_x = 1
    if step_y == 0: step_y = 1
    if step_z == 0: step_z = 1
    
    chunk_faces = {} # (ix, iy, iz) -> list of face indices
    
    for i, centroid in enumerate(centroids):
        ix = min(grid_size - 1, max(0, int((centroid[0] - bounds[0][0]) / step_x)))
        iy = min(grid_size - 1, max(0, int((centroid[1] - bounds[0][1]) / step_y)))
        iz = min(grid_size - 1, max(0, int((centroid[2] - bounds[0][2]) / step_z)))
        
        key = (ix, iy, iz)
        if key not in chunk_faces:
            chunk_faces[key] = []
        chunk_faces[key].append(i)
        
    print(f"Split into {len(chunk_faces)} spatial groups.")
    
    chunk_id = 0
    scene_out = trimesh.Scene()
    
    for key, face_indices in chunk_faces.items():
        if not face_indices:
            continue

        submesh = base_mesh.submesh([face_indices], append=True)

        if len(submesh.vertices) > max_vertices:
            print(f"Warning: Chunk {key} still has {len(submesh.vertices)} vertices. Splitting by raw face chunks...")

            faces_per_split = int(max_vertices / 3) 
            for i in range(0, len(submesh.faces), faces_per_split):
                raw_chunk_indices = face_indices[i:i+faces_per_split]
                final_submesh = base_mesh.submesh([raw_chunk_indices], append=True)
                
                scene_out.add_geometry(final_submesh, node_name=f"chunk_{chunk_id}")
                chunk_id += 1
        else:
            scene_out.add_geometry(submesh, node_name=f"chunk_{chunk_id}")
            chunk_id += 1
            
    scene_out.export(output_path)
    print(f"Saved optimized single model to {output_path} with {chunk_id} sub-meshes.")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python split_glb_to_chunks.py <input.glb> <output.glb> [max_vertices]")
        sys.exit(1)
    inp = sys.argv[1]
    outp = sys.argv[2]
    mv = int(sys.argv[3]) if len(sys.argv) >= 4 else 60000
    split_mesh(inp, outp, max_vertices=mv)

