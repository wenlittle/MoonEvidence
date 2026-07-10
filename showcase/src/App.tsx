import { useEffect, useState } from "react";
import { HomePage } from "./components/HomePage";
import { SiteHeader, type SiteSurface } from "./components/SiteHeader";
import { buildEvidenceScenario } from "./moon-rpc";
import { useStoryStore } from "./store";
import { LoaderCircle, ShieldAlert } from "lucide-react";
import { Workbench, type WorkbenchView } from "./workbench/Workbench";

const WORKBENCH_VIEWS: WorkbenchView[] = ["verify", "create", "proof", "audit", "sign", "tamper"];

function readLocation(): { surface: SiteSurface; view: WorkbenchView } {
  const match = window.location.hash.match(/^#workbench(?:\/(\w+))?$/);
  const requested = match?.[1] as WorkbenchView | undefined;
  return {
    surface: match ? "workbench" : "home",
    view: requested && WORKBENCH_VIEWS.includes(requested) ? requested : "verify",
  };
}

export default function App() {
  const initialLocation = readLocation();
  const [surface, setSurface] = useState<SiteSurface>(initialLocation.surface);
  const [workbenchView, setWorkbenchView] = useState<WorkbenchView>(initialLocation.view);
  const [workbenchMounted, setWorkbenchMounted] = useState(initialLocation.surface === "workbench");
  const scenario = useStoryStore((state) => state.scenario);
  const loading = useStoryStore((state) => state.loading);
  const loadError = useStoryStore((state) => state.loadError);
  const setScenario = useStoryStore((state) => state.setScenario);
  const setLoadError = useStoryStore((state) => state.setLoadError);

  const openWorkbench = (view: WorkbenchView = "verify") => {
    if (surface === "workbench" && workbenchView === view) return;
    setWorkbenchView(view);
    setWorkbenchMounted(true);
    setSurface("workbench");
    window.history.pushState(null, "", `#workbench/${view}`);
  };

  const changeWorkbenchView = (view: WorkbenchView) => {
    if (workbenchView === view) return;
    setWorkbenchView(view);
    window.history.pushState(null, "", `#workbench/${view}`);
  };

  const openHome = () => {
    if (surface === "home") {
      window.scrollTo({ top: 0, behavior: "smooth" });
      return;
    }
    setSurface("home");
    window.history.pushState(null, "", `${window.location.pathname}${window.location.search}`);
    window.requestAnimationFrame(() => window.scrollTo({ top: 0, behavior: "smooth" }));
  };

  const scrollToStory = () => {
    if (surface !== "home") {
      setSurface("home");
      window.history.pushState(null, "", `${window.location.pathname}${window.location.search}`);
      window.requestAnimationFrame(() => {
        document.querySelector("#story-intro")?.scrollIntoView({ behavior: "smooth" });
      });
      return;
    }
    document.querySelector("#story-intro")?.scrollIntoView({ behavior: "smooth" });
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

  useEffect(() => {
    const syncLocation = () => {
      const next = readLocation();
      setSurface(next.surface);
      setWorkbenchView(next.view);
      if (next.surface === "workbench") setWorkbenchMounted(true);
    };
    window.addEventListener("popstate", syncLocation);
    window.addEventListener("hashchange", syncLocation);
    return () => {
      window.removeEventListener("popstate", syncLocation);
      window.removeEventListener("hashchange", syncLocation);
    };
  }, []);

  useEffect(() => {
    document.documentElement.classList.toggle("workbench-open", surface === "workbench");
    return () => document.documentElement.classList.remove("workbench-open");
  }, [surface]);

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
    <main className={`app-shell app-${surface}`}>
      <SiteHeader
        surface={surface}
        onHome={openHome}
        onStory={scrollToStory}
        onStart={() => openWorkbench("verify")}
      />
      {surface === "home" && (
        <HomePage scenario={scenario} openWorkbench={openWorkbench} />
      )}
      {workbenchMounted && (
        <section
          className={`workbench-shell${surface === "workbench" ? " active" : ""}`}
          aria-label="MoonEvidence 证据工作台"
          aria-hidden={surface !== "workbench"}
        >
          <Workbench
            scenario={scenario}
            requestedView={workbenchView}
            onViewChange={changeWorkbenchView}
          />
        </section>
      )}
    </main>
  );
}
