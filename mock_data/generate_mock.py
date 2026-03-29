import json
import os

def generate_mock_json():
    world_data = {
        "metadata": {
            "version": "1.0",
            "name": "Mock Test Scene",
            "description": "A simple terrain for testing rendering and collisions."
        },
        "player": {
            "spawn_point": [0.0, 5.0, 0.0]
        },
        "colliders": [
            {
                "id": "ground",
                "type": "AABB",
                "min": [-10.0, -1.0, -10.0],
                "max": [10.0, 0.0, 10.0]
            },
            {
                "id": "wall_north",
                "type": "AABB",
                "min": [-10.0, 0.0, -10.0],
                "max": [10.0, 5.0, -9.0]
            },
            {
                "id": "obstacle_1",
                "type": "AABB",
                "min": [2.0, 0.0, 2.0],
                "max": [4.0, 2.0, 4.0]
            }
        ],
        "story_nodes": [
            {
                "id": "node_1",
                "position": [0.0, 1.0, -5.0],
                "radius": 2.0,
                "event": {
                    "type": "dialog",
                    "text": "Welcome to Aetheria3D Mock Scene!"
                }
            }
        ]
    }
    
    with open("mock_data/mock_world.json", "w") as f:
        json.dump(world_data, f, indent=4)
    print("Generated mock_world.json")

def generate_mock_obj():
    # Simple terrain: A large floor (20x20) and one cube obstacle
    obj_content = """# Mock Terrain OBJ
# Floor
v -10.0 0.0 -10.0
v 10.0 0.0 -10.0
v -10.0 0.0 10.0
v 10.0 0.0 10.0

# Obstacle
v 2.0 0.0 2.0
v 4.0 0.0 2.0
v 2.0 2.0 2.0
v 4.0 2.0 2.0
v 2.0 0.0 4.0
v 4.0 0.0 4.0
v 2.0 2.0 4.0
v 4.0 2.0 4.0

vn 0.0 1.0 0.0
vn 0.0 0.0 -1.0
vn 0.0 0.0 1.0
vn -1.0 0.0 0.0
vn 1.0 0.0 0.0

usemtl Material_Floor
f 3//1 4//1 2//1 1//1

usemtl Material_Obstacle
# Front
f 5//2 6//2 8//2 7//2
# Back
f 11//3 12//3 10//3 9//3
# Left
f 9//4 11//4 7//4 5//4
# Right
f 6//5 8//5 12//5 10//5
# Top
f 7//1 8//1 12//1 11//1
"""
    
    mtl_content = """# Mock Materials
newmtl Material_Floor
Kd 0.4 0.8 0.4
Ks 0.0 0.0 0.0

newmtl Material_Obstacle
Kd 0.8 0.2 0.2
Ks 0.5 0.5 0.5
"""
    
    with open("mock_data/mock_terrain.obj", "w") as f:
        f.write(obj_content)
    with open("mock_data/mock_terrain.mtl", "w") as f:
        f.write(mtl_content)
    print("Generated mock_terrain.obj and mock_terrain.mtl")

if __name__ == "__main__":
    generate_mock_json()
    generate_mock_obj()
