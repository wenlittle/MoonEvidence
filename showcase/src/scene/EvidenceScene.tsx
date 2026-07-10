import { Canvas, useFrame, useThree } from "@react-three/fiber";
import { Edges, Grid, Html, Line, RoundedBox } from "@react-three/drei";
import { useMemo, useRef } from "react";
import * as THREE from "three";
import type { EvidenceScenario } from "../types";
import { useSceneVisibility } from "./useSceneVisibility";

type Vec3 = [number, number, number];

const COLORS = {
  background: "#080a0d",
  neutral: "#d8dee6",
  cyan: "#36c2d9",
  green: "#46bd70",
  amber: "#d6a13c",
  red: "#df6262",
  muted: "#66707c",
  line: "#3e4752",
};

function reveal(progress: number, at: number): number {
  return THREE.MathUtils.smoothstep(progress, at - 0.1, at + 0.14);
}

type StoryCardProps = {
  position: Vec3;
  progress: number;
  appearAt: number;
  color: string;
  eyebrow: string;
  label: string;
  detail: string;
  width?: number;
  muted?: boolean;
  phase?: number;
};

function StoryCard({
  position,
  progress,
  appearAt,
  color,
  eyebrow,
  label,
  detail,
  width = 1.9,
  muted = false,
  phase = 0,
}: StoryCardProps) {
  const group = useRef<THREE.Group>(null);
  const visibility = reveal(progress, appearAt);

  useFrame((state, delta) => {
    if (!group.current) return;
    const targetScale = visibility * (muted ? 0.94 : 1);
    const scale = THREE.MathUtils.damp(group.current.scale.x, targetScale, 8, delta);
    group.current.scale.setScalar(scale);
    group.current.position.x = THREE.MathUtils.damp(
      group.current.position.x,
      position[0],
      7,
      delta,
    );
    group.current.position.y =
      position[1] + Math.sin(state.clock.elapsedTime * 0.55 + phase) * 0.035;
    group.current.rotation.z = Math.sin(state.clock.elapsedTime * 0.32 + phase) * 0.008;
  });

  return (
    <group
      ref={group}
      position={[position[0] - 0.35, position[1], position[2]]}
      scale={0}
    >
      <RoundedBox args={[width, 1, 0.18]} radius={0.07} smoothness={4}>
        <meshStandardMaterial
          color="#11161b"
          emissive={color}
          emissiveIntensity={muted ? 0.025 : 0.105}
          metalness={0.32}
          roughness={0.46}
          transparent
          opacity={muted ? 0.48 : 0.97}
        />
        <Edges
          color={color}
          lineWidth={0.65}
          transparent
          opacity={muted ? 0.12 : 0.34}
          threshold={18}
        />
      </RoundedBox>
      <mesh position={[-width / 2 + 0.045, 0, 0.11]}>
        <boxGeometry args={[0.055, 0.72, 0.035]} />
        <meshBasicMaterial color={color} transparent opacity={muted ? 0.3 : 0.84} />
      </mesh>
      <mesh position={[width / 2 - 0.18, 0.34, 0.115]}>
        <boxGeometry args={[0.17, 0.025, 0.02]} />
        <meshBasicMaterial color={color} transparent opacity={muted ? 0.18 : 0.48} />
      </mesh>
      <Html transform position={[0.04, 0, 0.14]} distanceFactor={5.2} center>
        <div
          className={`story-node-label${muted ? " muted" : ""}`}
          style={{ width: `${Math.round(width * 80)}px` }}
        >
          <span style={{ color }}>{eyebrow}</span>
          <strong>{label}</strong>
          <small>{detail}</small>
        </div>
      </Html>
    </group>
  );
}

type StorySealProps = {
  position: Vec3;
  progress: number;
  appearAt: number;
  color: string;
  label: string;
  detail: string;
  phase?: number;
};

function StorySeal({
  position,
  progress,
  appearAt,
  color,
  label,
  detail,
  phase = 0,
}: StorySealProps) {
  const group = useRef<THREE.Group>(null);
  const visibility = reveal(progress, appearAt);

  useFrame((state, delta) => {
    if (!group.current) return;
    const scale = THREE.MathUtils.damp(group.current.scale.x, visibility, 8, delta);
    group.current.scale.setScalar(scale);
    group.current.rotation.z = Math.sin(state.clock.elapsedTime * 0.38 + phase) * 0.035;
    group.current.position.y =
      position[1] + Math.sin(state.clock.elapsedTime * 0.5 + phase) * 0.04;
  });

  return (
    <group ref={group} position={position} scale={0}>
      <mesh rotation={[Math.PI / 2, 0, 0]}>
        <cylinderGeometry args={[0.58, 0.58, 0.16, 6]} />
        <meshStandardMaterial
          color="#101713"
          emissive={color}
          emissiveIntensity={0.22}
          metalness={0.48}
          roughness={0.34}
        />
      </mesh>
      <mesh position={[0, 0, 0.115]} rotation={[0, 0, Math.PI / 6]}>
        <ringGeometry args={[0.45, 0.48, 6]} />
        <meshBasicMaterial color={color} transparent opacity={0.5} />
      </mesh>
      <mesh position={[0, 0, 0.13]}>
        <ringGeometry args={[0.18, 0.245, 32]} />
        <meshBasicMaterial color={color} transparent opacity={0.92} />
      </mesh>
      <Html transform position={[0, -0.88, 0.13]} distanceFactor={5.2} center>
        <div className="story-seal-label">
          <strong style={{ color }}>{label}</strong>
          <span>{detail}</span>
        </div>
      </Html>
    </group>
  );
}

