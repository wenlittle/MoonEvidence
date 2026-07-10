import { useRef, useState } from "react";
import { Download, FilePlus2, Files, Play } from "lucide-react";
import { callMoon } from "../moon-rpc";
import type { EvidenceScenario, VerifyResponse } from "../types";
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
  const [runId, setRunId] = useState(0);
  const [status, setStatus] = useState<ToolStatus>({ tone: "neutral", text: "选择文件后即可创建证据清单" });
  const revision = useRef(0);

  const invalidate = (text: string) => {
    revision.current += 1;
    setManifest("");
    setVerification(null);
    setStatus({ tone: "warning", text });
  };

  const pickFiles = async (fileList: FileList | null) => {
    if (!fileList?.length) return;
    const loaded = await readCreateFiles(fileList);
    revision.current += 1;
    setFiles(loaded);
    setManifest("");
    setVerification(null);
    setStatus({ tone: "neutral", text: `已选择 ${Object.keys(loaded).length} 个文件，可以开始创建` });
  };

  const loadBuiltIn = () => {
    revision.current += 1;
    setFiles(builtInFiles);
    setSubjectId(scenario.manifest.subject.id);
    setSubjectType(scenario.manifest.subject.type);
    setVersionId(scenario.manifest.version.id);
    setManifest("");
    setVerification(null);
    setStatus({ tone: "neutral", text: "仓库样例已载入，可以开始创建" });
  };

  const create = async () => {
    if (Object.keys(files).length === 0) {
      setStatus({ tone: "danger", text: "至少需要选择一个文件" });
      return;
    }
    const activeRevision = revision.current;
    setBusy(true);
    setStatus({ tone: "neutral", text: "正在计算文件摘要与证据根" });
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
      if (activeRevision !== revision.current) return;
      setManifest(response.manifest);
      setVerification(verifyResponse);
      setRunId((value) => value + 1);
      setStatus({
        tone: verifyResponse.ok ? "success" : "danger",
        text: verifyResponse.ok ? "证据清单已生成并完成回读检查" : "清单已生成，但回读检查失败",
      });
    } catch (error) {
      if (activeRevision !== revision.current) return;
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
        id="workbench-title-create"
        icon={<FilePlus2 size={21} />}
        title="创建证据清单"
        detail="为一组本地文件生成可复核的摘要、证据根和 manifest.json。"
      />
      <div className="wb-split wb-split-create">
        <Pane title="选择文件">
          <div className="wb-inline-actions">
            <label className="wb-file-button">
              <Files size={16} />
              <span>选择本地文件</span>
              <input type="file" multiple onChange={(event) => void pickFiles(event.target.files)} />
            </label>
            <button type="button" className="wb-button wb-button-secondary" onClick={loadBuiltIn}>
              载入仓库样例
            </button>
          </div>

          <div className="wb-file-inventory">
            {Object.entries(files).length > 0 ? Object.entries(files).map(([path, hex]) => (
              <div key={path}>
                <Files size={16} />
                <span>{path}</span>
                <code>{hex.length / 2} B</code>
              </div>
            )) : <EmptyState>尚未选择文件</EmptyState>}
          </div>

          <TechnicalDetails label="高级选项">
            <div className="wb-form-grid">
              <label className="wb-field wb-field-span-2">
                <span>证据主题 ID</span>
                <input value={subjectId} onChange={(event) => { setSubjectId(event.target.value); invalidate("创建参数已修改，请重新生成"); }} />
              </label>
              <label className="wb-field">
                <span>主题类型</span>
                <input value={subjectType} onChange={(event) => { setSubjectType(event.target.value); invalidate("创建参数已修改，请重新生成"); }} />
              </label>
              <label className="wb-field">
                <span>版本</span>
                <input value={versionId} onChange={(event) => { setVersionId(event.target.value); invalidate("创建参数已修改，请重新生成"); }} />
              </label>
              <label className="wb-field wb-field-span-2">
                <span>摘要算法</span>
                <select value={algorithm} onChange={(event) => { setAlgorithm(event.target.value as "sha256" | "sha512"); invalidate("摘要算法已修改，请重新生成"); }}>
                  <option value="sha256">SHA-256</option>
                  <option value="sha512">SHA-512</option>
                </select>
              </label>
            </div>
          </TechnicalDetails>

          <button type="button" className="wb-button wb-button-primary" onClick={() => void create()} disabled={busy}>
            <Play size={16} />
            {busy ? "正在创建" : "创建证据清单"}
          </button>
          <StatusLine status={status} busy={busy} />
        </Pane>

        <Pane title="创建结果" className={busy ? "wb-pane-running" : ""}>
          {manifest && parsedManifest ? (
            <div className="wb-result-content" key={runId}>
              <ResultHero
                tone={verification?.ok ? "success" : "danger"}
                title={verification?.ok ? "证据清单已创建" : "回读检查未通过"}
                detail={verification?.ok
                  ? `已为 ${Object.keys(files).length} 个文件生成并复核 manifest.json`
                  : "生成结果需要重新检查后再使用"}
              />
              <div className="wb-metrics">
                <div><span>文件数量</span><strong>{Object.keys(files).length}</strong></div>
                <div><span>证据根</span><strong>{shortValue(String(parsedManifest.merkle_root ?? ""), 12)}</strong></div>
                <div><span>回读检查</span><strong className={verification?.ok ? "value-good" : "value-bad"}>{verification?.ok ? "通过" : "失败"}</strong></div>
              </div>
              <NextActions>
                <button type="button" className="wb-button wb-button-primary" onClick={() => downloadText("manifest.json", manifest)}>
                  <Download size={16} />下载 manifest.json
                </button>
              </NextActions>
              <TechnicalDetails>
                <CodeBlock label="规范化清单">{formatJson(manifest)}</CodeBlock>
              </TechnicalDetails>
            </div>
          ) : (
            <EmptyState>{busy ? "正在生成证据清单" : "创建完成后，复核结论和下载入口会显示在这里"}</EmptyState>
          )}
        </Pane>
      </div>
    </div>
  );
}
