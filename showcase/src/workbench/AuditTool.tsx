import { useMemo, useState } from "react";
import { BadgeCheck, KeyRound, Link2, ListPlus, ScrollText, ShieldCheck } from "lucide-react";
import { callMoon } from "../moon-rpc";
import { EmptyState, Pane, StatusLine, ToolTitle } from "./shared";
import type {
  AuditAppendResponse,
  AuditEntry,
  AuditSignResponse,
  AuditVerifyResponse,
  Keypair,
  ToolStatus,
} from "./types";
import { shortValue } from "./utils";

export function AuditTool({
  keypair,
  ensureKeypair,
}: {
  keypair: Keypair | null;
  ensureKeypair: () => Promise<Keypair>;
}) {
  const [actor, setActor] = useState("alice@example.com");
  const [action, setAction] = useState("created");
  const [subjectId, setSubjectId] = useState("my-evidence-pack");
  const [manifestDigest, setManifestDigest] = useState("");
  const [log, setLog] = useState("");
  const [verification, setVerification] = useState<AuditVerifyResponse | null>(null);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<ToolStatus>({ tone: "neutral", text: "追加第一条记录以建立哈希链" });

  const entries = useMemo<AuditEntry[]>(() => {
    if (!log) return [];
    try {
      return JSON.parse(log) as AuditEntry[];
    } catch {
      return [];
    }
  }, [log]);

  const append = async () => {
    setBusy(true);
    setStatus({ tone: "neutral", text: "正在计算新记录与前序哈希" });
    try {
      const response = await callMoon<AuditAppendResponse>("audit_append", {
        log: log || null,
        actor,
        action,
        subject_id: subjectId,
        manifest_digest: manifestDigest.trim() || null,
        timestamp: new Date().toISOString(),
      });
      if (!response.ok) throw new Error(response.error ?? "Audit append failed");
      setLog(response.log);
      setVerification(null);
      setStatus({ tone: "success", text: `记录已追加：${shortValue(response.entry_hash, 16)}` });
    } catch (error) {
      setStatus({ tone: "danger", text: error instanceof Error ? error.message : String(error) });
    } finally {
      setBusy(false);
    }
  };

  const verify = async (signatures: boolean) => {
    if (!log) {
      setStatus({ tone: "warning", text: "请先追加审计记录" });
      return;
    }
    setBusy(true);
    try {
      let activeKeypair = keypair;
      if (signatures && !activeKeypair) activeKeypair = await ensureKeypair();
      const response = await callMoon<AuditVerifyResponse>("audit_verify", {
        log,
        verify_signatures: signatures,
        public_key: signatures ? activeKeypair?.public_key : undefined,
      });
      if (!response.ok) throw new Error(response.error ?? "Audit verification failed");
      setVerification(response);
      const passed = response.chain_valid && (!signatures || response.signatures_valid);
      setStatus({
        tone: passed ? "success" : "danger",
        text: passed ? `${response.length} 条记录验证通过` : "审计链或签名验证失败",
      });
    } catch (error) {
      setStatus({ tone: "danger", text: error instanceof Error ? error.message : String(error) });
    } finally {
      setBusy(false);
    }
  };

  const signLast = async () => {
    if (!log) {
      setStatus({ tone: "warning", text: "请先追加审计记录" });
      return;
    }
    setBusy(true);
    try {
      const activeKeypair = keypair ?? await ensureKeypair();
      const response = await callMoon<AuditSignResponse>("audit_sign", {
        log,
        secret_key: activeKeypair.secret_key,
      });
      if (!response.ok) throw new Error(response.error ?? "Audit signing failed");
      setLog(response.log);
      setVerification(null);
      setStatus({ tone: "success", text: "最后一条记录已使用 Ed25519 签名" });
    } catch (error) {
      setStatus({ tone: "danger", text: error instanceof Error ? error.message : String(error) });
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="wb-tool-page">
      <ToolTitle
        icon={<ScrollText size={21} />}
        title="哈希链审计日志"
        detail="每条操作记录绑定前序哈希，并可使用共享 Ed25519 密钥签署最后一条记录。"
      />
      <div className="wb-split wb-split-audit">
        <Pane title="追加操作">
          <div className="wb-form-grid">
            <label className="wb-field wb-field-span-2">
              <span>Actor</span>
              <input value={actor} onChange={(event) => setActor(event.target.value)} />
            </label>
            <label className="wb-field">
              <span>Action</span>
              <select value={action} onChange={(event) => setAction(event.target.value)}>
                {['created', 'verified', 'sealed', 'signed', 'shared'].map((value) => <option key={value}>{value}</option>)}
              </select>
            </label>
            <label className="wb-field">
              <span>Subject ID</span>
              <input value={subjectId} onChange={(event) => setSubjectId(event.target.value)} />
            </label>
            <label className="wb-field wb-field-span-2">
              <span>Manifest Digest（可选）</span>
              <input value={manifestDigest} onChange={(event) => setManifestDigest(event.target.value)} placeholder="sha256:..." />
            </label>
          </div>
          <div className="wb-actions wb-actions-wrap">
            <button type="button" className="wb-button wb-button-primary" onClick={() => void append()} disabled={busy}>
              <ListPlus size={16} />追加记录
            </button>
            <button type="button" className="wb-button wb-button-secondary" onClick={() => void verify(false)} disabled={busy || !log}>
              <Link2 size={16} />验证链条
            </button>
            <button type="button" className="wb-button wb-button-secondary" onClick={() => void signLast()} disabled={busy || !log}>
              <KeyRound size={16} />签名末条
            </button>
            <button type="button" className="wb-button wb-button-secondary" onClick={() => void verify(true)} disabled={busy || !log}>
              <ShieldCheck size={16} />验证签名
            </button>
          </div>
          <StatusLine status={status} busy={busy} />
          <div className="wb-key-state">
            <KeyRound size={15} />
            <span>{keypair ? `共享公钥 ${shortValue(keypair.public_key, 20)}` : "签名时将生成浏览器随机密钥"}</span>
          </div>
        </Pane>

        <Pane
          title="审计时间线"
          action={verification ? (
            <span className={`wb-verdict ${verification.chain_valid ? "ok" : "bad"}`}>
              {verification.chain_valid ? "CHAIN OK" : "BROKEN"}
            </span>
          ) : undefined}
        >
          {entries.length > 0 ? (
            <div className="wb-audit-timeline">
              {entries.map((entry, index) => (
                <article key={`${entry.hash}-${index}`}>
                  <div className="wb-audit-index">{String(index + 1).padStart(2, "0")}</div>
                  <div>
                    <header>
                      <strong>{entry.action ?? "operation"}</strong>
                      {entry.signature && <BadgeCheck size={15} />}
                      <time>{entry.timestamp ?? ""}</time>
                    </header>
                    <p>{entry.actor ?? "unknown"} · {entry.subject_id ?? "subject"}</p>
                    <code>{shortValue(entry.hash, 30)}</code>
                  </div>
                </article>
              ))}
            </div>
          ) : (
            <EmptyState>审计记录会按哈希链顺序显示在这里</EmptyState>
          )}
        </Pane>
      </div>
    </div>
  );
}
