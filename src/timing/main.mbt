// Native Ed25519 timing sampler.
//
// This is a dudect-style engineering probe, not a formal side-channel proof:
// two same-shape input classes are randomly interleaved, timed on the native
// backend, and summarized with Welch's t statistic.

///|
extern "C" fn native_now_ticks() -> Int64 = "moon_evidence_timing_now_ticks"

///|
extern "C" fn native_ticks_per_second() -> Int64 = "moon_evidence_timing_ticks_per_second"

///|
extern "C" fn native_print_env() -> Unit = "moon_evidence_timing_print_native_env"

///|
let default_samples : Int = 10000

///|
let default_warmup : Int = 512

///|
let usage : String =
  #|moon-evidence-native-timing
  #|
  #|Usage:
  #|  moon-evidence-native-timing [--target verify|sign-message|sign-secret|both]
  #|                              [--samples <even-int>] [--warmup <int>]
  #|
  #|Targets:
  #|  verify        Ed25519 verify with two valid public-input classes
  #|  sign-message  Ed25519 sign with fixed secret and two public messages
  #|  sign-secret   Ed25519 sign with two secret-key classes and fixed message
  #|  both          Runs verify, sign-message, and sign-secret

///|
struct Options {
  target : String
  samples : Int
  warmup : Int
}

///|
struct Rng {
  mut state : UInt64
}

///|
fn Rng::make(seed : UInt64) -> Rng {
  { state: seed }
}

///|
fn Rng::next(self : Rng) -> UInt64 {
  self.state = self.state + 0x9E3779B97F4A7C15UL
  let mut z = self.state
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL
  z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL
  z ^ (z >> 31)
}

///|
fn Rng::coin(self : Rng) -> Bool {
  (self.next() & 1UL) == 1UL
}

///|
struct OnlineStats {
  mut count : Int
  mut mean : Double
  mut m2 : Double
}

///|
fn OnlineStats::new() -> OnlineStats {
  { count: 0, mean: 0.0, m2: 0.0 }
}

///|
fn OnlineStats::add(self : OnlineStats, x : Double) -> Unit {
  self.count = self.count + 1
  let delta = x - self.mean
  self.mean = self.mean + delta / self.count.to_double()
  let delta2 = x - self.mean
  self.m2 = self.m2 + delta * delta2
}

///|
fn OnlineStats::variance(self : OnlineStats) -> Double {
  if self.count < 2 {
    0.0
  } else {
    self.m2 / (self.count - 1).to_double()
  }
}

///|
struct TimingResult {
  label : String
  class_a : OnlineStats
  class_b : OnlineStats
  checksum : Int
}

///|
fn parse_positive_int(s : String) -> Int? {
  if s.length() == 0 {
    return None
  }
  let mut value = 0
  for i in 0..<s.length() {
    let c = s[i].to_int()
    if c < 48 || c > 57 {
      return None
    }
    value = value * 10 + (c - 48)
  }
  Some(value)
}

///|
fn parse_options(raw : Array[String]) -> Options? {
  let mut target = "both"
  let mut samples = default_samples
  let mut warmup = default_warmup
  let mut i = 0
  while i < raw.length() {
    let arg = raw[i]
    if arg == "--target" && i + 1 < raw.length() {
      i = i + 1
      target = raw[i]
    } else if arg == "--samples" && i + 1 < raw.length() {
      i = i + 1
      match parse_positive_int(raw[i]) {
        Some(n) => samples = n
        None => return None
      }
    } else if arg == "--warmup" && i + 1 < raw.length() {
      i = i + 1
      match parse_positive_int(raw[i]) {
        Some(n) => warmup = n
        None => return None
      }
    } else if arg == "--help" || arg == "-h" || arg == "help" {
      println(usage)
      return None
    }
    i = i + 1
  }
  if samples < 2 || samples % 2 != 0 || warmup < 0 {
    return None
  }
  match target {
    "verify" | "sign-message" | "sign-secret" | "both" =>
      Some({ target, samples, warmup })
    _ => None
  }
}

///|
fn byte_range(start : Int, count : Int, step : Int) -> Bytes {
  let out : Array[Byte] = []
  for i in 0..<count {
    out.push(((start + i * step) & 0xff).to_byte())
  }
  Bytes::from_array(out)
}

