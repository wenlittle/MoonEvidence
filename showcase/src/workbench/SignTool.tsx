import { useState } from "react";
import { Check, Copy, KeyRound, PenLine, ShieldCheck, ShieldX } from "lucide-react";
import { callMoon } from "../moon-rpc";
import { EmptyState, Pane, StatusLine, ToolTitle } from "./shared";
import type { Keypair, SignatureResponse, SignatureVerifyResponse, ToolStatus } from "./types";
import { shortValue, utf8Hex } from "./utils";

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
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<ToolStatus>({ tone: "neutral", text: "生成浏览器随机密钥开始签名流程" });

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
    setBusy(true);
    try {
      const activeKeypair = keypair ?? await ensureKeypair();
      const response = await callMoon<SignatureResponse>("ed25519_sign", {
        secret_key: activeKeypair.secret_key,
        message: utf8Hex(message),
      });
      if (!response.ok) throw new Error(response.error ?? "Signing failed");
      setSignature(response.signature);
      setValid(null);
      setTamperedValid(null);
      setStatus({ tone: "success", text: "消息已由 MoonBit Ed25519 签名" });
    } catch (error) {
      setStatus({ tone: "danger", text: error instanceof Error ? error.message : String(error) });
    } finally {
      setBusy(false);
    }
  };

  const verify = async () => {
    if (!keypair || !signature) return;
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
      setValid(accepted.valid);
      setTamperedValid(rejected.valid);
      const oraclePassed = accepted.valid && !rejected.valid;
      setStatus({
        tone: oraclePassed ? "success" : "danger",
        text: oraclePassed ? "原消息验签通过，篡改消息被拒绝" : "签名正反验证未满足预期",
      });
    } catch (error) {
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
        icon={<KeyRound size={21} />}
        title="Ed25519 数字签名"
        detail="随机密钥、签名、验签与篡改拒绝均在浏览器内调用纯 MoonBit 实现。"
      />
      <div className="wb-sign-grid">
        <Pane title="1 · 密钥">
          <button type="button" className="wb-button wb-button-primary" onClick={() => void generate()} disabled={busy}>
            <KeyRound size={16} />生成随机密钥
          </button>
          {keypair ? (
            <div className="wb-key-output">
              <div>
                <span>PUBLIC KEY</span>
                <code>{keypair.public_key}</code>
                <button type="button" className="wb-icon-button" onClick={() => void copy("pk", keypair.public_key)} title="复制公钥" aria-label="复制公钥">
                  {copied === "pk" ? <Check size={15} /> : <Copy size={15} />}
                </button>
              </div>
              <div>
                <span>SECRET KEY</span>
                <code>{keypair.secret_key}</code>
                <button type="button" className="wb-icon-button" onClick={() => void copy("sk", keypair.secret_key)} title="复制私钥" aria-label="复制私钥">
                  {copied === "sk" ? <Check size={15} /> : <Copy size={15} />}
                </button>
              </div>
            </div>
          ) : <EmptyState>尚未生成密钥</EmptyState>}
        </Pane>

        <Pane title="2 · 签名">
          <label className="wb-field">
            <span>消息</span>
            <textarea value={message} onChange={(event) => setMessage(event.target.value)} />
          </label>
          <button type="button" className="wb-button wb-button-primary" onClick={() => void sign()} disabled={busy || !message.trim()}>
            <PenLine size={16} />签名消息
          </button>
          {signature ? (
            <div className="wb-signature-value">
              <span>SIGNATURE</span>
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
              <strong>{valid === null ? "WAIT" : valid ? "VALID" : "INVALID"}</strong>
            </div>
            <div className={tamperedValid === false ? "pass" : tamperedValid ? "fail" : "idle"}>
              <ShieldX size={19} />
              <span>篡改消息</span>
              <strong>{tamperedValid === null ? "WAIT" : tamperedValid ? "VALID" : "REJECTED"}</strong>
            </div>
          </div>
          <StatusLine status={status} busy={busy} />
          {keypair && signature && <code className="wb-compact-proof">pk {shortValue(keypair.public_key)} · sig {shortValue(signature)}</code>}
        </Pane>
      </div>
    </div>
  );
}
