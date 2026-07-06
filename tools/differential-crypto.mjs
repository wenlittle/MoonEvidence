// Differential crypto checks against Node.js crypto.
//
// This is intentionally outside the MoonBit test runner: it compares the
// compiled JS API artifact with an independent implementation from Node.
//
// Usage:
//   moon build --target js
//   node tools/differential-crypto.mjs
//   node tools/differential-crypto.mjs --rounds 1000

import {
  createPrivateKey,
  createPublicKey,
  sign as nodeSign,
  verify as nodeVerify,
} from "node:crypto";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const repoRoot = join(fileURLToPath(new URL(".", import.meta.url)), "..");
const apiPath = join(repoRoot, "_build", "js", "release", "build", "src", "api", "api.js");

const parseArgs = (argv) => {
  let rounds = 64;
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === "--rounds" && i + 1 < argv.length) {
      rounds = Number.parseInt(argv[i + 1], 10);
      i += 1;
    }
  }
  if (!Number.isInteger(rounds) || rounds <= 0) {
    throw new Error("--rounds must be a positive integer");
  }
  return { rounds };
};

const hex = (buf) =>
  [...buf].map((b) => b.toString(16).padStart(2, "0")).join("");

const fromHex = (s) => Buffer.from(s, "hex");

const request = (fn, body) => JSON.parse(fn(JSON.stringify(body)));

// SplitMix64 gives deterministic, reproducible bytes without adding deps.
let rngState = 0x6d6f6f6e65766964n;
const next64 = () => {
  rngState = (rngState + 0x9e3779b97f4a7c15n) & 0xffffffffffffffffn;
  let z = rngState;
  z = ((z ^ (z >> 30n)) * 0xbf58476d1ce4e5b9n) & 0xffffffffffffffffn;
  z = ((z ^ (z >> 27n)) * 0x94d049bb133111ebn) & 0xffffffffffffffffn;
  return (z ^ (z >> 31n)) & 0xffffffffffffffffn;
};

const randomBytes = (length) => {
  const out = Buffer.alloc(length);
  let word = 0n;
  for (let i = 0; i < length; i += 1) {
    if (i % 8 === 0) word = next64();
    out[i] = Number((word >> BigInt((i % 8) * 8)) & 0xffn);
  }
  return out;
};

const ed25519PrivateKeyFromSeed = (seed) =>
  createPrivateKey({
    key: Buffer.concat([
      Buffer.from("302e020100300506032b657004220420", "hex"),
      seed,
    ]),
    format: "der",
    type: "pkcs8",
  });

const rawPublicKey = (privateKey) => {
  const spki = createPublicKey(privateKey).export({ format: "der", type: "spki" });
  return Buffer.from(spki).subarray(-32);
};

const main = async () => {
  const { rounds } = parseArgs(process.argv.slice(2));
  if (!existsSync(apiPath)) {
    throw new Error("JS artifact not found; run `moon build --target js` first");
  }

  const {
    ed25519_keypair,
    ed25519_sign,
    ed25519_verify,
  } = await import(pathToFileURL(apiPath).href);

  let failures = 0;
  for (let i = 0; i < rounds; i += 1) {
    const seed = randomBytes(32);
    const msg = randomBytes(i % 257);
    const nodeSk = ed25519PrivateKeyFromSeed(seed);
    const nodePk = rawPublicKey(nodeSk);
    const nodeSig = nodeSign(null, msg, nodeSk);

    const moonKp = request(ed25519_keypair, { seed: hex(seed) });
    const moonSig = request(ed25519_sign, {
      secret_key: hex(seed),
      message: hex(msg),
    });

    const checks = [
      ["keypair ok", moonKp.ok === true],
      ["public key matches Node", moonKp.public_key === hex(nodePk)],
      ["sign ok", moonSig.ok === true],
      ["signature matches Node", moonSig.signature === hex(nodeSig)],
      [
        "Node accepts Moon signature",
        nodeVerify(null, msg, createPublicKey(nodeSk), fromHex(moonSig.signature || "")),
      ],
      [
        "Moon accepts Node signature",
        request(ed25519_verify, {
          public_key: hex(nodePk),
          message: hex(msg),
          signature: hex(nodeSig),
        }).valid === true,
      ],
    ];

    if (msg.length > 0) {
      const tampered = Buffer.from(msg);
      tampered[0] ^= 1;
      checks.push([
        "Moon rejects tampered message",
        request(ed25519_verify, {
          public_key: hex(nodePk),
          message: hex(tampered),
          signature: hex(nodeSig),
        }).valid === false,
      ]);
    }

    for (const [label, ok] of checks) {
      if (!ok) {
        failures += 1;
        console.log(`FAIL round ${i}: ${label}`);
        console.log(`  seed=${hex(seed)}`);
        console.log(`  msg=${hex(msg)}`);
        console.log(`  node_pk=${hex(nodePk)}`);
        console.log(`  moon_pk=${moonKp.public_key}`);
        console.log(`  node_sig=${hex(nodeSig)}`);
        console.log(`  moon_sig=${moonSig.signature}`);
        break;
      }
    }
  }

  if (failures > 0) {
    console.log(`differential-crypto: ${failures} failure(s) over ${rounds} rounds`);
    process.exit(1);
  }
  console.log(`differential-crypto: ${rounds}/${rounds} Ed25519 vectors matched Node.js crypto`);
};

main().catch((error) => {
  console.error(`differential-crypto: ${error.message}`);
  process.exit(1);
});
