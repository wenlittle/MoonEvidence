import type { WorkerRequest, WorkerResponse } from "../types";

type MoonApi = Record<string, (payload: string) => string>;

let apiPromise: Promise<MoonApi> | null = null;

function loadApi(): Promise<MoonApi> {
  if (!apiPromise) {
    const apiUrl = import.meta.env.DEV
      ? new URL("/moon-api.js", self.location.origin)
      : new URL("../moon-api.js", self.location.href);
    apiPromise = fetch(apiUrl)
      .then((response) => {
        if (!response.ok) throw new Error(`MoonBit API load failed: ${response.status}`);
        return response.text();
      })
      .then((source) => {
        const blobUrl = URL.createObjectURL(
          new Blob([source], { type: "text/javascript" }),
        );
        return import(/* @vite-ignore */ blobUrl).finally(() => URL.revokeObjectURL(blobUrl));
      }) as Promise<MoonApi>;
  }
  return apiPromise;
}

self.onmessage = async (event: MessageEvent<WorkerRequest>) => {
  const { id, method, payload } = event.data;
  try {
    const api = await loadApi();
    const fn = api[method];
    if (typeof fn !== "function") {
      throw new Error(`MoonBit API export not found: ${method}`);
    }
    const response: WorkerResponse = { id, ok: true, result: fn(payload) };
    self.postMessage(response);
  } catch (error) {
    const response: WorkerResponse = {
      id,
      ok: false,
      error: error instanceof Error ? error.message : String(error),
    };
    self.postMessage(response);
  }
};
