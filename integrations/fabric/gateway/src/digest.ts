import { FabricAdapterError } from "./errors.js";

const canonicalDigest =
  /^(sha256:[0-9a-f]{64}|sha512:[0-9a-f]{128})$/;

export function assertCanonicalDigest(value: string): void {
  if (!canonicalDigest.test(value)) {
    throw new FabricAdapterError(
      "INVALID_MANIFEST_DIGEST",
      "manifest digest must be canonical sha256:<64 lowercase hex> or sha512:<128 lowercase hex>",
    );
  }
}
