import { useEffect, useState } from "react";
import {
  FileCheck2,
  FilePlus2,
  FlaskConical,
  GitBranch,
  KeyRound,
  ScrollText,
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

const TABS: Array<{ id: WorkbenchView; label: string; icon: typeof FileCheck2 }> = [
  { id: "verify", label: "检查证据", icon: FileCheck2 },
  { id: "create", label: "创建证据包", icon: FilePlus2 },
  { id: "tamper", label: "篡改演示", icon: FlaskConical },
  { id: "proof", label: "文件证明", icon: GitBranch },
  { id: "audit", label: "操作记录", icon: ScrollText },
  { id: "sign", label: "数字签名", icon: KeyRound },
];

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

  useEffect(() => setActiveView(requestedView), [requestedView]);

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
      <nav className="wb-tabs" aria-label="证据工作台工具">
        <div className="wb-tabs-inner">
          {TABS.map((tab) => {
            const Icon = tab.icon;
            return (
              <button
                type="button"
                key={tab.id}
                className={activeView === tab.id ? "active" : ""}
                onClick={() => {
                  setActiveView(tab.id);
                  onViewChange?.(tab.id);
                }}
                aria-pressed={activeView === tab.id}
              >
                <Icon size={16} />
                <span>{tab.label}</span>
              </button>
            );
          })}
        </div>
      </nav>

      <div className="wb-content">
        <section className={`wb-view${activeView === "verify" ? " active" : ""}`} aria-hidden={activeView !== "verify"}>
          <VerifyTool scenario={scenario} />
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
      </div>
    </div>
  );
}
