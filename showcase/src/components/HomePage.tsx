import {
  ArrowDown,
  ArrowRight,
  CheckCircle2,
  ChevronDown,
  FileCheck2,
  FileText,
  Fingerprint,
  GitCompareArrows,
  PackageCheck,
  ShieldCheck,
  ShieldX,
} from "lucide-react";
import { useRef } from "react";
import { EvidenceScene } from "../scene/EvidenceScene";
import { HeroScene } from "../scene/HeroScene";
import { useHeroProgress, useRevealOnce } from "../story/useHomeMotion";
import { useScrollNarrative } from "../story/useScrollNarrative";
import type { EvidenceScenario } from "../types";
import type { WorkbenchView } from "../workbench/Workbench";

const STORY_CHAPTERS = [
  {
    number: "01",
    title: "材料进入证据包",
    detail: "文件与必要信息被放在一起，形成一份可以重复检查的材料集合。",
  },
  {
    number: "02",
    title: "形成可复核的凭证",
    detail: "每份内容生成唯一指纹，再汇聚、签名并锁定为一个整体结果。",
  },
  {
    number: "03",
    title: "一个字节改变，结果随之分叉",
    detail: "内容只发生极小变化，文件指纹和整体结果也会立即改变。",
  },
  {
    number: "04",
    title: "准确定位并拒绝不一致材料",
    detail: "验证器指出发生变化的文件，让结论清楚，技术证据仍可继续复核。",
  },
] as const;

function MobileStoryVisual({ chapter }: { chapter: number }) {
  if (chapter === 0) {
    return (
      <div className="mobile-story-visual" key="mobile-story-1" aria-hidden="true">
        <div className="mobile-source-pair">
          <span><FileText size={18} />a.txt</span>
          <span><FileText size={18} />b.bin</span>
        </div>
        <ArrowDown className="mobile-flow-arrow" size={20} />
        <div className="mobile-flow-result good"><PackageCheck size={21} />材料已整理</div>
      </div>
    );
  }

  if (chapter === 1) {
    return (
      <div className="mobile-story-visual mobile-story-row" key="mobile-story-2" aria-hidden="true">
        <div className="mobile-flow-node"><FileText size={20} /><span>文件内容</span></div>
        <ArrowRight className="mobile-flow-arrow" size={18} />
        <div className="mobile-flow-node good"><Fingerprint size={20} /><span>唯一指纹</span></div>
        <ArrowRight className="mobile-flow-arrow" size={18} />
        <div className="mobile-flow-node good"><ShieldCheck size={20} /><span>签名封存</span></div>
      </div>
    );
  }

  if (chapter === 2) {
    return (
      <div className="mobile-story-visual mobile-story-branches" key="mobile-story-3" aria-hidden="true">
        <div className="mobile-branch good"><span>原始结果</span><strong>保持一致</strong></div>
        <GitCompareArrows size={25} />
        <div className="mobile-branch bad"><span>修改后结果</span><strong>已经分叉</strong></div>
      </div>
    );
  }

  return (
    <div className="mobile-story-visual mobile-story-row" key="mobile-story-4" aria-hidden="true">
      <div className="mobile-flow-node bad"><FileText size={20} /><span>a.txt 变化</span></div>
      <ArrowRight className="mobile-flow-arrow bad" size={18} />
      <div className="mobile-flow-node bad"><Fingerprint size={20} /><span>整体不一致</span></div>
      <ArrowRight className="mobile-flow-arrow bad" size={18} />
      <div className="mobile-flow-node bad"><ShieldX size={20} /><span>拒绝通过</span></div>
    </div>
  );
}

