import { existsSync, readFileSync, statSync } from "node:fs";
import { dirname, isAbsolute, resolve } from "node:path";

import { FabricAdapterError } from "./errors.js";
import type { FabricProfile } from "./types.js";

type JsonObject = Record<string, unknown>;

const defaultTimeouts = {
  evaluate: 5_000,
  endorse: 15_000,
  submit: 5_000,
  commit_status: 60_000,
};

function requiredString(object: JsonObject, key: string): string {
  const value = object[key];
  if (typeof value !== "string" || value.length === 0) {
    throw new FabricAdapterError(
      "INVALID_PROFILE",
      "profile field \"" + key + "\" must be a non-empty string",
    );
  }
  return value;
}

function resolveFile(profilePath: string, value: string, key: string): string {
  const path = isAbsolute(value)
    ? value
    : resolve(dirname(profilePath), value);
  if (!existsSync(path) || !statSync(path).isFile()) {
    throw new FabricAdapterError(
      "PROFILE_FILE_NOT_FOUND",
      "profile field \"" + key + "\" does not point to a file",
      { path },
    );
  }
  return path;
}

function positiveTimeout(
  object: JsonObject | undefined,
  key: keyof FabricProfile["timeouts_ms"],
): number {
  const value = object?.[key];
  if (value === undefined) {
    return defaultTimeouts[key];
  }
  if (typeof value !== "number" || !Number.isInteger(value) || value <= 0) {
    throw new FabricAdapterError(
      "INVALID_PROFILE",
      "profile timeout \"" + key + "\" must be a positive integer",
    );
  }
  return value;
}

export function loadFabricProfile(inputPath: string): FabricProfile {
  const profilePath = resolve(inputPath);
  let parsed: unknown;
  try {
    parsed = JSON.parse(readFileSync(profilePath, "utf8"));
  } catch (error) {
    throw new FabricAdapterError(
      "INVALID_PROFILE",
      "profile is not readable JSON",
      { path: profilePath, cause: String(error) },
    );
  }
  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new FabricAdapterError(
      "INVALID_PROFILE",
      "profile must be a JSON object",
    );
  }
  const object = parsed as JsonObject;
  if (object.schema !== "moon-evidence-fabric-profile/v1") {
    throw new FabricAdapterError(
      "INVALID_PROFILE",
      "unsupported profile schema",
    );
  }
  let timeouts: JsonObject | undefined;
  if (object.timeouts_ms !== undefined) {
    if (
      object.timeouts_ms === null ||
      typeof object.timeouts_ms !== "object" ||
      Array.isArray(object.timeouts_ms)
    ) {
      throw new FabricAdapterError(
        "INVALID_PROFILE",
        "profile field \"timeouts_ms\" must be an object",
      );
    }
    timeouts = object.timeouts_ms as JsonObject;
  }
  return {
    schema: "moon-evidence-fabric-profile/v1",
    channel: requiredString(object, "channel"),
    chaincode: requiredString(object, "chaincode"),
    msp_id: requiredString(object, "msp_id"),
    peer_endpoint: requiredString(object, "peer_endpoint"),
    peer_host_alias: requiredString(object, "peer_host_alias"),
    tls_certificate_path: resolveFile(
      profilePath,
      requiredString(object, "tls_certificate_path"),
      "tls_certificate_path",
    ),
    certificate_path: resolveFile(
      profilePath,
      requiredString(object, "certificate_path"),
      "certificate_path",
    ),
    private_key_path: resolveFile(
      profilePath,
      requiredString(object, "private_key_path"),
      "private_key_path",
    ),
    timeouts_ms: {
      evaluate: positiveTimeout(timeouts, "evaluate"),
      endorse: positiveTimeout(timeouts, "endorse"),
      submit: positiveTimeout(timeouts, "submit"),
      commit_status: positiveTimeout(timeouts, "commit_status"),
    },
  };
}
