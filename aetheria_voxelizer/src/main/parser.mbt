pub struct GLTF {
  json_string : String
  binary_data : Array[Byte]
}

pub fn parse_glb_file(path : String) -> GLTF? {
  let bytes = try {
    @fs.read_file_to_bytes(path)
  } catch {
    e => {
      println("Failed to read file: \{e}")
      return None
    }
  }

  println("File size: \{bytes.length()} bytes")

  if bytes.length() < 12 {
    println("File too small")
    return None
  }

  let m0 = bytes[0]
  let m1 = bytes[1]
  let m2 = bytes[2]
  let m3 = bytes[3]

  if m0 != 0x67 || m1 != 0x6C || m2 != 0x54 || m3 != 0x46 {
    println("Not a valid glTF file (magic mismatch)")
    return None
  }
  
  println("Magic: glTF OK")
  
  fn read_u32(offset: Int) -> Int {
    let b0 = bytes[offset].to_int()
    let b1 = bytes[offset + 1].to_int()
    let b2 = bytes[offset + 2].to_int()
    let b3 = bytes[offset + 3].to_int()
    b0.lor(b1 << 8).lor(b2 << 16).lor(b3 << 24)
  }

  let version = read_u32(4)
  let length = read_u32(8)

  println("Version: \{version}")
  println("Length: \{length}")

  // Read Chunk 0
  let chunk0_len = read_u32(12)
  let chunk0_type = read_u32(16)
  
  if chunk0_type != 0x4E4F534A {
    println("Chunk 0 is not JSON")
    return None
  }

  println("Chunk 0 (JSON) Length: \{chunk0_len}")

  // Read chunk 0 data
  let mut json_str = ""
  // Moonbit string builder
  let sb = StringBuilder::new(size_hint=chunk0_len)
  for i = 0; i < chunk0_len; i = i + 1 {
    let c = bytes[20 + i].to_int().unsafe_to_char()
    sb.write_char(c)
  }
  json_str = sb.to_string()

  // Read Chunk 1 (Binary)
  let chunk1_offset = 20 + chunk0_len
  if chunk1_offset + 8 > bytes.length() {
    println("No chunk 1 found")
    return None
  }

  let chunk1_len = read_u32(chunk1_offset)
  let chunk1_type = read_u32(chunk1_offset + 4)

  if chunk1_type != 0x004E4942 {
    println("Chunk 1 is not BIN")
    return None
  }

  println("Chunk 1 (BIN) Length: \{chunk1_len}")
  
  // Create an array of bytes
  let bin_bytes = Array::new(capacity=chunk1_len)
  for i = 0; i < chunk1_len; i = i + 1 {
    bin_bytes.push(bytes[chunk1_offset + 8 + i])
  }

  Some({ json_string: json_str, binary_data: bin_bytes })
}

