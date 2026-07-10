import { ArrowLeft, GitFork, ShieldCheck } from "lucide-react";

export type SiteSurface = "home" | "workbench";

export function SiteHeader({
  surface,
  onHome,
  onStory,
  onStart,
}: {
  surface: SiteSurface;
  onHome: () => void;
  onStory: () => void;
  onStart: () => void;
}) {
  return (
    <header className={`site-header site-header-${surface}`}>
      <button type="button" className="site-brand" onClick={onHome} aria-label="返回 MoonEvidence 首页">
        <span className="site-brand-mark" aria-hidden="true">
          <ShieldCheck size={20} strokeWidth={1.8} />
        </span>
        <strong>MoonEvidence</strong>
      </button>

      {surface === "home" ? (
        <nav className="site-nav" aria-label="首页导航">
          <button type="button" onClick={onStory}>工作原理</button>
          <a href="https://github.com/wenlittle/MoonEvidence" target="_blank" rel="noreferrer">
            <GitFork size={16} />
            <span>GitHub</span>
          </a>
        </nav>
      ) : (
        <span className="site-header-spacer" aria-hidden="true" />
      )}

      {surface === "home" ? (
        <button type="button" className="site-start" onClick={onStart}>
          开始使用
        </button>
      ) : (
        <button type="button" className="site-back site-back-workbench" onClick={onHome}>
          <ArrowLeft size={16} />
          返回首页
        </button>
      )}
    </header>
  );
}
