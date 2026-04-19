fn main {
  let ba = b"hello".to_fixedarray()
  ba[0] = b'\x61'
  let b2 = Bytes::from_fixedarray(ba)
  println(b2)
}