import { Canvas, useFrame, useThree } from "@react-three/fiber";
import { Grid, Html, Line, RoundedBox } from "@react-three/drei";
import { useMemo, useRef, useState } from "react";
import * as THREE from "three";
import { useStoryStore } from "../store";
import type { EvidenceScenario } from "../types";

type Vec3 = [number, number, number];

const COLORS = {
  background: "#080a0d",
  surface: "#171b20",
  neutral: "#d8dee6",
  cyan: "#36c2d9",
  green: "#35b56a",
  amber: "#e2aa3a",
  red: "#e05252",
  muted: "#66707c",
  line: "#3e4752",
};

function shortHash(value: string, length = 11): string {
  const clean = value.includes(":") ? value.split(":")[1] : value;
  return clean.length > length ? `${clean.slice(0, length)}...` : clean;
}

function stageVisibility(progress: number, threshold: number): number {
  return THREE.MathUtils.smoothstep(progress, threshold - 0.28, threshold + 0.28);
}

type NodeBlockProps = {
  position: Vec3;
  appearAt: number;
  progress: number;
  color: string;
  eyebrow: string;
  label: string;
  detail: string;
  width?: number;
  height?: number;
  selected?: boolean;
  dimmed?: boolean;
  onClick?: () => void;
};

function NodeBlock({
  position,
  appearAt,
  progress,
  color,
  eyebrow,
  label,
  detail,
  width = 1.16,
  height = 0.56,
  selected = false,
  dimmed = false,
  onClick,
}: NodeBlockProps) {
  const group = useRef<THREE.Group>(null);
  const { size } = useThree();
  const [hovered, setHovered] = useState(false);
  const visibility = stageVisibility(progress, appearAt);
  const responsiveScale = size.width < 720 ? 0.52 : size.height < 680 ? 0.92 : 1;

  useFrame((state, delta) => {
    if (!group.current) return;
    const targetScale = visibility * (hovered ? 1.05 : 1) * responsiveScale;
    const damp = 1 - Math.exp(-8 * delta);
    group.current.scale.lerp(
      new THREE.Vector3(targetScale, targetScale, targetScale),
      damp,
    );
    group.current.position.x = THREE.MathUtils.damp(
      group.current.position.x,
      position[0],
      7,
      delta,
    );
    group.current.position.y = THREE.MathUtils.damp(
      group.current.position.y,
      position[1],
      7,
      delta,
    );
    group.current.position.z = position[2] + Math.sin(state.clock.elapsedTime * 1.1 + position[0]) * 0.025;
  });

  return (
    <group ref={group} position={[position[0] - 0.3, position[1], position[2]]}>
      <RoundedBox
        args={[width, height, 0.16]}
        radius={0.07}
        smoothness={4}
        onClick={(event) => {
          event.stopPropagation();
          onClick?.();
        }}
        onPointerEnter={() => {
          if (onClick) document.body.style.cursor = "pointer";
          setHovered(true);
        }}
        onPointerLeave={() => {
          document.body.style.cursor = "default";
          setHovered(false);
        }}
      >
        <meshStandardMaterial
          color={dimmed ? COLORS.surface : COLORS.surface}
          emissive={color}
          emissiveIntensity={selected ? 0.72 : dimmed ? 0.08 : 0.28}
          roughness={0.48}
          metalness={0.24}
          transparent
          opacity={dimmed ? 0.42 : 0.96}
        />
      </RoundedBox>
      <mesh position={[-width / 2 + 0.035, 0, 0.1]}>
        <boxGeometry args={[0.045, height * 0.72, 0.035]} />
        <meshBasicMaterial color={color} transparent opacity={dimmed ? 0.4 : 1} />
      </mesh>
      <Html transform position={[0, 0, 0.12]} distanceFactor={7.2} center>
        <div
          className={`scene-label${onClick ? " scene-label-clickable" : ""}`}
          style={{ width: `${Math.round(width * 116)}px`, opacity: dimmed ? 0.5 : 1 }}
        >
          <span className="scene-eyebrow" style={{ color }}>
            {eyebrow}
          </span>
          <strong>{label}</strong>
          <code>{detail}</code>
        </div>
      </Html>
    </group>
  );
}

