fn main {
  let engine = @src.Engine::new()
  
  println("Aetheria3D Engine Starting UI Mode...")
  
  @raylib.init_window(800, 600, "Aetheria3D - Moonbit & Raylib")
  @raylib.set_target_fps(60)

  while not(@raylib.window_should_close()) {
    engine.update()
    
    @raylib.begin_drawing()
    @raylib.clear_background(30, 30, 40, 255)
    
    // Draw 3D Scene
    @raylib.begin_mode_3d(
      0.0, 10.0, 10.0, // camera position
      0.0, 0.0, 0.0,   // camera target
      0.0, 1.0, 0.0,   // camera up
      45.0             // fovy
    )
    
    @raylib.draw_grid(20, 1.0)
    
    // Draw player as a cube based on engine state
    let px = engine.player_pos.x
    let py = engine.player_pos.y / 5.0 // Just scale it down visually
    let pz = engine.player_pos.z
    @raylib.draw_cube(px, py, pz, 1.0, 1.0, 1.0, 50, 150, 250, 255)
    @raylib.draw_cube_wires(px, py, pz, 1.0, 1.0, 1.0, 20, 80, 150, 255)
    
    // Draw a hidden item box
    @raylib.draw_cube(6.0, 0.5, 0.0, 1.0, 1.0, 1.0, 200, 150, 50, 255)
    
    @raylib.end_mode_3d()
    
    // Draw UI & State Information
    @raylib.draw_text("Aetheria3D Engine - UI Mode", 20, 20, 20, 200, 200, 200, 255)
    @raylib.draw_text(engine.get_state_string(), 20, 50, 20, 100, 200, 100, 255)
    @raylib.draw_text("Frame: " + engine.frame_count.to_string(), 20, 80, 20, 150, 150, 150, 255)
    
    if engine.state == Dialog {
      @raylib.draw_text("DIALOG: You found a hidden item!", 200, 500, 30, 255, 255, 100, 255)
    }
    
    @raylib.draw_fps(700, 20)
    @raylib.end_drawing()
  }
  
  @raylib.close_window()
  println("Aetheria3D Engine Stopped.")
}