function StoryEdge({
  from,
  to,
  progress,
  appearAt,
  color = COLORS.line,
  dashed = false,
}: {
  from: Vec3;
  to: Vec3;
  progress: number;
  appearAt: number;
  color?: string;
  dashed?: boolean;
}) {
  const visibility = reveal(progress, appearAt);
  if (visibility < 0.02) return null;
  const visibleTo: Vec3 = [
    THREE.MathUtils.lerp(from[0], to[0], visibility),
    THREE.MathUtils.lerp(from[1], to[1], visibility),
    THREE.MathUtils.lerp(from[2], to[2], visibility),
  ];
  return (
    <group>
      <Line
        points={[from, visibleTo]}
        color={color}
        lineWidth={4.2}
        transparent
        opacity={visibility * 0.075}
        dashed={dashed}
        dashSize={0.13}
        gapSize={0.1}
      />
      <Line
        points={[from, visibleTo]}
        color={color}
        lineWidth={1.15}
        transparent
        opacity={visibility * 0.7}
        dashed={dashed}
        dashSize={0.13}
        gapSize={0.1}
      />
    </group>
  );
}

function FlowPulse({
  from,
  to,
  color,
  progress,
  appearAt,
  phase = 0,
}: {
  from: Vec3;
  to: Vec3;
  color: string;
  progress: number;
  appearAt: number;
  phase?: number;
}) {
  const packet = useRef<THREE.Group>(null);
  const start = useMemo(() => new THREE.Vector3(...from), [from]);
  const end = useMemo(() => new THREE.Vector3(...to), [to]);
  const active = reveal(progress, appearAt) > 0.8;

  useFrame((state) => {
    if (!packet.current) return;
    const t = (state.clock.elapsedTime * 0.16 + phase) % 1;
    packet.current.position.lerpVectors(start, end, t);
    packet.current.rotation.z = state.clock.elapsedTime * 0.8;
    packet.current.visible = active;
  });

  return (
    <group ref={packet} visible={false}>
      <mesh>
        <octahedronGeometry args={[0.075, 0]} />
        <meshBasicMaterial color={color} />
      </mesh>
      <mesh scale={1.8}>
        <ringGeometry args={[0.052, 0.068, 4]} />
        <meshBasicMaterial color={color} transparent opacity={0.22} />
      </mesh>
    </group>
  );
}

function StoryBackdrop() {
  return (
    <Grid
      args={[12, 8]}
      position={[0, 0, -0.72]}
      rotation={[Math.PI / 2, 0, 0]}
      cellColor="#151d23"
      cellSize={0.42}
      cellThickness={0.32}
      sectionColor="#24313a"
      sectionSize={2.52}
      sectionThickness={0.62}
      fadeDistance={7.4}
      fadeStrength={1.7}
      side={THREE.DoubleSide}
    />
  );
}

function IntakeChapter({ scenario, progress }: ChapterProps) {
  const fileA: Vec3 = [-2.35, 1.05, 0];
  const fileB: Vec3 = [-2.35, -1.05, 0];
  const pack: Vec3 = [1.55, 0, 0];

  return (
    <group>
      <StoryCard
        position={fileA}
        progress={progress}
        appearAt={0}
        color={COLORS.neutral}
        eyebrow="原始文件"
        label={scenario.files[0]?.path.replace("files/", "") ?? "a.txt"}
        detail={`${scenario.files[0]?.size ?? 0} 字节`}
        phase={0.3}
      />
      <StoryCard
        position={fileB}
        progress={progress}
        appearAt={0.08}
        color={COLORS.neutral}
        eyebrow="原始文件"
        label={scenario.files[1]?.path.replace("files/", "") ?? "b.bin"}
        detail={`${scenario.files[1]?.size ?? 0} 字节`}
        phase={1.5}
      />
      <StoryCard
        position={pack}
        progress={progress}
        appearAt={0.3}
        color={COLORS.amber}
        eyebrow="证据包"
        label="材料已进入"
        detail={`${scenario.files.length} 份文件等待校验`}
        width={2.15}
        phase={2.4}
      />
      <StoryEdge from={fileA} to={pack} progress={progress} appearAt={0.2} />
      <StoryEdge from={fileB} to={pack} progress={progress} appearAt={0.26} />
      <FlowPulse from={fileA} to={pack} color={COLORS.green} progress={progress} appearAt={0.42} />
      <FlowPulse from={fileB} to={pack} color={COLORS.green} progress={progress} appearAt={0.48} phase={0.4} />
    </group>
  );
}

