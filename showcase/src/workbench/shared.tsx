import type { ReactNode } from "react";
import { AlertTriangle, CheckCircle2, Circle, LoaderCircle } from "lucide-react";
import type { ToolStatus } from "./types";

export function ToolTitle({ icon, title, detail }: { icon: ReactNode; title: string; detail: string }) {
  return (
    <header className="wb-tool-title">
      <span aria-hidden="true">{icon}</span>
      <div>
        <h1>{title}</h1>
        <p>{detail}</p>
      </div>
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
    <div className={`wb-status wb-status-${status.tone}`} role="status">
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
