test "parse_world_data mock" {
  let mock_json = "{ \"ground\": true, \"Welcome\": true }"
  let data = parse_world_data(mock_json)
  
  assert_eq(data.spawn_point.y, 5.0) |> ignore
  assert_eq(data.colliders.length(), 1) |> ignore
  assert_eq(data.colliders[0].id, "ground") |> ignore
  assert_eq(data.story_nodes.length(), 1) |> ignore
  assert_eq(data.story_nodes[0].text, "Welcome") |> ignore
}
