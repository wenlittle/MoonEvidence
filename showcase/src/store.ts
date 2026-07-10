import { create } from "zustand";
import type { EvidenceScenario } from "./types";

type StoryState = {
  scenario: EvidenceScenario | null;
  loading: boolean;
  loadError: string | null;
  setScenario: (scenario: EvidenceScenario) => void;
  setLoadError: (message: string) => void;
};

export const useStoryStore = create<StoryState>((set) => ({
  scenario: null,
  loading: true,
  loadError: null,
  setScenario: (scenario) => set({ scenario, loading: false, loadError: null }),
  setLoadError: (message) => set({ loadError: message, loading: false }),
}));
