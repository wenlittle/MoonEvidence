import type {
  EvidenceManifest,
  EvidenceScenario,
  TreeResponse,
  VerifyResponse,
  WorkerMethod,
  WorkerResponse,
} from "./types";
import { buildVerifyEvidenceRequest } from "./verify-request";

class MoonRpc {
  private worker = new Worker(new URL("./workers/moon.worker.ts", import.meta.url), {
    type: "module",
  });

  private nextId = 1;
  private pending = new Map<
    number,
    { resolve: (value: string) => void; reject: (reason: Error) => void }
  >();

  constructor() {
    this.worker.onmessage = (event: MessageEvent<WorkerResponse>) => {
      const response = event.data;
      const request = this.pending.get(response.id);
      if (!request) return;
      this.pending.delete(response.id);
      if (response.ok && typeof response.result === "string") {
        request.resolve(response.result);
      } else {
        request.reject(new Error(response.error ?? "MoonBit worker failed"));
      }
    };
    this.worker.onerror = (event) => {
      const error = new Error(event.message || "MoonBit worker crashed");
      for (const request of this.pending.values()) request.reject(error);
      this.pending.clear();
    };
  }

  call<T>(method: WorkerMethod, payload: object): Promise<T> {
    const id = this.nextId++;
    return new Promise<T>((resolve, reject) => {
      this.pending.set(id, {
        resolve: (result) => {
          try {
            resolve(JSON.parse(result) as T);
          } catch (error) {
            reject(error instanceof Error ? error : new Error(String(error)));
          }
        },
        reject,
      });
      this.worker.postMessage({ id, method, payload: JSON.stringify(payload) });
    });
  }
}

const rpc = new MoonRpc();

export function callMoon<T>(method: WorkerMethod, payload: object): Promise<T> {
  return rpc.call<T>(method, payload);
}

export function toHex(bytes: Uint8Array): string {
  let output = "";
  for (const byte of bytes) output += byte.toString(16).padStart(2, "0");
  return output;
}

function fromHex(hex: string): Uint8Array {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.length; i += 1) {
    bytes[i] = Number.parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return bytes;
}

function stripDigestPrefix(value: string): string {
  const separator = value.indexOf(":");
  return separator >= 0 ? value.slice(separator + 1) : value;
}

type DigestResponse = { ok: boolean; digest: string; error?: string };
type KeypairResponse = { ok: boolean; public_key: string; secret_key: string };
type SignatureResponse = { ok: boolean; signature: string };
type SignatureVerifyResponse = { ok: boolean; valid: boolean };

