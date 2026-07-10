# MoonEvidence Trust Observatory

An interactive 3D walkthrough of the MoonEvidence verification pipeline.

[Open the live observatory](https://wenlittle.github.io/MoonEvidence/)

## What It Demonstrates

Every digest, Merkle root, verification result, and Ed25519 verdict shown in
the scene is computed at runtime by the repository's compiled MoonBit API. The
browser worker loads `examples/valid-pack`, changes byte 6 of `files/a.txt`,
and compares the original and tampered evidence paths through the same core
used by the CLI.

- **Auto** plays the eight-stage verification story.
- **Inspect** pauses the timeline for direct evidence-node inspection.
- **Challenge** asks the reviewer to locate the modified file and reveals the
  complete rejection path.
- **Evidence Workbench** switches from the visual home view into six native
  React tools: verify, create, proof, audit, signature, and tamper lab.

Both surfaces share one Web Worker and all 12 compiled MoonBit browser APIs.
There is no iframe or backend; tool state stays live when the reviewer moves
between the observatory and workbench.

## Run Locally

Prerequisites: Node.js 22+, npm, and the MoonBit toolchain.

```powershell
cd showcase
npm ci
npm run dev
```

Open the URL printed by Vite. `npm run dev` first compiles `src/api` in release
mode and copies the API plus the real example pack into Vite's generated
public assets.

For a production build:

```powershell
npm run build
npm run preview
```

## Architecture

```text
React navigation shell
        |
        +---- React HUD + GSAP timeline
        |            |
        |     Zustand story state ---- React Three Fiber / Three.js scene
        |
        +---- Native React Evidence Workbench ---- six operational tools
                         |
                  shared Web Worker RPC
                         |
               12 MoonBit release JS APIs ---- examples/valid-pack
```

The single worker boundary keeps MoonBit computation away from rendering and
makes the UI responsive while hashes, Merkle trees, verification reports, and
signature checks are produced. The same worker serves both the 3D story and
all six workbench tools.

## Quality Checks

```powershell
npm run check
npm run build
```

The experience is designed for desktop and mobile viewports, supports
keyboard-accessible HUD controls, and respects reduced-motion preferences.
