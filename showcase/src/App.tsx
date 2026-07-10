import { useEffect, useState } from "react";
import { EvidenceScene } from "./scene/EvidenceScene";
import { Hud, type SiteSurface } from "./components/Hud";
import { buildEvidenceScenario } from "./moon-rpc";
import { useStoryStore } from "./store";
import { useStoryTimeline } from "./story/useStoryTimeline";
import { LoaderCircle, ShieldAlert } from "lucide-react";

export default function App() {
  const [surface, setSurface] = useState<SiteSurface>("observatory");
  const [workbenchMounted, setWorkbenchMounted] = useState(false);
  const scenario = useStoryStore((state) => state.scenario);
  const loading = useStoryStore((state) => state.loading);
  const loadError = useStoryStore((state) => state.loadError);
  const progress = useStoryStore((state) => state.progress);
  const setScenario = useStoryStore((state) => state.setScenario);
  const setLoadError = useStoryStore((state) => state.setLoadError);
  const controls = useStoryTimeline(Boolean(scenario));

  const changeSurface = (nextSurface: SiteSurface) => {
    if (nextSurface === "workbench") setWorkbenchMounted(true);
    setSurface(nextSurface);
  };

  useEffect(() => {
    let active = true;
    buildEvidenceScenario()
      .then((result) => {
        if (active) setScenario(result);
      })
      .catch((error) => {
        if (active) setLoadError(error instanceof Error ? error.message : String(error));
      });
    return () => {
      active = false;
    };
  }, [setLoadError, setScenario]);

  if (loading) {
    return (
      <main className="loading-screen">
        <LoaderCircle size={28} className="spin" />
        <strong>MoonEvidence</strong>
        <span>正在装载 MoonBit 可信计算核心</span>
      </main>
    );
  }

  if (loadError || !scenario) {
    return (
      <main className="loading-screen error-screen">
        <ShieldAlert size={30} />
        <strong>观测台装载失败</strong>
        <span>{loadError ?? "Evidence scenario unavailable"}</span>
      </main>
    );
  }

  return (
    <main className="app-shell">
      {surface === "observatory" ? (
        <EvidenceScene scenario={scenario} progress={progress} />
      ) : null}
      {workbenchMounted && (
        <section
          className={`workbench-shell${surface === "workbench" ? " active" : ""}`}
          aria-label="MoonEvidence 证据工作台"
          aria-hidden={surface !== "workbench"}
        >
          <iframe src="./demo/web/index.html?embedded=1" title="MoonEvidence Trust Workbench" />
        </section>
      )}
      <Hud
        scenario={scenario}
        surface={surface}
        setSurface={changeSurface}
        {...controls}
      />
    </main>
  );
}
