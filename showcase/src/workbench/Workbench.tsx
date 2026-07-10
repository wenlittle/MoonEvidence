import { useState } from "react";
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

type WorkbenchView = "verify" | "create" | "proof" | "audit" | "sign" | "tamper";

const TABS: Array<{ id: WorkbenchView; label: string; icon: typeof FileCheck2 }> = [
  { id: "verify", label: "验证", icon: FileCheck2 },
  { id: "create", label: "创建", icon: FilePlus2 },
  { id: "proof", label: "证明", icon: GitBranch },
  { id: "audit", label: "审计", icon: ScrollText },
  { id: "sign", label: "签名", icon: KeyRound },
  { id: "tamper", label: "篡改实验", icon: FlaskConical },
];

export function Workbench({ scenario }: { scenario: EvidenceScenario }) {
  const [activeView, setActiveView] = useState<WorkbenchView>("verify");
  const [keypair, setKeypair] = useState<Keypair | null>(null);

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
                onClick={() => setActiveView(tab.id)}
                aria-pressed={activeView === tab.id}
              >
                <Icon size={16} />
                <span>{tab.label}</span>
              </button>
            );
          })}
        </div>
        <div className="wb-runtime-contract">
          <span />
          1 Worker · 12 MoonBit APIs
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
