# Ed25519 Constant-Time Static Audit

Date: 2026-07-06 Asia/Shanghai

This audit records the static control-flow review for the pure MoonBit
Ed25519 implementation. It is not a formal side-channel proof and it does not
replace backend disassembly review or dudect-style timing analysis.

## Verdict

The previous broad claim "Ed25519 is constant-time" was too strong until the
scalar-reduction branch issue was fixed. As of 2026-07-06, the source-level
review no longer finds explicit branches on secret-derived scalar-reduction
state in `reduce_scalar_512`.

- `Point::scalar_mul`, `fe_cmov`, `point_cmov`, `Fe::eq`, and
  `Fe::to_bytes` are written with fixed loop counts and no obvious
  secret-dependent branches in source.
- `ed25519_verify` rejects malformed signatures through public/adversarial
  inputs (`pk`, `R`, `S`, `msg`). Those early returns are acceptable for a
  verifier.
- `ed25519_sign` now uses reviewed scalar multiplication and branch-free
  source-level scalar reduction for the signing reductions.

The project may claim source-reviewed constant-time Ed25519 signing logic, but
must still avoid any stronger production-grade side-channel claim until backend
lowering, runtime behavior, and dudect-style timing analysis are completed.

## Secret Model

Secret in signing:

- Secret key `sk`.
- Clamped scalar `a = clamp_scalar(SHA-512(sk)[0..32])`.
- Nonce prefix `SHA-512(sk)[32..64]`.
- Nonce scalar `r = reduce_scalar_512(SHA-512(prefix || msg))`.
- `S = r + k*a mod l` and intermediate scalar-reduction state.

Public or attacker-controlled in verification:

- Public key `pk`.
- Message `msg`.
- Signature bytes `R || S`.
- Decoded public points and all rejection decisions derived from those bytes.

## Reviewed Functions

| Function | Source | Input class | Control-flow finding | Status |
| --- | --- | --- | --- | --- |
| `Fe::to_bytes` | `src/crypto/field25519.mbt:156-192` | May process secret field elements | Fixed two subtract rounds; `p_i` branch depends only on public loop index; final select uses masks from borrow. | OK by source review |
| `Fe::eq` | `src/crypto/field25519.mbt:199-207` | May compare secret field elements | Always scans 32 bytes and accumulates XOR diff before one final equality check. | OK by source review |
| `fe_cmov` | `src/crypto/field25519.mbt:214-227` | `bit` may be a secret scalar bit | Uses `bit` to build a mask and select limbs with XOR/AND, no explicit branch. | OK by source review |
| `point_cmov` | `src/crypto/point25519.mbt:129-136` | `bit` may be a secret scalar bit | Delegates to four `fe_cmov` calls. | OK by source review |
| `Point::scalar_mul` | `src/crypto/point25519.mbt:144-161` | Secret in signing and key derivation | Fixed 32-byte / 256-bit loop; every bit performs `double`, `add`, then `point_cmov`. | OK by source review |
| `Point::encode` | `src/crypto/point25519.mbt:180-193` | May encode secret-derived points during signing | Uses fixed operations; sign-bit write is arithmetic/bitwise. | OK by source review |
| `reduce_scalar_512` | `src/crypto/ed25519.mbt:81-153` | Secret-derived in signing | Fixed outer loop counts. The acc-vs-multiple comparison uses arithmetic greater/less masks, and borrow propagation uses arithmetic selection rather than `if diff < 0`. | OK by source review |
| `sc_muladd` | `src/crypto/ed25519.mbt:193-217` | Secret-derived in signing | Multiplication/carry loops are fixed; final reduction calls the reviewed `reduce_scalar_512`. | OK by source review |
| `scalar_lt_l` | `src/crypto/ed25519.mbt:223-239` | Public `S` in verification | Early returns depend on public signature bytes. Acceptable for `verify`; not suitable for future secret scalar checks. | Public-input only |
| `point_decode` | `src/crypto/ed25519.mbt:334-379` | Public `pk`/`R` in verification | Length, canonical encoding, sqrt correction, sign correction, and invalid-point branches depend on public input. | Public-input only |
| `ed25519_sign` | `src/crypto/ed25519.mbt:167-188` | Secret signing path | Uses reviewed `scalar_mul` and reviewed `reduce_scalar_512` for `r`, `k`, and `S` reduction. | OK by source review |
| `ed25519_verify` | `src/crypto/ed25519.mbt:244-295` | Public verification path | Rejection branches are based on public/adversarial inputs. | Acceptable |

## Findings

### CT-001: Secret-Dependent Branches In Scalar Reduction

Severity: P1 for the current project scope; P0 for any claim that Ed25519
signing is production-grade constant-time.

Status: fixed at source level on 2026-07-06.

Evidence:

- Previous code compared `acc[idx]` with `mul[k][idx]` using
  `if a > m` / `else if a < m`.
- Previous code branched on `diff < 0` during subtraction.
- `acc` is derived from `h`, and `h` is secret-derived in `ed25519_sign`
  through the deterministic nonce and scalar arithmetic paths.
- Current code uses `byte_gt_mask` / `byte_lt_mask`
  (`src/crypto/ed25519.mbt:60-67`) and arithmetic borrow selection
  (`src/crypto/ed25519.mbt:137-141`).

Impact:

- Functional tests prove the scalar-reduction rewrite preserved RFC behavior.
- Static source review no longer finds the specific CT-001 secret-derived
  branches.
- This still is not a formal constant-time proof: generated JS/Wasm/native code,
  runtime allocation, GC, and CPU behavior remain outside this source audit.

Follow-up before making a production-grade side-channel claim:

1. Add a focused timing smoke test for `reduce_scalar_512` / signing on
   `js`, `wasm-gc`, and native backends.
2. Review generated backend code for reintroduced branches or table lookups.
3. Keep RFC 8032 KAT, Wycheproof, cross-verify, and mutation checks green.

## Non-Goals And Caveats

- This review did not audit `Sha512Ctx` for constant-time behavior.
- This review did not inspect generated JavaScript, WebAssembly, or native
  machine code.
- MoonBit runtime behavior, allocation, GC, integer arithmetic lowering, and
  CPU microarchitecture can still affect timing.
- Dynamic timing checks are still useful, but they are noisy and belong after
  the source-level secret branches are removed.
