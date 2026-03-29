test "engine state transition" {
  let engine = Engine::new()
  assert_eq(engine.state, Init) |> ignore
  
  // Update 61 times to trigger state change to Loading
  for _ in 0..<61 {
    engine.update()
  }
  assert_eq(engine.state, Loading) |> ignore
  
  // Update another 60 times to trigger state change to Roam
  for _ in 0..<60 {
    engine.update()
  }
  assert_eq(engine.state, Roam) |> ignore
}
