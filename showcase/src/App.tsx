import { useEffect } from "react";
import { EvidenceScene } from "./scene/EvidenceScene";
import { Hud } from "./components/Hud";
import { buildEvidenceScenario } from "./moon-rpc";
import { useStoryStore } from "./store";
import { useStoryTimeline } from "./story/useStoryTimeline";
import { LoaderCircle, ShieldAlert } from "lucide-react";

export default function App() {
  const scenario = useStoryStore((state) => state.scenario);
  const loading = useStoryStore((state) => state.loading);
  const loadError = useStoryStore((state) => state.loadError);
  const progress = useStoryStore((state) => state.progress);
  const setScenario = useStoryStore((state) => state.setScenario);
  const setLoadError = useStoryStore((state) => state.setLoadError);
  const controls = useStoryTimeline(Boolean(scenario));

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
      <EvidenceScene scenario={scenario} progress={progress} />
      <Hud scenario={scenario} {...controls} />
    </main>
  );
}