///|
fn checksum_bytes(data : Bytes) -> Int {
  let mut acc = data.length()
  if data.length() > 0 {
    acc = acc + data[0].to_int()
    acc = acc + data[data.length() - 1].to_int()
  }
  acc
}

///|
fn elapsed_ns(
  start_ticks : Int64,
  end_ticks : Int64,
  ticks_per_second : Int64,
) -> Double {
  let delta = end_ticks - start_ticks
  delta.to_double() * 1000000000.0 / ticks_per_second.to_double()
}

///|
fn record_verify(
  pk : Bytes,
  msg : Bytes,
  sig : Bytes,
  ticks_per_second : Int64,
) -> (Double, Int) {
  let start = native_now_ticks()
  let valid = @crypto.ed25519_verify(pk, msg, sig)
  let end = native_now_ticks()
  if !valid {
    println("ERROR: valid signature rejected during timing run")
    @sys.exit(2)
  }
  (elapsed_ns(start, end, ticks_per_second), valid.to_int())
}

///|
fn record_sign(
  sk : Bytes,
  msg : Bytes,
  ticks_per_second : Int64,
) -> (Double, Int) {
  let start = native_now_ticks()
  let sig = @crypto.ed25519_sign(sk, msg)
  let end = native_now_ticks()
  if sig.length() != 64 {
    println("ERROR: signer returned non-64-byte signature")
    @sys.exit(2)
  }
  (elapsed_ns(start, end, ticks_per_second), checksum_bytes(sig))
}

///|
fn run_verify(
  samples : Int,
  warmup : Int,
  rng : Rng,
  ticks_per_second : Int64,
) -> TimingResult {
  let sk = byte_range(0, 32, 1)
  let pk = @crypto.ed25519_public_key(sk)
  let msg_a = byte_range(0, 64, 1)
  let msg_b = byte_range(255, 64, -1)
  let sig_a = @crypto.ed25519_sign(sk, msg_a)
  let sig_b = @crypto.ed25519_sign(sk, msg_b)
  for i in 0..<warmup {
    let _ = if i % 2 == 0 {
      @crypto.ed25519_verify(pk, msg_a, sig_a)
    } else {
      @crypto.ed25519_verify(pk, msg_b, sig_b)
    }
  }
  let a = OnlineStats::new()
  let b = OnlineStats::new()
  let mut checksum = 0
  for _ in 0..<(samples / 2) {
    if rng.coin() {
      let (ta, ca) = record_verify(pk, msg_a, sig_a, ticks_per_second)
      let (tb, cb) = record_verify(pk, msg_b, sig_b, ticks_per_second)
      a.add(ta)
      b.add(tb)
      checksum = checksum + ca + cb
    } else {
      let (tb, cb) = record_verify(pk, msg_b, sig_b, ticks_per_second)
      let (ta, ca) = record_verify(pk, msg_a, sig_a, ticks_per_second)
      b.add(tb)
      a.add(ta)
      checksum = checksum + ca + cb
    }
  }
  { label: "verify", class_a: a, class_b: b, checksum }
}

///|
fn run_sign_message(
  samples : Int,
  warmup : Int,
  rng : Rng,
  ticks_per_second : Int64,
) -> TimingResult {
  let sk = byte_range(0, 32, 1)
  let msg_a = byte_range(17, 64, 3)
  let msg_b = byte_range(203, 64, -5)
  for i in 0..<warmup {
    let _ = if i % 2 == 0 {
      @crypto.ed25519_sign(sk, msg_a)
    } else {
      @crypto.ed25519_sign(sk, msg_b)
    }
  }
  let a = OnlineStats::new()
  let b = OnlineStats::new()
  let mut checksum = 0
  for _ in 0..<(samples / 2) {
    if rng.coin() {
      let (ta, ca) = record_sign(sk, msg_a, ticks_per_second)
      let (tb, cb) = record_sign(sk, msg_b, ticks_per_second)
      a.add(ta)
      b.add(tb)
      checksum = checksum + ca + cb
    } else {
      let (tb, cb) = record_sign(sk, msg_b, ticks_per_second)
      let (ta, ca) = record_sign(sk, msg_a, ticks_per_second)
      b.add(tb)
      a.add(ta)
      checksum = checksum + ca + cb
    }
  }
  { label: "sign-message", class_a: a, class_b: b, checksum }
}

