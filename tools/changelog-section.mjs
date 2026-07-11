#!/usr/bin/env node

import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const changelog = readFileSync(join(repoRoot, "CHANGELOG.md"), "utf8");
const first = changelog.search(/^## \[\d+\.\d+\.\d+\]/m);

if (first < 0) {
  throw new Error("CHANGELOG.md has no release section");
}

const remaining = changelog.slice(first);
const nextMatch = remaining.slice(3).match(/^## \[\d+\.\d+\.\d+\]/m);
const end = nextMatch ? 3 + (nextMatch.index ?? remaining.length) : remaining.length;
process.stdout.write(`${remaining.slice(0, end).trim()}\n`);
