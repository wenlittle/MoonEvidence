import { Html, Line, RoundedBox } from "@react-three/drei";
import { Canvas, useFrame, useThree } from "@react-three/fiber";
import { useEffect, useMemo, useRef, useState } from "react";
import * as THREE from "three";
import type { EvidenceScenario } from "../types";
import { useSceneVisibility } from "./useSceneVisibility";

type Vec3 = [number, number, number];

const HERO_COLORS = {
  background: "#090b0a",
  paper: "#e8ece6",
  surface: "#171a18",
  line: "#5d6860",
  green: "#59c75f",
  red: "#d85e5e",
};

function useReducedMotionPreference(): boolean {
  const [reduced, setReduced] = useState(() =>
    typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches,
  );

  useEffect(() => {
    const query = window.matchMedia("(prefers-reduced-motion: reduce)");
    const update = () => setReduced(query.matches);
    query.addEventListener("change", update);
    return () => query.removeEventListener("change", update);
  }, []);

  return reduced;
}

function entranceProgress(elapsed: number, delay: number, reducedMotion: boolean): number {
  return reducedMotion ? 1 : THREE.MathUtils.smoothstep(elapsed, delay, delay + 0.78);
}

function HeroCamera({
  scrollProgress,
  reducedMotion,
}: {
  scrollProgress: number;
  reducedMotion: boolean;
}) {
  const { camera, size } = useThree();
  const target = useMemo(() => new THREE.Vector3(), []);

  useFrame((_, delta) => {
    const mobile = size.width < 720;
    const motion = reducedMotion ? 0 : scrollProgress;
    const baseY = mobile ? -0.35 : 0;
    const baseZ = mobile ? 15.8 : 12.4;
    target.set(0, baseY + motion * 0.15, baseZ + motion * 0.62);
    camera.position.lerp(target, 1 - Math.exp(-3.2 * delta));
    camera.lookAt(0, (mobile ? -0.55 : -0.3) - motion * 0.18, 0);
  });
  return null;
}

function DocumentSlab({
  position,
  rotation,
  changed = false,
  phase,
  appearAt,
  scrollProgress,
  reducedMotion,
}: {
  position: Vec3;
  rotation: Vec3;
  changed?: boolean;
  phase: number;
  appearAt: number;
  scrollProgress: number;
  reducedMotion: boolean;
}) {
  const group = useRef<THREE.Group>(null);
  const material = useRef<THREE.MeshStandardMaterial>(null);
  const direction = position[0] < 0 ? -1 : 1;

  useFrame((state, delta) => {
    if (!group.current) return;
    const intro = entranceProgress(state.clock.elapsedTime, appearAt, reducedMotion);
    const motion = reducedMotion ? 0 : scrollProgress;
    const drift = reducedMotion ? 0 : Math.sin(state.clock.elapsedTime * 0.55 + phase) * 0.08;
    const targetScale = (0.84 + intro * 0.16) * (1 - motion * 0.06);
    const scale = THREE.MathUtils.damp(group.current.scale.x, targetScale, 8, delta);

    group.current.visible = intro > 0.01;
    group.current.scale.setScalar(scale);
    group.current.position.x = THREE.MathUtils.damp(
      group.current.position.x,
      position[0] + (1 - intro) * direction * 1.15 + motion * direction * 0.52,
      7,
      delta,
    );
    group.current.position.y = THREE.MathUtils.damp(
      group.current.position.y,
      position[1] + (1 - intro) * 0.18 + drift,
      7,
      delta,
    );
    group.current.position.z = THREE.MathUtils.damp(
      group.current.position.z,
      position[2] - (1 - intro) * 1.1 - motion * 0.32,
      7,
      delta,
    );
    group.current.rotation.z =
      rotation[2] + (1 - intro) * direction * 0.045 +
      (reducedMotion ? 0 : Math.sin(state.clock.elapsedTime * 0.34 + phase) * 0.018);

    if (material.current) {
      material.current.opacity = THREE.MathUtils.damp(
        material.current.opacity,
        intro * (1 - motion * 0.38),
        8,
        delta,
      );
    }
  });

  return (
    <group
      ref={group}
      position={[
        position[0] + direction * (reducedMotion ? 0 : 1.15),
        position[1] + (reducedMotion ? 0 : 0.18),
        position[2] - (reducedMotion ? 0 : 1.1),
      ]}
      rotation={rotation}
      scale={reducedMotion ? 1 : 0.84}
      visible={reducedMotion}
    >
      <RoundedBox args={[1.72, 2.18, 0.14]} radius={0.06} smoothness={4}>
        <meshStandardMaterial
          ref={material}
          color={HERO_COLORS.surface}
          emissive={changed ? HERO_COLORS.red : HERO_COLORS.paper}
          emissiveIntensity={changed ? 0.18 : 0.1}
          metalness={0.08}
          opacity={reducedMotion ? 1 : 0}
          roughness={0.72}
          transparent
        />
      </RoundedBox>
      <mesh position={[-0.56, 0.58, 0.09]}>
        <boxGeometry args={[0.42, 0.08, 0.02]} />
        <meshBasicMaterial color={changed ? HERO_COLORS.red : HERO_COLORS.green} />
      </mesh>
      {[0.22, -0.02, -0.26].map((y, index) => (
        <mesh key={y} position={[index === 2 ? -0.08 : 0, y, 0.09]}>
          <boxGeometry args={[index === 2 ? 0.94 : 1.1, 0.035, 0.018]} />
          <meshBasicMaterial color="#7c8580" transparent opacity={0.72} />
        </mesh>
      ))}
    </group>
  );
}

