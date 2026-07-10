import { create } from "zustand";
import type { EvidenceScenario, StoryMode } from "./types";

type ChallengeState = "idle" | "correct" | "wrong";

type StoryState = {
  scenario: EvidenceScenario | null;
  loading: boolean;
  loadError: string | null;
  progress: number;
  playing: boolean;
  speed: number;
  mode: StoryMode;
  challenge: ChallengeState;
  selectedPath: string | null;
  setScenario: (scenario: EvidenceScenario) => void;
  setLoadError: (message: string) => void;
  setProgress: (progress: number) => void;
  setPlaying: (playing: boolean) => void;
  setSpeed: (speed: number) => void;
  setMode: (mode: StoryMode) => void;
  setSelectedPath: (path: string | null) => void;
  submitChallenge: (path: string) => void;
  resetChallenge: () => void;
};

export const useStoryStore = create<StoryState>((set, get) => ({
  scenario: null,
  loading: true,
  loadError: null,
  progress: 0,
  playing: true,
  speed: 1,
  mode: "auto",
  challenge: "idle",
  selectedPath: null,
  setScenario: (scenario) => set({ scenario, loading: false, loadError: null }),
  setLoadError: (message) => set({ loadError: message, loading: false, playing: false }),
  setProgress: (progress) => set({ progress }),
  setPlaying: (playing) => set({ playing }),
  setSpeed: (speed) => set({ speed }),
  setMode: (mode) => {
    if (mode === "auto") {
      set({ mode, playing: true, challenge: "idle", selectedPath: null });
      return;
    }
    if (mode === "challenge") {
      set({ mode, playing: false, progress: 6, challenge: "idle", selectedPath: null });
      return;
    }
    set({ mode, playing: false, challenge: "idle", selectedPath: null });
  },
  setSelectedPath: (selectedPath) => set({ selectedPath }),
  submitChallenge: (path) => {
    const scenario = get().scenario;
    if (!scenario) return;
    set({
      selectedPath: path,
      challenge: path === scenario.tamperedPath ? "correct" : "wrong",
      progress: path === scenario.tamperedPath ? 7 : 6,
    });
  },
  resetChallenge: () => set({ challenge: "idle", selectedPath: null, progress: 6 }),
}));
