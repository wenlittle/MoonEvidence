import {
  Activity,
  BadgeCheck,
  Braces,
  ChevronLeft,
  ChevronRight,
  CircleAlert,
  FileDigit,
  Gauge,
  Pause,
  Play,
  RefreshCw,
  ScanSearch,
  ShieldCheck,
} from "lucide-react";
import { useMemo } from "react";
import { useStoryStore } from "../store";
import { LAST_STAGE, STORY_STAGES, type EvidenceScenario, type StoryMode } from "../types";

function shortHash(value: string, length = 16): string {
  const clean = value.includes(":") ? value.split(":")[1] : value;
  return clean.length > length ? `${clean.slice(0, length)}...` : clean;
}

function modeLabel(mode: StoryMode): string {
  if (mode === "auto") return "自动演示";
  if (mode === "inspect") return "自由检查";
  return "篡改挑战";
}

function TopBar() {
  const mode = useStoryStore((state) => state.mode);
  const setMode = useStoryStore((state) => state.setMode);
  const modes: { value: StoryMode; label: string }[] = [
    { value: "auto", label: "自动" },
    { value: "inspect", label: "检查" },
    { value: "challenge", label: "挑战" },
  ];

  return (
    <header className="topbar">
      <div className="brand-lockup">
        <div className="brand-mark" aria-hidden="true">
          <ShieldCheck size={22} strokeWidth={1.8} />
        </div>
        <div>
          <strong>MoonEvidence</strong>
          <span>Trust Observatory</span>
        </div>
      </div>
      <div className="runtime-status">
        <Activity size={15} aria-hidden="true" />
        <span>MoonBit core live</span>
      </div>
      <div className="mode-control" aria-label="演示模式">
        {modes.map((item) => (
          <button
            key={item.value}
            type="button"
            className={mode === item.value ? "active" : ""}
            onClick={() => setMode(item.value)}
            aria-pressed={mode === item.value}
          >
            {item.label}
          </button>
        ))}
      </div>
    </header>
  );
}

function StagePanel({ scenario }: { scenario: EvidenceScenario }) {
  const progress = useStoryStore((state) => state.progress);
  const mode = useStoryStore((state) => state.mode);
  const stageIndex = Math.max(0, Math.min(LAST_STAGE, Math.floor(progress + 0.15)));
  const stage = STORY_STAGES[stageIndex];
  const changed = scenario.files.find((file) => file.path === scenario.tamperedPath);

  return (
    <section className="stage-panel" aria-live="polite">
      <div className="stage-kicker">
        <span>{String(stageIndex + 1).padStart(2, "0")}</span>
        <span>{modeLabel(mode)}</span>
      </div>
      <h1>{stage.title}</h1>
      <p>{stage.detail}</p>
      <div className="stage-fact">
        {stageIndex < 2 && (
          <>
            <FileDigit size={18} />
            <div>
              <span>evidence subject</span>
              <strong>{scenario.manifest.subject.id}</strong>
            </div>
          </>
        )}
        {stageIndex >= 2 && stageIndex < 4 && (
          <>
            <Braces size={18} />
            <div>
              <span>active digest</span>
              <strong>{shortHash(scenario.files[0].originalDigest, 22)}</strong>
            </div>
          </>
        )}
        {stageIndex >= 4 && stageIndex < 6 && (
          <>
            <BadgeCheck size={18} />
            <div>
              <span>public key</span>
              <strong>{shortHash(scenario.publicKey, 22)}</strong>
            </div>
          </>
        )}
        {stageIndex >= 6 && (
          <>
            <CircleAlert size={18} />
            <div>
              <span>changed byte</span>
              <strong>{changed ? `${changed.path} @ ${changed.changedByte}` : "detected"}</strong>
            </div>
          </>
        )}
      </div>
    </section>
  );
}

function EvidenceTelemetry({ scenario }: { scenario: EvidenceScenario }) {
  const progress = useStoryStore((state) => state.progress);
  const split = progress >= 5.7;
  const signatureValid = split
    ? scenario.tamperedSignatureValid
    : scenario.originalSignatureValid;
  const findings = scenario.tamperedVerification.report?.findings ?? [];

  return (
    <aside className="telemetry-panel">
      <div className="telemetry-heading">
        <Gauge size={17} />
        <span>实时证据</span>
      </div>
      <dl>
        <div>
          <dt>Manifest</dt>
          <dd>{scenario.manifest.schema}</dd>
        </div>
        <div>
          <dt>Files</dt>
          <dd>{scenario.files.length}</dd>
        </div>
        <div>
          <dt>Original root</dt>
          <dd className="value-good">{shortHash(scenario.originalTree.root.actual)}</dd>
        </div>
        <div className={split ? "telemetry-row-visible" : "telemetry-row-hidden"}>
          <dt>Tampered root</dt>
          <dd className="value-bad">{shortHash(scenario.tamperedTree.root.actual)}</dd>
        </div>
        <div>
          <dt>Signature</dt>
          <dd className={signatureValid ? "value-good" : "value-bad"}>
            {signatureValid ? "valid" : "rejected"}
          </dd>
        </div>
      </dl>
      <div className={`finding-strip ${split ? "visible" : ""}`}>
        {findings.slice(0, 2).map((finding) => (
          <div key={`${finding.code}-${finding.path}`}>
            <strong>{finding.code}</strong>
            <span>{finding.path}</span>
          </div>
        ))}
      </div>
    </aside>
  );
}

