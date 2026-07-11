export type ManifestFile = {
  path: string;
  size: number;
  digest: string;
};

export type EvidenceManifest = {
  schema: string;
  subject: { id: string; type: string };
  hash_algorithm: "sha256" | "sha512";
  files: ManifestFile[];
  merkle_root: string | null;
  version: { id: string; parent: string | null };
};

export type TreeData = {
  levels: string[][];
  leaf_count: number;
  height: number;
  root: {
    recorded: string | null;
    actual: string;
    matches: boolean;
  };
  leaves_meta: ManifestFile[];
};

export type TreeResponse = {
  ok: boolean;
  tree: TreeData;
  error?: string;
};

export type Finding = {
  code: string;
  severity: "Error" | "Warning";
  path: string;
  message: string;
};

export type VerifyResponse = {
  ok: boolean;
  explain?: string;
  error?: string;
  report?: {
    ok: boolean;
    findings: Finding[];
    stats: {
      files_total: number;
      files_passed: number;
      merkle_checked: boolean;
    };
  };
};

export type ScenarioFile = {
  path: string;
  originalHex: string;
  tamperedHex: string;
  originalDigest: string;
  tamperedDigest: string;
  size: number;
  changedByte: number | null;
};

export type EvidenceScenario = {
  manifest: EvidenceManifest;
  manifestText: string;
  versionChainText: string | null;
  files: ScenarioFile[];
  tamperedPath: string;
  originalTree: TreeData;
  tamperedTree: TreeData;
  validVerification: VerifyResponse;
  tamperedVerification: VerifyResponse;
  publicKey: string;
  signature: string;
  originalSignatureValid: boolean;
  tamperedSignatureValid: boolean;
};

export type WorkerMethod =
  | "digest_compute"
  | "verify_evidence"
  | "compute_merkle_tree"
  | "create_evidence_pack"
  | "generate_proof"
  | "verify_proof"
  | "audit_append"
  | "audit_verify"
  | "audit_sign"
  | "ed25519_keypair"
  | "ed25519_sign"
  | "ed25519_verify";

export type WorkerRequest = {
  id: number;
  method: WorkerMethod;
  payload: string;
};

export type WorkerResponse = {
  id: number;
  ok: boolean;
  result?: string;
  error?: string;
};
