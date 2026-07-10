import { useState } from "react";
import { FileCheck2, FolderOpen, Play, RotateCcw } from "lucide-react";
import { callMoon } from "../moon-rpc";
import type { EvidenceScenario, VerifyResponse } from "../types";
import { EmptyState, Pane, StatusLine, ToolTitle } from "./shared";
import type { ToolStatus } from "./types";
import { inputDirectoryProps, readPackDirectory, shortValue } from "./utils";

export function VerifyTool({ scenario }: { scenario: EvidenceScenario }) {
  const originalFiles = Object.fromEntries(scenario.files.map((file) => [file.path, file.originalHex]));
  const tamperedFiles = Object.fromEntries(scenario.files.map((file) => [file.path, file.tamperedHex]));
  const [manifestText, setManifestText] = useState(scenario.manifestText);
  const [files, setFiles] = useState<Record<string, string>>(originalFiles);
  const [source, setSource] = useState("内置完好证据包");
  const [result, setResult] = useState<VerifyResponse>(scenario.validVerification);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<ToolStatus>({ tone: "success", text: "完好示例验证通过" });

  const loadExample = (tampered: boolean) => {
    setManifestText(scenario.manifestText);
    setFiles(tampered ? tamperedFiles : originalFiles);
    setSource(tampered ? "内置单字节篡改包" : "内置完好证据包");
    setResult(tampered ? scenario.tamperedVerification : scenario.validVerification);
    setStatus({
      tone: tampered ? "danger" : "success",
      text: tampered ? "已载入单字节篡改场景" : "已恢复完好证据包",
    });
  };

  const loadDirectory = async (fileList: FileList | null) => {
    if (!fileList?.length) return;
    const loaded = await readPackDirectory(fileList);
    if (!loaded.manifestText) {
      setStatus({ tone: "danger", text: "所选目录中没有 manifest.json" });
      return;
    }
    setManifestText(loaded.manifestText);
    setFiles(loaded.files);
    setSource(loaded.directoryName);
    setResult({ ok: false });
    setStatus({ tone: "neutral", text: `已载入 ${loaded.directoryName}，等待验证` });
  };

  const verify = async () => {
    if (!manifestText.trim()) {
      setStatus({ tone: "danger", text: "请先提供 manifest JSON" });
      return;
    }
    setBusy(true);
    setStatus({ tone: "neutral", text: "MoonBit 正在执行完整验证流水线" });
    try {
      const response = await callMoon<VerifyResponse>("verify_evidence", {
        manifest: manifestText,
        files,
      });
      setResult(response);
      setStatus({
        tone: response.ok ? "success" : "danger",
        text: response.ok ? "证据包完整，全部检查通过" : "验证拒绝，诊断已定位失败路径",
      });
    } catch (error) {
      setStatus({ tone: "danger", text: error instanceof Error ? error.message : String(error) });
    } finally {
      setBusy(false);
    }
  };

  const findings = result.report?.findings ?? [];
  const checked = result.report?.checked;

  return (
    <div className="wb-tool-page">
      <ToolTitle
        icon={<FileCheck2 size={21} />}
        title="验证证据包"
        detail="目录、Manifest、内容摘要与 Merkle 根在浏览器本地完成一致性检查。"
      />
      <div className="wb-split wb-split-verify">
        <Pane title="验证输入">
          <div className="wb-segmented wb-segmented-wide">
            <button type="button" onClick={() => loadExample(false)} className={source.includes("完好") ? "active" : ""}>
              完好样例
            </button>
            <button type="button" onClick={() => loadExample(true)} className={source.includes("篡改") ? "active" : ""}>
              篡改样例
            </button>
          </div>

          <label className="wb-file-button">
            <FolderOpen size={16} />
            <span>选择证据包目录</span>
            <input
              type="file"
              multiple
              {...inputDirectoryProps()}
              onChange={(event) => void loadDirectory(event.target.files)}
            />
          </label>

          <div className="wb-source-summary">
            <span>当前来源</span>
            <strong>{source}</strong>
            <code>{Object.keys(files).length} files</code>
          </div>

          <label className="wb-field wb-field-grow">
            <span>Manifest JSON</span>
            <textarea value={manifestText} onChange={(event) => setManifestText(event.target.value)} spellCheck={false} />
          </label>

          <div className="wb-actions">
            <button type="button" className="wb-button wb-button-primary" onClick={() => void verify()} disabled={busy}>
              <Play size={16} />
              执行验证
            </button>
            <button type="button" className="wb-icon-button" onClick={() => loadExample(false)} title="恢复完好样例" aria-label="恢复完好样例">
              <RotateCcw size={16} />
            </button>
          </div>
          <StatusLine status={status} busy={busy} />
        </Pane>

        <Pane
          title="验证报告"
          action={
            <span className={`wb-verdict ${result.ok ? "ok" : "bad"}`}>
              {result.ok ? "PASS" : "REJECT"}
            </span>
          }
        >
          {checked && (
            <div className="wb-metrics">
              <div><span>文件</span><strong>{checked.files_passed}/{checked.files_total}</strong></div>
              <div><span>Merkle</span><strong>{checked.merkle_checked ? "checked" : "skipped"}</strong></div>
              <div><span>发现</span><strong>{findings.length}</strong></div>
            </div>
          )}

          <div className="wb-explain">{result.explain || "运行验证后，这里会显示结构化报告。"}</div>

          {findings.length > 0 ? (
            <div className="wb-findings-table" role="table" aria-label="验证发现">
              <div className="wb-findings-head" role="row">
                <span>代码</span><span>路径</span><span>说明</span>
              </div>
              {findings.map((finding, index) => (
                <div className="wb-finding-row" role="row" key={`${finding.code}-${finding.path}-${index}`}>
                  <strong>{finding.code}</strong>
                  <code title={finding.path}>{finding.path || "manifest"}</code>
                  <span>{finding.message}</span>
                </div>
              ))}
            </div>
          ) : result.ok ? (
            <div className="wb-pass-list">
              {scenario.files.map((file) => (
                <div key={file.path}>
                  <FileCheck2 size={16} />
                  <span>{file.path}</span>
                  <code>{shortValue(file.originalDigest)}</code>
                </div>
              ))}
            </div>
          ) : (
            <EmptyState>尚未生成验证结果</EmptyState>
          )}
        </Pane>
      </div>
    </div>
  );
}
