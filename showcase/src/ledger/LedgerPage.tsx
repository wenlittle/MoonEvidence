import {
  ArrowRight,
  Blocks,
  Building2,
  Check,
  CircleCheck,
  Database,
  ExternalLink,
  FileCheck2,
  Fingerprint,
  GitCompare,
  Network,
  RotateCcw,
  ShieldCheck,
} from "lucide-react";
import type { CSSProperties } from "react";
import { ledgerRecord } from "./record";
import "./ledger.css";

const timeline = [
  { icon: FileCheck2, step: "01", title: "本地复核", text: "证据包先通过完整性验证，规范摘要随后进入提交路径。" },
  { icon: Fingerprint, step: "02", title: "组织提交", text: "Org1 使用 Fabric Gateway 提交摘要，文件内容继续留在链下。" },
  { icon: Blocks, step: "03", title: "区块确认", text: "交易进入区块 6，验证状态为 VALID，原始交易标识被固定。" },
  { icon: Building2, step: "04", title: "跨组织查询", text: "Org1 与 Org2 查询到同一摘要、同一提交者和同一原始交易。" },
  { icon: GitCompare, step: "05", title: "摘要回灌", text: "账本摘要返回验证器，文件变化和清单重建分别触发明确拒绝。" },
];

export function LedgerPage({ onStart }: { onStart: () => void }) {
  return (
    <div className="ledger-page">
      <section className="ledger-hero" aria-labelledby="ledger-title">
        <div className="ledger-hero-copy">
          <div className="ledger-kicker"><CircleCheck size={16} />真实网络记录 · {ledgerRecord.observedAt}</div>
          <h1 id="ledger-title">一份证据摘要<br />穿过两个组织</h1>
          <p>MoonEvidence 在链下完成文件复核，再把稳定摘要交给 Fabric。区块确认、跨组织查询和摘要回灌共同留下这次实验的完整路径。</p>
          <div className="ledger-hero-actions">
            <a href={ledgerRecord.paths.record} target="_blank" rel="noreferrer">
              查看原始记录 <ExternalLink size={15} />
            </a>
            <button type="button" onClick={onStart}>打开验证工作台 <ArrowRight size={16} /></button>
          </div>
        </div>

        <div className="ledger-route" aria-label="Fabric 交易路径">
          <div className="ledger-route-line" aria-hidden="true"><span /></div>
          <div className="ledger-route-node node-local"><ShieldCheck /><span>本地验证</span><strong>通过</strong></div>
          <div className="ledger-route-node node-org1"><Building2 /><span>Org1</span><strong>提交</strong></div>
          <div className="ledger-route-node node-block"><Blocks /><span>区块 6</span><strong>VALID</strong></div>
          <div className="ledger-route-node node-org2"><Building2 /><span>Org2</span><strong>同一记录</strong></div>
          <div className="ledger-route-caption"><Network size={16} />{ledgerRecord.runtime} · {ledgerRecord.channel}</div>
        </div>
      </section>

      <section className="ledger-facts" aria-label="交易结论">
        <div><span>区块</span><strong>{ledgerRecord.block}</strong><small>首次提交</small></div>
        <div><span>状态</span><strong className="fact-valid">{ledgerRecord.validation}</strong><small>交易已确认</small></div>
        <div><span>组织</span><strong>2</strong><small>查询结果一致</small></div>
        <div><span>通道高度</span><strong>{ledgerRecord.channelHeight}</strong><small>重复提交后</small></div>
      </section>

      <section className="ledger-story" aria-labelledby="ledger-story-title">
        <header>
          <span>交易路径</span>
          <h2 id="ledger-story-title">从文件复核到区块回查</h2>
          <p>每一步都对应一份可下载记录。流程中的摘要保持不变，文件内容始终留在本地。</p>
        </header>
        <div className="ledger-timeline">
          {timeline.map(({ icon: Icon, step, title, text }, index) => (
            <article key={step} style={{ "--delay": `${index * 90}ms` } as CSSProperties}>
              <div className="ledger-step"><Icon size={19} /><span>{step}</span></div>
              <h3>{title}</h3>
              <p>{text}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="ledger-receipt" aria-labelledby="ledger-receipt-title">
        <div className="ledger-receipt-heading">
          <span>区块回执</span>
          <h2 id="ledger-receipt-title">原始交易保持可追溯</h2>
          <p>Org2 再次提交相同摘要时，合约返回已锚定，并继续保留 Org1 的首笔交易。</p>
        </div>
        <div className="ledger-receipt-data">
          <div><span>Manifest 摘要</span><code>{ledgerRecord.digest}</code></div>
          <div><span>交易标识</span><code>{ledgerRecord.transactionId}</code></div>
          <div className="receipt-inline">
            <p><span>提交者</span><strong>{ledgerRecord.organizations[0]}</strong></p>
            <p><span>重复提交</span><strong>block {ledgerRecord.duplicateBlock} · already_anchored</strong></p>
          </div>
        </div>
      </section>

      <section className="ledger-outcomes" aria-labelledby="ledger-outcomes-title">
        <header>
          <span>回灌结果</span>
          <h2 id="ledger-outcomes-title">三种材料，三个确定结论</h2>
        </header>
        <div className="ledger-outcome-list">
          <div className="outcome-ok"><Check /><span>原始证据包</span><strong>2 / 2 文件通过</strong><small>账本摘要一致</small></div>
          <div className="outcome-bad"><RotateCcw /><span>文件发生变化</span><strong>E2003</strong><small>定位到 files/a.txt</small></div>
          <div className="outcome-bad"><Database /><span>重新生成清单</span><strong>E2004</strong><small>与原始账本摘要冲突</small></div>
        </div>
        <div className="ledger-evidence-links">
          <a href={ledgerRecord.paths.transactions} target="_blank" rel="noreferrer">交易记录 <ExternalLink size={14} /></a>
          <a href={ledgerRecord.paths.verification} target="_blank" rel="noreferrer">验证结果 <ExternalLink size={14} /></a>
          <a href={ledgerRecord.paths.guide} target="_blank" rel="noreferrer">复现实验 <ExternalLink size={14} /></a>
        </div>
      </section>
    </div>
  );
}
