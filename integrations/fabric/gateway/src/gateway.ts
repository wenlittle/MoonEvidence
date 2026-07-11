import * as grpc from "@grpc/grpc-js";
import {
  connect,
  hash,
  signers,
  type Gateway,
} from "@hyperledger/fabric-gateway";
import { createPrivateKey } from "node:crypto";
import { readFile } from "node:fs/promises";

import type { ContractClient } from "./anchor.js";
import type { FabricProfile } from "./types.js";

export interface FabricSession {
  contract: ContractClient;
  close(): void;
}

export async function connectFabric(
  profile: FabricProfile,
): Promise<FabricSession> {
  const tlsRootCert = await readFile(profile.tls_certificate_path);
  const credentials = grpc.credentials.createSsl(tlsRootCert);
  const client = new grpc.Client(profile.peer_endpoint, credentials, {
    "grpc.ssl_target_name_override": profile.peer_host_alias,
  });

  const certificate = await readFile(profile.certificate_path);
  const privateKeyPem = await readFile(profile.private_key_path);
  const privateKey = createPrivateKey(privateKeyPem);
  const signer = signers.newPrivateKeySigner(privateKey);

  const gateway: Gateway = connect({
    client,
    identity: { mspId: profile.msp_id, credentials: certificate },
    signer,
    hash: hash.sha256,
    evaluateOptions: () => ({
      deadline: Date.now() + profile.timeouts_ms.evaluate,
    }),
    endorseOptions: () => ({
      deadline: Date.now() + profile.timeouts_ms.endorse,
    }),
    submitOptions: () => ({
      deadline: Date.now() + profile.timeouts_ms.submit,
    }),
    commitStatusOptions: () => ({
      deadline: Date.now() + profile.timeouts_ms.commit_status,
    }),
  });

  const network = gateway.getNetwork(profile.channel);
  const contract = network.getContract(
    profile.chaincode,
  ) as unknown as ContractClient;
  return {
    contract,
    close() {
      gateway.close();
      client.close();
    },
  };
}
