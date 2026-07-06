// Lightweight Ed25519 verify timing sampler for the compiled JS API.
//
// This is not a dudect proof and it is not a CI gate. It is a repeatable
// release-audit probe that compares two same-shape valid verification classes
// and reports Welch's t statistic so timing drift is visible in RESULTS_LOG.
//
// Run after:
//   moon build --target js --release src/api
//
// Example:
//   node tools/timing-ed25519-verify.mjs --samples 10000
import { performance } from "node:perf_hooks";
import {
  ed25519_keypair,
  ed25519_sign,
  ed25519_verify,
} from "../_build/js/release/build/src/api/api.js";

function parseArgs(argv) {
  let samples = 10000;
  let warmup = 256;
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--samples" && i + 1 < argv.length) {
      samples = Number.parseInt(argv[++i], 10);
    } else if (argv[i] === "--warmup" && i + 1 < argv.length) {
      warmup = Number.parseInt(argv[++i], 10);
    } else {
      throw new Error(`unknown argument: ${argv[i]}`);
    }
  }
  if (!Number.isInteger(samples) || samples < 2 || samples % 2 !== 0) {
    throw new Error("--samples must be an even integer >= 2");
  }
  if (!Number.isInteger(warmup) || warmup < 0) {
    throw new Error("--warmup must be a non-negative integer");
  }
  return { samples, warmup };
}

function hex(bytes) {
  return [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function call(fn, request, label) {
  const parsed = JSON.parse(fn(JSON.stringify(request)));
  if (parsed === null || typeof parsed !== "object" || parsed.ok !== true) {
    throw new Error(`${label} failed: ${JSON.stringify(parsed)}`);
  }
  return parsed;
}

function mean(values) {
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

function variance(values, avg) {
  if (values.length < 2) return 0;
  let total = 0;
  for (const value of values) {
    const delta = value - avg;
    total += delta * delta;
  }
  return total / (values.length - 1);
}

function stats(values) {
  const avg = mean(values);
  return { mean: avg, variance: variance(values, avg), count: values.length };
}

const { samples, warmup } = parseArgs(process.argv.slice(2));

const keypair = call(ed25519_keypair, {
  seed: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f",
}, "keypair");
const messageA = hex(new Uint8Array(64).map((_, i) => i));
const messageB = hex(new Uint8Array(64).map((_, i) => 255 - i));
const signatureA = call(ed25519_sign, {
  secret_key: keypair.secret_key,
  message: messageA,
}, "sign A").signature;
const signatureB = call(ed25519_sign, {
  secret_key: keypair.secret_key,
  message: messageB,
}, "sign B").signature;

const requestA = {
  public_key: keypair.public_key,
  message: messageA,
  signature: signatureA,
};
const requestB = {
  public_key: keypair.public_key,
  message: messageB,
  signature: signatureB,
};

function verifyTimed(request) {
  const start = performance.now();
  const response = call(ed25519_verify, request, "verify");
  const elapsed = performance.now() - start;
  if (response.valid !== true) {
    throw new Error(`valid signature rejected: ${JSON.stringify(response)}`);
  }
  return elapsed;
}

for (let i = 0; i < warmup; i++) {
  verifyTimed(i % 2 === 0 ? requestA : requestB);
}

const classA = [];
const classB = [];
for (let i = 0; i < samples; i++) {
  if (i % 2 === 0) {
    classA.push(verifyTimed(requestA));
  } else {
    classB.push(verifyTimed(requestB));
  }
}

const a = stats(classA);
const b = stats(classB);
const denominator = Math.sqrt(a.variance / a.count + b.variance / b.count);
const t = denominator === 0 ? 0 : (a.mean - b.mean) / denominator;

console.log(`ed25519 verify timing samples: ${samples} total (${a.count}/${b.count})`);
console.log(`class A mean ms: ${a.mean.toFixed(6)} variance: ${a.variance.toExponential(6)}`);
console.log(`class B mean ms: ${b.mean.toFixed(6)} variance: ${b.variance.toExponential(6)}`);
console.log(`welch_t: ${t.toFixed(6)}`);
console.log("TIMING SAMPLE PASS: functional checks passed; interpret t-statistic as informational, not a side-channel proof");
