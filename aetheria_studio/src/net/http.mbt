extern "C" fn net_clear_buffer() = "net_clear_buffer"
extern "C" fn net_append_char(c : Int) = "net_append_char"
extern "C" fn net_get_char(index : Int) -> Int = "net_get_char"

extern "C" fn net_internet_open() -> Int64 = "net_internet_open"
extern "C" fn net_internet_connect(hInternet : Int64, port : Int, is_https : Int) -> Int64 = "net_internet_connect"
extern "C" fn net_http_open_request(hConnect : Int64, is_post : Int, is_https : Int) -> Int64 = "net_http_open_request"
extern "C" fn net_http_add_header(hRequest : Int64) -> Int = "net_http_add_header"
extern "C" fn net_http_send_request(hRequest : Int64) -> Int = "net_http_send_request"
extern "C" fn net_http_get_status_code(hRequest : Int64) -> Int = "net_http_get_status_code"
extern "C" fn net_internet_read_file(hFile : Int64) -> Int = "net_internet_read_file"
extern "C" fn net_internet_close_handle(handle : Int64) = "net_internet_close_handle"

extern "C" fn worker_read_file() -> Int = "worker_read_file"
extern "C" fn worker_write_file(append : Int) -> Int = "worker_write_file"
extern "C" fn worker_sleep(ms : Int) = "worker_sleep"
extern "C" fn worker_get_random() -> Int = "worker_get_random"

pub fn get_random() -> Int {
  worker_get_random()
}

extern "C" fn worker_mkdir(path_ptr: Int) -> Int = "worker_mkdir"
extern "C" fn worker_get_exe_dir() -> Int = "worker_get_exe_dir"

pub fn get_exe_dir() -> String {
  let size = worker_get_exe_dir()
  if size <= 0 {
    return ""
  }
  let arr : Array[Byte] = []
  for i = 0; i < size; i = i + 1 {
    arr.push(net_get_char(i).to_byte())
  }
  try { @utf8.decode(Bytes::from_array(arr)) } catch { _ => "" }
}

extern "C" fn worker_rename_file(old_ptr: Int, new_ptr: Int) -> Int = "worker_rename_file"

extern "C" fn system_command_wrapper(cmd: Int) -> Int = "net_system_command_wrapper"

pub fn system_command(cmd: String) -> Unit {
  net_clear_buffer()
  let bytes = @utf8.encode(cmd + "\u0000")
  for i = 0; i < bytes.length(); i = i + 1 {
    net_append_char(bytes[i].to_int())
  }
  let _ = system_command_wrapper(0)
}

pub fn rename_file(old_path: String, new_path: String) -> Unit {
  // we will pass old_path in net_path, and new_path in net_buffer to C
  net_clear_path()
  let path_c = @utf8.encode(old_path + "\u0000")
  for i = 0; i < path_c.length(); i = i + 1 {
    net_append_path_char(path_c[i].to_int())
  }
  
  net_clear_buffer()
  let new_c = @utf8.encode(new_path + "\u0000")
  for i = 0; i < new_c.length(); i = i + 1 {
    net_append_char(new_c[i].to_int())
  }
  
  let _ = worker_rename_file(0, 0)
}

pub fn create_dir(path: String) -> Unit {
  net_clear_path()
  let path_c = @utf8.encode(path + "\u0000")
  for i = 0; i < path_c.length(); i = i + 1 {
    net_append_path_char(path_c[i].to_int())
  }
  let _ = worker_mkdir(0) // 0 is ignored, path is in net_path
}

pub fn sleep(ms : Int) -> Unit {
  worker_sleep(ms)
}

extern "C" fn net_clear_path() = "net_clear_path"
extern "C" fn net_append_path_char(c : Int) = "net_append_path_char"

pub fn read_file(path : String) -> Result[String, String] {
  net_clear_path()
  let path_c = @utf8.encode(path + "\u0000")
  for i = 0; i < path_c.length(); i = i + 1 {
    net_append_path_char(path_c[i].to_int())
  }
  let size = worker_read_file()
  if size < 0 {
    return Err("Failed to read file")
  }
  let arr : Array[Byte] = []
  for i = 0; i < size; i = i + 1 {
    arr.push(net_get_char(i).to_byte())
  }
  let s = try { @utf8.decode(Bytes::from_array(arr)) } catch { _ => "Decode error" }
  Ok(s)
}

