test "engine state transition" {
  let engine = Engine::new()
  assert_eq(engine.state, Roam) |> ignore
}
