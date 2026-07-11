export interface FabricProfile {
  schema: "moon-evidence-fabric-profile/v1";
  channel: string;
  chaincode: string;
  msp_id: string;
  peer_endpoint: string;
  peer_host_alias: string;
  tls_certificate_path: string;
  certificate_path: string;
  private_key_path: string;
  timeouts_ms: {
    evaluate: number;
    endorse: number;
    submit: number;
    commit_status: number;
  };
}
export interface AnchorRecord {
  schema: "moon-evidence-anchor/v1";
  manifest_digest: string;
  transaction_id: string;
  submitter_msp: string;
}

export interface CreateAnchorResult {
  created: boolean;
  anchor: AnchorRecord;
}

export type AnchorOutcome =
  | "created"
  | "already_anchored"
  | "already_anchored_after_conflict";

export interface CommitReceipt {
  transaction_id: string;
  block_number: string;
  status_code: number;
  successful: boolean;
}

export interface AnchorReceipt {
  schema: "moon-evidence-fabric-receipt/v1";
  ok: true;
  outcome: AnchorOutcome;
  manifest_digest: string;
  anchor: AnchorRecord;
  commit: CommitReceipt;
}

export interface InspectResult {
  schema: "moon-evidence-inspect/v1" | "moon-evidence-pack-result/v1";
  ok: true;
  pack_path: string;
  manifest_path: string;
  manifest_digest: string;
  merkle_root: string | null;
  algorithm: "sha256" | "sha512";
  files_total: number;
  subject: { id: string; type: string };
  version: { id: string; parent: string | null };
}

export interface VerifyReport {
  ok: boolean;
  findings: Array<{
    code: string;
    severity: string;
    path: string;
    message: string;
  }>;
  stats: {
    files_total: number;
    files_passed: number;
    merkle_checked: boolean;
  };
}
