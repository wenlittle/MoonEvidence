# MoonEvidence Web Experience

The public product homepage and native Evidence Workbench for MoonEvidence.

[Open the live experience](https://wenlittle.github.io/MoonEvidence/)

## Surfaces

The root route is an immersive introduction rather than an operations screen.
It uses a centered product hero and a four-chapter scroll narrative:

1. material enters an evidence pack;
2. a reviewable credential is formed;
3. one changed byte forks the result;
4. verification locates and rejects the inconsistent file.

`#workbench/verify` opens the operational surface. Its six native React tools
cover verification, creation, Merkle proofs, audit logs, Ed25519 signatures,
and byte-level tamper propagation. Homepage calls to action can deep-link to
verification or the tamper experiment, and browser history restores the
selected Workbench tool.

The Workbench shares one Web Worker and all 12 compiled MoonBit browser APIs.
There is no iframe or backend, and tool state stays mounted while the user
moves between the homepage and Workbench.

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
        +---- Product homepage
        |            |
        |     hero scene + scroll narrative
        |            |
        |     desktop Three.js graph / mobile compact flow
        |
        +---- Native React Evidence Workbench ---- six operational tools
                         |
                  shared Web Worker RPC
                         |
               12 MoonBit release JS APIs ---- examples/valid-pack
```

The single worker boundary keeps MoonBit computation away from rendering while
hashes, Merkle trees, verification reports, and signature checks are produced.
Only the visible 3D scene is mounted, so the hero and scroll story do not keep
two WebGL render loops active at the same time.

## Quality Checks

```powershell
npm run check
npm run build
```

The experience is designed for desktop, short-wide, and mobile viewports. The
homepage keeps technical detail subordinate to the user-facing conclusion;
the Workbench exposes the complete MoonBit result for review.