function HeroPath({
  from,
  via,
  to,
  color,
  appearAt,
  scrollProgress,
  reducedMotion,
}: {
  from: Vec3;
  via: Vec3;
  to: Vec3;
  color: string;
  appearAt: number;
  scrollProgress: number;
  reducedMotion: boolean;
}) {
  const group = useRef<THREE.Group>(null);
  const relativeVia: Vec3 = [via[0] - from[0], via[1] - from[1], via[2] - from[2]];
  const relativeTo: Vec3 = [to[0] - from[0], to[1] - from[1], to[2] - from[2]];

  useFrame((state, delta) => {
    if (!group.current) return;
    const intro = entranceProgress(state.clock.elapsedTime, appearAt, reducedMotion);
    const targetScale = intro * (1 - (reducedMotion ? 0 : scrollProgress) * 0.05);
    const scale = THREE.MathUtils.damp(group.current.scale.x, targetScale, 8, delta);
    group.current.visible = intro > 0.01;
    group.current.scale.setScalar(scale);
  });

  return (
    <group ref={group} position={from} scale={reducedMotion ? 1 : 0} visible={reducedMotion}>
      <Line
        points={[[0, 0, 0], relativeVia, relativeTo]}
        color={color}
        lineWidth={1.1}
        transparent
        opacity={0.72 * (1 - scrollProgress * 0.52)}
      />
    </group>
  );
}

function FlowPulse({
  from,
  via,
  to,
  offset,
  activeAt,
  scrollProgress,
  reducedMotion,
}: {
  from: Vec3;
  via: Vec3;
  to: Vec3;
  offset: number;
  activeAt: number;
  scrollProgress: number;
  reducedMotion: boolean;
}) {
  const mesh = useRef<THREE.Mesh>(null);
  const start = useMemo(() => new THREE.Vector3(...from), [from]);
  const corner = useMemo(() => new THREE.Vector3(...via), [via]);
  const end = useMemo(() => new THREE.Vector3(...to), [to]);

  useFrame((state) => {
    if (!mesh.current) return;
    const elapsed = state.clock.elapsedTime;
    mesh.current.visible = !reducedMotion && elapsed >= activeAt && scrollProgress < 0.9;
    if (!mesh.current.visible) return;
    const t = ((elapsed - activeAt) * 0.12 + offset) % 1;
    if (t < 0.55) {
      mesh.current.position.lerpVectors(start, corner, t / 0.55);
    } else {
      mesh.current.position.lerpVectors(corner, end, (t - 0.55) / 0.45);
    }
  });

  return (
    <mesh ref={mesh} visible={false}>
      <sphereGeometry args={[0.055, 16, 16]} />
      <meshBasicMaterial color={HERO_COLORS.green} />
    </mesh>
  );
}

function EvidenceSeal({
  position,
  appearAt,
  scrollProgress,
  reducedMotion,
}: {
  position: Vec3;
  appearAt: number;
  scrollProgress: number;
  reducedMotion: boolean;
}) {
  const group = useRef<THREE.Group>(null);
  const label = useRef<HTMLDivElement>(null);

  useFrame((state, delta) => {
    if (!group.current) return;
    const intro = entranceProgress(state.clock.elapsedTime, appearAt, reducedMotion);
    const motion = reducedMotion ? 0 : scrollProgress;
    const introPulse = reducedMotion ? 0 : Math.sin(intro * Math.PI) * 0.08;
    const targetScale = (0.76 + intro * 0.24 + introPulse) * (1 - motion * 0.05);
    const scale = THREE.MathUtils.damp(group.current.scale.x, targetScale, 8, delta);

    group.current.visible = intro > 0.01;
    group.current.scale.setScalar(scale);
    group.current.position.y = THREE.MathUtils.damp(
      group.current.position.y,
      position[1] + motion * 0.34,
      7,
      delta,
    );
    group.current.rotation.z = reducedMotion
      ? 0
      : Math.sin(state.clock.elapsedTime * 0.35) * 0.025;
    if (label.current) {
      label.current.style.opacity = intro.toFixed(3);
      label.current.style.visibility = intro > 0.03 ? "visible" : "hidden";
    }
  });

  return (
    <group
      ref={group}
      position={position}
      scale={reducedMotion ? 1 : 0.76}
      visible={reducedMotion}
    >
      <mesh rotation={[Math.PI / 2, 0, 0]}>
        <cylinderGeometry args={[0.64, 0.64, 0.16, 6]} />
        <meshStandardMaterial
          color="#172019"
          emissive={HERO_COLORS.green}
          emissiveIntensity={0.34}
          metalness={0.35}
          roughness={0.42}
        />
      </mesh>
      <mesh position={[0, 0, 0.12]}>
        <ringGeometry args={[0.23, 0.29, 32]} />
        <meshBasicMaterial color={HERO_COLORS.green} />
      </mesh>
      <Html transform position={[0, -0.9, 0.12]} distanceFactor={7.4} center>
        <div
          ref={label}
          className="hero-seal-label"
          style={{ opacity: reducedMotion ? 1 : 0, visibility: reducedMotion ? "visible" : "hidden" }}
        >
          变化已定位
        </div>
      </Html>
    </group>
  );
}

