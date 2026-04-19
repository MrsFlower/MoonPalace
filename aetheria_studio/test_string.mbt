fn test_string() -> Unit {
  let s = "Node 1"
  let mut res = ""
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i].to_int()
    res = res + String::make(1, c.unsafe_to_char())
  }
  println(res)
}