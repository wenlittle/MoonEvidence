import { Canvas, useFrame, useThree } from "@react-three/fiber";
import { Html, Line, RoundedBox } from "@react-three/drei";
import { useMemo, useRef } from "react";
import * as THREE from "three";
import type { EvidenceScenario } from "../types";
import { useSceneVisibility } from "./useSceneVisibility";

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
  dimmed?: boolean;
  hideAt?: number;
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
  dimmed = false,
  hideAt,
}: NodeBlockProps) {
  const group = useRef<THREE.Group>(null);
  const { size } = useThree();
  const exitVisibility = hideAt === undefined ? 1 : 1 - stageVisibility(progress, hideAt);
  const visibility = stageVisibility(progress, appearAt) * exitVisibility;
  const responsiveScale = size.width < 520 ? 0.64 : size.width < 760 ? 0.82 : size.height < 680 ? 0.92 : 1;

  useFrame((state, delta) => {
    if (!group.current) return;
    const targetScale = visibility * responsiveScale;
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
      >
        <meshStandardMaterial
          color={dimmed ? COLORS.surface : COLORS.surface}
          emissive={color}
          emissiveIntensity={dimmed ? 0.08 : 0.28}
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
          className="scene-label"
          style={{ width: `${Math.round(width * 140)}px`, opacity: dimmed ? 0.5 : 1 }}
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
  dimmed?: boolean;
};

function EvidenceEdge({
  from,
  to,
  progress,
  appearAt,
  color = COLORS.line,
  dashed = false,
  dimmed = false,
}: EdgeProps) {
  const opacity = stageVisibility(progress, appearAt);
  if (opacity < 0.02) return null;
  return (
    <Line
      points={[from, to]}
      color={color}
      lineWidth={1.15}
      transparent
      opacity={opacity * (dimmed ? 0.2 : 0.78)}
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
  dimmed = false,
}: {
  position: Vec3;
  progress: number;
  appearAt: number;
  color: string;
  label: string;
  detail: string;
  dimmed?: boolean;
}) {
  const group = useRef<THREE.Group>(null);
  const { size } = useThree();
  const visibility = stageVisibility(progress, appearAt);
  const responsiveScale = size.width < 520 ? 0.6 : size.width < 760 ? 0.82 : 1;
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
          emissiveIntensity={dimmed ? 0.08 : 0.42}
          metalness={0.48}
          roughness={0.32}
          transparent
          opacity={dimmed ? 0.42 : 1}
        />
      </mesh>
      <Html transform position={[0, 0, 0.12]} distanceFactor={7.2} center>
        <div className="seal-label" style={{ opacity: dimmed ? 0.45 : 1 }}>
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
    const mobile = size.width < 520;
    const narrow = !mobile && size.width < 760;
    const compactHeight = !mobile && size.height < 680;
    const split = stageVisibility(progress, 6);
    const target = new THREE.Vector3(
      (mobile ? 0 : narrow ? 0.72 : 1.25) + split * 0.25,
      mobile ? 0.2 : compactHeight ? 0.15 : split * -0.1,
      (mobile ? 17.8 : narrow ? 16.8 : compactHeight ? 9.8 : 13.2) +
        split * (mobile ? 1.3 : narrow ? 1 : compactHeight ? 0.8 : 1.1),
    );
    camera.position.lerp(target, 1 - Math.exp(-2.8 * delta));
    camera.lookAt(0, mobile ? -0.2 : 0, 0);
  });
  return null;
}

