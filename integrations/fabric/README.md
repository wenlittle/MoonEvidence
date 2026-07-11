# Hyperledger Fabric Integration

This integration turns a locally verified MoonEvidence pack into an immutable
Fabric ledger anchor. The MoonBit CLI remains the authority for evidence-pack
semantics; the TypeScript adapter transports its canonical manifest digest,
and the Go chaincode stores that digest once.

[Chinese task guide](../../docs/GUIDE.md#fabric-锚定) · [Anchor contract](../../docs/spec/FABRIC_ANCHOR_SPEC.md) · [Recorded release experiment](../../docs/records/fabric-e2e/2026-07-12-v0.5.1/)

```text
source directory
  -> moon-evidence pack / inspect / verify
  -> canonical manifest_digest
  -> TypeScript Fabric Gateway
  -> Go chaincode on evidencechannel
  -> transaction ID + block number + VALID status
  -> ledger query
  -> moon-evidence verify --expected-manifest-digest
```

Evidence semantics stay inside the MoonBit CLI. The adapter and chaincode
receive its canonical digest. Files, paths, per-file digests, Merkle leaves,
credentials, and the full manifest stay off-chain.

## Components

| Path | Responsibility |
| --- | --- |
| `chaincode-go/` | Immutable `CreateAnchor`, `ReadAnchor`, and `AnchorExists` transactions |
| `gateway/` | TLS Gateway connection, commit receipt handling, local pack verification, and CLI automation |
| `../../docs/spec/FABRIC_ANCHOR_SPEC.md` | Frozen state, transaction, privacy, and error contract |
| `../../docs/records/fabric-e2e/2026-07-12-v0.5.1/` | Sanitized two-organization `v0.5.1` release-artifact evidence |

## Prerequisites

- Hyperledger Fabric samples test-network with Org1 and Org2.
- Go 1.23 or newer for chaincode tests.
- Node.js 20 or newer for the Gateway adapter.
- A built MoonEvidence CLI (`moon build --target js`).

The commands below assume the Fabric binaries and Docker test-network are
already installed. The test-network is an integration environment; production
governance, identity enrollment, availability, and timestamp policy are
deployment responsibilities.

## 1. Start A Dedicated Channel

From `fabric-samples/test-network`:

```bash
./network.sh up createChannel -c evidencechannel
```

If the network is already running, create and join `evidencechannel` with the
same test-network scripts. A dedicated channel keeps the evidence experiment
isolated from course and application traffic.

## 2. Test And Deploy The Chaincode

From this repository:

```bash
cd integrations/fabric/chaincode-go
go test -race ./...
```

From `fabric-samples/test-network`, point `-ccp` at the chaincode directory:

```bash
./network.sh deployCC \
  -c evidencechannel \
  -ccn moonevidence \
  -ccp /absolute/path/to/MoonEvidence/integrations/fabric/chaincode-go \
  -ccl go \
  -ccv 1.0 \
  -ccs 1
```

The source path must be visible to the Fabric CLI process. With a Dockerized
CLI wrapper, place the chaincode under a directory mounted into that container.
The default channel endorsement policy is used; on the two-organization sample
channel this requires both organizations.

Confirm the committed definition from both organizations:

```bash
peer lifecycle chaincode querycommitted \
  --channelID evidencechannel \
  --name moonevidence
```

## 3. Create A Local Gateway Profile

Copy `gateway/profiles/test-network-org1.example.json` to a file under
`gateway/.local/` and replace the three certificate/key paths with the test
network's actual files. `gateway/.local/` and `profiles/*.local.json` are Git
ignored. Keep private keys and real identity profiles in those local paths;
commit only the example profile shape.

On Windows, Node.js can read a WSL identity through a UNC path such as:

```text
\\wsl.localhost\<distribution>\root\fabric-samples\test-network\organizations\...
```

Create an Org2 profile by changing the MSP, endpoint (`localhost:9051`), host
alias, and organization paths.

## 4. Build And Use The Adapter

From the repository root:

```powershell
moon build --target js
npm --prefix integrations/fabric/gateway ci
npm run fabric:check
npm run fabric:test
npm run fabric:build
```

Create a self-contained pack in one command:

```powershell
node _build/js/debug/build/src/cmd/main/main.js pack .\my-files `
  -o .\my-evidence-pack --subject-id dataset-001 --json
```

Verify locally and submit only its canonical manifest digest:

```powershell
node integrations/fabric/gateway/dist/src/cli.js anchor-pack `
  .\my-evidence-pack `
  --profile integrations/fabric/gateway/.local/org1.json `
  --moon-cli _build/js/debug/build/src/cmd/main/main.js `
  --json
```

Query the ledger and feed the recorded digest back into MoonEvidence:

```powershell
node integrations/fabric/gateway/dist/src/cli.js verify-anchor `
  .\my-evidence-pack `
  --profile integrations/fabric/gateway/.local/org1.json `
  --manifest-digest sha256:<64-lowercase-hex> `
  --moon-cli _build/js/debug/build/src/cmd/main/main.js `
  --json
```

The commit receipt contains the submitted transaction ID, block number,
numeric validation status, and `successful` flag. A sequential duplicate is
reported as `already_anchored` and preserves the original anchor transaction
ID. A concurrent transaction is normalized only when Fabric returns validation
code 11 (`MVCC_READ_CONFLICT`) and a ledger query finds the same digest. It is
reported as `already_anchored_after_conflict` together with the rejected commit
status; no other rejection code is converted into success.

## 5. Programmatic Node.js Use

After `npm run fabric:build`, the package entry point exports the supported
adapter surface:

```javascript
import {
  connectFabric,
  loadFabricProfile,
  submitAnchor,
} from "./integrations/fabric/gateway/dist/src/index.js";

const profile = loadFabricProfile("./gateway.local.json");
const session = await connectFabric(profile);
try {
  const receipt = await submitAnchor(
    session.contract,
    "sha256:<64-lowercase-hex>",
  );
  console.log(receipt);
} finally {
  session.close();
}
```

Application code should normally use `anchor-pack`, which performs local
`inspect` and `verify` before submission. The lower-level `anchor` command and
`submitAnchor()` API are intended for systems that already enforce that
precondition.

## Verification Evidence

The recorded two-organization experiment used the deterministic `v0.5.1`
module archive, Fabric v3.1.4 peers/orderer, and chaincode `moonevidence` 1.0
sequence 1 on `evidencechannel`. It observed:

- the downloaded GitHub Release archive passed its published SHA-256 sidecar;
- its evidence digest committed `VALID` in block 16;
- Org1 and Org2 returned the same immutable record;
- an Org2 duplicate preserved the original transaction ID;
- the original pack passed ledger-backfed verification;
- payload-only tampering produced exactly `E2003`;
- payload tampering followed by manifest regeneration produced exactly
  `E2004` against the original ledger anchor.

See the sanitized record directory linked above for transaction IDs, package
ID, block hashes, and complete result envelopes.
