// MoonBit bindings for WebUI

pub struct WebWindow(Int64)

extern "C" fn clear_text_buffer() = "clear_text_buffer"
extern "C" fn append_text_char(c: Int) = "append_text_char"

fn pass_string(s: String) -> Unit {
    clear_text_buffer()
    let bytes = @utf8.encode(s)
    for i = 0; i < bytes.length(); i = i + 1 {
        append_text_char(bytes[i].to_int())
    }
}

extern "C" fn webui_new_window_wrapper() -> Int64 = "webui_new_window_wrapper"

extern "C" fn init_moonbit_mutex() = "init_moonbit_mutex"

pub fn _keep_alive() -> Unit {
    if webui_get_string_char(0L, 0) == 1 {
        moonbit_webui_dispatcher_v2(0L, 0L, 0L, 0L, 0L)
    }
}

pub fn webui_new_window() -> WebWindow {
    _keep_alive()
    init_moonbit_mutex()
    let window = webui_new_window_wrapper()
    WebWindow(window)
}

extern "C" fn webui_show_wrapper(window: Int64) -> Int = "webui_show_wrapper"
extern "C" fn webui_show_browser_wrapper(window: Int64, browser: Int) -> Bool = "webui_show_browser_wrapper"

pub fn webui_show(window: WebWindow, content: String) -> Unit {
    pass_string(content)
    let _ = webui_show_wrapper(window.0)
}

pub fn webui_show_browser(window: WebWindow, content: String, browser: Int) -> Bool {
    pass_string(content)
    webui_show_browser_wrapper(window.0, browser)
}

extern "C" fn webui_set_timeout_wrapper(second: Int) = "webui_set_timeout_wrapper"
pub fn webui_set_timeout(second: Int) -> Unit {
    webui_set_timeout_wrapper(second)
}

extern "C" fn webui_wait_wrapper() = "webui_wait_wrapper"
pub fn webui_wait() -> Unit {
    webui_wait_wrapper()
}

extern "C" fn webui_exit_wrapper() = "webui_exit_wrapper"
pub fn webui_exit() -> Unit {
    webui_exit_wrapper()
}

extern "C" fn webui_run_wrapper(window: Int64) = "webui_run_wrapper"
pub fn webui_run(window: WebWindow, script: String) -> Unit {
    pass_string(script)
    webui_run_wrapper(window.0)
}

extern "C" fn webui_navigate_wrapper(window: Int64) = "webui_navigate_wrapper"
pub fn webui_navigate(window: WebWindow, url: String) -> Unit {
    pass_string(url)
    webui_navigate_wrapper(window.0)
}

extern "C" fn webui_set_root_folder_wrapper(window: Int64) -> Int = "webui_set_root_folder_wrapper"
pub fn webui_set_root_folder(window: WebWindow, path: String) -> Bool {
    pass_string(path)
    webui_set_root_folder_wrapper(window.0) != 0
}

extern "C" fn webui_bind_wrapper_v2(window: Int64) -> Int64 = "webui_bind_wrapper_v2"
extern "C" fn webui_return_string_wrapper(window: Int64, event_number: Int64) = "webui_return_string_wrapper"

pub fn webui_set_response(window: WebWindow, event_number: Int64, response: String) -> Unit {
    pass_string(response)
    webui_return_string_wrapper(window.0, event_number)
}

extern "C" fn system_command_wrapper() = "system_command_wrapper"
pub fn system_command(cmd: String) -> Unit {
    pass_string(cmd)
    system_command_wrapper()
}

extern "C" fn get_env_wrapper() -> Int64 = "get_env_wrapper"
pub fn get_env(name: String) -> String {
    pass_string(name)
    let ptr = get_env_wrapper()
    read_c_string(ptr)
}

extern "C" fn webui_get_url_wrapper(window: Int64) -> Int64 = "webui_get_url_wrapper"
pub fn webui_get_url(window: WebWindow) -> String {
    let ptr = webui_get_url_wrapper(window.0)
    read_c_string(ptr)
}
extern "C" fn get_time_wrapper() -> Int = "get_time_wrapper"
pub fn get_time() -> Int {
    get_time_wrapper()
}

extern "C" fn webui_get_string_char(ptr: Int64, index: Int) -> Int = "webui_get_string_char"

fn read_c_string(ptr: Int64) -> String {
    if ptr == 0L {
        return ""
    }
    
    let mut len = 0
    let sb = StringBuilder::new()
    let bytes_arr : Array[Byte] = []
    
    while true {
        let c = webui_get_string_char(ptr, len)
        if c == 0 {
            break
        }
        bytes_arr.push(c.to_byte())
        len = len + 1
    }
    
    if len == 0 {
        return ""
    }
    
    let b = Bytes::from_iter(bytes_arr.iter())
    
    try {
        @utf8.decode(b)
    } catch {
        _ => {
            for i = 0; i < len; i = i + 1 {
                let mut char_code = bytes_arr[i].to_int()
                if char_code > 127 { char_code = 63 }
                sb.write_char(char_code.unsafe_to_char())
            }
            sb.to_string()
        }
    }
}

// Global callback dispatcher
let callbacks : Map[String, (WebWindow, String, Int64) -> Unit] = Map::new()

pub fn on(window: WebWindow, element: String, cb: (WebWindow, String, Int64) -> Unit) -> Unit {
    callbacks.set(element, cb)
    pass_string(element)
    let _ = webui_bind_wrapper_v2(window.0)
}

pub fn moonbit_webui_dispatcher_v2(window_id: Int64, event_type: Int64, element_ptr: Int64, data_ptr: Int64, event_number: Int64) -> Unit {
    let _ = event_type
    let element_str = read_c_string(element_ptr)
    let data_str = read_c_string(data_ptr)
    
    // DEBUG LOG
    println("DEBUG [Dispatcher]: Received event from element: \{element_str}")
    
    match callbacks.get(element_str) {
        Some(cb) => cb(WebWindow(window_id), data_str, event_number)
        None => println("DEBUG [Dispatcher]: No callback found for element: \{element_str}")
    }
}
