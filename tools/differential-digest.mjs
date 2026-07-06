// Differential digest checks against Node.js crypto.
//
// This compares the compiled MoonBit JS API with Node's independent crypto
// implementation over deterministic random inputs and padding-boundary sizes.
//
// Usage:
//   moon build --target js
//   node tools/differential-digest.mjs
//   node tools/differential-digest.mjs --rounds 1000

import { createHash, createHmac } from "node:crypto";
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

const request = (fn, body) => JSON.parse(fn(JSON.stringify(body)));

let rngState = 0x6469676573746f72n;
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

const boundaryLengths = [
  0, 1, 2, 3, 7, 15, 31, 32, 33, 55, 56, 57, 63, 64, 65, 111, 112, 113,
  127, 128, 129, 255, 256, 257, 511, 512, 513, 1023, 1024, 4096, 65536,
];

const lengthForRound = (round) => {
  if (round < boundaryLengths.length) return boundaryLengths[round];
  const word = next64();
  return Number(word % 65537n);
};

const nodeDigest = (algorithm, data, key) => {
  if (algorithm === "hmac-sha256") {
    return createHmac("sha256", key).update(data).digest("hex");
  }
  return createHash(algorithm).update(data).digest("hex");
};

const main = async () => {
  const { rounds } = parseArgs(process.argv.slice(2));
  if (!existsSync(apiPath)) {
    throw new Error("JS artifact not found; run `moon build --target js` first");
  }

  const { digest_compute } = await import(pathToFileURL(apiPath).href);

  const algorithms = ["sha256", "sha512", "hmac-sha256"];
  let failures = 0;
  for (let round = 0; round < rounds; round += 1) {
    const data = randomBytes(lengthForRound(round));
    const key = randomBytes(round % 2 === 0 ? round % 129 : lengthForRound(round + 11));

    for (const algorithm of algorithms) {
      const body = { algorithm, data: hex(data) };
      if (algorithm === "hmac-sha256") body.key = hex(key);

      const moon = request(digest_compute, body);
      const expected = nodeDigest(algorithm, data, key);

      if (moon.ok !== true || moon.digest !== expected) {
        failures += 1;
        console.log(`FAIL round ${round}: ${algorithm}`);
        console.log(`  data_len=${data.length}`);
        console.log(`  key_len=${key.length}`);
        console.log(`  data=${hex(data)}`);
        console.log(`  key=${hex(key)}`);
        console.log(`  node=${expected}`);
        console.log(`  moon=${moon.digest}`);
        break;
      }
    }
  }

  if (failures > 0) {
    console.log(`differential-digest: ${failures} failure(s) over ${rounds} rounds`);
    process.exit(1);
  }
  console.log(
    `differential-digest: ${rounds}/${rounds} rounds matched Node.js crypto for SHA-256, SHA-512, and HMAC-SHA256`,
  );
};

main().catch((error) => {
  console.error(`differential-digest: ${error.message}`);
  process.exit(1);
});
