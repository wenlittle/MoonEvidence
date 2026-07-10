import { useEffect, useRef, useState } from "react";

export function useSceneVisibility(initiallyVisible: boolean) {
  const ref = useRef<HTMLDivElement>(null);
  const [visible, setVisible] = useState(initiallyVisible);

  useEffect(() => {
    const element = ref.current;
    if (!element || typeof IntersectionObserver === "undefined") {
      setVisible(true);
      return;
    }

    const observer = new IntersectionObserver(
      ([entry]) => setVisible(entry?.isIntersecting ?? false),
      { rootMargin: "240px 0px", threshold: 0.01 },
    );
    observer.observe(element);
    return () => observer.disconnect();
  }, []);

  return { ref, visible };
}
