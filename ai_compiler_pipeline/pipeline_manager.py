# -----------------------------------------------------------------------------
# Aetheria3D AI Compiler - Main Pipeline Manager
# -----------------------------------------------------------------------------

import argparse
from sdxl_caller import generate_isometric_scene
from llm_architect import generate_world_data

def run_pipeline(prompt: str, output_dir: str):
    print(f"=== Starting Aetheria3D AI Compiler Pipeline ===")
    print(f"Prompt: {prompt}")
    print(f"Output Directory: {output_dir}\n")
    
    # Step 1: LLM World Generation (JSON Schema)
    json_path = f"{output_dir}/world_data.json"
    generate_world_data(prompt, json_path)
    print("")
    
    # Step 2: Visual Generation (SDXL 2D -> future 3DGS)
    img_path = f"{output_dir}/scene_base.png"
    generate_isometric_scene(prompt, img_path)
    print("")
    
    print("=== Pipeline Complete ===")
    print("Next step: The Moonbit engine will read from the generated asset folder.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Aetheria3D AI Compiler")
    parser.add_argument("--prompt", type=str, required=True, help="Text prompt describing the scene")
    parser.add_argument("--output", type=str, default="assets/generated", help="Output directory")
    
    args = parser.parse_args()
    run_pipeline(args.prompt, args.output)
