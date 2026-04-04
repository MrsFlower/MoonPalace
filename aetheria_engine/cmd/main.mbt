fn main {
  let engine = @src.Engine::new()
  
  println("Aetheria3D Engine Starting UI Mode...")
  
  @raylib.init_window(800, 600, "Aetheria3D - Moonbit & Raylib")
  @raylib.set_target_fps(60)
  @raylib.load_texture_atlas("assets/atlas_albedo.png")

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
    @raylib.begin_mode_3d(
      engine.player_pos.x, engine.player_pos.y + 10.0, engine.player_pos.z + 10.0, // camera position
      engine.player_pos.x, engine.player_pos.y, engine.player_pos.z,   // camera target
      0.0, 1.0, 0.0,   // camera up
      45.0             // fovy
    )
    
    @raylib.draw_grid(20, 1.0)
    
    // Draw player as a red cube
    let px = engine.player_pos.x
    let py = engine.player_pos.y
    let pz = engine.player_pos.z
    @raylib.draw_cube(px, py, pz, 0.8, 0.8, 0.8, 250, 50, 50, 255)
    @raylib.draw_cube_wires(px, py, pz, 0.8, 0.8, 0.8, 20, 20, 20, 255)
    
    // Render the voxel world using texture atlas
    @raylib.begin_texture_mode()
    for v in engine.world.voxels {
      // Find UV rect
      let mut u_min = 0.0
      let mut v_min = 0.0
      let mut uv_w = 1.0
      let mut uv_h = 1.0
      
      match engine.materials.get(v.mat_id) {
        Some(rect) => {
          u_min = rect.u_min
          v_min = rect.v_min
          uv_w = rect.u_max - rect.u_min
          uv_h = rect.v_max - rect.v_min
        }
        None => ()
      }
      
      @raylib.draw_textured_voxel(v.x.to_double(), v.y.to_double(), v.z.to_double(), 1.0, u_min, v_min, uv_w, uv_h)
    }
    @raylib.end_texture_mode()
    
    @raylib.end_mode_3d()
    
    // Draw UI & State Information
    @raylib.draw_text("Aetheria3D Engine - Interactive Mode", 20, 20, 20, 200, 200, 200, 255)
    @raylib.draw_text(engine.get_state_string(), 20, 50, 20, 100, 200, 100, 255)
    
    if engine.state == Dialog {
      @raylib.draw_text("DIALOG: You found a hidden item! (Press SPACE)", 100, 500, 25, 255, 255, 100, 255)
    }
    
    @raylib.draw_fps(700, 20)
    @raylib.end_drawing()
  }
  
  @raylib.close_window()
  println("Aetheria3D Engine Stopped.")
}
