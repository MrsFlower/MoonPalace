// 简单的 2D UI 叠加层系统
// 用于在 3D 渲染之上绘制剧情对话框、调试信息等。

pub struct UIManager {
  mut active_dialog : Option[String]
  mut show_debug : Bool
}

pub fn UIManager::new() -> UIManager {
  { active_dialog: None, show_debug: false }
}

pub fn UIManager::show_dialog(self: UIManager, text: String) -> Unit {
  self.active_dialog = Some(text)
}

pub fn UIManager::hide_dialog(self: UIManager) -> Unit {
  self.active_dialog = None
}

pub fn UIManager::toggle_debug(self: UIManager) -> Unit {
  self.show_debug = not(self.show_debug)
}

// 供引擎主循环调用的更新函数（目前 UI 没有复杂的内部状态更新，主要为了后续扩展预留）
pub fn UIManager::update(self: UIManager) -> Unit {
  // 比如：处理文字逐字打印的动画效果等
  let _ = self
}

// 在实际环境中，这个函数会调用 raylib 的 draw_text 等方法。
// 目前返回一个代表渲染指令的字符串用于单元测试验证。
pub fn UIManager::render_mock(self: UIManager, player_pos: Vector3, fps: Int, state_str: String) -> String {
  let mut render_cmds = ""
  
  if self.show_debug {
    render_cmds = render_cmds + "DEBUG PANEL: FPS: \{fps} | State: \{state_str} | Pos: (\{player_pos.x}, \{player_pos.y}, \{player_pos.z})\n"
  }
  
  match self.active_dialog {
    Some(text) => {
      render_cmds = render_cmds + "DIALOG BOX: [ \{text} ]"
    }
    None => ()
  }
  
  render_cmds
}
