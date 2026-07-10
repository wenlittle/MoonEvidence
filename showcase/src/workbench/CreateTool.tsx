import { useState } from "react";
import { Download, FilePlus2, Files, PackageCheck, Play } from "lucide-react";
import { callMoon } from "../moon-rpc";
import type { EvidenceScenario, VerifyResponse } from "../types";
import { CodeBlock, EmptyState, Pane, StatusLine, ToolTitle } from "./shared";
import type { CreateResponse, ToolStatus } from "./types";
import { downloadText, formatJson, readCreateFiles, shortValue } from "./utils";

export function CreateTool({ scenario }: { scenario: EvidenceScenario }) {
  const builtInFiles = Object.fromEntries(scenario.files.map((file) => [file.path, file.originalHex]));
  const [files, setFiles] = useState<Record<string, string>>({});
  const [subjectId, setSubjectId] = useState("my-evidence-pack");
  const [subjectType, setSubjectType] = useState("dataset");
  const [versionId, setVersionId] = useState("v1");
  const [algorithm, setAlgorithm] = useState<"sha256" | "sha512">("sha256");
  const [manifest, setManifest] = useState("");
  const [verification, setVerification] = useState<VerifyResponse | null>(null);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<ToolStatus>({ tone: "neutral", text: "选择文件后即可生成证据包 Manifest" });

  const pickFiles = async (fileList: FileList | null) => {
    if (!fileList?.length) return;
    const loaded = await readCreateFiles(fileList);
    setFiles(loaded);
    setManifest("");
    setVerification(null);
    setStatus({ tone: "neutral", text: `已选择 ${Object.keys(loaded).length} 个文件` });
  };

  const loadBuiltIn = () => {
    setFiles(builtInFiles);
    setSubjectId(scenario.manifest.subject.id);
    setSubjectType(scenario.manifest.subject.type);
    setVersionId(scenario.manifest.version.id);
    setManifest("");
    setVerification(null);
    setStatus({ tone: "neutral", text: "已载入仓库示例文件" });
  };

  const create = async () => {
    if (Object.keys(files).length === 0) {
      setStatus({ tone: "danger", text: "至少需要选择一个文件" });
      return;
    }
    setBusy(true);
    setStatus({ tone: "neutral", text: "MoonBit 正在计算摘要与 Merkle 根" });
    try {
      const response = await callMoon<CreateResponse>("create_evidence_pack", {
        files,
        subject: { id: subjectId, type: subjectType },
        algorithm,
        version_id: versionId,
      });
      if (!response.ok) throw new Error(response.error ?? "Manifest creation failed");
      const verifyResponse = await callMoon<VerifyResponse>("verify_evidence", {
        manifest: response.manifest,
        files,
      });
      setManifest(response.manifest);
      setVerification(verifyResponse);
      setStatus({
        tone: verifyResponse.ok ? "success" : "danger",
        text: verifyResponse.ok ? "Manifest 已生成并通过回读验证" : "Manifest 已生成，但回读验证失败",
      });
    } catch (error) {
      setStatus({ tone: "danger", text: error instanceof Error ? error.message : String(error) });
    } finally {
      setBusy(false);
    }
  };

  let parsedManifest: Record<string, unknown> | null = null;
  if (manifest) {
    try {
      parsedManifest = JSON.parse(manifest) as Record<string, unknown>;
    } catch {
      parsedManifest = null;
    }
  }

  return (
    <div className="wb-tool-page">
      <ToolTitle
        icon={<FilePlus2 size={21} />}
        title="创建证据包"
        detail="从原始文件生成规范 Manifest，并立即通过同一 MoonBit 核心回读验证。"
      />
      <div className="wb-split wb-split-create">
        <Pane title="创建参数">
          <div className="wb-inline-actions">
            <label className="wb-file-button">
              <Files size={16} />
              <span>选择文件</span>
              <input type="file" multiple onChange={(event) => void pickFiles(event.target.files)} />
            </label>
            <button type="button" className="wb-button wb-button-secondary" onClick={loadBuiltIn}>
              载入仓库样例
            </button>
          </div>

          <div className="wb-file-inventory">
            {Object.entries(files).length > 0 ? Object.entries(files).map(([path, hex]) => (
              <div key={path}>
                <Files size={15} />
                <span>{path}</span>
                <code>{hex.length / 2} B</code>
              </div>
            )) : <EmptyState>尚未选择文件</EmptyState>}
          </div>

          <div className="wb-form-grid">
            <label className="wb-field wb-field-span-2">
              <span>Subject ID</span>
              <input value={subjectId} onChange={(event) => setSubjectId(event.target.value)} />
            </label>
            <label className="wb-field">
              <span>Subject Type</span>
              <input value={subjectType} onChange={(event) => setSubjectType(event.target.value)} />
            </label>
            <label className="wb-field">
              <span>Version</span>
              <input value={versionId} onChange={(event) => setVersionId(event.target.value)} />
            </label>
            <label className="wb-field wb-field-span-2">
              <span>摘要算法</span>
              <select value={algorithm} onChange={(event) => setAlgorithm(event.target.value as "sha256" | "sha512")}>
                <option value="sha256">SHA-256</option>
                <option value="sha512">SHA-512</option>
              </select>
            </label>
          </div>

          <button type="button" className="wb-button wb-button-primary" onClick={() => void create()} disabled={busy}>
            <Play size={16} />
            生成并验证
          </button>
          <StatusLine status={status} busy={busy} />
        </Pane>

        <Pane
          title="Manifest 输出"
          action={manifest ? (
            <button type="button" className="wb-icon-button" onClick={() => downloadText("manifest.json", manifest)} title="下载 manifest.json" aria-label="下载 manifest.json">
              <Download size={16} />
            </button>
          ) : undefined}
        >
          {manifest && parsedManifest ? (
            <>
              <div className="wb-metrics">
                <div><span>文件</span><strong>{Object.keys(files).length}</strong></div>
                <div><span>根</span><strong>{shortValue(String(parsedManifest.merkle_root ?? ""), 12)}</strong></div>
                <div><span>回读</span><strong className={verification?.ok ? "value-good" : "value-bad"}>{verification?.ok ? "PASS" : "FAIL"}</strong></div>
              </div>
              <div className="wb-closure-line">
                <PackageCheck size={17} />
                <span>create_evidence_pack → verify_evidence</span>
              </div>
              <CodeBlock label="canonical manifest">{formatJson(manifest)}</CodeBlock>
            </>
          ) : (
            <EmptyState>生成后的规范 Manifest 与回读结果会显示在这里</EmptyState>
          )}
        </Pane>
      </div>
    </div>
  );
}
