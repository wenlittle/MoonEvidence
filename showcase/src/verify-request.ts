export type VerifyEvidenceRequest = {
  manifest: string;
  files: Record<string, string>;
  version_chain?: string;
};

export function buildVerifyEvidenceRequest(
  manifest: string,
  files: Record<string, string>,
  versionChainText: string | null,
): VerifyEvidenceRequest {
  const request: VerifyEvidenceRequest = { manifest, files };
  if (versionChainText !== null) request.version_chain = versionChainText;
  return request;
}