pub fn read_file_bytes(path : String) -> Result[Bytes, String] {
  net_clear_path()
  let path_c = @utf8.encode(path + "\u0000")
  for i = 0; i < path_c.length(); i = i + 1 {
    net_append_path_char(path_c[i].to_int())
  }
  let size = worker_read_file()
  if size < 0 {
    return Err("Failed to read file")
  }
  let arr : Array[Byte] = []
  for i = 0; i < size; i = i + 1 {
    arr.push(net_get_char(i).to_byte())
  }
  Ok(Bytes::from_array(arr))
}

pub fn write_file(path : String, content : String) -> Result[Unit, String] {
  net_clear_path()
  put_string_to_buffer(content)
  let path_c = @utf8.encode(path + "\u0000")
  for i = 0; i < path_c.length(); i = i + 1 {
    net_append_path_char(path_c[i].to_int())
  }
  let written = worker_write_file(0)
  if written < 0 {
    return Err("Failed to write file")
  }
  Ok(())
}

pub fn append_file(path : String, content : String) -> Result[Unit, String] {
  net_clear_path()
  put_string_to_buffer(content)
  let path_c = @utf8.encode(path + "\u0000")
  for i = 0; i < path_c.length(); i = i + 1 {
    net_append_path_char(path_c[i].to_int())
  }
  let written = worker_write_file(1)
  if written < 0 {
    return Err("Failed to append file")
  }
  Ok(())
}


pub fn write_file_bytes(path : String, bytes : Bytes) -> Result[Unit, String] {
  net_clear_path()
  let path_c = @utf8.encode(path + "\u0000")
  for i = 0; i < path_c.length(); i = i + 1 {
    net_append_path_char(path_c[i].to_int())
  }
  
  // write in chunks to avoid buffer overflow
  let chunk_size = 10 * 1024 * 1024 // 10MB chunk
  let mut offset = 0
  
  // write the first chunk (mode=wb)
  net_clear_buffer()
  let mut to_write = if bytes.length() > chunk_size { chunk_size } else { bytes.length() }
  for i = 0; i < to_write; i = i + 1 {
    net_append_char(bytes[i].to_int())
  }
  let mut written = worker_write_file(0)
  if written < 0 {
    return Err("Failed to write file bytes")
  }
  offset = offset + to_write
  
  // append remaining chunks (mode=ab)
  while offset < bytes.length() {
    net_clear_buffer()
    to_write = if bytes.length() - offset > chunk_size { chunk_size } else { bytes.length() - offset }
    for i = 0; i < to_write; i = i + 1 {
      net_append_char(bytes[offset + i].to_int())
    }
    written = worker_write_file(1)
    if written < 0 {
      return Err("Failed to append file bytes")
    }
    offset = offset + to_write
  }
  
  Ok(())
}

fn put_string_to_buffer(s : String) -> Unit {
  net_clear_buffer()
  let bytes = @utf8.encode(s)
  for i = 0; i < bytes.length(); i = i + 1 {
    net_append_char(bytes[i].to_int())
  }
}

pub struct HttpResponse {
  status_code : Int
  body : String
}