type ChapterProps = {
  scenario: EvidenceScenario;
  progress: number;
};

function CredentialChapter({ scenario, progress }: ChapterProps) {
  const digestA: Vec3 = [-2.4, 1.05, 0];
  const digestB: Vec3 = [-2.4, -1.05, 0];
  const root: Vec3 = [0.15, 0, 0];
  const signature: Vec3 = [2.65, 0, 0];

  return (
    <group>
      <StoryCard
        position={digestA}
        progress={progress}
        appearAt={0}
        color={COLORS.cyan}
        eyebrow="文件指纹"
        label={`${scenario.files[0]?.path.replace("files/", "") ?? "a.txt"} 已确认`}
        detail="内容形成唯一结果"
        phase={0.2}
      />
      <StoryCard
        position={digestB}
        progress={progress}
        appearAt={0.06}
        color={COLORS.cyan}
        eyebrow="文件指纹"
        label={`${scenario.files[1]?.path.replace("files/", "") ?? "b.bin"} 已确认`}
        detail="内容形成唯一结果"
        phase={1.4}
      />
      <StorySeal
        position={root}
        progress={progress}
        appearAt={0.25}
        color={COLORS.green}
        label="整体凭证"
        detail={`${scenario.files.length} 份材料形成一个结果`}
        phase={2}
      />
      <StoryCard
        position={signature}
        progress={progress}
        appearAt={0.55}
        color={COLORS.amber}
        eyebrow="来源确认"
        label="签名已绑定"
        detail="可以交付或归档"
        width={1.95}
        phase={2.7}
      />
      <StoryEdge from={digestA} to={root} progress={progress} appearAt={0.18} color={COLORS.green} />
      <StoryEdge from={digestB} to={root} progress={progress} appearAt={0.22} color={COLORS.green} />
      <StoryEdge from={root} to={signature} progress={progress} appearAt={0.5} color={COLORS.amber} />
      <FlowPulse from={digestA} to={root} color={COLORS.green} progress={progress} appearAt={0.36} />
      <FlowPulse from={root} to={signature} color={COLORS.amber} progress={progress} appearAt={0.66} phase={0.35} />
    </group>
  );
}

function ForkChapter({ scenario, progress }: ChapterProps) {
  const source: Vec3 = [-2.35, 0, 0];
  const original: Vec3 = [0.05, 1.3, 0];
  const changed: Vec3 = [0.05, -1.3, 0];
  const originalResult: Vec3 = [2.75, 1.3, 0];
  const changedResult: Vec3 = [2.75, -1.3, 0];
  const changedByte = scenario.files.find((file) => file.path === scenario.tamperedPath)?.changedByte;

  return (
    <group>
      <StoryCard
        position={source}
        progress={progress}
        appearAt={0}
        color={COLORS.neutral}
        eyebrow="同一份材料"
        label={scenario.tamperedPath.replace("files/", "")}
        detail="从同一个原始记录出发"
        width={2.05}
        phase={0.2}
      />
      <StoryCard
        position={original}
        progress={progress}
        appearAt={0.14}
        color={COLORS.green}
        eyebrow="原始内容"
        label="结果保持一致"
        detail="与记录中的凭证相同"
        width={2.05}
        phase={1.1}
      />
      <StoryCard
        position={changed}
        progress={progress}
        appearAt={0.18}
        color={COLORS.red}
        eyebrow="修改后内容"
        label="一个字节改变"
        detail={`第 ${changedByte ?? 0} 个字节留下差异`}
        width={2.05}
        phase={2.2}
      />
      <StorySeal
        position={originalResult}
        progress={progress}
        appearAt={0.38}
        color={COLORS.green}
        label="保持一致"
        detail="原始结果"
        phase={0.7}
      />
      <StorySeal
        position={changedResult}
        progress={progress}
        appearAt={0.42}
        color={COLORS.red}
        label="结果分叉"
        detail="修改后结果"
        phase={1.8}
      />
      <StoryEdge from={source} to={original} progress={progress} appearAt={0.1} color={COLORS.green} />
      <StoryEdge from={source} to={changed} progress={progress} appearAt={0.14} color={COLORS.red} />
      <StoryEdge from={original} to={originalResult} progress={progress} appearAt={0.3} color={COLORS.green} />
      <StoryEdge from={changed} to={changedResult} progress={progress} appearAt={0.34} color={COLORS.red} />
      <FlowPulse from={original} to={originalResult} color={COLORS.green} progress={progress} appearAt={0.52} />
      <FlowPulse from={changed} to={changedResult} color={COLORS.red} progress={progress} appearAt={0.5} phase={0.45} />
    </group>
  );
}

