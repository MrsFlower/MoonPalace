# -----------------------------------------------------------------------------
# Aetheria3D AI Compiler - LLM World Architect
# -----------------------------------------------------------------------------
# Uses an LLM (e.g. GPT-4, Claude) to generate the structural JSON
# representing the world (colliders, story nodes, etc.).

import json
import os

def generate_world_data(prompt: str, output_path: str):
    print(f"[*] Prompting LLM for world schema: '{prompt}'")
    
    # Mock response from LLM
    mock_response = {
        "metadata": {
            "version": "1.0",
            "name": "Generated Scene",
            "description": prompt
        },
        "player": {
            "spawn_point": [0.0, 5.0, 0.0]
        },
        "colliders": [
            {
                "id": "generated_ground",
                "type": "AABB",
                "min": [-20.0, -1.0, -20.0],
                "max": [20.0, 0.0, 20.0]
            }
        ],
        "story_nodes": [
            {
                "id": "node_intro",
                "position": [2.0, 1.0, -2.0],
                "radius": 3.0,
                "event": {
                    "type": "dialog",
                    "text": "The wind howls through the abandoned canyon..."
                }
            }
        ]
    }
    
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(mock_response, f, indent=4)
        
    print(f"[+] Successfully generated world schema at: {output_path}")

if __name__ == "__main__":
    generate_world_data("A ruined mining town built in a snowy canyon", "assets/raw/world_data.json")
