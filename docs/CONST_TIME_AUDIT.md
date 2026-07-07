# Ed25519 Constant-Time Audit And Native Timing Evidence

Date: 2026-07-07 Asia/Shanghai

This audit records the source-level control-flow review for the pure MoonBit
Ed25519 implementation plus one reproducible native dudect-style timing
experiment. The current assurance target is an engineering-grade evidence
package for a course/competition Evidence Pack verifier: source review,
independent crypto vectors, mutation/differential testing, and native timing
statistics are combined into one reproducible review trail. Full backend
disassembly review and specialist dudect certification are treated as the next
production-hardening tier, not as a blocker for this release scope.

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

The project may claim source-reviewed constant-time Ed25519 signing logic and
local native timing evidence with no obvious timing difference observed in the
recorded run. The stronger production-grade claim is deliberately separated
into a future certification tier that would include backend lowering review,
runtime behavior review, and specialist dudect analysis.

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
- Generated JS/Wasm/native code, runtime allocation, GC, and CPU behavior are
  intentionally tracked as the next assurance tier beyond this source and
  native-timing release gate.

Production-hardening track:

1. Review generated backend code for reintroduced branches or table lookups.
2. Run a specialist dudect/backend-machine-code campaign if the implementation
   will protect production-value secrets.
3. Keep RFC 8032 KAT, Wycheproof, cross-verify, native timing, and mutation
   checks green.

## Native Timing Evidence

The native timing harness is `src/timing`, driven by
`tools/timing-ed25519-native.ps1`. It directly calls the project's MoonBit
`@crypto.ed25519_verify` and `@crypto.ed25519_sign` implementation; the C stub
only supplies a high-resolution timer and prints native environment data.

Method controls:

- Native release build via MSVC, not a C/C++ reimplementation of Ed25519.
- A/B inputs are same-shape classes and are randomly order-interleaved.
- Warmup samples run before measurement.
- Each timed call contributes to a checksum so the compiler cannot discard it.
- Output includes sample counts, means, variances, Welch t, timer frequency,
  compiler, OS, arch, and CPU identifier.

Recorded long run:

```powershell
powershell -ExecutionPolicy Bypass -File tools/timing-ed25519-native.ps1 -Target both -Samples 50000 -Warmup 1024 -Config release
```

Environment:

- MoonBit: `moon 0.1.20260529 (3e1c753 2026-05-29)`
- Compiler: `D:\software\VStudio2022\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\cl.exe`, native macro `MSVC 1944`
- OS/arch: Windows x86_64
- Timer frequency: `10000000`
- CPU: `Intel64 Family 6 Model 154 Stepping 3, GenuineIntel`

| Target | Samples | Class A mean | Class B mean | Welch t | Assessment |
| --- | ---: | ---: | ---: | ---: | --- |
| `verify` | 50000 | 7872487.156 ns | 7874280.820 ns | -0.147045 | No obvious timing difference observed |
| `sign-message` | 50000 | 8132600.592 ns | 8131544.048 ns | 0.090476 | No obvious timing difference observed |
| `sign-secret` | 50000 | 7752745.632 ns | 7753546.544 ns | -0.040215 | No obvious timing difference observed |

Interpretation: all three recorded targets are comfortably below the common
`|t| >= 4.5` suspicion threshold in this local run. This establishes a
reproducible engineering assurance signal for the recorded
machine/toolchain/build, while leaving cross-toolchain certification to the
production-hardening track above.

## Non-Goals And Caveats

- `Sha512Ctx`, generated JavaScript, WebAssembly, native machine code, runtime
  allocation, GC, integer lowering, and CPU microarchitecture are explicitly
  separated into the production-hardening track.
- The recorded dynamic timing check is a bounded, reproducible assurance
  signal for the recorded native environment and is designed to be rerun when
  the toolchain or target machine changes.
