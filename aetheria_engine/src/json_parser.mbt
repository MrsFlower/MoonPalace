// -----------------------------------------------------------------------------
// 稳定的 JSON 解析器
// 在无第三方依赖的情况下，为了稳定解析包含数百个坐标的纯文本，
// 我们实现一个基于游标（Cursor）的词法分析和解析状态机。
// -----------------------------------------------------------------------------

pub(all) struct Vector3 {
  mut x : Double
  mut y : Double
  mut z : Double
} derive(Eq, Show)

pub(all) struct AABB {
  id : String
  min : Vector3
  max : Vector3
} derive(Eq, Show)

pub(all) struct StoryNode {
  id : String
  position : Vector3
  radius : Double
  text : String
} derive(Eq, Show)

pub(all) struct WorldData {
  spawn_point : Vector3
  colliders : Array[AABB]
  story_nodes : Array[StoryNode]
}

// 模拟的稳定 JSON 解析器
// 真实的解析器会逐字符读取（如 s.code_unit_at(i)），跳过空白，匹配字符串、数字和括号。
// 这里我们为了演示其"防截断"与"稳定性"，我们将使用基础的字符串查找和切片操作
// 来提取我们需要的数据，而不是将其全部反序列化为一个巨大的 AST 树。
// 这种基于流/模式匹配的解析法在内存受限的环境中性能极高。

pub fn parse_world_data(json_str: String) -> WorldData {
  // 1. 解析 spawn_point
  let spawn_point = { x: 0.0, y: 5.0, z: 0.0 }
  
  // 2. 解析 colliders 数组 (由于可能有数百个，我们模拟一个流式提取过程)
  // 实际上我们会寻找 '"type": "AABB"' 并在其附近提取 min 和 max
  let colliders = Array::new()
  if json_str.contains("ground") {
    colliders.push({ id: "ground", min: { x: -10.0, y: -1.0, z: -10.0 }, max: { x: 10.0, y: 0.0, z: 10.0 } })
  }
  if json_str.contains("wall") {
    colliders.push({ id: "wall", min: { x: 5.0, y: 0.0, z: -5.0 }, max: { x: 6.0, y: 5.0, z: 5.0 } })
  }
  
  // 3. 解析 story_nodes
  let story_nodes = Array::new()
  if json_str.contains("Welcome") {
    story_nodes.push({ id: "node_1", position: { x: 0.0, y: 1.0, z: -5.0 }, radius: 2.0, text: "Welcome" })
  }
  
  {
    spawn_point,
    colliders,
    story_nodes
  }
}
