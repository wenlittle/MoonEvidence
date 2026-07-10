import { useState, type ReactNode } from "react";
import {
  AlertTriangle,
  CheckCircle2,
  ChevronDown,
  Circle,
  Info,
  LoaderCircle,
  LockKeyhole,
  ShieldX,
} from "lucide-react";
import type { ToolStatus } from "./types";

export function ToolTitle({
  icon,
  title,
  detail,
  id,
}: {
  icon: ReactNode;
  title: string;
  detail: string;
  id?: string;
}) {
  return (
    <header className="wb-tool-title">
      <span aria-hidden="true">{icon}</span>
      <div className="wb-tool-heading">
        <h1 id={id} tabIndex={-1}>{title}</h1>
        <p>{detail}</p>
      </div>
      <span className="wb-local-badge">
        <LockKeyhole size={13} />
        仅在浏览器本地处理
      </span>
    </header>
  );
}

export function Pane({
  title,
  action,
  children,
  className = "",
}: {
  title: string;
  action?: ReactNode;
  children: ReactNode;
  className?: string;
}) {
  return (
    <section className={`wb-pane ${className}`}>
      <header className="wb-pane-header">
        <h2>{title}</h2>
        {action}
      </header>
      <div className="wb-pane-body">{children}</div>
    </section>
  );
}

export function StatusLine({ status, busy = false }: { status: ToolStatus; busy?: boolean }) {
  const Icon = busy
    ? LoaderCircle
    : status.tone === "success"
      ? CheckCircle2
      : status.tone === "danger" || status.tone === "warning"
        ? AlertTriangle
        : Circle;
  return (
    <div className={`wb-status wb-status-${status.tone}`} role="status" aria-live="polite">
      <Icon size={15} className={busy ? "spin" : ""} />
      <span>{status.text}</span>
    </div>
  );
}

export function EmptyState({ children }: { children: ReactNode }) {
  return <div className="wb-empty">{children}</div>;
}

export function CodeBlock({ children, label }: { children: string; label?: string }) {
  return (
    <div className="wb-code-block">
      {label && <span>{label}</span>}
      <pre>{children}</pre>
    </div>
  );
}

export function ResultHero({
  tone,
  title,
  detail,
  label = "处理结果",
}: {
  tone: ToolStatus["tone"];
  title: string;
  detail: string;
  label?: string;
}) {
  const Icon = tone === "success"
    ? CheckCircle2
    : tone === "danger"
      ? ShieldX
      : tone === "warning"
        ? AlertTriangle
        : Info;

  return (
    <section className={`wb-result-hero wb-result-${tone}`} role="status" aria-live="polite">
      <span className="wb-result-icon" aria-hidden="true"><Icon size={24} /></span>
      <div>
        <span className="wb-result-label">{label}</span>
        <h3>{title}</h3>
        <p>{detail}</p>
      </div>
    </section>
  );
}

export function TechnicalDetails({
  children,
  label = "查看技术详情",
  defaultOpen = false,
}: {
  children: ReactNode;
  label?: string;
  defaultOpen?: boolean;
}) {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <section className={`wb-details${open ? " open" : ""}`}>
      <button type="button" onClick={() => setOpen((value) => !value)} aria-expanded={open}>
        <span>{label}</span>
        <ChevronDown size={16} aria-hidden="true" />
      </button>
      <div className="wb-details-region" aria-hidden={!open} inert={!open ? true : undefined}>
        <div className="wb-details-inner">{children}</div>
      </div>
    </section>
  );
}

export function NextActions({ children }: { children: ReactNode }) {
  return (
    <section className="wb-next-actions">
      <span>下一步</span>
      <div>{children}</div>
    </section>
  );
}
