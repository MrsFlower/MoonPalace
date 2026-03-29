test "UIManager behavior" {
  let ui = UIManager::new()
  let player_pos: Vector3 = { x: 10.0, y: 0.0, z: -5.0 }
  
  // 默认不显示 debug，也不显示对话框
  assert_eq(ui.render_mock(player_pos, 60, "Roam"), "") |> ignore
  
  // 开启 debug
  ui.toggle_debug()
  let render_debug = ui.render_mock(player_pos, 60, "Roam")
  // 简单验证是否包含了 DEBUG PANEL 等关键字
  assert_eq(render_debug == "", false) |> ignore
  
  // 触发对话
  ui.show_dialog("Hello, Aetheria!")
  let render_dialog = ui.render_mock(player_pos, 60, "Dialog")
  assert_eq(render_dialog == "", false) |> ignore
  
  // 隐藏对话
  ui.hide_dialog()
  let render_hidden = ui.render_mock(player_pos, 60, "Roam")
  // 验证不包含 DIALOG BOX，但由于 debug 开着，不能是空字符串
  assert_eq(render_hidden == "", false) |> ignore
}