export function HomePage({
  scenario,
  openWorkbench,
}: {
  scenario: EvidenceScenario;
  openWorkbench: (view: WorkbenchView) => void;
}) {
  const hero = useRef<HTMLElement>(null);
  const storyRail = useRef<HTMLElement>(null);
  const storyIntro = useRevealOnce<HTMLElement>(0.3);
  const closing = useRevealOnce<HTMLElement>(0.24);
  const heroProgress = useHeroProgress(hero);
  const narrative = useScrollNarrative(storyRail);
  const chapter = STORY_CHAPTERS[narrative.chapter];

  const scrollToStory = () => {
    document.querySelector("#story-intro")?.scrollIntoView({ behavior: "smooth" });
  };

  return (
    <div className="home-page">
      <section className="hero" ref={hero} aria-labelledby="hero-title">
        <HeroScene scenario={scenario} scrollProgress={heroProgress} />
        <div className="hero-copy">
          <h1 id="hero-title">MoonEvidence</h1>
          <p className="hero-statement">让文件在提交、归档或上链前，经得起修改与追查</p>
          <p className="hero-support">为文件生成可验证的证据包，在内容发生变化时准确发现并定位。</p>
          <div className="hero-actions">
            <button type="button" className="primary-action" onClick={() => openWorkbench("verify")}>
              开始验证
              <ArrowRight size={17} />
            </button>
            <button type="button" className="secondary-action" onClick={scrollToStory}>
              了解原理
            </button>
          </div>
        </div>
        <button type="button" className="hero-scroll" onClick={scrollToStory} aria-label="向下了解工作原理">
          <span>继续了解</span>
          <ChevronDown size={18} />
        </button>
      </section>

      <section
        className={`story-intro${storyIntro.visible ? " is-visible" : ""}`}
        id="story-intro"
        ref={storyIntro.ref}
      >
        <div className="story-intro-inner">
          <h2>一次改动，如何被发现</h2>
          <p>不从术语开始，只跟随一份材料完成一次验证。</p>
          <div className="story-summary" aria-label="验证故事概览">
            <span>建立凭证</span>
            <i aria-hidden="true" />
            <span>内容变化</span>
            <i aria-hidden="true" />
            <span>准确定位</span>
          </div>
        </div>
      </section>

      <section className="story-rail" ref={storyRail} aria-label="MoonEvidence 工作原理">
        <div className="story-sticky">
          <EvidenceScene
            scenario={scenario}
            chapter={narrative.chapter}
            progress={narrative.chapterProgress}
          />
          <MobileStoryVisual chapter={narrative.chapter} />
          <article className="story-copy" key={chapter.number}>
            <span className="story-number">{chapter.number} / 04</span>
            <h2>{chapter.title}</h2>
            <p>{chapter.detail}</p>
            {narrative.chapter === 3 && (
              <div className="story-outcome">
                <FileCheck2 size={19} />
                <div>
                  <strong>检测到 1 个文件发生变化</strong>
                  <span>{scenario.tamperedPath} 与原始记录不一致</span>
                </div>
              </div>
            )}
          </article>
          <div className="story-chapter-nav" aria-hidden="true">
            {STORY_CHAPTERS.map((item, index) => (
              <span key={item.number} className={index === narrative.chapter ? "active" : index < narrative.chapter ? "reached" : ""} />
            ))}
          </div>
        </div>
      </section>

      <section
        className={`home-closing${closing.visible ? " is-visible" : ""}`}
        ref={closing.ref}
      >
        <div className="home-closing-inner">
          <CheckCircle2 size={34} />
          <h2>现在，验证你的第一份证据包</h2>
          <p>文件只在浏览器本地处理，结论直接呈现，技术细节随时可以展开复核。</p>
          <div className="closing-actions">
            <button type="button" className="primary-action" onClick={() => openWorkbench("verify")}>
              打开工作台
              <ArrowRight size={17} />
            </button>
            <button type="button" className="secondary-action light" onClick={() => openWorkbench("tamper")}>
              试试篡改实验
            </button>
          </div>
          <div className="closing-proof" aria-label="工程可信信息">
            <span>纯 MoonBit</span>
            <span>353 项可执行测试</span>
            <span>四后端验证</span>
            <span>Apache-2.0</span>
          </div>
        </div>
      </section>

      <footer className="site-footer">
        <strong>MoonEvidence</strong>
        <span>可信证据包验证核心</span>
        <a href="#ledger">实链记录</a>
        <a href="https://github.com/wenlittle/MoonEvidence" target="_blank" rel="noreferrer">GitHub</a>
      </footer>
    </div>
  );
}
