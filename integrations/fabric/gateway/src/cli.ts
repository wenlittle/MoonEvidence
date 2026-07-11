#!/usr/bin/env node

import { resolve } from "node:path";

import {
  queryAnchor,
  submitAnchor,
  type ContractClient,
} from "./anchor.js";
import { assertCanonicalDigest } from "./digest.js";
import { FabricAdapterError } from "./errors.js";
import { connectFabric } from "./gateway.js";
import {
  inspectMoonPack,
  resolveMoonCli,
  verifyMoonPack,
} from "./moon-cli.js";
import { loadFabricProfile } from "./profile.js";

const usage = [
  "me-fabric - MoonEvidence Hyperledger Fabric adapter",
  "",
  "Usage:",
  "  me-fabric anchor --profile <json> --manifest-digest <digest> [--json]",
  "  me-fabric query --profile <json> --manifest-digest <digest> [--json]",
  "  me-fabric anchor-pack <pack> --profile <json> [--moon-cli <path>] [--json]",
  "  me-fabric verify-anchor <pack> --profile <json>",
  "                          --manifest-digest <digest>",
  "                          [--moon-cli <path>] [--json]",
  "",
  "Exit codes: 0 success, 1 local evidence rejected, 2 usage/network/IO error",
].join("\n");

interface ParsedArguments {
  command: string;
  json: boolean;
  options: Map<string, string>;
  positionals: string[];
}

const valueOptions = new Set([
  "--profile",
  "--manifest-digest",
  "--moon-cli",
]);

function parseArguments(argv: string[]): ParsedArguments {
  const command = argv[0] ?? "help";
  const options = new Map<string, string>();
  const positionals: string[] = [];
  let json = false;
  for (let index = 1; index < argv.length; index++) {
    const arg = argv[index];
    if (arg === "--json") {
      json = true;
    } else if (arg && valueOptions.has(arg)) {
      const value = argv[index + 1];
      if (!value) {
        throw new FabricAdapterError(
          "INVALID_ARGUMENTS",
          arg + " requires a value",
        );
      }
      options.set(arg, value);
      index++;
    } else if (arg?.startsWith("-")) {
      throw new FabricAdapterError(
        "INVALID_ARGUMENTS",
        "unknown option " + arg,
      );
    } else if (arg) {
      positionals.push(arg);
    }
  }
  return { command, json, options, positionals };
}

function requiredOption(args: ParsedArguments, name: string): string {
  const value = args.options.get(name);
  if (!value) {
    throw new FabricAdapterError(
      "INVALID_ARGUMENTS",
      name + " is required",
    );
  }
  return value;
}

function emit(value: unknown, json: boolean): void {
  if (json) {
    process.stdout.write(JSON.stringify(value) + "\n");
  } else {
    process.stdout.write(JSON.stringify(value, null, 2) + "\n");
  }
}

function emitError(error: unknown, json: boolean): void {
  const normalized =
    error instanceof FabricAdapterError
      ? error
      : new FabricAdapterError(
          "FABRIC_OPERATION_FAILED",
          error instanceof Error ? error.message : String(error),
        );
  const envelope = {
    schema: "moon-evidence-fabric-error/v1",
    ok: false,
    error: {
      code: normalized.code,
      message: normalized.message,
      ...(normalized.details ? { details: normalized.details } : {}),
    },
  };
  if (json) {
    process.stdout.write(JSON.stringify(envelope) + "\n");
  } else {
    process.stderr.write(
      "[" + normalized.code + "] " + normalized.message + "\n",
    );
  }
}

async function withContract<T>(
  profilePath: string,
  action: (contract: ContractClient) => Promise<T>,
): Promise<T> {
  const profile = loadFabricProfile(profilePath);
  const session = await connectFabric(profile);
  try {
    return await action(session.contract);
  } finally {
    session.close();
  }
}

async function run(args: ParsedArguments): Promise<number> {
  if (
    args.command === "help" ||
    args.command === "--help" ||
    args.command === "-h"
  ) {
    process.stdout.write(usage + "\n");
    return 0;
  }

  const profilePath = requiredOption(args, "--profile");
  if (args.command === "anchor") {
    const digest = requiredOption(args, "--manifest-digest");
    assertCanonicalDigest(digest);
    const receipt = await withContract(profilePath, (contract) =>
      submitAnchor(contract, digest),
    );
    emit(receipt, args.json);
    return 0;
  }

  if (args.command === "query") {
    const digest = requiredOption(args, "--manifest-digest");
    assertCanonicalDigest(digest);
    const anchor = await withContract(profilePath, (contract) =>
      queryAnchor(contract, digest),
    );
    emit(
      {
        schema: "moon-evidence-fabric-query/v1",
        ok: true,
        manifest_digest: digest,
        anchor,
      },
      args.json,
    );
    return 0;
  }

  if (args.command === "anchor-pack") {
    const packPath = args.positionals[0];
    if (!packPath || args.positionals.length !== 1) {
      throw new FabricAdapterError(
        "INVALID_ARGUMENTS",
        "anchor-pack requires exactly one pack path",
      );
    }
    const moonCli = resolveMoonCli(args.options.get("--moon-cli"));
    const inspected = inspectMoonPack(moonCli, resolve(packPath));
    const verified = verifyMoonPack(
      moonCli,
      resolve(packPath),
      inspected.manifest_digest,
    );
    if (!verified.report.ok) {
      emit(
        {
          schema: "moon-evidence-anchor-pack/v1",
          ok: false,
          stage: "local_verify",
          manifest_digest: inspected.manifest_digest,
          report: verified.report,
        },
        args.json,
      );
      return 1;
    }
    const receipt = await withContract(profilePath, (contract) =>
      submitAnchor(contract, inspected.manifest_digest),
    );
    emit(
      {
        schema: "moon-evidence-anchor-pack/v1",
        ok: true,
        local_verification: verified.report,
        inspect: inspected,
        receipt,
      },
      args.json,
    );
    return 0;
  }

  if (args.command === "verify-anchor") {
    const packPath = args.positionals[0];
    if (!packPath || args.positionals.length !== 1) {
      throw new FabricAdapterError(
        "INVALID_ARGUMENTS",
        "verify-anchor requires exactly one pack path",
      );
    }
    const digest = requiredOption(args, "--manifest-digest");
    assertCanonicalDigest(digest);
    const anchor = await withContract(profilePath, (contract) =>
      queryAnchor(contract, digest),
    );
    const moonCli = resolveMoonCli(args.options.get("--moon-cli"));
    const verified = verifyMoonPack(moonCli, resolve(packPath), digest);
    emit(
      {
        schema: "moon-evidence-anchored-verification/v1",
        ok: verified.report.ok,
        manifest_digest: digest,
        anchor,
        report: verified.report,
      },
      args.json,
    );
    return verified.report.ok ? 0 : 1;
  }

  throw new FabricAdapterError(
    "INVALID_ARGUMENTS",
    "unknown command " + args.command,
  );
}

let parsed: ParsedArguments | undefined;
try {
  parsed = parseArguments(process.argv.slice(2));
  process.exitCode = await run(parsed);
} catch (error) {
  emitError(error, parsed?.json ?? process.argv.includes("--json"));
  if (!(parsed?.json ?? process.argv.includes("--json"))) {
    process.stderr.write(usage + "\n");
  }
  process.exitCode = 2;
}
