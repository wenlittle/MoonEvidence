import { useRef, useState } from "react";
import {
  FileCheck2,
  FlaskConical,
  FolderOpen,
  GitBranch,
  Play,
  RotateCcw,
} from "lucide-react";
import { callMoon } from "../moon-rpc";
import type { EvidenceScenario, VerifyResponse } from "../types";
import { buildVerifyEvidenceRequest } from "../verify-request";
import {
  EmptyState,
  NextActions,
  Pane,
  ResultHero,
  StatusLine,
  TechnicalDetails,
  ToolTitle,
} from "./shared";
import type { ToolStatus } from "./types";
import { inputDirectoryProps, readPackDirectory } from "./utils";
import type { WorkbenchView } from "./Workbench";

function findingSummary(code: string): string {
  switch (code) {
    case "E1001": return "证据清单格式无法解析";
    case "E1002": return "证据清单缺少必填项或字段格式无效";
    case "E1003": return "证据清单版本暂不受支持";
    case "E1004": return "证据清单无法转换为规范 JSON";
    case "E2001": return "证据清单指定了不受支持的摘要算法";
    case "E2002": return "证据清单中的摘要格式无效";
    case "E2003": return "文件缺失或内容与证据清单不一致";
    case "E2004": return "证据清单本身发生了变化";
    case "E3001": return "证据根与文件清单的存在状态不一致";
    case "E3003": return "当前证据根与清单记录不一致";
    case "E4001": return "版本记录为空";
    case "E4002": return "版本记录引用了不存在的上级版本";
    case "E4003": return "版本记录中存在循环或断开的链路";
    case "E4004": return "版本记录中存在分叉或重复版本";
    case "W1001": return "证据包中存在未列入清单的文件";
    default: return code.startsWith("W") ? "发现一项需要复核的内容" : "该项目未通过一致性检查";
  }
}

