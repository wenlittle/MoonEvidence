import { useState } from "react";
import { ArrowDown, GitBranch, Play, ShieldCheck, ShieldX } from "lucide-react";
import { callMoon } from "../moon-rpc";
import type { EvidenceScenario } from "../types";
import { EmptyState, Pane, StatusLine, ToolTitle } from "./shared";
import type { ProofResponse, ProofVerifyResponse, ToolStatus } from "./types";
import { canonicalLeafHex, flipHexByte, shortValue } from "./utils";

export function ProofTool({ scenario }: { scenario: EvidenceScenario }) {
  const [manifestText, setManifestText] = useState(scenario.manifestText);
  const [index, setIndex] = useState(0);
  const [proof, setProof] = useState<ProofResponse | null>(null);
  const [valid, setValid] = useState<boolean | null>(null);
  const [tamperedValid, setTamperedValid] = useState<boolean | null>(null);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<ToolStatus>({ tone: "neutral", text: "选择叶子后生成包含证明" });

  const generate = async () => {
    setBusy(true);
    setStatus({ tone: "neutral", text: "MoonBit 正在构建 Merkle 包含证明" });
    try {
      const response = await callMoon<ProofResponse>("generate_proof", {
        manifest: manifestText,
        index,
      });
      if (!response.ok) throw new Error(response.error ?? "Proof generation failed");
      const parsed = JSON.parse(manifestText) as { files: Array<{ path: string; size: number; digest: string }> };
      const entry = parsed.files[index];
      if (!entry) throw new Error("Selected leaf is not present in the manifest");
      const leaf = canonicalLeafHex(entry.path, entry.size, entry.digest);
      const [accepted, rejected] = await Promise.all([
        callMoon<ProofVerifyResponse>("verify_proof", {
          leaf,
          proof: response.proof,
          root: response.root,
          algorithm: response.algorithm,
        }),
        callMoon<ProofVerifyResponse>("verify_proof", {
          leaf: flipHexByte(leaf),
          proof: response.proof,
          root: response.root,
          algorithm: response.algorithm,
        }),
      ]);
      setProof(response);
      setValid(accepted.valid);
      setTamperedValid(rejected.valid);
      const oraclePassed = accepted.valid && !rejected.valid;
      setStatus({
        tone: oraclePassed ? "success" : "danger",
        text: oraclePassed ? "原始叶通过，反向篡改验证被拒绝" : "证明正反验证未满足预期",
      });
    } catch (error) {
      setProof(null);
      setStatus({ tone: "danger", text: error instanceof Error ? error.message : String(error) });
    } finally {
      setBusy(false);
    }
  };

  const manifestFiles = (() => {
    try {
      return (JSON.parse(manifestText) as { files?: Array<{ path: string }> }).files ?? [];
    } catch {
      return [];
    }
  })();

  return (
    <div className="wb-tool-page">
      <ToolTitle
        icon={<GitBranch size={21} />}
        title="Merkle 包含证明"
        detail="生成指定叶子的最短证明路径，同时执行接受与篡改拒绝两次验证。"
      />
      <div className="wb-split wb-split-proof">
        <Pane title="证明输入">
          <label className="wb-field">
            <span>目标叶子</span>
            <select value={index} onChange={(event) => setIndex(Number(event.target.value))}>
              {manifestFiles.map((file, fileIndex) => (
                <option value={fileIndex} key={`${file.path}-${fileIndex}`}>{fileIndex}: {file.path}</option>
              ))}
            </select>
          </label>
          <label className="wb-field wb-field-grow">
            <span>Manifest JSON</span>
            <textarea value={manifestText} onChange={(event) => setManifestText(event.target.value)} spellCheck={false} />
          </label>
          <button type="button" className="wb-button wb-button-primary" onClick={() => void generate()} disabled={busy || manifestFiles.length === 0}>
            <Play size={16} />
            生成并双向验证
          </button>
          <StatusLine status={status} busy={busy} />
        </Pane>

        <Pane title="证明路径">
          {proof ? (
            <div className="wb-proof-view">
              <div className="wb-proof-node root">
                <span>MERKLE ROOT</span>
                <code>{shortValue(proof.root, 26)}</code>
              </div>
              <ArrowDown size={18} />
              <div className="wb-proof-steps">
                {proof.proof.length > 0 ? proof.proof.map((step, stepIndex) => (
                  <div key={`${step.side}-${step.sibling}-${stepIndex}`}>
                    <span>{step.side === "left" ? "左侧兄弟" : "右侧兄弟"}</span>
                    <code>{shortValue(step.sibling, 24)}</code>
                  </div>
                )) : <div><span>单叶树</span><code>no siblings</code></div>}
              </div>
              <ArrowDown size={18} />
              <div className="wb-proof-node leaf">
                <span>LEAF {index}</span>
                <code>{shortValue(proof.leaf_hash, 26)}</code>
              </div>
              <div className="wb-proof-oracles">
                <div className={valid ? "pass" : "fail"}>
                  <ShieldCheck size={18} />
                  <span>原始叶</span>
                  <strong>{valid ? "ACCEPT" : "REJECT"}</strong>
                </div>
                <div className={tamperedValid === false ? "pass" : "fail"}>
                  <ShieldX size={18} />
                  <span>篡改叶</span>
                  <strong>{tamperedValid === false ? "REJECT" : "ACCEPT"}</strong>
                </div>
              </div>
            </div>
          ) : (
            <EmptyState>证明路径与正反验证结果会显示在这里</EmptyState>
          )}
        </Pane>
      </div>
    </div>
  );
}
