import { useRef, useState } from "react";
import { Check, Copy, Eye, EyeOff, KeyRound, PenLine, ShieldCheck, ShieldX } from "lucide-react";
import { callMoon } from "../moon-rpc";
import { EmptyState, Pane, ResultHero, StatusLine, ToolTitle } from "./shared";
import type { Keypair, SignatureResponse, SignatureVerifyResponse, ToolStatus } from "./types";
import { utf8Hex } from "./utils";

export function SignTool({
  keypair,
  ensureKeypair,
}: {
  keypair: Keypair | null;
  ensureKeypair: () => Promise<Keypair>;
}) {
  const [message, setMessage] = useState("hello moonbit");
  const [signature, setSignature] = useState("");
  const [valid, setValid] = useState<boolean | null>(null);
  const [tamperedValid, setTamperedValid] = useState<boolean | null>(null);
  const [copied, setCopied] = useState<string | null>(null);
  const [showSecret, setShowSecret] = useState(false);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<ToolStatus>({ tone: "neutral", text: "生成浏览器随机密钥开始签名流程" });
  const revision = useRef(0);

  const generate = async () => {
    setBusy(true);
    try {
      await ensureKeypair();
      setSignature("");
      setValid(null);
      setTamperedValid(null);
      setStatus({ tone: "success", text: "32 字节随机种子已在浏览器生成并交给 MoonBit" });
    } catch (error) {
      setStatus({ tone: "danger", text: error instanceof Error ? error.message : String(error) });
    } finally {
      setBusy(false);
    }
  };

  const sign = async () => {
    const activeRevision = revision.current;
    setBusy(true);
    try {
      const activeKeypair = keypair ?? await ensureKeypair();
      const response = await callMoon<SignatureResponse>("ed25519_sign", {
        secret_key: activeKeypair.secret_key,
        message: utf8Hex(message),
      });
      if (!response.ok) throw new Error(response.error ?? "Signing failed");
      if (activeRevision !== revision.current) return;
      setSignature(response.signature);
      setValid(null);
      setTamperedValid(null);
      setStatus({ tone: "success", text: "消息已由 MoonBit Ed25519 签名" });
    } catch (error) {
      if (activeRevision !== revision.current) return;
      setStatus({ tone: "danger", text: error instanceof Error ? error.message : String(error) });
    } finally {
      setBusy(false);
    }
  };

  const verify = async () => {
    if (!keypair || !signature) return;
    const activeRevision = revision.current;
    setBusy(true);
    try {
      const [accepted, rejected] = await Promise.all([
        callMoon<SignatureVerifyResponse>("ed25519_verify", {
          public_key: keypair.public_key,
          message: utf8Hex(message),
          signature,
        }),
        callMoon<SignatureVerifyResponse>("ed25519_verify", {
          public_key: keypair.public_key,
          message: utf8Hex(`${message}#tampered`),
          signature,
        }),
      ]);
      if (activeRevision !== revision.current) return;
      setValid(accepted.valid);
      setTamperedValid(rejected.valid);
      const oraclePassed = accepted.valid && !rejected.valid;
      setStatus({
        tone: oraclePassed ? "success" : "danger",
        text: oraclePassed ? "原消息验签通过，篡改消息被拒绝" : "签名正反验证未满足预期",
      });
    } catch (error) {
      if (activeRevision !== revision.current) return;
      setStatus({ tone: "danger", text: error instanceof Error ? error.message : String(error) });
    } finally {
      setBusy(false);
    }
  };

  const copy = async (name: string, value: string) => {
    await navigator.clipboard.writeText(value);
    setCopied(name);
    window.setTimeout(() => setCopied(null), 1200);
  };

  return (
    <div className="wb-tool-page">
      <ToolTitle
        id="workbench-title-sign"
        icon={<KeyRound size={21} />}
        title="签名与验签"
        detail="为一段内容生成数字签名，并确认修改后的内容无法继续通过验签。"
      />
      <div className="wb-sign-grid">
        <Pane title="1 · 密钥">
          <button type="button" className="wb-button wb-button-primary" onClick={() => void generate()} disabled={busy}>
            <KeyRound size={16} />生成随机密钥
          </button>
          {keypair ? (
            <div className="wb-key-output">
              <div>
                <span>公钥</span>
                <code>{keypair.public_key}</code>
                <button type="button" className="wb-icon-button" onClick={() => void copy("pk", keypair.public_key)} title="复制公钥" aria-label="复制公钥">
                  {copied === "pk" ? <Check size={15} /> : <Copy size={15} />}
                </button>
              </div>
              <div>
                <span>演示私钥</span>
                <code>{showSecret ? keypair.secret_key : "仅保留在当前浏览器会话中"}</code>
                <button type="button" className="wb-icon-button" onClick={() => setShowSecret((value) => !value)} title={showSecret ? "隐藏私钥" : "显示私钥"} aria-label={showSecret ? "隐藏私钥" : "显示私钥"}>
                  {showSecret ? <EyeOff size={15} /> : <Eye size={15} />}
                </button>
              </div>
              <p className="wb-security-note"><ShieldCheck size={14} />演示密钥不会上传，刷新页面后失效。</p>
            </div>
          ) : <EmptyState>尚未生成密钥</EmptyState>}
        </Pane>

        <Pane title="2 · 签名">
          <label className="wb-field">
            <span>消息</span>
            <textarea
              value={message}
              onChange={(event) => {
                revision.current += 1;
                setMessage(event.target.value);
                setSignature("");
                setValid(null);
                setTamperedValid(null);
                setStatus({ tone: "warning", text: "消息已修改，请重新签名" });
              }}
            />
          </label>
          <button type="button" className="wb-button wb-button-primary" onClick={() => void sign()} disabled={busy || !message.trim()}>
            <PenLine size={16} />签名消息
          </button>
          {signature ? (
            <div className="wb-signature-value">
              <span>数字签名</span>
              <code>{signature}</code>
              <button type="button" className="wb-icon-button" onClick={() => void copy("sig", signature)} title="复制签名" aria-label="复制签名">
                {copied === "sig" ? <Check size={15} /> : <Copy size={15} />}
              </button>
            </div>
          ) : <EmptyState>签名将在这里显示</EmptyState>}
        </Pane>

        <Pane title="3 · 验证">
          <button type="button" className="wb-button wb-button-primary" onClick={() => void verify()} disabled={busy || !keypair || !signature}>
            <ShieldCheck size={16} />执行双向验签
          </button>
          <div className="wb-sign-verdicts">
            <div className={valid ? "pass" : valid === false ? "fail" : "idle"}>
              <ShieldCheck size={19} />
              <span>原始消息</span>
              <strong>{valid === null ? "等待" : valid ? "有效" : "无效"}</strong>
            </div>
            <div className={tamperedValid === false ? "pass" : tamperedValid ? "fail" : "idle"}>
              <ShieldX size={19} />
              <span>篡改消息</span>
              <strong>{tamperedValid === null ? "等待" : tamperedValid ? "异常有效" : "已拒绝"}</strong>
            </div>
          </div>
          {valid !== null && tamperedValid !== null && (
            <ResultHero
              tone={valid && !tamperedValid ? "success" : "danger"}
              title={valid && !tamperedValid ? "签名验证通过" : "签名验证未通过"}
              detail={valid && !tamperedValid ? "签名与当前公钥和消息匹配，篡改对照已被拒绝" : "当前签名结果未满足正反验证要求"}
            />
          )}
          <StatusLine status={status} busy={busy} />
        </Pane>
      </div>
    </div>
  );
}