///|
fn run_sign_secret(
  samples : Int,
  warmup : Int,
  rng : Rng,
  ticks_per_second : Int64,
) -> TimingResult {
  let sk_a = byte_range(0, 32, 1)
  let sk_b = byte_range(131, 32, 7)
  let msg = byte_range(41, 64, 9)
  for i in 0..<warmup {
    let _ = if i % 2 == 0 {
      @crypto.ed25519_sign(sk_a, msg)
    } else {
      @crypto.ed25519_sign(sk_b, msg)
    }
  }
  let a = OnlineStats::new()
  let b = OnlineStats::new()
  let mut checksum = 0
  for _ in 0..<(samples / 2) {
    if rng.coin() {
      let (ta, ca) = record_sign(sk_a, msg, ticks_per_second)
      let (tb, cb) = record_sign(sk_b, msg, ticks_per_second)
      a.add(ta)
      b.add(tb)
      checksum = checksum + ca + cb
    } else {
      let (tb, cb) = record_sign(sk_b, msg, ticks_per_second)
      let (ta, ca) = record_sign(sk_a, msg, ticks_per_second)
      b.add(tb)
      a.add(ta)
      checksum = checksum + ca + cb
    }
  }
  { label: "sign-secret", class_a: a, class_b: b, checksum }
}

///|
fn welch_t(a : OnlineStats, b : OnlineStats) -> Double {
  let denom = (a.variance() / a.count.to_double() +
  b.variance() / b.count.to_double()).sqrt()
  if denom == 0.0 {
    0.0
  } else {
    (a.mean - b.mean) / denom
  }
}

///|
fn print_result(result : TimingResult) -> Unit {
  let a = result.class_a
  let b = result.class_b
  let t = welch_t(a, b)
  println("target: \{result.label}")
  println("samples_total: \{a.count + b.count}")
  println("samples_class_a: \{a.count}")
  println("samples_class_b: \{b.count}")
  println("class_a_mean_ns: \{a.mean}")
  println("class_a_variance_ns2: \{a.variance()}")
  println("class_b_mean_ns: \{b.mean}")
  println("class_b_variance_ns2: \{b.variance()}")
  println("welch_t: \{t}")
  println("checksum: \{result.checksum}")
  if t < -4.5 || t > 4.5 {
    println(
      "timing_assessment: suspicious |t| >= 4.5; rerun and inspect before making any claim",
    )
  } else {
    println(
      "timing_assessment: no obvious timing difference observed in this run (not a proof)",
    )
  }
}

///|
fn main {
  guard parse_options(@env.args()) is Some(opts) else {
    println(usage)
    @sys.exit(2)
    return
  }
  let ticks_per_second = native_ticks_per_second()
  println("moon_evidence_native_timing: Ed25519 dudect-style sampler")
  println("samples_requested: \{opts.samples}")
  println("warmup_requested: \{opts.warmup}")
  println("target_requested: \{opts.target}")
  native_print_env()
  let rng = Rng::make(0x6d6f6f6e2d74696dUL) // "moon-tim"
  match opts.target {
    "verify" =>
      print_result(run_verify(opts.samples, opts.warmup, rng, ticks_per_second))
    "sign-message" =>
      print_result(
        run_sign_message(opts.samples, opts.warmup, rng, ticks_per_second),
      )
    "sign-secret" =>
      print_result(
        run_sign_secret(opts.samples, opts.warmup, rng, ticks_per_second),
      )
    _ => {
      print_result(run_verify(opts.samples, opts.warmup, rng, ticks_per_second))
      print_result(
        run_sign_message(opts.samples, opts.warmup, rng, ticks_per_second),
      )
      print_result(
        run_sign_secret(opts.samples, opts.warmup, rng, ticks_per_second),
      )
    }
  }
  println(
    "TIMING NATIVE PASS: functional checks passed; interpret Welch t as local empirical evidence, not a formal side-channel proof",
  )
}