type EdgeProps = {
  from: Vec3;
  to: Vec3;
  progress: number;
  appearAt: number;
  color?: string;
  dashed?: boolean;
};

function EvidenceEdge({
  from,
  to,
  progress,
  appearAt,
  color = COLORS.line,
  dashed = false,
}: EdgeProps) {
  const opacity = stageVisibility(progress, appearAt);
  if (opacity < 0.02) return null;
  return (
    <Line
      points={[from, to]}
      color={color}
      lineWidth={1.15}
      transparent
      opacity={opacity * 0.78}
      dashed={dashed}
      dashSize={0.13}
      gapSize={0.1}
    />
  );
}

function DataPacket({ from, to, color, active }: { from: Vec3; to: Vec3; color: string; active: boolean }) {
  const mesh = useRef<THREE.Mesh>(null);
  const start = useMemo(() => new THREE.Vector3(...from), [from]);
  const end = useMemo(() => new THREE.Vector3(...to), [to]);

  useFrame((state) => {
    if (!mesh.current) return;
    const t = (state.clock.elapsedTime * 0.22 + Math.abs(from[0]) * 0.07) % 1;
    mesh.current.position.lerpVectors(start, end, t);
    mesh.current.visible = active;
  });

  return (
    <mesh ref={mesh}>
      <boxGeometry args={[0.1, 0.035, 0.035]} />
      <meshBasicMaterial color={color} />
    </mesh>
  );
}

function HexSeal({
  position,
  progress,
  appearAt,
  color,
  label,
  detail,
}: {
  position: Vec3;
  progress: number;
  appearAt: number;
  color: string;
  label: string;
  detail: string;
}) {
  const group = useRef<THREE.Group>(null);
  const { size } = useThree();
  const visibility = stageVisibility(progress, appearAt);
  const responsiveScale = size.width < 720 ? 0.58 : 1;
  useFrame((state, delta) => {
    if (!group.current) return;
    const scale = THREE.MathUtils.damp(
      group.current.scale.x,
      visibility * responsiveScale,
      8,
      delta,
    );
    group.current.scale.setScalar(scale);
    group.current.rotation.z = Math.sin(state.clock.elapsedTime * 0.45) * 0.035;
  });
  return (
    <group ref={group} position={position} scale={0}>
      <mesh rotation={[Math.PI / 2, 0, 0]}>
        <cylinderGeometry args={[0.48, 0.48, 0.13, 6]} />
        <meshStandardMaterial
          color={COLORS.surface}
          emissive={color}
          emissiveIntensity={0.42}
          metalness={0.48}
          roughness={0.32}
        />
      </mesh>
      <Html transform position={[0, 0, 0.12]} distanceFactor={7.2} center>
        <div className="seal-label">
          <strong style={{ color }}>{label}</strong>
          <code>{detail}</code>
        </div>
      </Html>
    </group>
  );
}

function CameraRig({ progress }: { progress: number }) {
  const { camera, size } = useThree();
  useFrame((_, delta) => {
    const mobile = size.width < 760;
    const compactHeight = !mobile && size.height < 680;
    const split = stageVisibility(progress, 6);
    const target = new THREE.Vector3(
      split * 0.45,
      mobile ? 0.2 : compactHeight ? 0.15 : split * -0.1,
      (mobile ? 17.8 : compactHeight ? 9.8 : 12.6) +
        split * (mobile ? 1.3 : compactHeight ? 0.8 : 1.1),
    );
    camera.position.lerp(target, 1 - Math.exp(-2.8 * delta));
    camera.lookAt(0, mobile ? -0.2 : 0, 0);
  });
  return null;
}

