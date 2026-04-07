// 核心 Raylib C-FFI 绑定
// 为了性能和稳定性，我们将采用 "极薄绑定" 策略。

extern "C" fn init_window_wrapper(width: Int, height: Int) = "InitWindow_wrapper"
extern "C" fn window_should_close_wrapper() -> Int = "WindowShouldClose_wrapper"
extern "C" fn close_window_wrapper() = "CloseWindow_wrapper"
extern "C" fn set_target_fps_wrapper(fps: Int) = "SetTargetFPS_wrapper"
extern "C" fn get_frame_time_wrapper() -> Double = "get_frame_time_wrapper"
extern "C" fn begin_drawing_wrapper() = "BeginDrawing_wrapper"
extern "C" fn end_drawing_wrapper() = "EndDrawing_wrapper"
extern "C" fn clear_background_wrapper(r: Int, g: Int, b: Int, a: Int) = "ClearBackground_wrapper"

// 键盘输入
extern "C" fn is_key_down_wrapper(key: Int) -> Int = "IsKeyDown_wrapper"
extern "C" fn is_key_pressed_wrapper(key: Int) -> Int = "IsKeyPressed_wrapper"

// 鼠标输入
extern "C" fn is_mouse_button_down_wrapper(button: Int) -> Int = "IsMouseButtonDown_wrapper"
extern "C" fn is_mouse_button_pressed_wrapper(button: Int) -> Int = "IsMouseButtonPressed_wrapper"

pub fn is_mouse_button_down(button: Int) -> Bool {
  is_mouse_button_down_wrapper(button) != 0
}

pub fn is_mouse_button_pressed(button: Int) -> Bool {
  is_mouse_button_pressed_wrapper(button) != 0
}

extern "C" fn get_mouse_delta_x_wrapper() -> Double = "GetMouseDeltaX_wrapper"
extern "C" fn get_mouse_delta_y_wrapper() -> Double = "GetMouseDeltaY_wrapper"

pub fn get_mouse_delta_y() -> Double {
  get_mouse_delta_y_wrapper()
}

pub fn get_mouse_delta_x() -> Double {
  get_mouse_delta_x_wrapper()
}

pub fn get_mouse_wheel_move() -> Double {
  get_mouse_wheel_move_wrapper()
}

extern "C" fn get_mouse_wheel_move_wrapper() -> Double = "get_mouse_wheel_move_wrapper"

// 安全传递字符串的 C-FFI 辅助函数
extern "C" fn clear_text_buffer() = "clear_text_buffer"
extern "C" fn append_text_char(c: Int) = "append_text_char"
extern "C" fn draw_text_from_buffer(x: Int, y: Int, fontSize: Int, r: Int, g: Int, b: Int, a: Int) = "draw_text_from_buffer"

// Texture Atlas FFI
extern "C" fn load_atlas_from_buffer() = "load_atlas_from_buffer"
extern "C" fn begin_voxel_batch() = "begin_voxel_batch"
extern "C" fn end_voxel_batch() = "end_voxel_batch"
extern "C" fn draw_voxel_faces(x: Double, y: Double, z: Double, size: Double, u: Double, v: Double, uv_w: Double, uv_h: Double) = "draw_voxel_faces"

// 3D 渲染支持
extern "C" fn setup_camera_wrapper(cam_px: Double, cam_py: Double, cam_pz: Double, tar_x: Double, tar_y: Double, tar_z: Double, up_x: Double, up_y: Double, up_z: Double, fovy: Double) = "setup_camera"
extern "C" fn update_camera_wrapper(mode: Int) = "update_camera_wrapper"
extern "C" fn begin_mode_3d_current_camera_wrapper() = "begin_mode_3d_current_camera_wrapper"

extern "C" fn load_global_model_from_buffer() = "load_global_model_from_buffer"
extern "C" fn draw_global_model_wrapper(x: Double, y: Double, z: Double, scale: Double) = "draw_global_model_wrapper"

// extern "C" fn begin_mode_3d_wrapper(cam_px: Double, cam_py: Double, cam_pz: Double, tar_x: Double, tar_y: Double, tar_z: Double, up_x: Double, up_y: Double, up_z: Double, fovy: Double) = "BeginMode3D_wrapper"
extern "C" fn end_mode_3d_wrapper() = "EndMode3D_wrapper"
extern "C" fn draw_cube_wrapper(x: Double, y: Double, z: Double, w: Double, h: Double, l: Double, r: Int, g: Int, b: Int, a: Int) = "DrawCube_wrapper"
extern "C" fn draw_cube_wires_wrapper(x: Double, y: Double, z: Double, w: Double, h: Double, l: Double, r: Int, g: Int, b: Int, a: Int) = "DrawCubeWires_wrapper"
extern "C" fn draw_grid_wrapper(slices: Int, spacing: Double) = "DrawGrid_wrapper"
extern "C" fn draw_fps_wrapper(x: Int, y: Int) = "DrawFPS_wrapper"

