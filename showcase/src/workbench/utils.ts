import { toHex } from "../moon-rpc";

export type LoadedPack = {
  manifestText: string | null;
  files: Record<string, string>;
  directoryName: string;
};

type DirectoryFile = File & { webkitRelativePath?: string };

export async function readPackDirectory(fileList: FileList): Promise<LoadedPack> {
  const files: Record<string, string> = {};
  let manifestText: string | null = null;
  let directoryName = "selected-pack";

  for (const rawFile of Array.from(fileList) as DirectoryFile[]) {
    const parts = (rawFile.webkitRelativePath || rawFile.name).split("/");
    if (parts.length > 1) directoryName = parts[0];
    const relativePath = parts.length > 1 ? parts.slice(1).join("/") : rawFile.name;
    if (relativePath === "manifest.json") {
      manifestText = await rawFile.text();
    } else if (relativePath.startsWith("files/") || relativePath.startsWith("versions/")) {
      files[relativePath] = toHex(new Uint8Array(await rawFile.arrayBuffer()));
    }
  }

  return { manifestText, files, directoryName };
}

export async function readCreateFiles(fileList: FileList): Promise<Record<string, string>> {
  const files: Record<string, string> = {};
  for (const file of Array.from(fileList)) {
    files[`files/${file.name}`] = toHex(new Uint8Array(await file.arrayBuffer()));
  }
  return files;
}

export function utf8Hex(value: string): string {
  return toHex(new TextEncoder().encode(value));
}

export function canonicalLeafHex(path: string, size: number, digest: string): string {
  return utf8Hex(JSON.stringify({ digest, path, size }));
}

export function shortValue(value: string | null | undefined, length = 18): string {
  if (!value) return "-";
  const clean = value.includes(":") ? value.split(":").at(-1)! : value;
  return clean.length > length ? `${clean.slice(0, length)}...` : clean;
}

export function formatJson(value: unknown): string {
  if (typeof value === "string") {
    try {
      return JSON.stringify(JSON.parse(value), null, 2);
    } catch {
      return value;
    }
  }
  return JSON.stringify(value, null, 2);
}

export function downloadText(filename: string, content: string): void {
  const url = URL.createObjectURL(new Blob([content], { type: "application/json" }));
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  URL.revokeObjectURL(url);
}

export function flipHexByte(hex: string, offset = 0): string {
  if (hex.length < 2) return hex;
  const normalizedOffset = Math.max(0, Math.min(Math.floor(hex.length / 2) - 1, offset));
  const start = normalizedOffset * 2;
  const byte = Number.parseInt(hex.slice(start, start + 2), 16) ^ 0x01;
  return `${hex.slice(0, start)}${byte.toString(16).padStart(2, "0")}${hex.slice(start + 2)}`;
}

export function inputDirectoryProps(): Record<string, string> {
  return { webkitdirectory: "", directory: "" };
}
