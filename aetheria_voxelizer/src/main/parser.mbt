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
  let all_uvs = Array::new()
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
      let uv_acc_idx = match attributes.get("TEXCOORD_0") { Some(Number(n)) => n.to_int(); _ => -1 }
      let idx_acc_idx = match prim.get("indices") { Some(Number(n)) => n.to_int(); _ => continue }
      
      // Get Accessors
      let acc_arr = match accessors { Array(arr) => arr; _ => return None }
      let pos_acc = match acc_arr[pos_acc_idx] { Object(o) => o; _ => continue }
      let uv_acc = if uv_acc_idx >= 0 { match acc_arr[uv_acc_idx] { Object(o) => o; _ => pos_acc } } else { pos_acc }
      let idx_acc = match acc_arr[idx_acc_idx] { Object(o) => o; _ => continue }
      
      let pos_count = match pos_acc.get("count") { Some(Number(n)) => n.to_int(); _ => continue }
      let idx_count = match idx_acc.get("count") { Some(Number(n)) => n.to_int(); _ => continue }
      
      let pos_bv_idx = match pos_acc.get("bufferView") { Some(Number(n)) => n.to_int(); _ => continue }
      let uv_bv_idx = match uv_acc.get("bufferView") { Some(Number(n)) => n.to_int(); _ => pos_bv_idx }
      let idx_bv_idx = match idx_acc.get("bufferView") { Some(Number(n)) => n.to_int(); _ => continue }
      
      let pos_acc_offset = match pos_acc.get("byteOffset") { Some(Number(n)) => n.to_int(); _ => 0 }
      let uv_acc_offset = match uv_acc.get("byteOffset") { Some(Number(n)) => n.to_int(); _ => 0 }
      let idx_acc_offset = match idx_acc.get("byteOffset") { Some(Number(n)) => n.to_int(); _ => 0 }
      let idx_type = match idx_acc.get("componentType") { Some(Number(n)) => n.to_int(); _ => 5123 } // 5123=ushort, 5125=uint
      
      // Get BufferViews
      let bv_arr = match bufferViews { Array(arr) => arr; _ => return None }
      let pos_bv = match bv_arr[pos_bv_idx] { Object(o) => o; _ => continue }
      let uv_bv = match bv_arr[uv_bv_idx] { Object(o) => o; _ => pos_bv }
      let idx_bv = match bv_arr[idx_bv_idx] { Object(o) => o; _ => continue }
      
      let pos_bv_offset = match pos_bv.get("byteOffset") { Some(Number(n)) => n.to_int(); _ => 0 }
      let uv_bv_offset = match uv_bv.get("byteOffset") { Some(Number(n)) => n.to_int(); _ => 0 }
      let idx_bv_offset = match idx_bv.get("byteOffset") { Some(Number(n)) => n.to_int(); _ => 0 }
      
      // Assume VEC3 FLOAT for positions: 12 bytes per element
      let pos_byte_stride = match pos_bv.get("byteStride") { Some(Number(n)) => n.to_int(); _ => 12 }
      // Assume VEC2 FLOAT for UVs: 8 bytes per element
      let uv_byte_stride = match uv_bv.get("byteStride") { Some(Number(n)) => n.to_int(); _ => 8 }
      
      let vertex_offset_base = all_vertices.length()
      
      // Read vertices and UVs
      for i = 0; i < pos_count; i = i + 1 {
        let offset = pos_bv_offset + pos_acc_offset + i * pos_byte_stride
        let vx = read_f32(offset)
        let vy = read_f32(offset + 4)
        let vz = read_f32(offset + 8)
        all_vertices.push({ x: vx, y: vy, z: vz })
        
        if uv_acc_idx >= 0 {
          let u_offset = uv_bv_offset + uv_acc_offset + i * uv_byte_stride
          let u = read_f32(u_offset)
          let v = read_f32(u_offset + 4)
          all_uvs.push({ u: u, v: v })
        } else {
          all_uvs.push({ u: 0.0, v: 0.0 })
        }
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
  println("Extracted total uvs: \{all_uvs.length()}")
  println("Extracted total indices: \{all_indices.length()}")
  
  Some({ vertices: all_vertices, uvs: all_uvs, indices: all_indices })
}

