import type { Finding, TreeData, VerifyResponse } from "../types";

export type ApiResponse = {
  ok: boolean;
  error?: string;
};

export type Keypair = ApiResponse & {
  public_key: string;
  secret_key: string;
};

export type SignatureResponse = ApiResponse & {
  signature: string;
};

export type SignatureVerifyResponse = ApiResponse & {
  valid: boolean;
};

export type CreateResponse = ApiResponse & {
  manifest: string;
};

export type ProofStep = {
  side: "left" | "right";
  sibling: string;
};

export type ProofResponse = ApiResponse & {
  proof: ProofStep[];
  leaf_hash: string;
  root: string;
  algorithm: "sha256" | "sha512";
};

export type ProofVerifyResponse = ApiResponse & {
  valid: boolean;
};

export type AuditAppendResponse = ApiResponse & {
  log: string;
  entry_hash: string;
};

export type AuditVerifyResponse = ApiResponse & {
  chain_valid: boolean;
  signatures_valid: boolean;
  length: number;
};

export type AuditSignResponse = ApiResponse & {
  log: string;
};

export type AuditEntry = {
  timestamp?: string;
  actor?: string;
  action?: string;
  subject_id?: string;
  manifest_digest?: string | null;
  previous_hash?: string | null;
  prev_hash?: string | null;
  hash?: string;
  signature?: string | null;
};

export type TreeApiResponse = ApiResponse & {
  tree: TreeData;
};

export type ToolStatus = {
  tone: "neutral" | "success" | "danger" | "warning";
  text: string;
};

export type { Finding, VerifyResponse };
