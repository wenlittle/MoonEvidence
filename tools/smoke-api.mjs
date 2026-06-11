// Smoke check for the browser adapter, mirroring demo/web/index.html's
// request building (hex-encoded bytes, optional version chain). Run from
// the repository root after `moon build --target js`:
//
//   node tools/smoke-api.mjs
//
// Exit code 0 on pass, 1 on any unexpected verdict.
import { verify_evidence } from "../_build/js/release/build/src/api/api.js";
import { existsSync, readFileSync } from "node:fs";

const hex = (buf) =>
  [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");

function run(pack) {
  const manifest = readFileSync(`examples/${pack}/manifest.json`, "utf8");
  const request = {
    manifest,
    files: {
      "files/a.txt": hex(readFileSync(`examples/${pack}/files/a.txt`)),
      "files/b.bin": hex(readFileSync(`examples/${pack}/files/b.bin`)),
    },
  };
  const chainPath = `examples/${pack}/versions/version_chain.json`;
  if (existsSync(chainPath)) {
    request.version_chain = readFileSync(chainPath, "utf8");
  }
  const response = JSON.parse(verify_evidence(JSON.stringify(request)));
  console.log(
    pack,
    "ok =", response.ok,
    "codes =", JSON.stringify(response.report.findings.map((f) => f.code)),
  );
  return response;
}

const valid = run("valid-pack");
const tampered = run("tampered-pack");
const bad = JSON.parse(verify_evidence("{ not json"));
console.log("malformed request error =", JSON.stringify(bad.error));

if (
  valid.ok === true &&
  tampered.ok === false &&
  tampered.report.findings.some((f) => f.code === "E2003") &&
  bad.ok === false
) {
  console.log("SMOKE PASS");
} else {
  console.log("SMOKE FAIL");
  process.exit(1);
}
