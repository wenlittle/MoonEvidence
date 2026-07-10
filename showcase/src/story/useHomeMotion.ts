import { useEffect, useRef, useState, type RefObject } from "react";

function clamp(value: number): number {
  return Math.min(1, Math.max(0, value));
}

function prefersReducedMotion(): boolean {
  return window.matchMedia?.("(prefers-reduced-motion: reduce)").matches ?? false;
}

function applyHeroProgress(hero: HTMLElement, progress: number): void {
  hero.style.setProperty("--hero-exit", progress.toFixed(4));
  hero.style.setProperty("--hero-copy-y", `${(-52 * progress).toFixed(2)}px`);
  hero.style.setProperty("--hero-copy-opacity", (1 - progress * 0.72).toFixed(4));
  hero.style.setProperty("--hero-copy-scale", (1 - progress * 0.025).toFixed(4));
  hero.style.setProperty("--hero-scene-opacity", (1 - progress * 0.42).toFixed(4));
  hero.style.setProperty("--hero-scene-scale", (1 + progress * 0.018).toFixed(4));
  hero.style.setProperty("--hero-scroll-opacity", (1 - progress).toFixed(4));
}

export function useHeroProgress(heroRef: RefObject<HTMLElement | null>): number {
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    const hero = heroRef.current;
    if (!hero || prefersReducedMotion()) {
      if (hero) applyHeroProgress(hero, 0);
      return;
    }

    let frame = 0;
    let lastProgress = -1;
    const update = () => {
      frame = 0;
      const rect = hero.getBoundingClientRect();
      const next = clamp(-rect.top / Math.max(1, rect.height * 0.82));
      if (Math.abs(lastProgress - next) < 0.001) return;
      lastProgress = next;
      applyHeroProgress(hero, next);
      setProgress((current) => Math.abs(current - next) < 0.004 ? current : next);
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
  }, [heroRef]);

  return progress;
}

export function useRevealOnce<T extends HTMLElement>(threshold = 0.24): {
  ref: RefObject<T | null>;
  visible: boolean;
} {
  const ref = useRef<T>(null);
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const element = ref.current;
    if (!element || prefersReducedMotion() || typeof IntersectionObserver === "undefined") {
      setVisible(true);
      return;
    }

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (!entry?.isIntersecting) return;
        setVisible(true);
        observer.disconnect();
      },
      { threshold, rootMargin: "0px 0px -10%" },
    );
    observer.observe(element);
    return () => observer.disconnect();
  }, [threshold]);

  return { ref, visible };
}
