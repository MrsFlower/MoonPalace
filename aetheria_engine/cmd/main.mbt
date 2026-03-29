fn main {
  let engine = @aetheria/engine/src.Engine::new()
  
  // 在真实环境中我们会调用 Raylib，但由于目前我们可能没有编译好 C 扩展，我们先做一个纯逻辑的模拟循环
  println("Aetheria3D Engine Starting...")
  
  // 模拟运行 150 帧
  for i in 0..<150 {
    engine.update()
    if i % 30 == 0 {
      println("Frame \{i}: \{engine.get_state_string()}")
    }
  }
  
  println("Aetheria3D Engine Stopped.")
}
