import { useRef, useState } from "react";
import { ArrowDown, Download, GitBranch, Play, ShieldCheck, ShieldX } from "lucide-react";
import { callMoon } from "../moon-rpc";
import type { EvidenceScenario } from "../types";
import {
  CodeBlock,
  EmptyState,
  NextActions,
  Pane,
  ResultHero,
  StatusLine,
  TechnicalDetails,
  ToolTitle,
} from "./shared";
import type { ProofResponse, ProofVerifyResponse, ToolStatus } from "./types";
import { canonicalLeafHex, downloadText, flipHexByte, formatJson, shortValue } from "./utils";

export function ProofTool({ scenario }: { scenario: EvidenceScenario }) {
  const [manifestText, setManifestText] = useState(scenario.manifestText);
  const [index, setIndex] = useState(0);
  const [proof, setProof] = useState<ProofResponse | null>(null);
  const [valid, setValid] = useState<boolean | null>(null);
  const [tamperedValid, setTamperedValid] = useState<boolean | null>(null);
  const [busy, setBusy] = useState(false);
  const [runId, setRunId] = useState(0);
  const [status, setStatus] = useState<ToolStatus>({ tone: "neutral", text: "选择文件后即可生成收录证明" });
  const revision = useRef(0);

  const invalidate = (text: string) => {
    revision.current += 1;
    setProof(null);
    setValid(null);
    setTamperedValid(null);
    setStatus({ tone: "warning", text });
  };

  const generate = async () => {
    const activeRevision = revision.current;
    setBusy(true);
    setStatus({ tone: "neutral", text: "正在构建并复核文件收录证明" });
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
      if (activeRevision !== revision.current) return;
      setProof(response);
      setValid(accepted.valid);
      setTamperedValid(rejected.valid);
      setRunId((value) => value + 1);
      const oraclePassed = accepted.valid && !rejected.valid;
      setStatus({
        tone: oraclePassed ? "success" : "danger",
        text: oraclePassed ? "原始文件通过，篡改对照已被拒绝" : "证明正反验证未满足预期",
      });
    } catch (error) {
      if (activeRevision !== revision.current) return;
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
  const selectedPath = manifestFiles[index]?.path ?? `文件 ${index + 1}`;
  const proofDocument = proof ? formatJson({
    algorithm: proof.algorithm,
    leaf_hash: proof.leaf_hash,
    root: proof.root,
    proof: proof.proof,
  }) : "";

  return (
    <div className="wb-tool-page">
      <ToolTitle
        id="workbench-title-proof"
        icon={<GitBranch size={21} />}
        title="文件收录证明"
        detail="证明指定文件已被纳入当前证据清单，并用篡改对照复核结论。"
      />
      <div className="wb-split wb-split-proof">
        <Pane title="选择文件">
          <label className="wb-field">
            <span>需要证明的文件</span>
            <select value={index} onChange={(event) => { setIndex(Number(event.target.value)); invalidate("目标文件已改变，请重新生成证明"); }}>
              {manifestFiles.map((file, fileIndex) => (
                <option value={fileIndex} key={`${file.path}-${fileIndex}`}>{file.path}</option>
              ))}
            </select>
          </label>
          <TechnicalDetails label="查看或编辑证据清单">
            <label className="wb-field wb-field-grow">
              <span>Manifest JSON</span>
              <textarea
                value={manifestText}
                onChange={(event) => { setManifestText(event.target.value); invalidate("证据清单已修改，请重新生成证明"); }}
                spellCheck={false}
              />
            </label>
          </TechnicalDetails>
          <button type="button" className="wb-button wb-button-primary" onClick={() => void generate()} disabled={busy || manifestFiles.length === 0}>
            <Play size={16} />
            {busy ? "正在生成" : "生成并复核证明"}
          </button>
          <StatusLine status={status} busy={busy} />
        </Pane>

        <Pane title="证明结果" className={busy ? "wb-pane-running" : ""}>
          {proof ? (
            <div className="wb-result-content" key={runId}>
              <ResultHero
                tone={valid && tamperedValid === false ? "success" : "danger"}
                title={valid && tamperedValid === false ? "文件已被收录" : "证明复核未通过"}
                detail={`${selectedPath} 已包含在这份证据清单的校验根中`}
              />
              <div className="wb-proof-view">
                <div className="wb-proof-node root">
                  <span>证据根</span>
                  <code>{shortValue(proof.root, 26)}</code>
                </div>
                <ArrowDown size={18} />
                <div className="wb-proof-steps">
                  {proof.proof.length > 0 ? proof.proof.map((step, stepIndex) => (
                    <div key={`${step.side}-${step.sibling}-${stepIndex}`}>
                      <span>{step.side === "left" ? "左侧节点" : "右侧节点"}</span>
                      <code>{shortValue(step.sibling, 24)}</code>
                    </div>
                  )) : <div><span>单文件树</span><code>无需中间节点</code></div>}
                </div>
                <ArrowDown size={18} />
                <div className="wb-proof-node leaf">
                  <span>{selectedPath}</span>
                  <code>{shortValue(proof.leaf_hash, 26)}</code>
                </div>
                <div className="wb-proof-oracles">
                  <div className={valid ? "pass" : "fail"}>
                    <ShieldCheck size={18} />
                    <span>原始文件</span>
                    <strong>{valid ? "通过" : "拒绝"}</strong>
                  </div>
                  <div className={tamperedValid === false ? "pass" : "fail"}>
                    <ShieldX size={18} />
                    <span>篡改对照</span>
                    <strong>{tamperedValid === false ? "已拒绝" : "异常通过"}</strong>
                  </div>
                </div>
              </div>
              <NextActions>
                <button type="button" className="wb-button wb-button-secondary" onClick={() => downloadText("merkle-proof.json", proofDocument)}>
                  <Download size={16} />下载证明
                </button>
              </NextActions>
              <TechnicalDetails>
                <CodeBlock label="完整证明数据">{proofDocument}</CodeBlock>
              </TechnicalDetails>
            </div>
          ) : (
            <EmptyState>{busy ? "正在生成文件收录证明" : "选择文件并运行后，证明路径会显示在这里"}</EmptyState>
          )}
        </Pane>
      </div>
    </div>
  );
}
