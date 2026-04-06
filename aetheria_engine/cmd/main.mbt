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

    let mut current_chunk_to_load = 0
    let chunk_count = engine.get_chunk_count()

  while not(@raylib.window_should_close()) {
    // 渐进式加载模型 Chunks
    if current_chunk_to_load < chunk_count {
      // 渐进式加载模型 Chunks
      let path = "../aetheria_voxelizer/mock_pyramid.chunk"
      @raylib.load_custom_chunk(0, path)
      current_chunk_to_load = current_chunk_to_load + 1
      
      // 画一个平滑的 Loading 界面，由于只加载了一个，界面更新率能维持在几十帧以上
      @raylib.begin_drawing()
      @raylib.clear_background(20, 20, 20, 255)
      
      let percentage = current_chunk_to_load * 100 / chunk_count
      @raylib.draw_text("Loading Aetheria World...", 280, 250, 20, 200, 200, 200, 255)
      let progress = "Progress: \{percentage}% (\{current_chunk_to_load} / \{chunk_count})"
      @raylib.draw_text(progress, 300, 300, 20, 100, 255, 100, 255)
      
      @raylib.end_drawing()
      continue
    }
    // 收集输入
    let mut input_x = 0.0
    let mut input_z = 0.0
    
    if engine.state == Roam {
      if @raylib.is_key_down(@raylib.key_w) { input_z = 1.0 }
      if @raylib.is_key_down(@raylib.key_s) { input_z = -1.0 }
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
        // 实际上，Raylib 的 DisableCursor() 会在底层通过 glfwSetInputMode 将光标锁定在中心。
        // 这是第一人称相机的标准做法，如果不锁在中心，鼠标移动到屏幕边缘就会停住，DeltaX/Y 就变成了 0。
        // 您说的画面抽动并弹回原处，是因为之前我们用了 `HideCursor()`。
        // `HideCursor()` 只隐藏了光标，但光标仍然会撞到屏幕边缘。
        // 当光标撞到屏幕边缘，甚至跳出窗口范围时，操作系统处理的鼠标事件会导致 Delta 异常跳变。
        // 所以我们还是必须使用 `DisableCursor()`。
        // 但为了防止 "按住左键就永远锁死" 的错觉，我们只在 `is_mouse_button_down` 期间 Disable。
        // 松开时，立刻 EnableCursor() 并恢复到拖动前的位置（Raylib 底层会自动处理恢复位置）。
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
    }        

    @raylib.begin_mode_3d_current_camera()
    
    @raylib.draw_grid(20, 1.0)
    
    // Draw the GLB model Chunks
    if chunk_count > 0 {
      @raylib.draw_custom_chunk()
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
