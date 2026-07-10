import { useEffect, useLayoutEffect, useRef } from "react";
import { gsap } from "gsap";
import { useStoryStore } from "../store";
import { LAST_STAGE } from "../types";

export function useStoryTimeline(ready: boolean) {
  const timelineRef = useRef<gsap.core.Timeline | null>(null);
  const playheadRef = useRef({ value: 0 });
  const playing = useStoryStore((state) => state.playing);
  const speed = useStoryStore((state) => state.speed);
  const mode = useStoryStore((state) => state.mode);
  const setProgress = useStoryStore((state) => state.setProgress);
  const setPlaying = useStoryStore((state) => state.setPlaying);

  useLayoutEffect(() => {
    if (!ready) return;
    const playhead = playheadRef.current;
    const timeline = gsap.timeline({
      paused: true,
      defaults: { ease: "none" },
      onComplete: () => setPlaying(false),
    });
    timeline.to(playhead, {
      value: LAST_STAGE,
      duration: 28,
      onUpdate: () => setProgress(playhead.value),
    });
    timelineRef.current = timeline;
    if (mode === "auto") timeline.play();
    return () => {
      timeline.kill();
      timelineRef.current = null;
    };
  }, [mode, ready, setPlaying, setProgress]);

  useEffect(() => {
    const timeline = timelineRef.current;
    if (!timeline) return;
    if (playing) timeline.play();
    else timeline.pause();
  }, [playing]);

  useEffect(() => {
    timelineRef.current?.timeScale(speed);
  }, [speed]);

  const seek = (value: number) => {
    const clamped = Math.max(0, Math.min(LAST_STAGE, value));
    playheadRef.current.value = clamped;
    timelineRef.current?.progress(clamped / LAST_STAGE, false);
    setProgress(clamped);
  };

  const step = (direction: -1 | 1) => {
    setPlaying(false);
    const current = useStoryStore.getState().progress;
    seek(Math.max(0, Math.min(LAST_STAGE, Math.round(current) + direction)));
  };

  const restart = () => {
    seek(0);
    if (useStoryStore.getState().mode === "auto") setPlaying(true);
  };

  return { seek, step, restart };
}