pub fn http_get(url : String, headers~: Array[String] = []) -> Result[HttpResponse, String] {
  let is_https = if url.has_prefix("https://") { 1 } else { 0 }
  let prefix_len = if is_https == 1 { 8 } else { 7 }
  
  let without_prefix = url[prefix_len:].to_string()
  
  let mut path_idx = without_prefix.length()
  for i = 0; i < without_prefix.length(); i = i + 1 {
    if without_prefix[i] == '/' || without_prefix[i] == '?' {
      path_idx = i
      break
    }
  }
  
  let host_port = without_prefix[:path_idx].to_string()
  let path_str = if path_idx == without_prefix.length() { "/" } else { without_prefix[path_idx:].to_string() }
  
  let mut port = if is_https == 1 { 443 } else { 80 }
  let mut host_str = host_port
  for i = 0; i < host_port.length(); i = i + 1 {
    if host_port[i] == ':' {
      host_str = host_port[:i].to_string()
      let port_str = host_port[i+1:].to_string()
      let mut p = 0
      for j = 0; j < port_str.length(); j = j + 1 {
        let c = port_str[j].to_int()
        if c >= 48 && c <= 57 {
          p = p * 10 + (c - 48)
        }
      }
      port = p
      break
    }
  }
  
  println("GET HOST: \{host_str}, PORT: \{port}, PATH: \{path_str}")
  let hInternet = net_internet_open()
  if hInternet == 0L {
    return Err("Failed to open internet handle")
  }
  
  put_string_to_buffer(host_str)
  let hConnect = net_internet_connect(hInternet, port, is_https)
  if hConnect == 0L {
    net_internet_close_handle(hInternet)
    return Err("Failed to connect to host")
  }
  
  put_string_to_buffer(path_str)
  let hRequest = net_http_open_request(hConnect, 0, is_https)
  if hRequest == 0L {
    net_internet_close_handle(hConnect)
    net_internet_close_handle(hInternet)
    return Err("Failed to open HTTP request")
  }
  
  for header in headers {
    put_string_to_buffer(header + "\r\n")
    let _ = net_http_add_header(hRequest)
  }
  
  net_clear_buffer() // empty body
  let send_res = net_http_send_request(hRequest)
  if send_res == 0 {
    net_internet_close_handle(hRequest)
    net_internet_close_handle(hConnect)
    net_internet_close_handle(hInternet)
    return Err("Failed to send HTTP request")
  }
  
  let status_code = net_http_get_status_code(hRequest)
  
  let response_bytes : Array[Byte] = []
  
  while true {
    let bytes_read = net_internet_read_file(hRequest)
    if bytes_read <= 0 {
      break
    }
    for i = 0; i < bytes_read; i = i + 1 {
      let b = net_get_char(i)
      response_bytes.push(b.to_byte())
    }
  }
  
  net_internet_close_handle(hRequest)
  net_internet_close_handle(hConnect)
  net_internet_close_handle(hInternet)
  
  let final_bytes = Bytes::from_array(response_bytes)
  let body_str = try { @utf8.decode(final_bytes) } catch { _ => "Error decoding response" }
  
  Ok({ status_code, body: body_str })
}

pub fn http_post(url : String, headers : Array[String], body : String) -> Result[HttpResponse, String] {
  let is_https = if url.has_prefix("https://") { 1 } else { 0 }
  let prefix_len = if is_https == 1 { 8 } else { 7 }
  
  let without_prefix = url[prefix_len:].to_string()
  
  let mut path_idx = without_prefix.length()
  for i = 0; i < without_prefix.length(); i = i + 1 {
    if without_prefix[i] == '/' || without_prefix[i] == '?' {
      path_idx = i
      break
    }
  }
  
  let host_port = without_prefix[:path_idx].to_string()
  let path_str = if path_idx == without_prefix.length() { "/" } else { without_prefix[path_idx:].to_string() }
  
  let mut port = if is_https == 1 { 443 } else { 80 }
  let mut host_str = host_port
  for i = 0; i < host_port.length(); i = i + 1 {
    if host_port[i] == ':' {
      host_str = host_port[:i].to_string()
      let port_str = host_port[i+1:].to_string()
      let mut p = 0
      for j = 0; j < port_str.length(); j = j + 1 {
        let c = port_str[j].to_int()
        if c >= 48 && c <= 57 {
          p = p * 10 + (c - 48)
        }
      }
      port = p
      break
    }
  }
  
  println("GET HOST: \{host_str}, PORT: \{port}, PATH: \{path_str}")
  let hInternet = net_internet_open()
  if hInternet == 0L {
    return Err("Failed to open internet handle")
  }
  
  put_string_to_buffer(host_str)
  let hConnect = net_internet_connect(hInternet, port, is_https)
  if hConnect == 0L {
    net_internet_close_handle(hInternet)
    return Err("Failed to connect to host")
  }
  
  put_string_to_buffer(path_str)
  let hRequest = net_http_open_request(hConnect, 1, is_https)
  if hRequest == 0L {
    net_internet_close_handle(hConnect)
    net_internet_close_handle(hInternet)
    return Err("Failed to open HTTP request")
  }
  
  for header in headers {
    put_string_to_buffer(header + "\r\n")
    let _ = net_http_add_header(hRequest)
  }
  
  put_string_to_buffer(body)
  let send_res = net_http_send_request(hRequest)
  if send_res == 0 {
    net_internet_close_handle(hRequest)
    net_internet_close_handle(hConnect)
    net_internet_close_handle(hInternet)
    return Err("Failed to send HTTP request")
  }
  
  let status_code = net_http_get_status_code(hRequest)
  
  let response_bytes : Array[Byte] = []
  
  while true {
    let bytes_read = net_internet_read_file(hRequest)
    if bytes_read <= 0 {
      break
    }
    for i = 0; i < bytes_read; i = i + 1 {
      let b = net_get_char(i)
      response_bytes.push(b.to_byte())
    }
  }
  
  net_internet_close_handle(hRequest)
  net_internet_close_handle(hConnect)
  net_internet_close_handle(hInternet)
  
  let final_bytes = Bytes::from_array(response_bytes)
  let body_str = try { @utf8.decode(final_bytes) } catch { _ => "Error decoding response" }
  
  Ok({ status_code, body: body_str })
}

