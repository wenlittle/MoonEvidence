import { Canvas, useFrame, useThree } from "@react-three/fiber";
import { Html, Line, RoundedBox } from "@react-three/drei";
import { useMemo, useRef } from "react";
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

function HeroCamera() {
  const { camera, size } = useThree();
  useFrame((_, delta) => {
    const mobile = size.width < 720;
    const target = new THREE.Vector3(0, mobile ? -0.35 : 0, mobile ? 15.8 : 12.4);
    camera.position.lerp(target, 1 - Math.exp(-3.2 * delta));
    camera.lookAt(0, mobile ? -0.55 : -0.3, 0);
  });
  return null;
}

function DocumentSlab({
  position,
  rotation,
  changed = false,
  phase,
}: {
  position: Vec3;
  rotation: Vec3;
  changed?: boolean;
  phase: number;
}) {
  const group = useRef<THREE.Group>(null);

  useFrame((state) => {
    if (!group.current) return;
    group.current.position.y = position[1] + Math.sin(state.clock.elapsedTime * 0.55 + phase) * 0.08;
    group.current.rotation.z = rotation[2] + Math.sin(state.clock.elapsedTime * 0.34 + phase) * 0.018;
  });

  return (
    <group ref={group} position={position} rotation={rotation}>
      <RoundedBox args={[1.72, 2.18, 0.14]} radius={0.06} smoothness={4}>
        <meshStandardMaterial
          color={HERO_COLORS.surface}
          emissive={changed ? HERO_COLORS.red : HERO_COLORS.paper}
          emissiveIntensity={changed ? 0.18 : 0.1}
          metalness={0.08}
          roughness={0.72}
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

function FlowPulse({ from, to, offset }: { from: Vec3; to: Vec3; offset: number }) {
  const mesh = useRef<THREE.Mesh>(null);
  const start = useMemo(() => new THREE.Vector3(...from), [from]);
  const end = useMemo(() => new THREE.Vector3(...to), [to]);

  useFrame((state) => {
    if (!mesh.current) return;
    const t = (state.clock.elapsedTime * 0.12 + offset) % 1;
    mesh.current.position.lerpVectors(start, end, t);
  });

  return (
    <mesh ref={mesh}>
      <sphereGeometry args={[0.055, 16, 16]} />
      <meshBasicMaterial color={HERO_COLORS.green} />
    </mesh>
  );
}

function EvidenceSeal({ position }: { position: Vec3 }) {
  const group = useRef<THREE.Group>(null);
  useFrame((state) => {
    if (!group.current) return;
    group.current.rotation.z = Math.sin(state.clock.elapsedTime * 0.35) * 0.025;
  });
  return (
    <group ref={group} position={position}>
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
        <div className="hero-seal-label">变化已定位</div>
      </Html>
    </group>
  );
}

function HeroComposition({ scenario }: { scenario: EvidenceScenario }) {
  const { size } = useThree();
  const mobile = size.width < 720;
  const compactHeight = !mobile && size.height < 620;
  const scale = mobile ? 0.72 : 1;
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

  return (
    <group scale={scale}>
      {positions.map((position, index) => (
        <DocumentSlab
          key={labels[index]}
          position={position}
          rotation={[index === 2 ? -0.08 : 0.05, index === 0 ? 0.14 : -0.12, index === 0 ? -0.08 : 0.08]}
          changed={index === 2}
          phase={index * 1.7}
        />
      ))}
      {positions.map((position, index) => (
        <group key={`flow-${labels[index]}`}>
          <Line points={[position, sealPosition]} color={index === 2 ? HERO_COLORS.red : HERO_COLORS.line} lineWidth={1.1} transparent opacity={0.72} />
          {index < 2 && <FlowPulse from={position} to={sealPosition} offset={index * 0.31} />}
        </group>
      ))}
      <EvidenceSeal position={sealPosition} />
    </group>
  );
}

export function HeroScene({ scenario }: { scenario: EvidenceScenario }) {
  const { ref, visible } = useSceneVisibility(true);

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
          <HeroCamera />
          <HeroComposition scenario={scenario} />
        </Canvas>
      )}
    </div>
  );
}