function TrustGraph({ scenario, progress }: { scenario: EvidenceScenario; progress: number }) {
  const { size } = useThree();
  const split = stageVisibility(progress, 6);
  const originalDimmed = progress > 5.72;
  const originalOffset = split * 1.52;
  const tamperedOffset = -split * 1.72;
  const mobile = size.width < 520;
  const narrow = !mobile && size.width < 760;
  const compactHeight = !mobile && size.height < 680;
  const xScale = mobile ? 0.42 : narrow ? 0.68 : 0.9;
  const yScale = compactHeight ? 0.7 : narrow ? 0.86 : 1;
  const xOffset = mobile ? 0 : narrow ? 1.15 : compactHeight ? 1.55 : 1.7;
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
  const rootPosition: Vec3 = [x(0), y(originalOffset), 0];
  const signaturePosition: Vec3 = [x(2.5), y(originalOffset), 0];
  const anchorPosition: Vec3 = [x(3.8), y(originalOffset), 0];

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
  const tamperedRootPosition: Vec3 = [x(0), y(tamperedOffset), -0.1];
  const tamperedSignaturePosition: Vec3 = [x(2.5), y(tamperedOffset), -0.1];
  const tamperedAnchorPosition: Vec3 = [x(3.8), y(tamperedOffset), -0.1];

  return (
    <group>
      <Html transform position={[x(0.35), y(2 + originalOffset), 0]} distanceFactor={8} center>
        <div className="lane-label lane-label-valid">原始材料</div>
      </Html>

      {scenario.files.map((file, index) => {
        return (
          <NodeBlock
            key={`file-${file.path}`}
            position={filePositions[index] ?? filePositions[0]}
            appearAt={0}
            progress={progress}
            color={COLORS.neutral}
            eyebrow="原始文件"
            label={file.path.replace("files/", "")}
            detail={`${file.size} 字节`}
            dimmed={originalDimmed}
          />
        );
      })}

      <NodeBlock
        position={[x(-5.25), y(-2.1 + originalOffset + split * 0.55), 0]}
        appearAt={1}
        progress={progress}
        color={COLORS.amber}
        eyebrow="证据清单"
        label="材料信息已整理"
        detail="等待生成凭证"
        width={1.5}
        hideAt={5.6}
      />

      {scenario.files.map((file, index) => (
        <NodeBlock
          key={`digest-${file.path}`}
          position={digestPositions[index] ?? digestPositions[0]}
          appearAt={2}
          progress={progress}
            color={COLORS.cyan}
            eyebrow="文件指纹"
            label={`内容 ${index + 1} 已确认`}
          detail="唯一结果已生成"
          dimmed={originalDimmed}
        />
      ))}

      {scenario.originalTree.levels[0]?.map((hash, index) => (
        <NodeBlock
          key={`leaf-${hash}`}
          position={leafPositions[index] ?? leafPositions[0]}
          appearAt={2.5}
          progress={progress}
          color={COLORS.green}
          eyebrow={`材料 ${index + 1}`}
          label="纳入整体校验"
          detail="与文件指纹绑定"
          dimmed={originalDimmed}
        />
      ))}

      <NodeBlock
        position={rootPosition}
        appearAt={3}
        progress={progress}
        color={COLORS.green}
        eyebrow="整体指纹"
        label="全部材料已锁定"
        detail={`${scenario.files.length} 个文件形成一个结果`}
        width={1.28}
        height={0.64}
        dimmed={originalDimmed}
      />

      <NodeBlock
        position={signaturePosition}
        appearAt={4}
        progress={progress}
        color={COLORS.amber}
        eyebrow="数字签名"
        label="来源已经确认"
        detail="当前整体结果已签署"
        width={1.3}
        dimmed={originalDimmed}
      />

      <HexSeal
        position={anchorPosition}
        progress={progress}
        appearAt={5}
        color={COLORS.green}
        label="证据已生成"
        detail="可以交付或归档"
        dimmed={originalDimmed}
      />

      {scenario.files.map((_, index) => (
        <EvidenceEdge
          key={`file-digest-edge-${index}`}
          from={filePositions[index] ?? filePositions[0]}
          to={digestPositions[index] ?? digestPositions[0]}
          progress={progress}
          appearAt={2}
          color={COLORS.cyan}
          dimmed={originalDimmed}
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
          dimmed={originalDimmed}
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
          dimmed={originalDimmed}
        />
      ))}
      <EvidenceEdge
        from={rootPosition}
        to={signaturePosition}
        progress={progress}
        appearAt={4}
        color={COLORS.amber}
        dimmed={originalDimmed}
      />
      <EvidenceEdge
        from={signaturePosition}
        to={anchorPosition}
        progress={progress}
        appearAt={5}
        color={COLORS.green}
        dimmed={originalDimmed}
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
            <div className="lane-label lane-label-tampered">修改后的材料</div>
          </Html>
          {scenario.files.map((file, index) => {
            const changed = file.path === scenario.tamperedPath;
            return (
              <NodeBlock
                key={`tampered-file-${file.path}`}
                position={tamperedFilePositions[index] ?? tamperedFilePositions[0]}
                appearAt={6}
                progress={progress}
                color={changed ? COLORS.red : COLORS.muted}
                eyebrow={changed ? "内容变化" : "内容一致"}
                label={file.path.replace("files/", "")}
                detail={changed ? `第 ${file.changedByte} 个字节被修改` : `${file.size} 字节未变化`}
                dimmed={!changed}
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
                eyebrow="文件指纹"
                label={changed ? "结果已经改变" : "结果保持一致"}
                detail={changed ? "修改留下了差异" : "未发现变化"}
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
                eyebrow={`材料 ${index + 1}`}
                label={changed ? "变化向上传播" : "仍与原记录一致"}
                detail={changed ? "影响整体结果" : "未受影响"}
                dimmed={!changed}
              />
            );
          })}
          <NodeBlock
            position={tamperedRootPosition}
            appearAt={6.42}
            progress={progress}
            color={COLORS.red}
            eyebrow="整体指纹"
            label="整体结果不一致"
            detail="一处修改改变了整体凭证"
            width={1.28}
            height={0.64}
          />
          <NodeBlock
            position={tamperedSignaturePosition}
            appearAt={6.64}
            progress={progress}
            color={COLORS.red}
            eyebrow="数字签名"
            label="原签名不再匹配"
            detail="当前内容无法通过确认"
            width={1.3}
          />
          <HexSeal
            position={tamperedAnchorPosition}
            progress={progress}
            appearAt={6.82}
            color={COLORS.red}
            label="验证未通过"
            detail="发现 1 处内容变化"
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
  const { ref, visible } = useSceneVisibility(false);

  return (
    <div ref={ref} className="story-scene" aria-hidden="true">
      {visible && (
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
        </Canvas>
      )}
    </div>
  );
}
