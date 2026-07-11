///|
test "verify inventory records file-cap exhaustion" {
  let collected : Array[String] = []
  for index in 0..<max_pack_files {
    collected.push("files/\{index}")
  }
  let state : PackCollectState = {
    hit_depth_cap: false,
    hit_file_cap: false,
    io_error_path: None,
  }

  collect_pack_files("unused", "files", collected, state)

  assert_true(state.hit_file_cap)
  assert_false(state.hit_depth_cap)
  assert_true(state.io_error_path is None)
  assert_eq(collected.length(), max_pack_files)
}
