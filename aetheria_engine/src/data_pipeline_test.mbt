test "data pipeline handles OBJ format" {
  let raw_obj = "v 1.0 1.0 1.0\n" // Mock OBJ string
  let result = process_3d_asset(OBJ, raw_obj)
  
  assert_eq(result.render_model_path, "asset.obj") |> ignore
  assert_eq(result.colliders.length(), 2) |> ignore
  assert_eq(result.colliders[0].id, "obj_ground") |> ignore
}

test "data pipeline handles PLY format with voxelization" {
  let raw_ply = "ply\nformat ascii 1.0\n" // Mock PLY string
  let result = process_3d_asset(PLY, raw_ply)
  
  assert_eq(result.render_model_path, "converted_from_ply.obj") |> ignore
  assert_eq(result.colliders.length(), 1) |> ignore
  assert_eq(result.colliders[0].id, "voxel_1") |> ignore
}
