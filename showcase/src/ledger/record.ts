export const ledgerRecord = {
  observedAt: "2026-07-11 13:45 CST",
  runtime: "Hyperledger Fabric v3.1.4",
  channel: "evidencechannel",
  chaincode: "moonevidence 1.0",
  organizations: ["Org1MSP", "Org2MSP"],
  digest: "sha256:16bbf1e91de3acfb8bd9091233926b454045c6d96c24327baec20272af583f1e",
  transactionId: "ca3dc7810d375ddabd3ba7d0bbba6f3e95a48c1224c6dfbd892d50edf7a28393",
  block: "6",
  validation: "VALID",
  duplicateBlock: "7",
  channelHeight: "8",
  paths: {
    record: "https://github.com/wenlittle/MoonEvidence/tree/main/docs/records/fabric-e2e/2026-07-11",
    transactions: "https://github.com/wenlittle/MoonEvidence/blob/main/docs/records/fabric-e2e/2026-07-11/transactions.json",
    verification: "https://github.com/wenlittle/MoonEvidence/blob/main/docs/records/fabric-e2e/2026-07-11/verification.json",
    guide: "https://github.com/wenlittle/MoonEvidence/tree/main/integrations/fabric",
  },
} as const;
