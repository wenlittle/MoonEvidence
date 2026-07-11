#!/usr/bin/env node

import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const moonMod = readFileSync(join(repoRoot, "moon.mod"), "utf8");
const version = moonMod.match(/^version\s*=\s*"([^"]+)"/m)?.[1];

if (!version) {
  throw new Error("moon.mod does not contain a version");
}

const builtCli = join(
  repoRoot,
  "_build",
  "js",
  "release",
  "build",
  "src",
  "cmd",
  "main",
  "main.js",
);

if (!existsSync(builtCli)) {
  throw new Error(
    `release CLI not found: ${builtCli}\nRun moon build --target js --release src/cmd/main first.`,
  );
}

const artifactRoot = join(repoRoot, "_build", "release-cli");
const folderName = `moon-evidence-cli-js-v${version}`;
const outputDir = join(artifactRoot, folderName);
rmSync(outputDir, { recursive: true, force: true });
mkdirSync(outputDir, { recursive: true });

function copyTree(source, destination) {
  mkdirSync(destination, { recursive: true });
  for (const entry of readdirSync(source)) {
    const from = join(source, entry);
    const to = join(destination, entry);
    const stat = statSync(from);
    if (stat.isDirectory()) {
      copyTree(from, to);
    } else if (stat.isFile()) {
      copyFileSync(from, to);
    } else {
      throw new Error(`unsupported release input: ${from}`);
    }
  }
}

copyFileSync(builtCli, join(outputDir, "moon-evidence.mjs"));
copyFileSync(join(repoRoot, "LICENSE"), join(outputDir, "LICENSE"));
copyTree(
  join(repoRoot, "examples", "valid-pack"),
  join(outputDir, "examples", "valid-pack"),
);

writeFileSync(
  join(outputDir, "moon-evidence.cmd"),
  '@echo off\r\nnode "%~dp0moon-evidence.mjs" %*\r\n',
);
writeFileSync(
  join(outputDir, "moon-evidence"),
  '#!/usr/bin/env sh\nexec node "$(dirname "$0")/moon-evidence.mjs" "$@"\n',
  { mode: 0o755 },
);
writeFileSync(
  join(outputDir, "README.txt"),
  `MoonEvidence CLI v${version}\n\n` +
    "Requirement: Node.js 20 or newer. MoonBit and the source repository are not required.\n\n" +
    "Windows:\n" +
    "  moon-evidence.cmd --version\n" +
    "  moon-evidence.cmd verify examples\\valid-pack\n\n" +
    "Linux/macOS:\n" +
    "  ./moon-evidence --version\n" +
    "  ./moon-evidence verify examples/valid-pack\n\n" +
    "Exit codes: 0 accepted, 1 verification rejected, 2 usage or IO failure.\n",
);

console.log(outputDir);