pub fn extract_mesh(glb: GLTF) -> Mesh? {
  let parsed_json = try {
    @json.parse(glb.json_string)
  } catch {
    _ => return None
  }
  
  let root = match parsed_json {
    Object(map) => map
    _ => return None
  }
  
  // Extract accessors, bufferViews, meshes
  let meshes = match root.get("meshes") { Some(x) => x; None => return None }
  let accessors = match root.get("accessors") { Some(x) => x; None => return None }
  let bufferViews = match root.get("bufferViews") { Some(x) => x; None => return None }
  
  // Helper to read float32 (little endian) manually
  fn read_f32(offset: Int) -> Double {
    let b0 = glb.binary_data[offset].to_int()
    let b1 = glb.binary_data[offset + 1].to_int()
    let b2 = glb.binary_data[offset + 2].to_int()
    let b3 = glb.binary_data[offset + 3].to_int()
    let bits = b0.lor(b1 << 8).lor(b2 << 16).lor(b3 << 24)
    
    if bits == 0 { return 0.0 }
    
    let sign = if (bits.lsr(31).land(1)) == 1 { -1.0 } else { 1.0 }
    let exp = bits.lsr(23).land(255)
    let frac = bits.land(8388607) // 0x7FFFFF
    
    if exp == 0 {
      return sign * frac.to_double() * @math.pow(2.0, -149.0)
    }
    
    let mantissa = 1.0 + frac.to_double() / 8388608.0 // 2^23
    sign * mantissa * @math.pow(2.0, (exp - 127).to_double())
  }
  
  fn read_u16(offset: Int) -> Int {
    let b0 = glb.binary_data[offset].to_int()
    let b1 = glb.binary_data[offset + 1].to_int()
    b0.lor(b1 << 8)
  }

  fn read_u32(offset: Int) -> Int {
    let b0 = glb.binary_data[offset].to_int()
    let b1 = glb.binary_data[offset + 1].to_int()
    let b2 = glb.binary_data[offset + 2].to_int()
    let b3 = glb.binary_data[offset + 3].to_int()
    b0.lor(b1 << 8).lor(b2 << 16).lor(b3 << 24)
  }

  let all_vertices = Array::new()
  let all_indices = Array::new()
  
  // For each mesh in meshes array
  let meshes_arr = match meshes {
    Array(arr) => arr
    _ => return None
  }
  
  for m_idx = 0; m_idx < meshes_arr.length(); m_idx = m_idx + 1 {
    let mesh = match meshes_arr[m_idx] { Object(m) => m; _ => continue }
    let prims = match mesh.get("primitives") {
      Some(Array(arr)) => arr
      _ => continue
    }
    
    for p_idx = 0; p_idx < prims.length(); p_idx = p_idx + 1 {
      let prim = match prims[p_idx] { Object(p) => p; _ => continue }
      let attributes = match prim.get("attributes") { Some(Object(a)) => a; _ => continue }
      
      let pos_acc_idx = match attributes.get("POSITION") { Some(Number(n)) => n.to_int(); _ => continue }
      let idx_acc_idx = match prim.get("indices") { Some(Number(n)) => n.to_int(); _ => continue }
      
      // Get Accessors
      let acc_arr = match accessors { Array(arr) => arr; _ => return None }
      let pos_acc = match acc_arr[pos_acc_idx] { Object(o) => o; _ => continue }
      let idx_acc = match acc_arr[idx_acc_idx] { Object(o) => o; _ => continue }
      
      let pos_count = match pos_acc.get("count") { Some(Number(n)) => n.to_int(); _ => continue }
      let idx_count = match idx_acc.get("count") { Some(Number(n)) => n.to_int(); _ => continue }
      
      let pos_bv_idx = match pos_acc.get("bufferView") { Some(Number(n)) => n.to_int(); _ => continue }
      let idx_bv_idx = match idx_acc.get("bufferView") { Some(Number(n)) => n.to_int(); _ => continue }
      
      let pos_acc_offset = match pos_acc.get("byteOffset") { Some(Number(n)) => n.to_int(); _ => 0 }
      let idx_acc_offset = match idx_acc.get("byteOffset") { Some(Number(n)) => n.to_int(); _ => 0 }
      let idx_type = match idx_acc.get("componentType") { Some(Number(n)) => n.to_int(); _ => 5123 } // 5123=ushort, 5125=uint
      
      // Get BufferViews
      let bv_arr = match bufferViews { Array(arr) => arr; _ => return None }
      let pos_bv = match bv_arr[pos_bv_idx] { Object(o) => o; _ => continue }
      let idx_bv = match bv_arr[idx_bv_idx] { Object(o) => o; _ => continue }
      
      let pos_bv_offset = match pos_bv.get("byteOffset") { Some(Number(n)) => n.to_int(); _ => 0 }
      let idx_bv_offset = match idx_bv.get("byteOffset") { Some(Number(n)) => n.to_int(); _ => 0 }
      
      // Assume VEC3 FLOAT for positions: 12 bytes per element
      let pos_byte_stride = match pos_bv.get("byteStride") { Some(Number(n)) => n.to_int(); _ => 12 }
      
      let vertex_offset_base = all_vertices.length()
      
      // Read vertices
      for i = 0; i < pos_count; i = i + 1 {
        let offset = pos_bv_offset + pos_acc_offset + i * pos_byte_stride
        let vx = read_f32(offset)
        let vy = read_f32(offset + 4)
        let vz = read_f32(offset + 8)
        all_vertices.push({ x: vx, y: vy, z: vz })
      }
      
      // Read indices
      for i = 0; i < idx_count; i = i + 1 {
        let idx_val = if idx_type == 5125 {
          // UInt32
          read_u32(idx_bv_offset + idx_acc_offset + i * 4)
        } else {
          // UInt16 (5123)
          read_u16(idx_bv_offset + idx_acc_offset + i * 2)
        }
        all_indices.push(idx_val + vertex_offset_base)
      }
    }
  }
  
  println("Extracted total vertices: \{all_vertices.length()}")
  println("Extracted total indices: \{all_indices.length()}")
  
  Some({ vertices: all_vertices, indices: all_indices })
}

pub fn export_chunk(grid: VoxelGrid, path: String) -> Unit {
  let total_voxels = grid.width * grid.height * grid.depth
  let buf_len = 28 + total_voxels
  
  // Use Bytes directly if possible, or an array first
  let buf = Array::make(buf_len, b'\x00')
  
  // Magic "CHNK"
  buf[0] = b'C'
  buf[1] = b'H'
  buf[2] = b'N'
  buf[3] = b'K'
  
  // Helper to write Int
  fn write_i32(offset: Int, val: Int) {
    buf[offset] = val.land(0xFF).to_byte()
    buf[offset + 1] = val.lsr(8).land(0xFF).to_byte()
    buf[offset + 2] = val.lsr(16).land(0xFF).to_byte()
    buf[offset + 3] = val.lsr(24).land(0xFF).to_byte()
  }
  
  write_i32(4, 1) // version
  write_i32(8, grid.width)
  write_i32(12, grid.height)
  write_i32(16, grid.depth)
  
  // voxel_size (ignoring double bits for now, we just write 0s)
  write_i32(20, 0)
  write_i32(24, 0)
  
  let data_offset = 28
  for i = 0; i < total_voxels; i = i + 1 {
    buf[data_offset + i] = if grid.data[i] != 0 { b'\x01' } else { b'\x00' }
  }
  
  // Copy to bytes
  let bytes = Bytes::from_array(buf)
  
  try {
    @fs.write_bytes_to_file(path, bytes)
  } catch {
    _ => println("Failed to write chunk")
  }
}