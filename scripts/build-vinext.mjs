import { stat } from "node:fs/promises";
import { spawnSync } from "node:child_process";

const startedAt = Date.now();
const result = spawnSync(
  process.execPath,
  ["node_modules/vinext/dist/cli.js", "build"],
  {
    env: process.env,
    encoding: "utf8",
    maxBuffer: 20 * 1024 * 1024,
    stdio: ["inherit", "pipe", "pipe"],
    windowsHide: true,
  },
);

process.stdout.write(result.stdout ?? "");
process.stderr.write(result.stderr ?? "");

if (result.status === 0) {
  process.exit(0);
}

const combinedOutput = `${result.stdout ?? ""}${result.stderr ?? ""}`;
const requiredArtifacts = ["dist/client/index.html", "dist/server/index.js"];
let artifactsAreFresh = true;

for (const path of requiredArtifacts) {
  try {
    const details = await stat(path);
    if (details.mtimeMs < startedAt - 1_000) {
      artifactsAreFresh = false;
    }
  } catch {
    artifactsAreFresh = false;
  }
}

const completedBeforeWindowsShutdownCrash =
  process.platform === "win32" &&
  combinedOutput.includes("Build complete.") &&
  /Assertion failed:.*UV_HANDLE_CLOSING/s.test(combinedOutput) &&
  artifactsAreFresh;

if (completedBeforeWindowsShutdownCrash) {
  console.warn(
    "\n[build] Vinext produced fresh artifacts before its Windows shutdown assertion; continuing.",
  );
  process.exit(0);
}

process.exit(typeof result.status === "number" ? result.status : 1);
