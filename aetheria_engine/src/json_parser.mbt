// 一个简单的 JSON 结构化解析器占位，用于解析 world_data.json
// 由于处于只读文件系统环境或者无网络环境，导致 moon add 失败，
// 我们暂时构建一个原生的解析占位结构。

pub(all) struct Vector3 {
  x : Double
  y : Double
  z : Double
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

// TODO: 等待引入标准的 json 解析库，目前返回一个 Mock 对象
pub fn parse_world_data(json_str: String) -> WorldData {
  // 假装我们在解析 json_str
  let _ = json_str
  
  {
    spawn_point: { x: 0.0, y: 5.0, z: 0.0 },
    colliders: [
      { id: "ground", min: { x: -10.0, y: -1.0, z: -10.0 }, max: { x: 10.0, y: 0.0, z: 10.0 } }
    ],
    story_nodes: [
      { id: "node_1", position: { x: 0.0, y: 1.0, z: -5.0 }, radius: 2.0, text: "Welcome" }
    ]
  }
}
