
import trimesh
import numpy as np

# Create a simple 3x3x3 grid of colored boxes to simulate a house/plaza
# We will use a single mesh with vertex colors
boxes = []

for x in range(3):
    for y in range(3):
        for z in range(3):
            # Skip the center to make it like a hollow room
            if x == 1 and y == 1 and z == 1:
                continue
                
            box = trimesh.creation.box(extents=(0.9, 0.9, 0.9))
            box.apply_translation((x, y, z))
            
            # Color based on height
            if y == 0:
                color = [50, 200, 50, 255] # Green floor
            elif y == 2:
                color = [200, 50, 50, 255] # Red roof
            else:
                color = [200, 200, 200, 255] # White walls
                
            box.visual.vertex_colors = color
            boxes.append(box)

# Combine all boxes into a single mesh
combined_mesh = trimesh.util.concatenate(boxes)

# Export as GLB
combined_mesh.export("aetheria_engine/assets/mock_house_3x3x3.glb")
print(f"Generated mock GLB with {len(combined_mesh.vertices)} vertices and {len(combined_mesh.faces)} faces.")

