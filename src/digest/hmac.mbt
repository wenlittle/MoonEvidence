// RFC 2104 HMAC-SHA256 implementation built on top of the pure-MoonBit
// SHA-256 in sha256.mbt. HMAC provides message authentication: given a
// shared secret key, the recipient can verify both integrity and origin.
//
// HMAC(K, m) = H((K' XOR opad) || H((K' XOR ipad) || m))
// where K' = H(K) if |K| > block_size, else K zero-padded to block_size.

///|
/// SHA-256 block size in bytes (512 bits).
let hmac_block_size : Int = 64

///|
/// Computes HMAC-SHA256 of `message` under `key`, returning the 32-byte MAC.
pub fn hmac_sha256(key : Bytes, message : Bytes) -> Bytes {
  let k_prime = derive_key(key)

  let ipad_key = xor_pad(k_prime, 0x36)
  let inner_ctx = Sha256Ctx::new()
  inner_ctx.update(Bytes::from_array(ipad_key))
  inner_ctx.update(message)
  let inner_hash = inner_ctx.finalize()

  let opad_key = xor_pad(k_prime, 0x5c)
  let outer_ctx = Sha256Ctx::new()
  outer_ctx.update(Bytes::from_array(opad_key))
  outer_ctx.update(inner_hash)
  outer_ctx.finalize()
}

///|
/// Computes HMAC-SHA256 and returns the result as a lowercase hex string.
pub fn hmac_sha256_hex(key : Bytes, message : Bytes) -> String {
  bytes_to_lower_hex(hmac_sha256(key, message))
}

///|
fn derive_key(key : Bytes) -> Array[Byte] {
  let effective : Bytes = if key.length() > hmac_block_size {
    let ctx = Sha256Ctx::new()
    ctx.update(key)
    ctx.finalize()
  } else {
    key
  }
  let padded : Array[Byte] = Array::make(hmac_block_size, b'\x00')
  for i in 0..<effective.length() {
    padded[i] = effective[i]
  }
  padded
}

///|
fn xor_pad(key : Array[Byte], pad_val : Int) -> Array[Byte] {
  let result : Array[Byte] = Array::make(hmac_block_size, b'\x00')
  for i in 0..<hmac_block_size {
    result[i] = key[i].to_int().lxor(pad_val).to_byte()
  }
  result
}
