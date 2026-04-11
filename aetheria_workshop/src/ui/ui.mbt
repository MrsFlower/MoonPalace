// Simple Immediate Mode GUI

pub fn draw_button(text: String, x: Int, y: Int, width: Int, height: Int) -> Bool {
  let mx = @raylib.get_mouse_x()
  let my = @raylib.get_mouse_y()
  let mut is_hovered = false
  
  if mx >= x && mx <= x + width && my >= y && my <= y + height {
    is_hovered = true
  }

  let mut is_clicked = false
  if is_hovered && @raylib.is_mouse_button_pressed(@raylib.mouse_button_left) {
    is_clicked = true
  }

  if is_clicked {
    @raylib.draw_rectangle(x, y, width, height, 180, 180, 180, 255)
  } else if is_hovered {
    @raylib.draw_rectangle(x, y, width, height, 200, 200, 200, 255)
  } else {
    @raylib.draw_rectangle(x, y, width, height, 220, 220, 220, 255)
  }
  
  @raylib.draw_rectangle_lines(x, y, width, height, 100, 100, 100, 255)
  
  // Centered text roughly
  let text_x = x + 10
  let text_y = y + (height - 20) / 2
  @raylib.draw_text(text, text_x, text_y, 20, 50, 50, 50, 255)
  
  is_clicked
}

let backspace_timer : Ref[Double] = { val: 0.0 }

pub fn draw_textbox(text: String, x: Int, y: Int, width: Int, height: Int, is_active: Bool) -> String {
  let mut new_text = text

  if is_active {
    @raylib.draw_rectangle(x, y, width, height, 255, 255, 255, 255)
    @raylib.draw_rectangle_lines(x, y, width, height, 0, 120, 255, 255)

    // Handle input
    let mut key = @raylib.get_char_pressed()
    while key > 0 {
      if key >= 32 && key <= 125 { // printable ASCII
        let c = key.unsafe_to_char()
        new_text = new_text + c.to_string()
      }
      key = @raylib.get_char_pressed()
    }

    let mut do_backspace = false
    if @raylib.is_key_pressed(259) {
      do_backspace = true
      backspace_timer.val = 0.0
    } else if @raylib.is_key_down(259) {
      backspace_timer.val = backspace_timer.val + 1.0
      if backspace_timer.val > 30.0 { // half a second delay
        if backspace_timer.val.to_int() % 3 == 0 { // repeat every 3 frames
          do_backspace = true
        }
      }
    } else {
      backspace_timer.val = 0.0
    }

    if do_backspace {
      let len = new_text.length()
      if len > 0 {
        if @raylib.is_key_down(341) || @raylib.is_key_down(345) { // Ctrl + Backspace -> Clear all
          new_text = ""
        } else {
          new_text = new_text[:len - 1].to_string()
        }
      }
    }
    
    // Handle paste (Ctrl+V)
    if @raylib.is_key_down(341) || @raylib.is_key_down(345) { // 341=KEY_LEFT_CONTROL, 345=KEY_RIGHT_CONTROL
      if @raylib.is_key_pressed(86) { // 86=KEY_V
        new_text = new_text + @raylib.get_clipboard_text()
      }
    }
  } else {
    @raylib.draw_rectangle(x, y, width, height, 240, 240, 240, 255)
    @raylib.draw_rectangle_lines(x, y, width, height, 150, 150, 150, 255)
  }
  
  let display_text = if is_active && (@raylib.get_frame_time() * 1000.0).to_int() % 1000 < 500 {
    new_text + "_"
  } else {
    new_text
  }
  
  @raylib.draw_text(display_text, x + 5, y + (height - 20) / 2, 20, 0, 0, 0, 255)
  
  new_text
}

pub fn is_clicked(x: Int, y: Int, width: Int, height: Int) -> Bool {
  let mx = @raylib.get_mouse_x()
  let my = @raylib.get_mouse_y()
  if mx >= x && mx <= x + width && my >= y && my <= y + height {
    if @raylib.is_mouse_button_pressed(@raylib.mouse_button_left) {
      return true
    }
  }
  false
}