function HeroComposition({
  scenario,
  scrollProgress,
  reducedMotion,
}: {
  scenario: EvidenceScenario;
  scrollProgress: number;
  reducedMotion: boolean;
}) {
  const group = useRef<THREE.Group>(null);
  const { size } = useThree();
  const mobile = size.width < 720;
  const compactHeight = !mobile && size.height < 620;
  const baseScale = mobile ? 0.72 : 1;
  const positions: Vec3[] = mobile
    ? [[-2.4, 1.75, -0.4], [2.45, 1.35, -0.2], [2.15, -2.25, -0.5]]
    : [[-5.15, 1.35, -0.4], [5.05, 1.5, -0.2], [4.2, -2.15, -0.5]];
  const sealPosition: Vec3 = [
    mobile ? -0.35 : 0,
    mobile ? -2.35 : compactHeight ? -2.85 : -2.15,
    0,
  ];
  const labels = [
    scenario.files[0]?.path.replace("files/", "") ?? "report.pdf",
    scenario.files[1]?.path.replace("files/", "") ?? "data.csv",
    "manifest.json",
  ];

  useFrame((_, delta) => {
    if (!group.current) return;
    const motion = reducedMotion ? 0 : scrollProgress;
    group.current.position.y = THREE.MathUtils.damp(
      group.current.position.y,
      motion * 0.46,
      6,
      delta,
    );
    const targetScale = baseScale * (1 - motion * 0.035);
    const scale = THREE.MathUtils.damp(group.current.scale.x, targetScale, 6, delta);
    group.current.scale.setScalar(scale);
  });

  return (
    <group ref={group} scale={baseScale}>
      {positions.map((position, index) => (
        <DocumentSlab
          key={labels[index]}
          position={position}
          rotation={[index === 2 ? -0.08 : 0.05, index === 0 ? 0.14 : -0.12, index === 0 ? -0.08 : 0.08]}
          changed={index === 2}
          phase={index * 1.7}
          appearAt={0.06 + index * 0.14}
          scrollProgress={scrollProgress}
          reducedMotion={reducedMotion}
        />
      ))}
      {positions.map((position, index) => {
        const via: Vec3 = [position[0] * 0.76, sealPosition[1], -0.1];
        return (
          <group key={`flow-${labels[index]}`}>
            <HeroPath
              from={position}
              via={via}
              to={sealPosition}
              color={index === 2 ? HERO_COLORS.red : HERO_COLORS.line}
              appearAt={0.46 + index * 0.08}
              scrollProgress={scrollProgress}
              reducedMotion={reducedMotion}
            />
            {index < 2 && (
              <FlowPulse
                from={position}
                via={via}
                to={sealPosition}
                offset={index * 0.31}
                activeAt={1.08 + index * 0.12}
                scrollProgress={scrollProgress}
                reducedMotion={reducedMotion}
              />
            )}
          </group>
        );
      })}
      <EvidenceSeal
        position={sealPosition}
        appearAt={0.72}
        scrollProgress={scrollProgress}
        reducedMotion={reducedMotion}
      />
    </group>
  );
}

export function HeroScene({
  scenario,
  scrollProgress,
}: {
  scenario: EvidenceScenario;
  scrollProgress: number;
}) {
  const { ref, visible } = useSceneVisibility(true);
  const reducedMotion = useReducedMotionPreference();

  return (
    <div ref={ref} className="hero-scene" aria-hidden="true">
      {visible && (
        <Canvas
          dpr={[1, 1.75]}
          gl={{ antialias: true, powerPreference: "high-performance" }}
          camera={{ position: [0, 0, 12.4], fov: 43, near: 0.1, far: 80 }}
        >
          <color attach="background" args={[HERO_COLORS.background]} />
          <fog attach="fog" args={[HERO_COLORS.background, 10, 26]} />
          <ambientLight intensity={1.25} />
          <directionalLight position={[3, 7, 8]} intensity={2.2} color="#f0f3ee" />
          <directionalLight position={[-5, 1, 5]} intensity={0.85} color={HERO_COLORS.green} />
          <HeroCamera scrollProgress={scrollProgress} reducedMotion={reducedMotion} />
          <HeroComposition
            scenario={scenario}
            scrollProgress={scrollProgress}
            reducedMotion={reducedMotion}
          />
        </Canvas>
      )}
    </div>
  );
}
