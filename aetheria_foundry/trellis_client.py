import os
import time
from gradio_client import Client, handle_file

def generate_3d_from_image(image_path: str, hf_token: str = None, output_dir: str = "./output"):
    """
    调用 TRELLIS-2 Gradio Space 从图片生成 3D 模型
    """
    print(f"[*] Initializing connection to TRELLIS-2 space...")
    os.makedirs(output_dir, exist_ok=True)
    
    try:
        if hf_token:
            client = Client("JeffreyXiang/TRELLIS", hf_token=hf_token)
        else:
            client = Client("JeffreyXiang/TRELLIS")
             
        print(f"\n[*] Uploading image: {image_path}")
        
        # 1. 预处理图像 (获取移除背景后的图像)
        print("[*] Step 1: Preprocessing image...")
        preprocessed_image = client.predict(
            image=handle_file(image_path),
            api_name="/preprocess_image"
        )
        print(f"    -> Preprocessed image saved to: {preprocessed_image}")

        # 2. 生成 3D 资产 (返回视频预览，但这步是在后端生成 3D 数据)
        print("[*] Step 2: Generating 3D asset (this may take a few minutes)...")
        # 根据 API 文档，/image_to_3d 需要多个参数
        # predict(image, multiimages, seed, ss_guidance_strength, ss_sampling_steps, slat_guidance_strength, slat_sampling_steps, multiimage_algo, api_name="/image_to_3d")
        video_preview = client.predict(
            image=handle_file(preprocessed_image),
            multiimages=[],
            seed=0,
            ss_guidance_strength=7.5,
            ss_sampling_steps=12,
            slat_guidance_strength=3.0,
            slat_sampling_steps=12,
            multiimage_algo="stochastic",
            api_name="/image_to_3d" 
        )
        print(f"    -> 3D Asset generated. Preview video: {video_preview}")
        
        # 3. 提取并下载 GLB 模型
        print("[*] Step 3: Extracting GLB model...")
        # predict(mesh_simplify, texture_size, api_name="/extract_glb") -> (extracted_glbgaussian, download_glb)
        glb_result = client.predict(
            mesh_simplify=0.95,
            texture_size=1024,
            api_name="/extract_glb"
        )
        
        glb_file_path = glb_result[1] # 第二个返回值是供下载的路径
        print(f"[*] Success! GLB Model downloaded to: {glb_file_path}")
        
        # 将结果复制到我们的输出目录
        import shutil
        final_dest = os.path.join(output_dir, "generated_asset.glb")
        shutil.copy2(glb_file_path, final_dest)
        print(f"[*] Saved to final destination: {final_dest}")
        
    except Exception as e:
        print(f"[X] Inference failed: {e}")

if __name__ == "__main__":
    # 使用绝对路径解决 FileNotFoundError
    test_image = os.path.abspath("test_input.png")
    if not os.path.exists(test_image):
        from PIL import Image
        img = Image.new('RGB', (512, 512), color = 'gray')
        img.save(test_image)
        
    # HF_TOKEN 环境变量
    my_token = os.environ.get("HF_TOKEN", None)
    
    generate_3d_from_image(test_image, hf_token=my_token)