export function VerifyTool({
  scenario,
  onNavigate,
}: {
  scenario: EvidenceScenario;
  onNavigate: (view: WorkbenchView) => void;
}) {
  const originalFiles = Object.fromEntries(scenario.files.map((file) => [file.path, file.originalHex]));
  const tamperedFiles = Object.fromEntries(scenario.files.map((file) => [file.path, file.tamperedHex]));
  const [manifestText, setManifestText] = useState(scenario.manifestText);
  const [versionChainText, setVersionChainText] = useState(scenario.versionChainText);
  const [files, setFiles] = useState<Record<string, string>>(originalFiles);
  const [source, setSource] = useState("内置完好证据包");
  const [result, setResult] = useState<VerifyResponse | null>(null);
  const [busy, setBusy] = useState(false);
  const [runId, setRunId] = useState(0);
  const [status, setStatus] = useState<ToolStatus>({
    tone: "neutral",
    text: "完好样例已准备，点击开始验证",
  });
  const revision = useRef(0);

  const invalidate = (text: string) => {
    revision.current += 1;
    setResult(null);
    setStatus({ tone: "warning", text });
  };

  const loadExample = (tampered: boolean) => {
    revision.current += 1;
    setManifestText(scenario.manifestText);
    setVersionChainText(scenario.versionChainText);
    setFiles(tampered ? tamperedFiles : originalFiles);
    setSource(tampered ? "内置单字节篡改包" : "内置完好证据包");
    setResult(null);
    setStatus({
      tone: "neutral",
      text: tampered ? "篡改样例已准备，点击验证查看差异" : "完好样例已准备，点击开始验证",
    });
  };

  const loadDirectory = async (fileList: FileList | null) => {
    if (!fileList?.length) return;
    const loaded = await readPackDirectory(fileList);
    if (!loaded.manifestText) {
      setStatus({ tone: "danger", text: "所选目录中没有 manifest.json" });
      return;
    }
    revision.current += 1;
    setManifestText(loaded.manifestText);
    setVersionChainText(loaded.versionChainText);
    setFiles(loaded.files);
    setSource(loaded.directoryName);
    setResult(null);
    setStatus({ tone: "neutral", text: `已载入 ${loaded.directoryName}，可以开始验证` });
  };

  const verify = async () => {
    if (!manifestText.trim()) {
      setStatus({ tone: "danger", text: "请先提供 manifest JSON" });
      return;
    }
    const activeRevision = revision.current;
    setBusy(true);
    setStatus({ tone: "neutral", text: "正在核对文件摘要与证据根" });
    try {
      const response = await callMoon<VerifyResponse>(
        "verify_evidence",
        buildVerifyEvidenceRequest(manifestText, files, versionChainText),
      );
      if (activeRevision !== revision.current) return;
      setResult(response);
      setRunId((value) => value + 1);
      setStatus({
        tone: response.ok ? "success" : "danger",
        text: response.ok ? "验证完成，全部检查通过" : "验证完成，已定位不一致内容",
      });
    } catch (error) {
      if (activeRevision !== revision.current) return;
      setResult(null);
      setStatus({ tone: "danger", text: error instanceof Error ? error.message : String(error) });
    } finally {
      setBusy(false);
    }
  };

  const findings = result?.report?.findings ?? [];
  const stats = result?.report?.stats;
  const firstFinding = findings[0];
  const resultDetail = result?.ok
    ? `${stats?.files_passed ?? Object.keys(files).length} 个文件均与证据清单记录一致`
    : firstFinding?.path
      ? `${firstFinding.path} 未通过一致性检查`
      : "证据包中存在无法通过检查的内容";

  return (
    <div className="wb-tool-page">
      <ToolTitle
        id="workbench-title-verify"
        icon={<FileCheck2 size={21} />}
        title="验证证据包"
        detail="选择一份证据包，确认其中的文件从生成后是否发生变化。"
      />
      <div className="wb-split wb-split-verify">
        <Pane title="选择证据包">
          <div className="wb-segmented wb-segmented-wide" aria-label="体验样例">
            <button type="button" onClick={() => loadExample(false)} className={source.includes("完好") ? "active" : ""}>
              完好样例
            </button>
            <button type="button" onClick={() => loadExample(true)} className={source.includes("篡改") ? "active" : ""}>
              篡改样例
            </button>
          </div>

          <label className="wb-file-button">
            <FolderOpen size={16} />
            <span>选择本地证据包</span>
            <input
              type="file"
              multiple
              {...inputDirectoryProps()}
              onChange={(event) => void loadDirectory(event.target.files)}
            />
          </label>

          <div className="wb-source-summary">
            <span>已载入</span>
            <strong>{source}</strong>
            <code>{Object.keys(files).length} 个文件</code>
          </div>

          <TechnicalDetails label="查看或编辑证据清单">
            <label className="wb-field wb-field-grow">
              <span>Manifest JSON</span>
              <textarea
                value={manifestText}
                onChange={(event) => {
                  setManifestText(event.target.value);
                  invalidate("证据清单已修改，请重新验证");
                }}
                spellCheck={false}
              />
            </label>
          </TechnicalDetails>

          <div className="wb-actions">
            <button type="button" className="wb-button wb-button-primary" onClick={() => void verify()} disabled={busy}>
              <Play size={16} />
              {busy ? "正在验证" : "开始验证"}
            </button>
            <button type="button" className="wb-icon-button" onClick={() => loadExample(false)} title="恢复完好样例" aria-label="恢复完好样例">
              <RotateCcw size={16} />
            </button>
          </div>
          <StatusLine status={status} busy={busy} />
        </Pane>

        <Pane title="检查结果" className={busy ? "wb-pane-running" : ""}>
          {result ? (
            <div className="wb-result-content" key={runId}>
              <ResultHero
                tone={result.ok ? "success" : "danger"}
                title={result.ok ? "验证通过" : "发现内容不一致"}
                detail={resultDetail}
              />

              {stats && (
                <div className="wb-metrics">
                  <div><span>文件检查</span><strong>{stats.files_passed}/{stats.files_total}</strong></div>
                  <div><span>清单结构</span><strong>{stats.merkle_checked ? "已复核" : "未检查"}</strong></div>
                  <div><span>异常项</span><strong>{findings.length}</strong></div>
                </div>
              )}

              {findings.length > 0 ? (
                <div className="wb-findings-table wb-findings-plain" role="table" aria-label="验证发现">
                  <div className="wb-findings-head" role="row">
                    <span role="columnheader">位置</span><span role="columnheader">检查结论</span>
                  </div>
                  {findings.map((finding, index) => (
                    <div className="wb-finding-row" role="row" key={`${finding.code}-${finding.path}-${index}`}>
                      <code role="cell" title={finding.path}>{finding.path || "manifest"}</code>
                      <span role="cell">{findingSummary(finding.code)}</span>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="wb-pass-list">
                  {Object.entries(files).map(([path, hex]) => (
                    <div key={path}>
                      <FileCheck2 size={17} />
                      <span>{path}</span>
                      <code>{hex.length / 2} B</code>
                    </div>
                  ))}
                </div>
              )}

              <NextActions>
                {result.ok ? (
                  <>
                    <button type="button" className="wb-button wb-button-secondary" onClick={() => onNavigate("proof")}>
                      <GitBranch size={16} />体验文件证明
                    </button>
                    <button type="button" className="wb-button wb-button-secondary" onClick={() => onNavigate("tamper")}>
                      <FlaskConical size={16} />观察篡改传播
                    </button>
                  </>
                ) : (
                  <button type="button" className="wb-button wb-button-secondary" onClick={() => loadExample(false)}>
                    <RotateCcw size={16} />载入完好样例
                  </button>
                )}
              </NextActions>

              <TechnicalDetails>
                <div className="wb-explain">{result.explain || "没有额外技术报告。"}</div>
              </TechnicalDetails>
            </div>
          ) : (
            <EmptyState>{busy ? "正在生成检查结论" : "选择材料并开始验证后，结论会显示在这里"}</EmptyState>
          )}
        </Pane>
      </div>
    </div>
  );
}