function RejectionChapter({ scenario, progress }: ChapterProps) {
  const changed: Vec3 = [-2.35, 0.55, 0];
  const stable: Vec3 = [-2.35, -1.35, -0.08];
  const mismatch: Vec3 = [0.25, 0.55, 0];
  const rejected: Vec3 = [2.9, 0.55, 0];
  const changedFile = scenario.files.find((file) => file.path === scenario.tamperedPath);
  const stableFile = scenario.files.find((file) => file.path !== scenario.tamperedPath);

  return (
    <group>
      <StoryCard
        position={changed}
        progress={progress}
        appearAt={0}
        color={COLORS.red}
        eyebrow="已定位变化"
        label={scenario.tamperedPath.replace("files/", "")}
        detail={`第 ${changedFile?.changedByte ?? 0} 个字节发生变化`}
        width={2.1}
        phase={0.3}
      />
      <StoryCard
        position={stable}
        progress={progress}
        appearAt={0.08}
        color={COLORS.muted}
        eyebrow="内容一致"
        label={stableFile?.path.replace("files/", "") ?? "其他文件"}
        detail="未发现变化"
        width={2.1}
        muted
        phase={1.5}
      />
      <StoryCard
        position={mismatch}
        progress={progress}
        appearAt={0.22}
        color={COLORS.red}
        eyebrow="整体凭证"
        label="结果不再匹配"
        detail="变化已传递到整体结果"
        width={2.15}
        phase={2.1}
      />
      <StorySeal
        position={rejected}
        progress={progress}
        appearAt={0.5}
        color={COLORS.red}
        label="拒绝通过"
        detail="准确定位 1 个文件"
        phase={2.8}
      />
      <StoryEdge from={changed} to={mismatch} progress={progress} appearAt={0.16} color={COLORS.red} />
      <StoryEdge from={mismatch} to={rejected} progress={progress} appearAt={0.42} color={COLORS.red} dashed />
      <FlowPulse from={changed} to={mismatch} color={COLORS.red} progress={progress} appearAt={0.35} />
      <FlowPulse from={mismatch} to={rejected} color={COLORS.red} progress={progress} appearAt={0.62} phase={0.4} />
    </group>
  );
}

function StoryComposition({
  scenario,
  chapter,
  progress,
}: ChapterProps & { chapter: number }) {
  if (chapter === 0) return <IntakeChapter scenario={scenario} progress={progress} />;
  if (chapter === 1) return <CredentialChapter scenario={scenario} progress={progress} />;
  if (chapter === 2) return <ForkChapter scenario={scenario} progress={progress} />;
  return <RejectionChapter scenario={scenario} progress={progress} />;
}

function StoryCamera() {
  const { camera, size } = useThree();
  const target = useMemo(() => new THREE.Vector3(), []);

  useFrame((_, delta) => {
    const narrow = size.width < 760;
    const compactHeight = size.height < 680;
    const targetZ = narrow ? 12.6 : compactHeight ? 8.1 : 8.45;
    target.set(0, compactHeight ? 0.05 : 0, targetZ);
    camera.position.lerp(target, 1 - Math.exp(-3 * delta));
    camera.lookAt(0, compactHeight ? -0.05 : 0, 0);
  });
  return null;
}

export function EvidenceScene({
  scenario,
  chapter,
  progress,
}: {
  scenario: EvidenceScenario;
  chapter: number;
  progress: number;
}) {
  const { ref, visible } = useSceneVisibility(false);

  return (
    <div ref={ref} className="story-scene" aria-hidden="true">
      {visible && (
        <Canvas
          dpr={[1, 1.75]}
          gl={{ antialias: true, powerPreference: "high-performance" }}
          camera={{ position: [0, 0, 8.45], fov: 42, near: 0.1, far: 80 }}
        >
          <color attach="background" args={[COLORS.background]} />
          <fog attach="fog" args={[COLORS.background, 11, 24]} />
          <ambientLight intensity={1.25} />
          <directionalLight position={[4, 7, 8]} intensity={2.1} color="#f4f0e7" />
          <directionalLight position={[-6, 2, 4]} intensity={1.1} color={COLORS.cyan} />
          <StoryCamera />
          <StoryBackdrop />
          <StoryComposition
            key={chapter}
            scenario={scenario}
            chapter={chapter}
            progress={progress}
          />
        </Canvas>
      )}
    </div>
  );
}