pub fn http_get_bytes(url : String, headers~: Array[String] = []) -> Result[Bytes, String] {
  let is_https = if url.has_prefix("https://") { 1 } else { 0 }
  let prefix_len = if is_https == 1 { 8 } else { 7 }
  
  let without_prefix = url[prefix_len:].to_string()
  
  let mut path_idx = without_prefix.length()
  for i = 0; i < without_prefix.length(); i = i + 1 {
    if without_prefix[i] == '/' || without_prefix[i] == '?' {
      path_idx = i
      break
    }
  }
  
  let host_port = without_prefix[:path_idx].to_string()
  let path_str = if path_idx == without_prefix.length() { "/" } else { without_prefix[path_idx:].to_string() }
  
  let mut port = if is_https == 1 { 443 } else { 80 }
  let mut host_str = host_port
  for i = 0; i < host_port.length(); i = i + 1 {
    if host_port[i] == ':' {
      host_str = host_port[:i].to_string()
      let port_str = host_port[i+1:].to_string()
      let mut p = 0
      for j = 0; j < port_str.length(); j = j + 1 {
        let c = port_str[j].to_int()
        if c >= 48 && c <= 57 {
          p = p * 10 + (c - 48)
        }
      }
      port = p
      break
    }
  }
  
  println("GET BYTES HOST: \{host_str}, PORT: \{port}, PATH: \{path_str}")
  let hInternet = net_internet_open()
  if hInternet == 0L {
    return Err("Failed to open internet handle")
  }
  
  put_string_to_buffer(host_str)
  let hConnect = net_internet_connect(hInternet, port, is_https)
  if hConnect == 0L {
    net_internet_close_handle(hInternet)
    return Err("Failed to connect to host")
  }
  
  put_string_to_buffer(path_str)
  let hRequest = net_http_open_request(hConnect, 0, is_https)
  if hRequest == 0L {
    net_internet_close_handle(hConnect)
    net_internet_close_handle(hInternet)
    return Err("Failed to open HTTP request")
  }
  
  for header in headers {
    put_string_to_buffer(header + "\r\n")
    let _ = net_http_add_header(hRequest)
  }
  
  net_clear_buffer() // empty body
  let send_res = net_http_send_request(hRequest)
  if send_res == 0 {
    net_internet_close_handle(hRequest)
    net_internet_close_handle(hConnect)
    net_internet_close_handle(hInternet)
    return Err("Failed to send HTTP request")
  }
  
  let response_bytes : Array[Byte] = []
  
  while true {
    let bytes_read = net_internet_read_file(hRequest)
    if bytes_read <= 0 {
      break
    }
    for i = 0; i < bytes_read; i = i + 1 {
      let b = net_get_char(i)
      response_bytes.push(b.to_byte())
    }
  }
  
  net_internet_close_handle(hRequest)
  net_internet_close_handle(hConnect)
  net_internet_close_handle(hInternet)
  
  Ok(Bytes::from_array(response_bytes))
}
