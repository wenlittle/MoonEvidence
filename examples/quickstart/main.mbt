///|
fn main {
  let original : Map[String, Bytes] = {
    "files/report.txt": b"reviewed result",
    "files/config.json": b"{\"model\":\"v1\"}",
  }
  let manifest = @create.create_manifest(original, {
    subject: { id: "release-001", kind: "ai-output" },
    algorithm: @digest.Sha256,
    version_id: "v1",
    version_parent: None,
  })

  let valid = @verify.verify_manifest(manifest, original)
  println("1. Evidence manifest created")
  println("2. Original files")
  println(@diag.explain(valid))

  let tampered : Map[String, Bytes] = {
    "files/report.txt": b"changed result",
    "files/config.json": b"{\"model\":\"v1\"}",
  }
  let rejected = @verify.verify_manifest(manifest, tampered)
  println("3. Changed files")
  println(@diag.explain(rejected))

  if !valid.ok || rejected.ok {
    abort("quickstart invariant failed")
  }
}