function TrustGraph({ scenario, progress }: { scenario: EvidenceScenario; progress: number }) {
  const { size } = useThree();
  const mode = useStoryStore((state) => state.mode);
  const challenge = useStoryStore((state) => state.challenge);
  const selectedPath = useStoryStore((state) => state.selectedPath);
  const setSelectedPath = useStoryStore((state) => state.setSelectedPath);
  const submitChallenge = useStoryStore((state) => state.submitChallenge);
  const split = stageVisibility(progress, 6);
  const originalOffset = split * 1.52;
  const tamperedOffset = -split * 1.72;
  const originalRoot = scenario.originalTree.root.actual;
  const tamperedRoot = scenario.tamperedTree.root.actual;
  const signature = scenario.signature;
  const mobile = size.width < 720;
  const compactHeight = !mobile && size.height < 680;
  const xScale = mobile ? 0.42 : 1;
  const yScale = compactHeight ? 0.7 : 1;
  const xOffset = compactHeight ? 1.05 : 0;
  const yOffset = mobile ? -0.82 : compactHeight ? -0.5 : -0.68;
  const x = (value: number) => value * xScale + xOffset;
  const y = (value: number) => value * yScale + yOffset;

  const filePositions: Vec3[] = [
    [x(-5.25), y(0.72 + originalOffset), 0],
    [x(-5.25), y(-0.72 + originalOffset), 0],
  ];
  const digestPositions: Vec3[] = [
    [x(-3.45), y(0.72 + originalOffset), 0],
    [x(-3.45), y(-0.72 + originalOffset), 0],
  ];
  const leafPositions: Vec3[] = [
    [x(-1.55), y(0.72 + originalOffset), 0],
    [x(-1.55), y(-0.72 + originalOffset), 0],
  ];
  const rootPosition: Vec3 = [x(0.35), y(originalOffset), 0];
  const signaturePosition: Vec3 = [x(2.35), y(originalOffset), 0];
  const anchorPosition: Vec3 = [x(4.45), y(originalOffset), 0];

  const tamperedFilePositions: Vec3[] = [
    [x(-5.25), y(0.72 + tamperedOffset), -0.1],
    [x(-5.25), y(-0.72 + tamperedOffset), -0.1],
  ];
  const tamperedDigestPositions: Vec3[] = [
    [x(-3.45), y(0.72 + tamperedOffset), -0.1],
    [x(-3.45), y(-0.72 + tamperedOffset), -0.1],
  ];
  const tamperedLeafPositions: Vec3[] = [
    [x(-1.55), y(0.72 + tamperedOffset), -0.1],
    [x(-1.55), y(-0.72 + tamperedOffset), -0.1],
  ];
  const tamperedRootPosition: Vec3 = [x(0.35), y(tamperedOffset), -0.1];
  const tamperedSignaturePosition: Vec3 = [x(2.35), y(tamperedOffset), -0.1];
  const tamperedAnchorPosition: Vec3 = [x(4.45), y(tamperedOffset), -0.1];

  const chooseFile = (path: string) => {
    setSelectedPath(path);
    if (mode === "challenge") submitChallenge(path);
  };

  return (
    <group>
      <Html transform position={[x(0.35), y(2.58 + originalOffset), 0]} distanceFactor={8} center>
        <div className="lane-label lane-label-valid">ORIGINAL EVIDENCE</div>
      </Html>

      {scenario.files.map((file, index) => {
        const selected = selectedPath === file.path;
        return (
          <NodeBlock
            key={`file-${file.path}`}
            position={filePositions[index] ?? filePositions[0]}
            appearAt={0}
            progress={progress}
            color={COLORS.neutral}
            eyebrow="FILE"
            label={file.path.replace("files/", "")}
            detail={`${file.size} bytes`}
            selected={selected}
            onClick={mode === "challenge" || mode === "inspect" ? () => chooseFile(file.path) : undefined}
          />
        );
      })}

      <NodeBlock
        position={[x(-5.25), y(-2.1 + originalOffset + split * 0.55), 0]}
        appearAt={1}
        progress={progress}
        color={COLORS.amber}
        eyebrow="RFC 8785"
        label="manifest.json"
        detail={scenario.manifest.subject.id}
        width={1.5}
      />

      {scenario.files.map((file, index) => (
        <NodeBlock
          key={`digest-${file.path}`}
          position={digestPositions[index] ?? digestPositions[0]}
          appearAt={2}
          progress={progress}
            color={COLORS.cyan}
            eyebrow="SHA-256"
            label={`摘要 ${index + 1}`}
          detail={shortHash(file.originalDigest)}
        />
      ))}

      {scenario.originalTree.levels[0]?.map((hash, index) => (
        <NodeBlock
          key={`leaf-${hash}`}
          position={leafPositions[index] ?? leafPositions[0]}
          appearAt={2.5}
          progress={progress}
          color={COLORS.green}
          eyebrow={`LEAF ${index}`}
          label="规范条目"
          detail={shortHash(hash)}
        />
      ))}

      <NodeBlock
        position={rootPosition}
        appearAt={3}
        progress={progress}
        color={COLORS.green}
        eyebrow="MERKLE ROOT"
        label="可信根"
        detail={shortHash(originalRoot)}
        width={1.28}
        height={0.64}
      />

      <NodeBlock
        position={signaturePosition}
        appearAt={4}
        progress={progress}
        color={COLORS.amber}
        eyebrow="ED25519"
        label="签名有效"
        detail={shortHash(signature)}
        width={1.3}
      />

      <HexSeal
        position={anchorPosition}
        progress={progress}
        appearAt={5}
        color={COLORS.green}
        label="READY"
        detail={scenario.manifest.version.id}
      />

      {scenario.files.map((_, index) => (
        <EvidenceEdge
          key={`file-digest-edge-${index}`}
          from={filePositions[index] ?? filePositions[0]}
          to={digestPositions[index] ?? digestPositions[0]}
          progress={progress}
          appearAt={2}
          color={COLORS.cyan}
        />
      ))}
      {scenario.files.map((_, index) => (
        <EvidenceEdge
          key={`digest-leaf-edge-${index}`}
          from={digestPositions[index] ?? digestPositions[0]}
          to={leafPositions[index] ?? leafPositions[0]}
          progress={progress}
          appearAt={2.5}
          color={COLORS.green}
        />
      ))}
      {leafPositions.map((position, index) => (
        <EvidenceEdge
          key={`leaf-root-edge-${index}`}
          from={position}
          to={rootPosition}
          progress={progress}
          appearAt={3}
          color={COLORS.green}
        />
      ))}
      <EvidenceEdge
        from={rootPosition}
        to={signaturePosition}
        progress={progress}
        appearAt={4}
        color={COLORS.amber}
      />
      <EvidenceEdge
        from={signaturePosition}
        to={anchorPosition}
        progress={progress}
        appearAt={5}
        color={COLORS.green}
      />
      <DataPacket
        from={digestPositions[0]}
        to={leafPositions[0]}
        color={COLORS.cyan}
        active={progress >= 2 && progress < 6}
      />
      <DataPacket
        from={rootPosition}
        to={signaturePosition}
        color={COLORS.amber}
        active={progress >= 4 && progress < 6}
      />

      {split > 0.02 && (
        <group>
          <Html transform position={[x(0.35), y(0.92 + tamperedOffset), -0.1]} distanceFactor={8} center>
            <div className="lane-label lane-label-tampered">TAMPERED EVIDENCE</div>
          </Html>
          {scenario.files.map((file, index) => {
            const changed = file.path === scenario.tamperedPath;
            const selected = selectedPath === file.path;
            return (
              <NodeBlock
                key={`tampered-file-${file.path}`}
                position={tamperedFilePositions[index] ?? tamperedFilePositions[0]}
                appearAt={6}
                progress={progress}
                color={changed ? COLORS.red : COLORS.muted}
                eyebrow={changed ? "BYTE CHANGED" : "UNCHANGED"}
                label={file.path.replace("files/", "")}
                detail={changed ? `offset ${file.changedByte}` : `${file.size} bytes`}
                selected={selected || (challenge === "correct" && changed)}
                dimmed={!changed && challenge !== "wrong"}
                onClick={mode === "challenge" || mode === "inspect" ? () => chooseFile(file.path) : undefined}
              />
            );
          })}
          {scenario.files.map((file, index) => {
            const changed = file.path === scenario.tamperedPath;
            return (
              <NodeBlock
                key={`tampered-digest-${file.path}`}
                position={tamperedDigestPositions[index] ?? tamperedDigestPositions[0]}
                appearAt={6.12}
                progress={progress}
                color={changed ? COLORS.red : COLORS.muted}
                eyebrow="SHA-256"
                label={changed ? "摘要分叉" : "摘要稳定"}
                detail={shortHash(file.tamperedDigest)}
                dimmed={!changed}
              />
            );
          })}
          {scenario.tamperedTree.levels[0]?.map((hash, index) => {
            const changed = scenario.files[index]?.path === scenario.tamperedPath;
            return (
              <NodeBlock
                key={`tampered-leaf-${hash}`}
                position={tamperedLeafPositions[index] ?? tamperedLeafPositions[0]}
                appearAt={6.25}
                progress={progress}
                color={changed ? COLORS.red : COLORS.muted}
                eyebrow={`LEAF ${index}`}
                label={changed ? "叶子分叉" : "叶子稳定"}
                detail={shortHash(hash)}
                dimmed={!changed}
              />
            );
          })}
          <NodeBlock
            position={tamperedRootPosition}
            appearAt={6.42}
            progress={progress}
            color={COLORS.red}
            eyebrow="MERKLE ROOT"
            label="根不匹配"
            detail={shortHash(tamperedRoot)}
            width={1.28}
            height={0.64}
          />
          <NodeBlock
            position={tamperedSignaturePosition}
            appearAt={6.64}
            progress={progress}
            color={COLORS.red}
            eyebrow="ED25519"
            label="签名拒绝"
            detail={shortHash(signature)}
            width={1.3}
          />
          <HexSeal
            position={tamperedAnchorPosition}
            progress={progress}
            appearAt={6.82}
            color={COLORS.red}
            label="REJECTED"
            detail="E2003"
          />
          {scenario.files.map((file, index) => {
            const changed = file.path === scenario.tamperedPath;
            const edgeColor = changed ? COLORS.red : COLORS.muted;
            return (
              <group key={`tampered-path-${file.path}`}>
                <EvidenceEdge
                  from={tamperedFilePositions[index] ?? tamperedFilePositions[0]}
                  to={tamperedDigestPositions[index] ?? tamperedDigestPositions[0]}
                  progress={progress}
                  appearAt={6.08}
                  color={edgeColor}
                />
                <EvidenceEdge
                  from={tamperedDigestPositions[index] ?? tamperedDigestPositions[0]}
                  to={tamperedLeafPositions[index] ?? tamperedLeafPositions[0]}
                  progress={progress}
                  appearAt={6.2}
                  color={edgeColor}
                />
                <EvidenceEdge
                  from={tamperedLeafPositions[index] ?? tamperedLeafPositions[0]}
                  to={tamperedRootPosition}
                  progress={progress}
                  appearAt={6.4}
                  color={changed ? COLORS.red : COLORS.line}
                  dashed={!changed}
                />
              </group>
            );
          })}
          <EvidenceEdge
            from={tamperedRootPosition}
            to={tamperedSignaturePosition}
            progress={progress}
            appearAt={6.6}
            color={COLORS.red}
          />
          <EvidenceEdge
            from={tamperedSignaturePosition}
            to={tamperedAnchorPosition}
            progress={progress}
            appearAt={6.8}
            color={COLORS.red}
            dashed
          />
          <DataPacket
            from={tamperedDigestPositions[0]}
            to={tamperedLeafPositions[0]}
            color={COLORS.red}
            active={progress >= 6}
          />
        </group>
      )}
    </group>
  );
}

export function EvidenceScene({ scenario, progress }: { scenario: EvidenceScenario; progress: number }) {
  return (
    <div className="scene-shell" aria-hidden="true">
      <Canvas
        dpr={[1, 1.75]}
        gl={{ antialias: true, powerPreference: "high-performance" }}
        camera={{ position: [0, 0.4, 12.6], fov: 42, near: 0.1, far: 100 }}
      >
        <color attach="background" args={[COLORS.background]} />
        <fog attach="fog" args={[COLORS.background, 12, 28]} />
        <ambientLight intensity={1.2} />
        <directionalLight position={[4, 7, 8]} intensity={2.1} color="#f4f0e7" />
        <directionalLight position={[-6, 2, 4]} intensity={1.35} color={COLORS.cyan} />
        <CameraRig progress={progress} />
        <TrustGraph scenario={scenario} progress={progress} />
        <Grid
          position={[0, -4.5, -1.6]}
          args={[30, 20]}
          cellSize={0.5}
          cellThickness={0.45}
          cellColor="#2a3037"
          sectionSize={2.5}
          sectionThickness={0.8}
          sectionColor="#4a4031"
          fadeDistance={18}
          fadeStrength={1.8}
          infiniteGrid
        />
      </Canvas>
    </div>
  );
}
