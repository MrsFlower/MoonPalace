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
    // 这里我们开启 cursor，免得鼠标被锁死
    @raylib.enable_cursor()

    // 加载 GLB 模型
    @raylib.load_global_model("../Trellis2output/DwarfWarrior_Textured_00001_.glb")

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
      @raylib.update_camera(@raylib.camera_free) // 1 = camera free
    } else {
      // Locked Mode - 只有按住鼠标左键时才允许转动视角
      if @raylib.is_mouse_button_down(@raylib.mouse_button_left) { // 0 = left mouse button
        @raylib.disable_cursor() // 隐藏并锁定鼠标
        @raylib.update_camera(@raylib.camera_free) // 1 = camera free
        // 从摄像机读取新位置，同步给引擎
        let (cx, cy, cz) = @raylib.get_camera_position()
        engine.set_player_pos(cx, cy, cz)
      } else {
        @raylib.enable_cursor() // 释放鼠标
        // 手动把摄像机位置放到引擎的坐标，以覆盖内部的惯性或残留
        @raylib.set_camera_position(engine.get_player_pos_x(), engine.get_player_pos_y() + 0.5, engine.get_player_pos_z())
        @raylib.update_camera(@raylib.camera_custom) // 0 = custom, 不处理鼠标输入
      }
    }
    
    @raylib.begin_mode_3d_current_camera()
    
    @raylib.draw_grid(20, 1.0)
    
    // Draw the GLB model
    // 模型已经在 C 层归一化大小（缩放到了 10）并居中，所以只需放在原点
    @raylib.draw_global_model(0.0, 0.0, 0.0, 1.0) 
    
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
