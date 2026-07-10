import { useMemo, useState } from "react";
import { FileWarning, FlaskConical, FolderOpen, RotateCcw, Zap } from "lucide-react";
import { callMoon } from "../moon-rpc";
import type { EvidenceScenario, VerifyResponse } from "../types";
import { CodeBlock, EmptyState, Pane, ResultHero, StatusLine, TechnicalDetails, ToolTitle } from "./shared";
import type { ToolStatus, TreeApiResponse } from "./types";
import { flipHexByte, inputDirectoryProps, readPackDirectory, shortValue } from "./utils";

export function TamperTool({ scenario }: { scenario: EvidenceScenario }) {
  const builtInFiles = Object.fromEntries(scenario.files.map((file) => [file.path, file.originalHex]));
  const [manifestText, setManifestText] = useState(scenario.manifestText);
  const [originalFiles, setOriginalFiles] = useState<Record<string, string>>(builtInFiles);
  const [files, setFiles] = useState<Record<string, string>>(builtInFiles);
  const [selectedPath, setSelectedPath] = useState(scenario.tamperedPath);
  const [tree, setTree] = useState(scenario.originalTree);
  const [verification, setVerification] = useState<VerifyResponse>(scenario.validVerification);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<ToolStatus>({ tone: "success", text: "内置证据包处于完好状态" });

  const modifiedPaths = useMemo(
    () => Object.keys(files).filter((path) => files[path] !== originalFiles[path]),
    [files, originalFiles],
  );

  const rebuild = async (
    nextManifest: string,
    nextFiles: Record<string, string>,
    message: string,
  ) => {
    setBusy(true);
    setStatus({ tone: "neutral", text: "MoonBit 正在重算摘要、Merkle 树与诊断" });
    try {
      const materializedManifest = JSON.parse(nextManifest) as {
        hash_algorithm: "sha256" | "sha512";
        files: Array<{ path: string; size: number; digest: string }>;
      };
      await Promise.all(materializedManifest.files.map(async (entry) => {
        const content = nextFiles[entry.path];
        if (content === undefined) return;
        const digestResponse = await callMoon<{ ok: boolean; digest: string; error?: string }>(
          "digest_compute",
          { algorithm: materializedManifest.hash_algorithm, data: content },
        );
        if (!digestResponse.ok) throw new Error(digestResponse.error ?? `Digest failed for ${entry.path}`);
        entry.digest = `${materializedManifest.hash_algorithm}:${digestResponse.digest}`;
        entry.size = content.length / 2;
      }));
      const [treeResponse, verifyResponse] = await Promise.all([
        callMoon<TreeApiResponse>("compute_merkle_tree", {
          manifest: JSON.stringify(materializedManifest),
          files: nextFiles,
        }),
        callMoon<VerifyResponse>("verify_evidence", {
          manifest: nextManifest,
          files: nextFiles,
        }),
      ]);
      if (!treeResponse.ok) throw new Error(treeResponse.error ?? "Merkle tree build failed");
      setTree(treeResponse.tree);
      setVerification(verifyResponse);
      setStatus({ tone: verifyResponse.ok ? "success" : "danger", text: message });
    } catch (error) {
      setStatus({ tone: "danger", text: error instanceof Error ? error.message : String(error) });
    } finally {
      setBusy(false);
    }
  };

  const loadBuiltIn = () => {
    setManifestText(scenario.manifestText);
    setOriginalFiles(builtInFiles);
    setFiles(builtInFiles);
    setSelectedPath(scenario.tamperedPath);
    setTree(scenario.originalTree);
    setVerification(scenario.validVerification);
    setStatus({ tone: "success", text: "内置证据包已恢复" });
  };

  const loadDirectory = async (fileList: FileList | null) => {
    if (!fileList?.length) return;
    const loaded = await readPackDirectory(fileList);
    if (!loaded.manifestText) {
      setStatus({ tone: "danger", text: "所选目录中没有 manifest.json" });
      return;
    }
    const firstPath = Object.keys(loaded.files)[0] ?? "";
    setManifestText(loaded.manifestText);
    setOriginalFiles(loaded.files);
    setFiles(loaded.files);
    setSelectedPath(firstPath);
    await rebuild(loaded.manifestText, loaded.files, `${loaded.directoryName} 验证完成`);
  };

  const tamper = async () => {
    const current = files[selectedPath];
    if (!current) return;
    const nextFiles = {
      ...files,
      [selectedPath]: flipHexByte(current, Math.floor(current.length / 4)),
    };
    setFiles(nextFiles);
    await rebuild(manifestText, nextFiles, `${selectedPath} 已改变一个字节，验证器拒绝该证据包`);
  };

  const reset = async () => {
    const restored = { ...originalFiles };
    setFiles(restored);
    await rebuild(manifestText, restored, "全部文件已恢复，可信根重新匹配");
  };

  const highlightedNodes = useMemo(() => {
    const highlighted = new Set<string>();
    const metadata = tree.leaves_meta ?? [];
    for (const path of modifiedPaths) {
      let nodeIndex = metadata.findIndex((entry) => entry.path === path);
      if (nodeIndex < 0) continue;
      for (let level = 0; level < tree.levels.length; level += 1) {
        highlighted.add(`${level}:${nodeIndex}`);
        nodeIndex = Math.floor(nodeIndex / 2);
      }
    }
    return highlighted;
  }, [modifiedPaths, tree]);

  const findings = verification.report?.findings ?? [];

  return (
    <div className="wb-tool-page wb-tamper-page">
      <ToolTitle
        id="workbench-title-tamper"
        icon={<FlaskConical size={21} />}
        title="篡改实验"
        detail="改变一个文件字节，观察这次变化如何被发现并定位到具体文件。"
      />
      <div className="wb-tamper-toolbar">
        <label className="wb-file-button">
          <FolderOpen size={16} />
          <span>选择证据包</span>
          <input type="file" multiple {...inputDirectoryProps()} onChange={(event) => void loadDirectory(event.target.files)} />
        </label>
        <button type="button" className="wb-button wb-button-secondary" onClick={loadBuiltIn}>
          载入内置样例
        </button>
        <select value={selectedPath} onChange={(event) => setSelectedPath(event.target.value)} aria-label="选择要篡改的文件">
          {Object.keys(files).map((path) => <option key={path}>{path}</option>)}
        </select>
        <button type="button" className="wb-button wb-button-danger" onClick={() => void tamper()} disabled={busy || !selectedPath}>
          <Zap size={16} />篡改一个字节
        </button>
        <button type="button" className="wb-icon-button" onClick={() => void reset()} disabled={busy} title="重置文件" aria-label="重置文件">
          <RotateCcw size={16} />
        </button>
        <StatusLine status={status} busy={busy} />
      </div>

      <div className="wb-tamper-grid">
        <Pane title="文件路径">
          <div className="wb-tamper-files">
            {Object.entries(files).map(([path, hex]) => {
              const changed = modifiedPaths.includes(path);
              return (
                <button type="button" key={path} className={`${selectedPath === path ? "selected" : ""}${changed ? " changed" : ""}`} onClick={() => setSelectedPath(path)}>
                  <FileWarning size={16} />
                  <span>{path}</span>
                  <code>{hex.length / 2} B</code>
                  <strong>{changed ? "已改变" : "未改变"}</strong>
                </button>
              );
            })}
          </div>
        </Pane>

        <Pane
          title="变化传播路径"
          action={<span className={`wb-verdict ${tree.root?.matches ? "ok" : "bad"}`}>{tree.root?.matches ? "证据根匹配" : "证据根不匹配"}</span>}
        >
          {tree.levels.length > 0 ? (
            <div className="wb-tree-view">
              {[...tree.levels].map((nodes, reverseIndex) => {
                const level = tree.levels.length - reverseIndex - 1;
                const levelNodes = tree.levels[level];
                return (
                  <div className="wb-tree-level" key={level} style={{ gridTemplateColumns: `repeat(${levelNodes.length}, minmax(74px, 1fr))` }}>
                    {levelNodes.map((hash, nodeIndex) => {
                      const highlighted = highlightedNodes.has(`${level}:${nodeIndex}`);
                      const isLeaf = level === 0;
                      return (
                        <div className={`${highlighted ? "changed" : ""}${level === tree.levels.length - 1 ? " root" : ""}`} key={`${level}-${hash}-${nodeIndex}`}>
                          <span>{level === tree.levels.length - 1 ? "证据根" : isLeaf ? `文件节点 ${nodeIndex + 1}` : `中间节点 ${level}.${nodeIndex}`}</span>
                          <code>{shortValue(hash, 15)}</code>
                        </div>
                      );
                    })}
                  </div>
                );
              })}
              <div className="wb-root-comparison">
                <div><span>清单记录</span><code>{shortValue(tree.root?.recorded, 24)}</code></div>
                <div><span>当前计算</span><code>{shortValue(tree.root?.actual, 24)}</code></div>
              </div>
            </div>
          ) : <EmptyState>当前 Manifest 没有可显示的 Merkle 节点</EmptyState>}
        </Pane>

        <Pane title="检查结论" className={busy ? "wb-pane-running" : ""}>
          <ResultHero
            tone={verification.ok ? "success" : "danger"}
            title={verification.ok ? "证据包保持一致" : "篡改已被发现"}
            detail={verification.ok
              ? `${Object.keys(files).length} 个文件与证据清单记录一致`
              : `${modifiedPaths[0] ?? selectedPath} 的变化已经传播到证据根`}
          />
          {findings.length > 0 ? (
            <div className="wb-diagnostic-list">
              {findings.map((finding, index) => (
                <div key={`${finding.code}-${index}`}>
                  <strong>文件内容与记录不一致</strong>
                  <code>{finding.path}</code>
                  <p>当前文件摘要无法与证据清单中的记录匹配。</p>
                </div>
              ))}
            </div>
          ) : (
            <div className="wb-diagnostic-pass">
              <strong>没有诊断发现</strong>
              <p>文件摘要与记录的 Merkle 根一致。</p>
            </div>
          )}
          {findings.length > 0 && (
            <TechnicalDetails>
              <CodeBlock label="完整诊断报告">{verification.explain ?? JSON.stringify(findings, null, 2)}</CodeBlock>
            </TechnicalDetails>
          )}
        </Pane>
      </div>
    </div>
  );
}
