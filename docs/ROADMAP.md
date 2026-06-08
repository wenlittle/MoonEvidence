# Roadmap

## Week 1: Skeleton and Verification Core Start

- Freeze minimal evidence pack spec.
- Verify MoonBit toolchain installation.
- Generate or validate MoonBit module/package files.
- Implement `canonjson` MVP.
- Implement `digest` wrapper and SHA-256 integration.
- Add first valid and tampered fixtures.
- Add CI skeleton after local `moon check` and `moon test` pass.

## Week 2: Manifest and Merkle

- Implement manifest model and validation.
- Implement Merkle root/proof verification.
- Add tamper cases for missing file, digest mismatch, and invalid proof.
- Add structured diagnostics.

## Week 3: Version Chain and CLI

- Implement linear version chain verification.
- Implement `verify` and `explain` CLI.
- Add black-box CLI regression fixtures.
- Write user-facing README examples.

## Week 4: Completion Polish

- Add property tests for canonical JSON and Merkle proof behavior.
- Add benchmarks if the MoonBit benchmark package is stable enough.
- Add JS/Wasm demo only if pure library build is stable.
- Publish package/docs and prepare Mooncakes submission.
- Prepare competition report and demonstration script.

## Out of MVP

- Full signing/PKI.
- Multi-chain adapters.
- Smart contract deployment.
- Full in-toto/SLSA compatibility.
- Version DAG and authorization snapshot.

