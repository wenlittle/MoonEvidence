// Run the randomized API/differential hardening suite with named round-count
// profiles. This makes the difference between CI, release-candidate, and
// stress sampling explicit instead of scattering ad-hoc `--rounds` values.
//
// Examples:
//   node tools/randomized-hardening.mjs --profile ci --skip-build
//   node tools/randomized-hardening.mjs --profile release
//   node tools/randomized-hardening.mjs --profile stress --dry-run
import { spawnSync } from "node:child_process";

const profiles = {
  ci: {
    malformed: 64,
    semantic: 16,
    crypto: 64,
    digest: 64,
  },
  release: {
    malformed: 1000,
    semantic: 256,
    crypto: 1000,
    digest: 1000,
  },
  stress: {
    malformed: 10000,
    semantic: 1000,
    crypto: 5000,
    digest: 5000,
  },
};

function parseArgs(argv) {
  const opts = {
    profile: "ci",
    skipBuild: false,
    dryRun: false,
    overrides: {},
  };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--profile" && i + 1 < argv.length) {
      opts.profile = argv[++i];
    } else if (arg === "--skip-build") {
      opts.skipBuild = true;
    } else if (arg === "--dry-run") {
      opts.dryRun = true;
    } else if (arg.startsWith("--") && i + 1 < argv.length) {
      const key = arg.slice(2);
      if (["malformed", "semantic", "crypto", "digest"].includes(key)) {
        const value = Number.parseInt(argv[++i], 10);
        if (!Number.isInteger(value) || value < 1) {
          throw new Error(`${arg} must be a positive integer`);
        }
        opts.overrides[key] = value;
      } else {
        throw new Error(`unknown argument: ${arg}`);
      }
    } else {
      throw new Error(`unknown argument: ${arg}`);
    }
  }
  if (!Object.hasOwn(profiles, opts.profile)) {
    throw new Error(`unknown profile ${opts.profile}; expected ${Object.keys(profiles).join(", ")}`);
  }
  return opts;
}

function run(command, args, dryRun) {
  const rendered = [command, ...args].join(" ");
  console.log(`$ ${rendered}`);
  if (dryRun) return;
  const result = spawnSync(command, args, {
    stdio: "inherit",
  });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

const opts = parseArgs(process.argv.slice(2));
const rounds = { ...profiles[opts.profile], ...opts.overrides };

console.log(`randomized-hardening profile=${opts.profile}`);
console.log(JSON.stringify(rounds, null, 2));

if (!opts.skipBuild) {
  run("moon", ["build", "--target", "js", "--release", "src/api"], opts.dryRun);
}

run("node", ["tools/fuzz-api-malformed.mjs", "--rounds", String(rounds.malformed)], opts.dryRun);
run("node", ["tools/property-api-semantic.mjs", "--rounds", String(rounds.semantic)], opts.dryRun);
run("node", ["tools/differential-crypto.mjs", "--rounds", String(rounds.crypto)], opts.dryRun);
run("node", ["tools/differential-digest.mjs", "--rounds", String(rounds.digest)], opts.dryRun);

console.log(`randomized-hardening PASS profile=${opts.profile}`);
