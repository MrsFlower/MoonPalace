fn main {
  let engine = @src.Engine::new()
  
  println("Aetheria3D Engine Starting UI Mode...")
  
  @raylib.init_window(800, 600, "Aetheria3D - Moonbit & Raylib")
  @raylib.set_target_fps(60)
  // 初始化摄像头
    @raylib.setup_camera(
      0.0, 5.0, 10.0, // 初始位置 (向外拉远一点)
      0.0, 0.0, 0.0,   // target
      0.0, 1.0, 0.0,   // up
      45.0             // fovy
    )

    // Raylib 5.0 中，如果不 DisableCursor，orbital 模式的鼠标拖拽可能受限
    // 但在 Custom 模式下，不需要 disable。我们在启动时默认显示鼠标。
    @raylib.show_cursor()

    // 加载 GLB 模型 Chunks
    let chunk_count = engine.get_chunk_count()
    if chunk_count > 0 {
      println("Loading \{chunk_count} model chunks...")
      for i = 0; i < chunk_count; i = i + 1 {
        let path = "../aetheria_engine/assets/chunks/chunk_\{i}.glb"
        @raylib.load_chunk_model(i, path)
      }
    } else {
      // Fallback
      @raylib.load_global_model("../aetheria_engine/assets/mock_house_3x3x3.glb")
    }

  while not(@raylib.window_should_close()) {
    // 收集输入
    let mut input_x = 0.0
    let mut input_z = 0.0
    
    if engine.state == Roam {
      if @raylib.is_key_down(@raylib.key_w) { input_z = -1.0 }
      if @raylib.is_key_down(@raylib.key_s) { input_z = 1.0 }
      if @raylib.is_key_down(@raylib.key_a) { input_x = -1.0 }
      if @raylib.is_key_down(@raylib.key_d) { input_x = 1.0 }
    } else if engine.state == Dialog {
      if @raylib.is_key_pressed(@raylib.key_space) {
        engine.dismiss_dialog()
      }
    }

    engine.update(input_x, input_z)
    
    @raylib.begin_drawing()
    @raylib.clear_background(30, 30, 40, 255)
    
    // Draw 3D Scene
    // Toggle camera control mode
    let current_cam_mode = engine.get_camera_mode()
    
    // 自定义按住左键拖动旋转视角 (Camera Custom)
    if current_cam_mode == 1 {
      // Free Camera 模式下 Raylib 接管，允许鼠标乱飞
      @raylib.update_camera(1) // 1 = camera free
    } else {
      // Locked Mode - 只有按住鼠标左键时才允许转动视角
      if @raylib.is_mouse_button_down(0) { // 0 = left mouse button
        // 在按住左键时，我们仅仅是隐藏并锁定鼠标，这样我们能获取 delta_x/y
        @raylib.disable_cursor() 
      } else {
        @raylib.enable_cursor() // 释放鼠标
      }
      
      // 我们自己计算相机的 target
      let px = engine.get_player_pos_x()
      let py = engine.get_player_pos_y() + 0.5 // 摄像机在角色头部
      let pz = engine.get_player_pos_z()
      
      let yaw = engine.get_player_yaw()
      let pitch = engine.get_player_pitch()
      
      // 计算视线前方
      let tx = px - @math.sin(yaw) * @math.cos(pitch)
      let ty = py + @math.sin(pitch)
      let tz = pz - @math.cos(yaw) * @math.cos(pitch)
      
      @raylib.setup_camera(px, py, pz, tx, ty, tz, 0.0, 1.0, 0.0, 45.0)
      @raylib.update_camera(0) // custom mode, 不自己处理鼠标
    }
    
    @raylib.begin_mode_3d_current_camera()
    
    @raylib.draw_grid(20, 1.0)
    
    // Draw the GLB model Chunks
    if chunk_count > 0 {
      for i = 0; i < chunk_count; i = i + 1 {
        // Trellis 模型的坐标已经在 python 切分时保留了，缩放放大 20 倍以便漫游
        @raylib.draw_chunk_model(i, 0.0, 0.0, 0.0, 20.0)
      }
    } else {
      @raylib.draw_global_model(0.0, 0.0, 0.0, 1.0)
    }
    
    @raylib.end_mode_3d()
    
    // Draw UI & State Information
    @raylib.draw_text("Aetheria3D Engine - Interactive Mode", 20, 20, 20, 200, 200, 200, 255)
    @raylib.draw_text(engine.get_state_string(), 20, 50, 20, 100, 200, 100, 255)
    
    if current_cam_mode == 1 {
      @raylib.draw_text("Camera: FREE FLY (Press Right Mouse Button to switch mode)", 20, 80, 20, 255, 255, 100, 255)
    } else {
      @raylib.draw_text("Camera: ROAM (Hold Left Mouse Button to look around)", 20, 80, 20, 200, 200, 200, 255)
    }
    
    if engine.state == Dialog {
      @raylib.draw_text("DIALOG: You found a hidden item! (Press SPACE)", 100, 500, 25, 255, 255, 100, 255)
    }
    
    @raylib.draw_fps(700, 20)
    @raylib.end_drawing()
  }
  
  @raylib.close_window()
  println("Aetheria3D Engine Stopped.")
}