export async function buildEvidenceScenario(): Promise<EvidenceScenario> {
  const manifestResponse = await fetch("./packs/valid-pack/manifest.json");
  if (!manifestResponse.ok) throw new Error("Unable to load the built-in manifest");
  const manifestText = await manifestResponse.text();
  const manifest = JSON.parse(manifestText) as EvidenceManifest;
  const versionChainResponse = await fetch("./packs/valid-pack/versions/version_chain.json");
  const versionChainText = versionChainResponse.ok ? await versionChainResponse.text() : null;

  const originalFiles: Record<string, string> = {};
  for (const entry of manifest.files) {
    const response = await fetch(`./packs/valid-pack/${entry.path}`);
    if (!response.ok) throw new Error(`Unable to load ${entry.path}`);
    originalFiles[entry.path] = toHex(new Uint8Array(await response.arrayBuffer()));
  }

  const tamperedPath = manifest.files.find((entry) => entry.size > 0)?.path ?? manifest.files[0].path;
  const changedBytes = fromHex(originalFiles[tamperedPath]);
  const changedByte = Math.max(0, Math.floor(changedBytes.length / 2));
  if (changedBytes.length > 0) changedBytes[changedByte] ^= 0x20;
  const tamperedFiles = { ...originalFiles, [tamperedPath]: toHex(changedBytes) };

  const digestResponses = await Promise.all(
    manifest.files.map(async (entry) => {
      const original = await rpc.call<DigestResponse>("digest_compute", {
        algorithm: manifest.hash_algorithm,
        data: originalFiles[entry.path],
      });
      const tampered = await rpc.call<DigestResponse>("digest_compute", {
        algorithm: manifest.hash_algorithm,
        data: tamperedFiles[entry.path],
      });
      if (!original.ok || !tampered.ok) throw new Error("Digest computation failed");
      return { path: entry.path, original: original.digest, tampered: tampered.digest };
    }),
  );

  const tamperedManifest = structuredClone(manifest);
  const changedEntry = tamperedManifest.files.find((entry) => entry.path === tamperedPath);
  const changedDigest = digestResponses.find((entry) => entry.path === tamperedPath);
  if (!changedEntry || !changedDigest) throw new Error("Tampered file is missing from manifest");
  if (changedDigest.original === changedDigest.tampered) {
    throw new Error("Tampered file digest did not diverge");
  }
  changedEntry.digest = `${manifest.hash_algorithm}:${changedDigest.tampered}`;
  changedEntry.size = changedBytes.length;
  const tamperedManifestText = JSON.stringify(tamperedManifest);

  const [originalTreeResponse, tamperedTreeResponse, validVerification, tamperedVerification] =
    await Promise.all([
      rpc.call<TreeResponse>("compute_merkle_tree", {
        manifest: manifestText,
        files: originalFiles,
      }),
      rpc.call<TreeResponse>("compute_merkle_tree", {
        manifest: tamperedManifestText,
        files: tamperedFiles,
      }),
      rpc.call<VerifyResponse>(
        "verify_evidence",
        buildVerifyEvidenceRequest(manifestText, originalFiles, versionChainText),
      ),
      rpc.call<VerifyResponse>(
        "verify_evidence",
        buildVerifyEvidenceRequest(manifestText, tamperedFiles, versionChainText),
      ),
    ]);

  if (!originalTreeResponse.ok || !tamperedTreeResponse.ok) {
    throw new Error(originalTreeResponse.error ?? tamperedTreeResponse.error ?? "Tree build failed");
  }
  if (!validVerification.ok || tamperedVerification.ok) {
    throw new Error("Evidence verification invariant failed");
  }
  const digestFinding = tamperedVerification.report?.findings.some(
    (finding) => finding.code === "E2003" && finding.path === tamperedPath,
  );
  if (!digestFinding) throw new Error("Tamper diagnostic invariant failed");

  const signatureSeed = new Uint8Array(32);
  crypto.getRandomValues(signatureSeed);
  const keypair = await rpc.call<KeypairResponse>("ed25519_keypair", {
    seed: toHex(signatureSeed),
  });
  if (!keypair.ok) throw new Error("Ed25519 key generation failed");
  const originalRootHex = stripDigestPrefix(originalTreeResponse.tree.root.actual);
  const tamperedRootHex = stripDigestPrefix(tamperedTreeResponse.tree.root.actual);
  if (originalRootHex === tamperedRootHex) throw new Error("Tampered Merkle root did not diverge");
  const signed = await rpc.call<SignatureResponse>("ed25519_sign", {
    secret_key: keypair.secret_key,
    message: originalRootHex,
  });
  if (!signed.ok) throw new Error("Ed25519 signing failed");
  const [originalSignature, tamperedSignature] = await Promise.all([
    rpc.call<SignatureVerifyResponse>("ed25519_verify", {
      public_key: keypair.public_key,
      message: originalRootHex,
      signature: signed.signature,
    }),
    rpc.call<SignatureVerifyResponse>("ed25519_verify", {
      public_key: keypair.public_key,
      message: tamperedRootHex,
      signature: signed.signature,
    }),
  ]);
  if (
    !originalSignature.ok ||
    !tamperedSignature.ok ||
    !originalSignature.valid ||
    tamperedSignature.valid
  ) {
    throw new Error("Ed25519 verification invariant failed");
  }

  return {
    manifest,
    manifestText,
    versionChainText,
    tamperedPath,
    originalTree: originalTreeResponse.tree,
    tamperedTree: tamperedTreeResponse.tree,
    validVerification,
    tamperedVerification,
    publicKey: keypair.public_key,
    signature: signed.signature,
    originalSignatureValid: originalSignature.valid,
    tamperedSignatureValid: tamperedSignature.valid,
    files: manifest.files.map((entry) => {
      const digest = digestResponses.find((item) => item.path === entry.path)!;
      return {
        path: entry.path,
        originalHex: originalFiles[entry.path],
        tamperedHex: tamperedFiles[entry.path],
        originalDigest: digest.original,
        tamperedDigest: digest.tampered,
        size: entry.size,
        changedByte: entry.path === tamperedPath ? changedByte : null,
      };
    }),
  };
}
