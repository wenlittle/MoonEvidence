import { useEffect, useRef, useState } from "react";
import {
  FileCheck2,
  FilePlus2,
  FlaskConical,
  GitBranch,
  KeyRound,
  ScrollText,
  ShieldCheck,
} from "lucide-react";
import { callMoon, toHex } from "../moon-rpc";
import type { EvidenceScenario } from "../types";
import { AuditTool } from "./AuditTool";
import { CreateTool } from "./CreateTool";
import { ProofTool } from "./ProofTool";
import { SignTool } from "./SignTool";
import { TamperTool } from "./TamperTool";
import type { Keypair } from "./types";
import { VerifyTool } from "./VerifyTool";
import "./workbench.css";

export type WorkbenchView = "verify" | "create" | "proof" | "audit" | "sign" | "tamper";

const NAV_GROUPS: Array<{
  label: string;
  items: Array<{ id: WorkbenchView; label: string; icon: typeof FileCheck2 }>;
}> = [
  {
    label: "常用任务",
    items: [
      { id: "verify", label: "验证证据包", icon: FileCheck2 },
      { id: "create", label: "创建证据清单", icon: FilePlus2 },
    ],
  },
  {
    label: "证明与记录",
    items: [
      { id: "proof", label: "文件收录证明", icon: GitBranch },
      { id: "sign", label: "签名与验签", icon: KeyRound },
      { id: "audit", label: "操作记录", icon: ScrollText },
    ],
  },
  {
    label: "学习实验",
    items: [
      { id: "tamper", label: "篡改实验", icon: FlaskConical },
    ],
  },
];

const NAV_ITEMS = NAV_GROUPS.flatMap((group) => group.items);

export function Workbench({
  scenario,
  requestedView = "verify",
  onViewChange,
}: {
  scenario: EvidenceScenario;
  requestedView?: WorkbenchView;
  onViewChange?: (view: WorkbenchView) => void;
}) {
  const [activeView, setActiveView] = useState<WorkbenchView>(requestedView);
  const [keypair, setKeypair] = useState<Keypair | null>(null);
  const contentRef = useRef<HTMLElement>(null);

  useEffect(() => {
    setActiveView(requestedView);
    contentRef.current?.scrollTo({ top: 0 });
  }, [requestedView]);

  const selectView = (view: WorkbenchView) => {
    setActiveView(view);
    onViewChange?.(view);
    contentRef.current?.scrollTo({ top: 0 });
  };

  const ensureKeypair = async (): Promise<Keypair> => {
    if (keypair) return keypair;
    const seed = new Uint8Array(32);
    crypto.getRandomValues(seed);
    const response = await callMoon<Keypair>("ed25519_keypair", { seed: toHex(seed) });
    if (!response.ok) throw new Error(response.error ?? "Key generation failed");
    setKeypair(response);
    return response;
  };

  return (
    <div className="workbench-app">
      <aside className="wb-sidebar">
        <header className="wb-sidebar-header">
          <strong>证据工作台</strong>
          <span><ShieldCheck size={14} />MoonBit 本地运行</span>
        </header>
        <nav aria-label="证据工作台工具">
          {NAV_GROUPS.map((group) => (
            <section key={group.label} className="wb-nav-group">
              <h2>{group.label}</h2>
              {group.items.map((item) => {
                const Icon = item.icon;
                return (
                  <button
                    type="button"
                    key={item.id}
                    className={activeView === item.id ? "active" : ""}
                    onClick={() => selectView(item.id)}
                    aria-current={activeView === item.id ? "page" : undefined}
                  >
                    <Icon size={17} />
                    <span>{item.label}</span>
                  </button>
                );
              })}
            </section>
          ))}
        </nav>
        <p className="wb-sidebar-foot">文件不会离开当前浏览器</p>
      </aside>

      <div className="wb-mobile-tools">
        <label htmlFor="wb-tool-select">当前工具</label>
        <select
          id="wb-tool-select"
          value={activeView}
          onChange={(event) => selectView(event.target.value as WorkbenchView)}
        >
          {NAV_ITEMS.map((item) => <option value={item.id} key={item.id}>{item.label}</option>)}
        </select>
      </div>

      <main className="wb-content" ref={contentRef}>
        <section className={`wb-view${activeView === "verify" ? " active" : ""}`} aria-hidden={activeView !== "verify"}>
          <VerifyTool scenario={scenario} onNavigate={selectView} />
        </section>
        <section className={`wb-view${activeView === "create" ? " active" : ""}`} aria-hidden={activeView !== "create"}>
          <CreateTool scenario={scenario} />
        </section>
        <section className={`wb-view${activeView === "proof" ? " active" : ""}`} aria-hidden={activeView !== "proof"}>
          <ProofTool scenario={scenario} />
        </section>
        <section className={`wb-view${activeView === "audit" ? " active" : ""}`} aria-hidden={activeView !== "audit"}>
          <AuditTool keypair={keypair} ensureKeypair={ensureKeypair} />
        </section>
        <section className={`wb-view${activeView === "sign" ? " active" : ""}`} aria-hidden={activeView !== "sign"}>
          <SignTool keypair={keypair} ensureKeypair={ensureKeypair} />
        </section>
        <section className={`wb-view${activeView === "tamper" ? " active" : ""}`} aria-hidden={activeView !== "tamper"}>
          <TamperTool scenario={scenario} />
        </section>
      </main>
    </div>
  );
}
