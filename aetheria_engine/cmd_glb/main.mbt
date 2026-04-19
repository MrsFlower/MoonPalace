fn main {
  println("Aetheria3D Engine GLB-Only Mode Starting...")
  
  @raylib.init_window(1280, 720, "Aetheria3D - Original GLB Rendering")
  @raylib.set_target_fps(60)

  // 设置一个自由视角相机，因为没有体素物理碰撞系统
  @raylib.setup_camera(
    0.0, 10.0, 20.0, // 初始位置
    0.0, 0.0, 0.0,   // 看向中心点
    0.0, 1.0, 0.0,   // up
    45.0             // fov
  )

  // 仅仅加载 GLB 模型，不加载 Chunk
  let glb_path = "../aetheria_engine/assets/optimized_dwarf.glb"
  @raylib.load_global_model(glb_path)

  let mut camera_mode = 1 // 1 = CameraMode.Free

  while not(@raylib.window_should_close()) {
    // 允许通过按 'C' 键切换鼠标锁定状态
    if @raylib.is_key_pressed(67) { // 'C' key
      if camera_mode == 1 {
        camera_mode = 0
        @raylib.enable_cursor()
      } else {
        camera_mode = 1
        @raylib.disable_cursor()
      }
    }

    if camera_mode == 1 {
      @raylib.update_camera(1) // CAMERA_FREE
    }

    @raylib.begin_drawing()
    @raylib.clear_background(135, 206, 235, 255) // 天蓝色背景匹配之前加的雾
    
    @raylib.begin_mode_3d_current_camera()
    
    // 渲染地面网格辅助线
    @raylib.draw_grid(50, 2.0)
    
    // 以 80.0 倍的缩放系数渲染原模型 (匹配体素化时的尺寸)
    @raylib.draw_global_model(0.0, 0.0, 0.0, 80.0)
    
    @raylib.end_mode_3d()
    
    // 绘制 UI 信息
    @raylib.draw_text("Aetheria3D GLB Viewer", 20, 20, 20, 200, 200, 200, 255)
    @raylib.draw_text("Press 'C' to toggle free camera", 20, 50, 20, 100, 200, 100, 255)
    @raylib.draw_fps(1150, 20)
    
    @raylib.end_drawing()
  }
  
  @raylib.close_window()
  println("Aetheria3D Engine GLB-Only Mode Stopped.")
}