// Raylib 键盘常量 (部分)
pub let key_w: Int = 87
pub let key_a: Int = 65
pub let key_s: Int = 83
pub let key_d: Int = 68
pub let key_up: Int = 265
pub let key_down: Int = 264
pub let key_left: Int = 263
pub let key_right: Int = 262
pub let key_space: Int = 32
pub let mouse_button_left: Int = 0
pub let mouse_button_right: Int = 1
pub let mouse_button_middle: Int = 2

pub fn init_window(width: Int, height: Int, title: String) -> Unit {
  clear_text_buffer()
  for c in title {
    append_text_char(c.to_int())
  }
  init_window_wrapper(width, height)
}

pub fn window_should_close() -> Bool {
  window_should_close_wrapper() != 0
}

pub fn close_window() -> Unit {
  close_window_wrapper()
}

pub fn set_target_fps(fps: Int) -> Unit {
  set_target_fps_wrapper(fps)
}

pub fn get_frame_time() -> Double {
  get_frame_time_wrapper()
}

pub fn begin_drawing() -> Unit {
  begin_drawing_wrapper()
}

pub fn end_drawing() -> Unit {
  end_drawing_wrapper()
}

pub fn clear_background(r: Int, g: Int, b: Int, a: Int) -> Unit {
  clear_background_wrapper(r, g, b, a)
}

pub fn is_key_down(key: Int) -> Bool {
  is_key_down_wrapper(key) != 0
}

pub fn is_key_pressed(key: Int) -> Bool {
  is_key_pressed_wrapper(key) != 0
}

pub fn draw_text(text: String, x: Int, y: Int, fontSize: Int, r: Int, g: Int, b: Int, a: Int) -> Unit {
  clear_text_buffer()
  for c in text {
    append_text_char(c.to_int())
  }
  draw_text_from_buffer(x, y, fontSize, r, g, b, a)
}

pub fn load_texture_atlas(path: String) -> Unit {
  clear_text_buffer()
  for c in path {
    append_text_char(c.to_int())
  }
  load_atlas_from_buffer()
}

pub fn begin_texture_mode() -> Unit {
  begin_voxel_batch()
}

pub fn end_texture_mode() -> Unit {
  end_voxel_batch()
}

pub fn draw_textured_voxel(x: Double, y: Double, z: Double, size: Double, u: Double, v: Double, uv_w: Double, uv_h: Double) -> Unit {
  draw_voxel_faces(x, y, z, size, u, v, uv_w, uv_h)
}

pub let camera_custom: Int = 0
pub let camera_free: Int = 1
pub let camera_orbital: Int = 2
pub let camera_first_person: Int = 3
pub let camera_third_person: Int = 4

pub fn setup_camera(cam_px: Double, cam_py: Double, cam_pz: Double, tar_x: Double, tar_y: Double, tar_z: Double, up_x: Double, up_y: Double, up_z: Double, fovy: Double) -> Unit {
  setup_camera_wrapper(cam_px, cam_py, cam_pz, tar_x, tar_y, tar_z, up_x, up_y, up_z, fovy)
}

// DisableCursor/EnableCursor 等 FFI 可以加，但我们为了简单先用 FREE
extern "C" fn disable_cursor_wrapper() = "DisableCursor_wrapper"
extern "C" fn enable_cursor_wrapper() = "EnableCursor_wrapper"

pub fn disable_cursor() -> Unit {
  disable_cursor_wrapper()
}

pub fn enable_cursor() -> Unit {
  enable_cursor_wrapper()
}

pub fn hide_cursor() -> Unit {
  hide_cursor_wrapper()
}

pub fn show_cursor() -> Unit {
  show_cursor_wrapper()
}

extern "C" fn hide_cursor_wrapper() = "HideCursor_wrapper"
extern "C" fn show_cursor_wrapper() = "ShowCursor_wrapper"

pub fn get_camera_position() -> (Double, Double, Double) {
  (get_camera_position_x_wrapper(), get_camera_position_y_wrapper(), get_camera_position_z_wrapper())
}

