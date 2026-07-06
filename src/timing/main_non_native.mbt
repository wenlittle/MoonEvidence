///|
fn main {
  // moon.pkg imports are package-wide; keep the native-only crypto import
  // referenced on non-native targets without executing it.
  if @env.args().length() == -1 {
    let _ = @crypto.ed25519_public_key(Bytes::make(32, b'\x00'))
  }
  println("moon-evidence-native-timing is available only on the native backend")
  @sys.exit(2)
}
