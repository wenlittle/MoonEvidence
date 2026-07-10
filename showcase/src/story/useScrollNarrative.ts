import { useEffect, useState, type RefObject } from "react";

type ScrollNarrative = {
  chapter: number;
  chapterProgress: number;
  ratio: number;
};

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function smoothstep(value: number): number {
  const t = clamp(value, 0, 1);
  return t * t * (3 - 2 * t);
}

function mapNarrative(ratio: number): ScrollNarrative {
  const scaled = clamp(ratio, 0, 0.999999) * 4;
  const chapter = Math.floor(scaled);
  const local = smoothstep(scaled - chapter);
  return {
    chapter,
    chapterProgress: local,
    ratio,
  };
}

export function useScrollNarrative(
  railRef: RefObject<HTMLElement | null>,
): ScrollNarrative {
  const [narrative, setNarrative] = useState<ScrollNarrative>(() => mapNarrative(0));

  useEffect(() => {
    let frame = 0;

    const update = () => {
      frame = 0;
      const rail = railRef.current;
      if (!rail) return;
      const rect = rail.getBoundingClientRect();
      const distance = Math.max(1, rail.offsetHeight - window.innerHeight);
      const ratio = clamp(-rect.top / distance, 0, 1);
      const next = mapNarrative(ratio);
      setNarrative((current) => {
        if (
          current.chapter === next.chapter &&
          Math.abs(current.chapterProgress - next.chapterProgress) < 0.002
        ) {
          return current;
        }
        return next;
      });
    };

    const requestUpdate = () => {
      if (!frame) frame = window.requestAnimationFrame(update);
    };

    update();
    window.addEventListener("scroll", requestUpdate, { passive: true });
    window.addEventListener("resize", requestUpdate);
    return () => {
      window.removeEventListener("scroll", requestUpdate);
      window.removeEventListener("resize", requestUpdate);
      if (frame) window.cancelAnimationFrame(frame);
    };
  }, [railRef]);

  return narrative;
}