function ChallengePanel({ scenario }: { scenario: EvidenceScenario }) {
  const mode = useStoryStore((state) => state.mode);
  const challenge = useStoryStore((state) => state.challenge);
  const selectedPath = useStoryStore((state) => state.selectedPath);
  const submitChallenge = useStoryStore((state) => state.submitChallenge);
  const resetChallenge = useStoryStore((state) => state.resetChallenge);

  if (mode !== "challenge") return null;
  return (
    <section className={`challenge-panel challenge-${challenge}`}>
      <div className="challenge-title">
        <ScanSearch size={18} />
        <strong>定位篡改源</strong>
      </div>
      <div className="challenge-files">
        {scenario.files.map((file) => (
          <button
            type="button"
            key={file.path}
            className={selectedPath === file.path ? "selected" : ""}
            onClick={() => submitChallenge(file.path)}
          >
            {file.path}
          </button>
        ))}
      </div>
      {challenge !== "idle" && (
        <div className="challenge-result">
          <span>{challenge === "correct" ? "定位成功" : "该文件路径保持稳定"}</span>
          <button type="button" onClick={resetChallenge} title="重新挑战" aria-label="重新挑战">
            <RefreshCw size={15} />
          </button>
        </div>
      )}
    </section>
  );
}

function TimelineControls({
  seek,
  step,
  restart,
}: {
  seek: (value: number) => void;
  step: (direction: -1 | 1) => void;
  restart: () => void;
}) {
  const progress = useStoryStore((state) => state.progress);
  const playing = useStoryStore((state) => state.playing);
  const speed = useStoryStore((state) => state.speed);
  const mode = useStoryStore((state) => state.mode);
  const setPlaying = useStoryStore((state) => state.setPlaying);
  const setSpeed = useStoryStore((state) => state.setSpeed);

  const stageTicks = useMemo(() => STORY_STAGES.map((stage, index) => ({ stage, index })), []);

  return (
    <footer className="timeline-shell">
      <div className="transport-controls">
        <button type="button" onClick={restart} title="重新播放" aria-label="重新播放">
          <RefreshCw size={17} />
        </button>
        <button type="button" onClick={() => step(-1)} title="上一步" aria-label="上一步">
          <ChevronLeft size={19} />
        </button>
        <button
          type="button"
          className="play-button"
          onClick={() => setPlaying(!playing)}
          title={playing ? "暂停" : "播放"}
          aria-label={playing ? "暂停" : "播放"}
          disabled={mode === "challenge"}
        >
          {playing ? <Pause size={18} /> : <Play size={18} fill="currentColor" />}
        </button>
        <button type="button" onClick={() => step(1)} title="下一步" aria-label="下一步">
          <ChevronRight size={19} />
        </button>
      </div>
      <div className="timeline-track-area">
        <input
          aria-label="演示时间轴"
          type="range"
          min="0"
          max={LAST_STAGE}
          step="0.01"
          value={progress}
          onChange={(event) => {
            setPlaying(false);
            seek(Number(event.target.value));
          }}
          style={{ "--timeline-progress": `${(progress / LAST_STAGE) * 100}%` } as React.CSSProperties}
        />
        <div className="timeline-ticks" aria-hidden="true">
          {stageTicks.map(({ stage, index }) => (
            <button
              type="button"
              key={stage.label}
              className={progress >= index - 0.05 ? "reached" : ""}
              onClick={() => seek(index)}
              tabIndex={-1}
            >
              <span />
              {stage.label}
            </button>
          ))}
        </div>
      </div>
      <select
        value={speed}
        onChange={(event) => setSpeed(Number(event.target.value))}
        aria-label="播放速度"
        title="播放速度"
      >
        <option value="0.5">0.5x</option>
        <option value="1">1x</option>
        <option value="1.5">1.5x</option>
        <option value="2">2x</option>
      </select>
    </footer>
  );
}

export function Hud({
  scenario,
  seek,
  step,
  restart,
}: {
  scenario: EvidenceScenario;
  seek: (value: number) => void;
  step: (direction: -1 | 1) => void;
  restart: () => void;
}) {
  return (
    <div className="hud-root">
      <TopBar />
      <StagePanel scenario={scenario} />
      <EvidenceTelemetry scenario={scenario} />
      <ChallengePanel scenario={scenario} />
      <TimelineControls seek={seek} step={step} restart={restart} />
    </div>
  );
}
