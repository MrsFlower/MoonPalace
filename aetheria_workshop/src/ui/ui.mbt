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
      if key >= 32 { // Accept all printable characters including Unicode (Chinese)
        // Raylib's GetCharPressed returns Unicode codepoints!
        // We can safely convert it to Moonbit Char
        let c = key.unsafe_to_char()
        new_text = new_text + c.to_string()
      }
      key = @raylib.get_char_pressed()
    }

    // Handle backspace
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
          // Handle UTF-8 deletion safely by iterating to find the last valid char boundary
          // In Moonbit, String is UTF-16 internally, so simple substring is mostly safe
          // However, for supplementary planes (surrogate pairs), we might need to remove 2 code units.
          // Moonbit's String.length() counts characters (Unicode scalar values), not just bytes.
          new_text = new_text[:len - 1].to_string()
        }
      }
    }
    
    // Handle paste (Ctrl+V) and copy (Ctrl+C)
    if @raylib.is_key_down(341) || @raylib.is_key_down(345) { // 341=KEY_LEFT_CONTROL, 345=KEY_RIGHT_CONTROL
      if @raylib.is_key_pressed(86) { // 86=KEY_V
        new_text = new_text + @raylib.get_clipboard_text()
      }
      if @raylib.is_key_pressed(67) { // 67=KEY_C
        @raylib.set_clipboard_text(new_text)
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

  // Scroll text if it's too long
  let max_chars = width / 11
  let visible_text = if display_text.length() > max_chars {
    "..." + display_text[display_text.length() - max_chars + 3:].to_string()
  } else {
    display_text
  }

  @raylib.draw_text(visible_text, x + 5, y + (height - 20) / 2, 20, 0, 0, 0, 255)

  new_text
}

pub fn draw_text_wrapped(text: String, x: Int, y: Int, width: Int, fontSize: Int, r: Int, g: Int, b: Int, a: Int) -> Int {
  let mut current_y = y
  let mut current_line = ""
  
  for c in text {
    if c == '\n' {
      @raylib.draw_text(current_line, x, current_y, fontSize, r, g, b, a)
      current_y = current_y + fontSize + 5
      current_line = ""
      continue
    }
    
    let test_line = current_line + c.to_string()
    let w = @raylib.measure_text(test_line, fontSize)
    if w > width {
      @raylib.draw_text(current_line, x, current_y, fontSize, r, g, b, a)
      current_y = current_y + fontSize + 5
      current_line = c.to_string()
    } else {
      current_line = test_line
    }
  }
  
  if current_line != "" {
    @raylib.draw_text(current_line, x, current_y, fontSize, r, g, b, a)
    current_y = current_y + fontSize + 5
  }
  
  current_y - y // Return total height
}

pub fn draw_scrollable_text_area(text: String, x: Int, y: Int, width: Int, height: Int, scroll_y: Ref[Double]) -> Unit {
  @raylib.draw_rectangle(x, y, width, height, 245, 245, 245, 255)
  @raylib.draw_rectangle_lines(x, y, width, height, 150, 150, 150, 255)

  // Handle scroll
  let mx = @raylib.get_mouse_x()
  let my = @raylib.get_mouse_y()
  if mx >= x && mx <= x + width && my >= y && my <= y + height {
    let wheel = @raylib.get_mouse_wheel_move()
    scroll_y.val = scroll_y.val - wheel * 30.0
    if scroll_y.val < 0.0 {
      scroll_y.val = 0.0
    }
  }

  @raylib.begin_scissor_mode(x + 5, y + 5, width - 10, height - 10)
  
  let total_h = draw_text_wrapped(text, x + 10, y + 10 - scroll_y.val.to_int(), width - 30, 20, 50, 50, 50, 255)
  
  @raylib.end_scissor_mode()

  // Scrollbar handle
  let max_scroll = if total_h > height { (total_h - height + 20).to_double() } else { 0.0 }
  if scroll_y.val > max_scroll { scroll_y.val = max_scroll }

  if max_scroll > 0.0 {
    let bar_h = height * height / total_h
    let bar_y = y + (scroll_y.val / max_scroll * (height - bar_h).to_double()).to_int()
    @raylib.draw_rectangle(x + width - 15, bar_y, 10, bar_h, 180, 180, 180, 255)
  }
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
