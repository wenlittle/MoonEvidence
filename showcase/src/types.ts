export type StoryMode = "auto" | "inspect" | "challenge";

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
    checked: {
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

export const STORY_STAGES = [
  {
    label: "采集",
    title: "原始文件进入证据包",
    detail: "文件字节与 manifest 在本地装载，内容不会离开浏览器。",
  },
  {
    label: "规范化",
    title: "固定证据描述",
    detail: "RFC 8785 将 manifest 收敛为唯一字节表示。",
  },
  {
    label: "摘要",
    title: "计算内容指纹",
    detail: "MoonBit 对每个文件计算真实 SHA-256 摘要。",
  },
  {
    label: "聚合",
    title: "构建 Merkle 可信根",
    detail: "叶子摘要逐层聚合，形成可独立复核的根。",
  },
  {
    label: "签名",
    title: "绑定发布者身份",
    detail: "Ed25519 对 Merkle 根签名，固定完整性与来源。",
  },
  {
    label: "封存",
    title: "生成外部锚点载荷",
    detail: "证据根、签名和版本信息组成可上链或归档的最小载荷。",
  },
  {
    label: "分叉",
    title: "单字节篡改产生第二条世界线",
    detail: "文件只改变一个字节，新的摘要和 Merkle 路径立即分叉。",
  },
  {
    label: "拒绝",
    title: "验证器定位并拒绝篡改",
    detail: "内容摘要、可信根和签名三层证据同时给出失败结论。",
  },
] as const;

export const LAST_STAGE = STORY_STAGES.length - 1;