extern "C" fn get_camera_position_x_wrapper() -> Double = "get_camera_position_x_wrapper"
extern "C" fn get_camera_position_y_wrapper() -> Double = "get_camera_position_y_wrapper"
extern "C" fn get_camera_position_z_wrapper() -> Double = "get_camera_position_z_wrapper"

pub fn set_camera_position(x: Double, y: Double, z: Double) -> Unit {
  set_camera_position_wrapper(x, y, z)
}

extern "C" fn set_camera_position_wrapper(x: Double, y: Double, z: Double) = "set_camera_position_wrapper"

pub fn update_camera(mode: Int) -> Unit {
  update_camera_wrapper(mode)
}

extern "C" fn update_camera_pro_wrapper(movement_x: Double, movement_y: Double, movement_z: Double, rotation_x: Double, rotation_y: Double, rotation_z: Double, zoom: Double) = "UpdateCameraPro_wrapper"

pub fn update_camera_pro(movement_x: Double, movement_y: Double, movement_z: Double, rotation_x: Double, rotation_y: Double, rotation_z: Double, zoom: Double) -> Unit {
  update_camera_pro_wrapper(movement_x, movement_y, movement_z, rotation_x, rotation_y, rotation_z, zoom)
}

pub fn begin_mode_3d_current_camera() -> Unit {
  begin_mode_3d_current_camera_wrapper()
}

extern "C" fn debug_global_model_wrapper() = "debug_global_model_wrapper"

pub fn debug_global_model() -> Unit {
  debug_global_model_wrapper()
}

pub fn load_global_model(path: String) -> Unit {
  clear_text_buffer()
  for c in path {
    append_text_char(c.to_int())
  }
  load_global_model_from_buffer()
}

pub fn load_chunk_model(index: Int, path: String) -> Unit {
  clear_text_buffer()
  for c in path {
    append_text_char(c.to_int())
  }
  load_chunk_model_from_buffer(index)
}

pub fn load_custom_chunk(index: Int, path: String) -> Unit {
  clear_text_buffer()
  for c in path {
    append_text_char(c.to_int())
  }
  load_custom_chunk_wrapper(index)
}

extern "C" fn load_chunk_model_from_buffer(index: Int) = "load_chunk_model_from_buffer"
extern "C" fn draw_chunk_model_wrapper(index: Int, x: Double, y: Double, z: Double, scale: Double) = "draw_chunk_model_wrapper"

extern "C" fn load_custom_chunk_wrapper(index: Int) = "load_custom_chunk"

extern "C" fn draw_custom_chunk_wrapper() = "draw_custom_chunk"
extern "C" fn bind_atlas_to_chunk_wrapper() = "bind_atlas_to_chunk"

pub fn draw_custom_chunk() -> Unit {
  draw_custom_chunk_wrapper()
}

pub fn bind_atlas_to_chunk() -> Unit {
  bind_atlas_to_chunk_wrapper()
}

pub fn draw_chunk_model(index: Int, x: Double, y: Double, z: Double, scale: Double) -> Unit {
  draw_chunk_model_wrapper(index, x, y, z, scale)
}

pub fn draw_global_model(x: Double, y: Double, z: Double, scale: Double) -> Unit {
  draw_global_model_wrapper(x, y, z, scale)
}

pub fn draw_fps(x: Int, y: Int) -> Unit {
  draw_fps_wrapper(x, y)
}

// pub fn begin_mode_3d(cam_px: Double, cam_py: Double, cam_pz: Double, tar_x: Double, tar_y: Double, tar_z: Double, up_x: Double, up_y: Double, up_z: Double, fovy: Double) -> Unit {
//   begin_mode_3d_wrapper(cam_px, cam_py, cam_pz, tar_x, tar_y, tar_z, up_x, up_y, up_z, fovy)
// }

pub fn end_mode_3d() -> Unit {
  end_mode_3d_wrapper()
}

pub fn draw_cube(x: Double, y: Double, z: Double, w: Double, h: Double, l: Double, r: Int, g: Int, b: Int, a: Int) -> Unit {
  draw_cube_wrapper(x, y, z, w, h, l, r, g, b, a)
}

pub fn draw_cube_wires(x: Double, y: Double, z: Double, w: Double, h: Double, l: Double, r: Int, g: Int, b: Int, a: Int) -> Unit {
  draw_cube_wires_wrapper(x, y, z, w, h, l, r, g, b, a)
}

pub fn draw_grid(slices: Int, spacing: Double) -> Unit {
  draw_grid_wrapper(slices, spacing)
}