pub fn export_chunk(grid: VoxelGrid, mesh_opt: Mesh?, path: String) -> Unit {
  let total_voxels = grid.width * grid.height * grid.depth
  let mut solid_count = 0
  for i = 0; i < total_voxels; i = i + 1 {
    if grid.data[i] != 0 {
      solid_count = solid_count + 1
    }
  }

  // Chunk format:
  // 0-3: "CHNK"
  // 4-7: version
  // 8-19: width, height, depth
  // 20-27: voxel_size (double, 8 bytes, ignored for now)
  // 28-31: has_uv (1 = true, 0 = false)
  // 32..32+total_voxels: 1D grid array (1 byte per voxel, 1=solid, 0=empty)
  // [If has_uv]: 32+total_voxels .. end: 8 UVs (16 floats) per solid voxel in the same order as they appear in the grid array.
  
  let has_uv = match mesh_opt { Some(_) => 1; None => 0 }
  let uv_data_len = if has_uv == 1 { solid_count * 16 * 4 } else { 0 }
  let buf_len = 32 + total_voxels + uv_data_len
  
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
  
  // Helper to write Double as Float32
  fn write_f32(offset: Int, val: Double) {
    let bits = if val == 0.0 { 0 } else {
      let b64 = val.reinterpret_as_i64()
      let sign = b64.lsr(63).land(1L)
      let exp_f64 = b64.lsr(52).land(2047L)
      let mant_f64 = b64.land(4503599627370495L) // 0xFFFFFFFFFFFFF
      let exp_f32 = exp_f64 - 1023L + 127L
      let mant_f32 = mant_f64.lsr(29)
      
      let s = sign.to_int()
      let e = exp_f32.to_int().land(255)
      let m = mant_f32.to_int().land(8388607)
      
      (s << 31).lor(e << 23).lor(m)
    }
    write_i32(offset, bits)
  }

  
  write_i32(4, 1) // version
  write_i32(8, grid.width)
  write_i32(12, grid.height)
  write_i32(16, grid.depth)
  
  // voxel_size (ignoring double bits for now, we just write 0s)
  write_i32(20, 0)
  write_i32(24, 0)
  
  write_i32(28, has_uv)
  
  let data_offset = 32
  for i = 0; i < total_voxels; i = i + 1 {
    buf[data_offset + i] = if grid.data[i] != 0 { b'\x01' } else { b'\x00' }
  }

  // Write UV data if we have mesh
  match mesh_opt {
    Some(mesh) => {
      let mut uv_offset = 32 + total_voxels
      for i = 0; i < total_voxels; i = i + 1 {
        let val = grid.data[i]
        if val != 0 {
          let tri_id = val - 1
          
          let v0 = mesh.vertices[mesh.indices[tri_id * 3]]
          let v1 = mesh.vertices[mesh.indices[tri_id * 3 + 1]]
          let v2 = mesh.vertices[mesh.indices[tri_id * 3 + 2]]
          
          let uv0 = mesh.uvs[mesh.indices[tri_id * 3]]
          let uv1 = mesh.uvs[mesh.indices[tri_id * 3 + 1]]
          let uv2 = mesh.uvs[mesh.indices[tri_id * 3 + 2]]
          
          // Compute triangle normal
          let e1x = v1.x - v0.x
          let e1y = v1.y - v0.y
          let e1z = v1.z - v0.z
          let e2x = v2.x - v0.x
          let e2y = v2.y - v0.y
          let e2z = v2.z - v0.z
          
          let nx = e1y * e2z - e1z * e2y
          let ny = e1z * e2x - e1x * e2z
          let nz = e1x * e2y - e1y * e2x
          let n_dot_n = nx * nx + ny * ny + nz * nz
          
          let z = i / (grid.width * grid.height)
          let y = (i / grid.width) % grid.height
          let x = i % grid.width
          
          let vx = x.to_double() * grid.voxel_size
          let vy = y.to_double() * grid.voxel_size
          let vz = z.to_double() * grid.voxel_size
          
          // ----------------------------------------------------------------------
          // 核心贴图逻辑: 将体素化方块的 8 个顶点映射回原始三角形获取 UV
          // ----------------------------------------------------------------------
          // 我们遍历方块的 8 个角 (Corners)
          for c = 0; c < 8; c = c + 1 {
            let cx = vx + (if (c.land(1)) != 0 { grid.voxel_size } else { 0.0 })
            let cy = vy + (if (c.land(2)) != 0 { grid.voxel_size } else { 0.0 })
            let cz = vz + (if (c.land(4)) != 0 { grid.voxel_size } else { 0.0 })
            
            let mut final_u = 0.0
            let mut final_v = 0.0
            
            if n_dot_n > 0.0000001 {
              // 步骤 1: 将方块的顶点垂直投影到原始三角形面所在的平面上
              let px = cx - v0.x
              let py = cy - v0.y
              let pz = cz - v0.z
              
              let dist = (px * nx + py * ny + pz * nz) / n_dot_n
              
              let p_proj_x = cx - dist * nx
              let p_proj_y = cy - dist * ny
              let p_proj_z = cz - dist * nz
              
              // 步骤 2: 计算投影点在该三角形中的重心坐标 (Barycentric Coordinates)
              // 重心坐标 u_bary, v_bary, w_bary 表示该点在三个顶点间的权重分配
              let w0x = e1x; let w0y = e1y; let w0z = e1z
              let w1x = e2x; let w1y = e2y; let w1z = e2z
              let w2x = p_proj_x - v0.x
              let w2y = p_proj_y - v0.y
              let w2z = p_proj_z - v0.z
              
              let d00 = w0x*w0x + w0y*w0y + w0z*w0z
              let d01 = w0x*w1x + w0y*w1y + w0z*w1z
              let d11 = w1x*w1x + w1y*w1y + w1z*w1z
              let d20 = w2x*w0x + w2y*w0y + w2z*w0z
              let d21 = w2x*w1x + w2y*w1y + w2z*w1z
              
              let denom = d00 * d11 - d01 * d01
              if denom > 0.0000001 {
                let v_bary = (d11 * d20 - d01 * d21) / denom
                let w_bary = (d00 * d21 - d01 * d20) / denom
                let u_bary = 1.0 - v_bary - w_bary
                
                // 步骤 3: 严格重心坐标钳制 (Barycentric Clamping)
                // 解释: 体素的顶点必然会超出它所映射的原始三角形边界，这会导致重心坐标出现负数。
                // 如果不加钳制，直接进行 UV 采样会导致严重的“越界采样 (Texture Bleeding)”，
                // 从图集中读取到毫不相干的其他物体贴图，从而出现“迷彩噪点”。
                // 这里的钳制逻辑确保投影点始终被强行拉回到三角形内部或者边缘上。
                let mut clamped_u = u_bary
                let mut clamped_v = v_bary
                let mut clamped_w = w_bary
                
                if clamped_u < 0.0 { clamped_v = clamped_v + clamped_u / 2.0; clamped_w = clamped_w + clamped_u / 2.0; clamped_u = 0.0 }
                if clamped_v < 0.0 { clamped_u = clamped_u + clamped_v / 2.0; clamped_w = clamped_w + clamped_v / 2.0; clamped_v = 0.0 }
                if clamped_w < 0.0 { clamped_u = clamped_u + clamped_w / 2.0; clamped_v = clamped_v + clamped_w / 2.0; clamped_w = 0.0 }
                
                // 重新归一化确保总权重为 1.0
                let sum = clamped_u + clamped_v + clamped_w
                if sum > 0.0000001 {
                    clamped_u = clamped_u / sum
                    clamped_v = clamped_v / sum
                    clamped_w = clamped_w / sum
                }
                
                // 步骤 4: 通过重心坐标插值计算出最终的 UV 坐标
                final_u = clamped_u * uv0.u + clamped_v * uv1.u + clamped_w * uv2.u
                final_v = clamped_u * uv0.v + clamped_v * uv1.v + clamped_w * uv2.v
              }
            }
            
            write_f32(uv_offset, final_u)
            write_f32(uv_offset + 4, final_v)
            uv_offset = uv_offset + 8
          }
        }
      }
    }
    None => ()
  }
  
  // Copy to bytes
  let bytes = Bytes::from_array(buf)
  
  try {
    @fs.write_bytes_to_file(path, bytes)
  } catch {
    _ => println("Failed to write chunk")
  }
}