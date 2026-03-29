fn main {
  let engine = @aetheria/engine/src.Engine::new()
  
  println("Aetheria3D Engine Starting...")
  
  // 模拟运行 250 帧，展示状态流转、UI 交互和 Debug 面板
  for i in 0..<250 {
    engine.update()
    if i % 30 == 0 || i == 180 || i == 240 {
      println(engine.render())
    }
  }
  
  println("Aetheria3D Engine Stopped.")
}
